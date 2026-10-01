"""Module 8 — rule-based flags (the design's "Spam" section; SRS FR-15).

Rules look at what people publish (reviews, business listings, offers and campaigns) and
at a few behaviour patterns (bursts of 5★ reviews from new accounts, duplicate listings,
the same message sent to many businesses). A match raises a `ModerationFlag` for an
admin. Nothing is hidden or changed automatically (BR-13), and editing the content so it
no longer matches clears the flag.

Private chat text is never scanned (SEC-5). Chat is only checked for mass messaging, and
the flag shows the pattern, not the messages.

Rules are deliberately simple and explainable: each flag says which rule fired and shows
the matching text. The word lists cover English and Roman Urdu.
"""
from __future__ import annotations

import logging
import re
from collections import defaultdict
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from functools import wraps

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.business import BusinessProfile, DealType, Offer
from app.models.campaign import Campaign
from app.models.chat import Message
from app.models.moderation import FlagLabel, FlagStatus, FlagTarget, ModerationFlag
from app.models.review import Review
from app.models.user import User

log = logging.getLogger("uvicorn.error")

# ─────────────── thresholds ───────────────
BURST_WINDOW = timedelta(hours=24)
BURST_NEW_ACCOUNT_AGE = timedelta(days=7)
BURST_MIN_REVIEWS = 3
MASS_MESSAGE_WINDOW = timedelta(hours=1)
MASS_MESSAGE_MIN_CONVERSATIONS = 5
MASS_MESSAGE_MIN_LENGTH = 12
DUPLICATE_RADIUS_KM = 0.2
EXTREME_DISCOUNT_PERCENT = 90


@dataclass(frozen=True)
class Hit:
    rule: str
    label: FlagLabel
    detail: str
    excerpt: str = ""


def _words(*items: str) -> re.Pattern:
    return re.compile(r"\b(?:" + "|".join(items) + r")\b", re.IGNORECASE)


# ─────────────── text patterns ───────────────
LINK = re.compile(
    r"(?:https?://|www\.)\S+|\b[\w-]+\.(?:com|pk|net|org|io|co|shop|store)(?:/\S*)?\b",
    re.IGNORECASE,
)
# Pakistani mobile numbers: 0300 1234567, +92 300-1234567, 0092 3001234567.
PHONE = re.compile(r"(?:\+92|0092|\b0)\s?3\d{2}[\s-]?\d{7}\b")
WHATSAPP = _words(r"wh?ats?\s?app", r"wa\.me", r"watsap")
WALLET = _words(
    r"jazz\s?cash", r"easy\s?paisa", r"sada\s?pay", r"naya\s?pay", r"raast",
    r"bank\s+transfer", r"send\s+(?:the\s+)?(?:money|payment|amount)", r"pay(?:ment)?\s+first",
)
ADVANCE = _words(
    r"advance", r"pehle", r"pahle", r"upfront", r"booking\s+(?:fee|amount)",
    r"token\s+(?:money|amount)", r"registration\s+fee", r"security\s+deposit",
)
PRIZE = _words(r"you(?:'ve|\s+have)?\s+won", r"lucky\s+draw", r"inaam", r"jackpot",
               r"prize\s+money")
PRIZE_ASK = _words(r"claim", r"fee", r"send", r"call", r"contact")
VULGAR = _words(
    # English
    r"fuck\w*", r"motherfuck\w*", r"shit", r"bitch\w*", r"bastards?", r"assholes?",
    r"sluts?", r"whores?", r"dicks?", r"pussy", r"cunts?",
    # Roman Urdu
    r"chutiy[ae]", r"chutia", r"harami", r"haramzad[ai]", r"kanjar[i]?", r"gandu",
    r"b[eh]h?[ae]nchod", r"bhanchod", r"mad[ae]rchod", r"randi", r"bhosd\w*", r"gashti",
    r"kutt[iy]",
)
ADULT = _words(
    r"escorts?", r"call\s?girls?", r"happy\s+ending", r"nudes?", r"xxx", r"porn\w*",
    r"adult\s+(?:videos?|movies?|content|services?)", r"sexy\s+massage", r"body\s+to\s+body",
    r"hook\s?ups?",
)
PROHIBITED = _words(
    r"charas", r"cocaine", r"heroin", r"ganja", r"marijuana", r"weed", r"hashish",
    r"shar[a]?ab", r"liquor", r"crystal\s+meth", r"meth",
    r"fake\s+(?:cnic|degrees?|documents?|passports?|licen[cs]es?)",
    r"unlicensed\s+(?:guns?|pistols?|weapons?)",
)


def _excerpt(text: str, match: re.Match, width: int = 50) -> str:
    """The match in context, kept within its own field (fields are joined by newlines),
    so editing another field doesn't change it."""
    line_start = text.rfind("\n", 0, match.start()) + 1
    line_end = text.find("\n", match.end())
    line_end = len(text) if line_end == -1 else line_end
    start = max(line_start, match.start() - width)
    end = min(line_end, match.end() + width)
    snippet = " ".join(text[start:end].split())
    return ("…" if start > line_start else "") + snippet + ("…" if end < line_end else "")


def _first(pattern: re.Pattern, text: str) -> re.Match | None:
    return pattern.search(text) if text else None


# Rules that only apply to reviews: a review has no reason to carry contact details.
REVIEW_ONLY_RULES = ("link_in_review", "phone_in_review", "whatsapp_in_review")
TEXT_RULES = (*REVIEW_ONLY_RULES, "advance_payment", "prize_scam", "vulgar_language",
              "adult_services", "prohibited_items")


def scan_text(text: str, *, review: bool = False) -> list[Hit]:
    """Text rules for one piece of content. `review` adds the contact-detail rules."""
    text = text or ""
    hits: list[Hit] = []
    if review:
        for rule, pattern, detail in (
            ("link_in_review", LINK, "A link in a review"),
            ("phone_in_review", PHONE, "A phone number in a review"),
            ("whatsapp_in_review", WHATSAPP, "Asks people to get in touch on WhatsApp"),
        ):
            if m := _first(pattern, text):
                hits.append(Hit(rule, FlagLabel.spam, detail, _excerpt(text, m)))
    wallet, advance = _first(WALLET, text), _first(ADVANCE, text)
    if wallet and advance:
        hits.append(Hit("advance_payment", FlagLabel.scam,
                        f"Asks for payment in advance ({wallet.group(0)})",
                        _excerpt(text, wallet)))
    prize = _first(PRIZE, text)
    if prize and _first(PRIZE_ASK, text):
        hits.append(Hit("prize_scam", FlagLabel.scam, "Looks like a prize or lottery scam",
                        _excerpt(text, prize)))
    for rule, pattern, label, detail in (
        ("vulgar_language", VULGAR, FlagLabel.offensive, "Offensive language"),
        ("adult_services", ADULT, FlagLabel.adult, "Mentions adult or sexual services"),
        ("prohibited_items", PROHIBITED, FlagLabel.prohibited, "Mentions prohibited items"),
    ):
        if m := _first(pattern, text):
            hits.append(Hit(rule, label, f"{detail} (“{m.group(0)}”)", _excerpt(text, m)))
    return hits


def _join(*parts: str | None) -> str:
    return "\n".join(p for p in parts if p)


# ─────────────── flag bookkeeping ───────────────
def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: datetime | None) -> datetime | None:
    if dt is not None and dt.tzinfo is None:  # SQLite returns naive datetimes
        return dt.replace(tzinfo=timezone.utc)
    return dt


def sync_flags(
    db: Session,
    *,
    target_type: FlagTarget,
    target_id: int,
    hits: Iterable[Hit],
    rules_checked: Iterable[str],
    business_id: int | None = None,
    user_id: int | None = None,
    now: datetime | None = None,
) -> list[ModerationFlag]:
    """Open a flag per hit (or refresh an open one), and clear open flags for rules that
    were checked this time but no longer match. Returns the flags newly opened."""
    now = now or _now()
    hits = {h.rule: h for h in hits}
    checked = set(rules_checked) | set(hits)
    existing = {
        f.rule: f
        for f in db.scalars(select(ModerationFlag).where(
            ModerationFlag.target_type == target_type,
            ModerationFlag.target_id == target_id,
            ModerationFlag.status == FlagStatus.open,
        ))
    }
    opened = []
    for rule, hit in hits.items():
        flag = existing.get(rule)
        if flag is not None:
            flag.detail, flag.excerpt, flag.updated_at = hit.detail, hit.excerpt, now
            continue
        # An admin already looked at this exact match and kept it: don't ask again.
        if _already_dismissed(db, target_type, target_id, hit):
            continue
        flag = ModerationFlag(
            target_type=target_type, target_id=target_id, business_id=business_id,
            user_id=user_id, rule=rule, label=hit.label, detail=hit.detail[:300],
            excerpt=hit.excerpt[:300], created_at=now,
        )
        db.add(flag)
        opened.append(flag)
    for rule, flag in existing.items():
        if rule in checked and rule not in hits:
            flag.status, flag.resolved_at = FlagStatus.cleared, now
    db.flush()
    return opened


def _already_dismissed(db: Session, target_type: FlagTarget, target_id: int, hit: Hit) -> bool:
    return db.scalar(select(ModerationFlag.id).where(
        ModerationFlag.target_type == target_type,
        ModerationFlag.target_id == target_id,
        ModerationFlag.rule == hit.rule,
        ModerationFlag.status == FlagStatus.dismissed,
        ModerationFlag.excerpt == hit.excerpt[:300],
    ).limit(1)) is not None


def never_fail(fn):
    """A rule bug must never break publishing: log it and carry on without flags."""

    @wraps(fn)
    def wrapper(*args, **kwargs):
        try:
            return fn(*args, **kwargs)
        except Exception:  # noqa: BLE001 — moderation is best-effort by design
            log.exception("Moderation rules failed in %s", fn.__name__)
            return []

    return wrapper


# ─────────────── what each kind of content runs ───────────────
@never_fail
def check_review(db: Session, review: Review, *, now: datetime | None = None
                 ) -> list[ModerationFlag]:
    now = now or _now()
    opened = sync_flags(
        db, target_type=FlagTarget.review, target_id=review.id,
        hits=scan_text(review.comment, review=True), rules_checked=TEXT_RULES,
        business_id=review.business_id, user_id=review.user_id, now=now,
    )
    if review.rating == 5:
        opened += _check_review_burst(db, review.business, now)
    return opened


def _check_review_burst(db: Session, business: BusinessProfile, now: datetime
                        ) -> list[ModerationFlag]:
    """Several 5★ reviews from brand-new accounts in a day: possibly bought reviews."""
    since, new_accounts = now - BURST_WINDOW, now - BURST_NEW_ACCOUNT_AGE
    count = db.scalar(
        select(func.count(Review.id)).join(User, User.id == Review.user_id).where(
            Review.business_id == business.id, Review.rating == 5,
            Review.deleted_at.is_(None), Review.created_at >= since,
            User.created_at >= new_accounts,
        )
    ) or 0
    if count < BURST_MIN_REVIEWS:
        return []
    hit = Hit("review_burst", FlagLabel.fake_reviews,
              f"{count} five-star reviews from new accounts within 24 hours")
    return sync_flags(db, target_type=FlagTarget.business, target_id=business.id, hits=[hit],
                      rules_checked=["review_burst"], business_id=business.id,
                      user_id=business.owner_id, now=now)


def business_text(b: BusinessProfile) -> str:
    return _join(b.name, b.tagline, b.description, b.custom_category,
                 *(s.name for s in b.services))


@never_fail
def check_business(db: Session, b: BusinessProfile, *, now: datetime | None = None
                   ) -> list[ModerationFlag]:
    hits = scan_text(business_text(b)) + _duplicates(db, b)
    return sync_flags(
        db, target_type=FlagTarget.business, target_id=b.id, hits=hits,
        rules_checked=(*TEXT_RULES, "duplicate_phone", "duplicate_listing"),
        business_id=b.id, user_id=b.owner_id, now=now,
    )


def _digits(phone: str | None) -> str:
    return re.sub(r"\D", "", phone or "")[-10:]


def _name_key(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def _duplicates(db: Session, b: BusinessProfile) -> list[Hit]:
    """The same phone number, or the same name next door, under a different owner."""
    from app.services.business_service import distance_km  # avoid an import cycle

    others = db.scalars(select(BusinessProfile).where(
        BusinessProfile.id != b.id, BusinessProfile.owner_id != b.owner_id))
    hits: list[Hit] = []
    phone, name = _digits(b.phone), _name_key(b.name)
    for other in others:
        if len(phone) == 10 and _digits(other.phone) == phone and not any(
                h.rule == "duplicate_phone" for h in hits):
            hits.append(Hit("duplicate_phone", FlagLabel.duplicate,
                            f"Same phone number as “{other.name}” (another owner)"))
        near = (b.latitude is not None and other.latitude is not None
                and distance_km(b.latitude, b.longitude, other.latitude, other.longitude)
                <= DUPLICATE_RADIUS_KM)
        if name and near and _name_key(other.name) == name and not any(
                h.rule == "duplicate_listing" for h in hits):
            hits.append(Hit("duplicate_listing", FlagLabel.duplicate,
                            f"Same name as “{other.name}” nearby (another owner)"))
    return hits


@never_fail
def check_offer(db: Session, o: Offer, *, now: datetime | None = None) -> list[ModerationFlag]:
    hits = scan_text(_join(o.title, o.description, o.deal_text, o.terms))
    if o.deal_type == DealType.percent_off and (o.deal_value or 0) >= EXTREME_DISCOUNT_PERCENT:
        hits.append(Hit("extreme_discount", FlagLabel.scam,
                        f"{o.deal_value:g}% off: an unusually large discount", o.title))
    return sync_flags(
        db, target_type=FlagTarget.offer, target_id=o.id, hits=hits,
        rules_checked=(*TEXT_RULES, "extreme_discount"), business_id=o.business_id,
        user_id=o.business.owner_id if o.business else None, now=now,
    )


@never_fail
def check_campaign(db: Session, c: Campaign, *, now: datetime | None = None
                   ) -> list[ModerationFlag]:
    return sync_flags(
        db, target_type=FlagTarget.campaign, target_id=c.id,
        hits=scan_text(_join(c.name, c.description, c.message, c.terms)),
        rules_checked=TEXT_RULES, business_id=c.business_id,
        user_id=c.business.owner_id if c.business else None, now=now,
    )


def _normalize(body: str) -> str:
    return " ".join(re.sub(r"[^\w\s]", "", body.lower()).split())


@never_fail
def check_mass_messaging(db: Session, sender: User, *, now: datetime | None = None
                         ) -> list[ModerationFlag]:
    """The same customer message sent to many businesses within an hour."""
    now = now or _now()
    rows = db.execute(select(Message.conversation_id, Message.body).where(
        Message.sender_id == sender.id, Message.from_business.is_(False),
        Message.created_at >= now - MASS_MESSAGE_WINDOW,
    )).all()
    conversations: dict[str, set[int]] = defaultdict(set)
    for conversation_id, body in rows:
        text = _normalize(body or "")
        if len(text) >= MASS_MESSAGE_MIN_LENGTH:
            conversations[text].add(conversation_id)
    widest = max((len(ids) for ids in conversations.values()), default=0)
    if widest < MASS_MESSAGE_MIN_CONVERSATIONS:
        return []
    hit = Hit("mass_messaging", FlagLabel.spam,
              f"Sent the same message to {widest} businesses within an hour")
    # Not cleared by later checks: the pattern happened, whatever comes next.
    return sync_flags(db, target_type=FlagTarget.user, target_id=sender.id, hits=[hit],
                      rules_checked=[], user_id=sender.id, now=now)
