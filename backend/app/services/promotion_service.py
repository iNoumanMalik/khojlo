"""Special offers and promotional campaigns: status, visibility, labels and notifications.

Special Offer = the deal. Promotional Campaign = a promotion that highlights one or more of
a business's offers for a period. Neither stores its status: the owner only switches an
offer on (`is_active`) or publishes a campaign (`is_published`), and the dates decide the
rest, so nothing has to run at midnight for an offer to start or expire.
"""
from __future__ import annotations

import enum
from collections.abc import Iterable
from datetime import date, datetime

from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session, selectinload

from app.models.business import BusinessProfile, DealType, Offer
from app.models.campaign import Campaign
from app.models.notification import NotificationKind
from app.schemas.business import OfferOut
from app.services import notification_service as ns
from app.services.hours import to_local


class PromoState(str, enum.Enum):
    draft = "draft"  # not switched on / not published (or deactivated)
    scheduled = "scheduled"  # on, but starts later
    active = "active"  # on and within its dates: customers see it
    expired = "expired"  # past its end date


def local_today(now: datetime | None = None) -> date:
    """Today in the businesses' timezone (offers start and end on local calendar days)."""
    return to_local(now).date()


def _state(enabled: bool, start: date, end: date | None, today: date) -> PromoState:
    if end is not None and end < today:
        return PromoState.expired
    if not enabled:
        return PromoState.draft
    if start > today:
        return PromoState.scheduled
    return PromoState.active


# ─────────────── offers ───────────────
def offer_state(o: Offer, today: date) -> PromoState:
    return _state(o.is_active, o.start_date, o.end_date, today)


def offer_is_live(o: Offer, today: date) -> bool:
    return o.deleted_at is None and offer_state(o, today) is PromoState.active


def live_offers(offers: Iterable[Offer], today: date) -> list[Offer]:
    return [o for o in offers if offer_is_live(o, today)]


def offer_out(o: Offer, today: date) -> OfferOut:
    return OfferOut(
        id=o.id, title=o.title, description=o.description, deal_type=o.deal_type,
        deal_value=o.deal_value, deal_text=o.deal_text, deal_label=deal_label(o),
        start_date=o.start_date, end_date=o.end_date, terms=o.terms, is_active=o.is_active,
        status=offer_state(o, today).value, tone=o.tone, views=o.views,
        redemptions=o.redemptions,
    )


def current_offers(offers: Iterable[Offer]) -> list[Offer]:
    """The owner's list: everything not deleted."""
    return [o for o in offers if o.deleted_at is None]


def offer_may_be_live():
    """SQL pre-filter for "has a live offer"; `offer_is_live` checks the dates exactly."""
    return and_(
        Offer.business_id == BusinessProfile.id,
        Offer.deleted_at.is_(None),
        Offer.is_active.is_(True),
    )


def deal_label(o: Offer) -> str:
    """The short badge text: "20% OFF", "Rs 500 OFF", "BUY 1 GET 1", "FREE DESSERT"."""
    value = o.deal_value
    match o.deal_type:
        case DealType.percent_off if value:
            return f"{value:g}% OFF"
        case DealType.amount_off if value:
            return f"Rs {int(value):,} OFF"
        case DealType.bogo:
            return "BUY 1 GET 1"
        case DealType.free_item if o.deal_text:
            return f"FREE {o.deal_text.upper()}"
        case _:
            return o.deal_text or "SPECIAL OFFER"


def offer_problem(o: Offer) -> str | None:
    """Why an offer's fields don't add up (UC-11 "invalid dates" and the deal rules)."""
    if o.end_date is not None and o.end_date < o.start_date:
        return "The end date can't be before the start date."
    match o.deal_type:
        case DealType.percent_off if o.deal_value is None or not 1 <= o.deal_value <= 100:
            return "Enter a discount between 1% and 100%."
        case DealType.amount_off if o.deal_value is None or o.deal_value < 1:
            return "Enter how many rupees off the deal gives."
        case DealType.free_item if not o.deal_text.strip():
            return "Say what's free, e.g. “Dessert”."
        case DealType.other if not o.deal_text.strip():
            return "Add a short label for the deal, e.g. “Student deal”."
    return None


# ─────────────── campaigns ───────────────
def campaign_state(c: Campaign, today: date) -> PromoState:
    return _state(c.is_published, c.start_date, c.end_date, today)


def campaign_live_offers(c: Campaign, today: date) -> list[Offer]:
    return live_offers(c.offers, today)


def campaign_is_visible(c: Campaign, today: date) -> bool:
    """Customers see a campaign that's published, within its dates, of a published business,
    and still has at least one live offer to show."""
    return (
        c.deleted_at is None
        and campaign_state(c, today) is PromoState.active
        and c.business is not None
        and c.business.is_published
        and bool(campaign_live_offers(c, today))
    )


def visible_campaign(b: BusinessProfile, today: date) -> Campaign | None:
    """The business's live campaign (at most one is published at a time)."""
    for c in b.campaigns:
        if campaign_is_visible(c, today):
            return c
    return None


def campaign_problem(c: Campaign) -> str | None:
    if c.end_date < c.start_date:
        return "The end date can't be before the start date."
    return None


def publish_problem(db: Session, c: Campaign, today: date) -> tuple[int, str] | None:
    """Why this campaign can't be published: (HTTP status, message)."""
    if not c.business.is_verified:
        return 403, ("Only verified businesses can publish campaigns. Save it as a draft for "
                     "now; you can publish it once Khojlo verifies your business.")
    if c.end_date < today:
        return 422, "This campaign has already ended. Change its dates to publish it."
    usable = [o for o in c.offers if o.deleted_at is None
              and offer_state(o, today) in (PromoState.active, PromoState.scheduled)]
    if not usable:
        return 422, ("Link at least one active or scheduled offer first. "
                     "A campaign promotes your offers.")
    other = db.scalar(select(Campaign).where(
        Campaign.business_id == c.business_id,
        Campaign.id != c.id,
        Campaign.is_published.is_(True),
        Campaign.deleted_at.is_(None),
        Campaign.end_date >= today,
    ))
    if other is not None:
        return 409, (f"“{other.name}” is already published. You can run one campaign at a "
                     "time: unpublish it or wait until it ends.")
    return None


def campaigns_for_feed(db: Session, today: date) -> list[Campaign]:
    candidates = db.scalars(
        select(Campaign)
        .options(selectinload(Campaign.business).selectinload(BusinessProfile.category))
        .where(
            Campaign.is_published.is_(True),
            Campaign.deleted_at.is_(None),
            Campaign.start_date <= today,
            Campaign.end_date >= today,
        )
    )
    return [c for c in candidates if campaign_is_visible(c, today)]


# ─────────────── notifications (one per offer / campaign, when it goes live) ───────────────
def campaign_route(c: Campaign) -> str:
    return f"/campaign/{c.id}"


def offer_notice(db: Session, o: Offer, today: date, now: datetime):
    """Tell people who saved the business about an offer the first time it's live."""
    b = o.business
    if o.notified_at is not None or not b.is_published or not offer_is_live(o, today):
        return None
    o.notified_at = now
    return ns.notify(
        db, ns.users_who_saved(db, b), NotificationKind.offer,
        title=f"New offer at {b.name}",
        body=ns.snippet(o.title),
        route=ns.business_route(b),
    )


def campaign_notice(db: Session, c: Campaign, today: date, now: datetime):
    """If the owner opted in: tell savers once, when the campaign becomes visible."""
    if not c.notify_savers or c.notified_at is not None or not campaign_is_visible(c, today):
        return None
    c.notified_at = now
    b = c.business
    return ns.notify(
        db, ns.users_who_saved(db, b), NotificationKind.offer,
        title=f"{c.name} at {b.name}",
        body=ns.snippet(c.message or c.description or "New deals are on now."),
        route=campaign_route(c),
    )


def due_notices(db: Session, now: datetime) -> list:
    """Notifications owed by offers and campaigns that started since they were switched on
    (scheduled ones). Returns the push jobs; the caller commits, then runs them."""
    today = local_today(now)
    jobs = []
    offers = db.scalars(
        select(Offer).options(selectinload(Offer.business)).where(
            Offer.notified_at.is_(None), Offer.is_active.is_(True), Offer.deleted_at.is_(None),
            Offer.start_date <= today,
            or_(Offer.end_date.is_(None), Offer.end_date >= today),
        )
    )
    jobs += [offer_notice(db, o, today, now) for o in offers]
    campaigns = db.scalars(
        select(Campaign).where(
            Campaign.notify_savers.is_(True), Campaign.notified_at.is_(None),
            Campaign.is_published.is_(True), Campaign.deleted_at.is_(None),
            Campaign.start_date <= today, Campaign.end_date >= today,
        )
    )
    jobs += [campaign_notice(db, c, today, now) for c in campaigns]
    return [j for j in jobs if j is not None]
