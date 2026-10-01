"""Special offers and promotional campaigns (SRS FR-10, UC-11; SDD `Offer`, Algorithm 6).

Owners manage both from the dashboard. Customers see live offers on the business page and
live campaigns as Home banners, an "Active promotion" badge on cards, and campaign details.
Activating an offer or publishing a campaign needs a verified business (UC-11
precondition); drafts don't.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_owner, get_optional_user
from app.core.database import get_db
from app.models.business import BusinessProfile, Offer, Service
from app.models.campaign import Campaign, CampaignOffer, CampaignService, sync_links
from app.models.user import User
from app.schemas.business import OfferIn, OfferOut, OfferUpdate, ServiceOut
from app.schemas.campaign import CampaignBanner, CampaignIn, CampaignOut, CampaignUpdate
from app.services import moderation_rules as rules
from app.services import promotion_service as ps
from app.services.business_service import is_new_business, photo_out, to_card
from app.services.media_service import UnknownPhotos, delete_if_unused, resolve_keys

router = APIRouter(tags=["offers & campaigns"])

UNPROCESSABLE = 422
NOT_VERIFIED_OFFER = ("Only verified businesses can activate offers. Save it as a draft for "
                      "now; you can activate it once Khojlo verifies your business.")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _owns(user: User | None, b: BusinessProfile) -> bool:
    # SEC-2: only the owner. Admins moderate offers and campaigns through /admin.
    return user is not None and b.owner_id == user.id


def _business(db: Session, business_id: int) -> BusinessProfile:
    b = db.get(BusinessProfile, business_id)
    if b is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Business not found")
    return b


def _owned_business(db: Session, business_id: int, owner: User) -> BusinessProfile:
    b = _business(db, business_id)
    if not _owns(owner, b):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your business")
    return b


def _run(background_tasks: BackgroundTasks, jobs) -> None:
    for job in jobs:
        if job is not None:
            background_tasks.add_task(job)


# ─────────────── special offers ───────────────
def _offer(b: BusinessProfile, offer_id: int) -> Offer:
    o = next((o for o in b.offers if o.id == offer_id and o.deleted_at is None), None)
    if o is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    return o


def _check_offer(b: BusinessProfile, o: Offer, today) -> None:
    """SDD Algorithm 6 "validate": the deal and the dates (UC-11 "invalid dates")."""
    problem = ps.offer_problem(o)
    if problem:
        raise HTTPException(status_code=UNPROCESSABLE, detail=problem)
    if o.is_active:
        if not b.is_verified:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=NOT_VERIFIED_OFFER)
        if o.end_date is not None and o.end_date < today:
            raise HTTPException(status_code=UNPROCESSABLE,
                                detail="This offer has already ended. Change its end date to "
                                       "activate it.")


@router.get("/businesses/{business_id}/offers", response_model=list[OfferOut],
            summary="A business's offers (the owner sees all, others only live ones)")
def list_offers(
    business_id: int,
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
) -> list[OfferOut]:
    b = _business(db, business_id)
    today = ps.local_today()
    offers = ps.current_offers(b.offers) if _owns(user, b) else ps.live_offers(b.offers, today)
    return [ps.offer_out(o, today) for o in offers]


@router.post("/businesses/{business_id}/offers", response_model=OfferOut,
             status_code=status.HTTP_201_CREATED, summary="Create an offer")
def create_offer(
    business_id: int,
    payload: OfferIn,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> OfferOut:
    b = _owned_business(db, business_id, owner)
    today, now = ps.local_today(), _now()
    data = payload.model_dump()
    data["deal_text"] = data["deal_text"].strip()
    offer = Offer(business_id=b.id, **data)
    offer.business = b
    _check_offer(b, offer, today)
    db.add(offer)
    db.flush()
    rules.check_offer(db, offer)
    job = ps.offer_notice(db, offer, today, now)
    db.commit()
    db.refresh(offer)
    _run(background_tasks, [job])
    return ps.offer_out(offer, today)


@router.patch("/businesses/{business_id}/offers/{offer_id}", response_model=OfferOut,
              summary="Edit, activate or deactivate an offer")
def update_offer(
    business_id: int,
    offer_id: int,
    payload: OfferUpdate,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> OfferOut:
    b = _owned_business(db, business_id, owner)
    offer = _offer(b, offer_id)
    today, now = ps.local_today(), _now()
    changes = payload.model_dump(exclude_unset=True)
    for field, value in changes.items():
        if value is None and field != "end_date" and field != "deal_value":
            continue  # only these two may be cleared
        setattr(offer, field, value.strip() if field == "deal_text" else value)
    _check_offer(b, offer, today)
    offer.updated_at = now
    rules.check_offer(db, offer)
    job = ps.offer_notice(db, offer, today, now)
    db.commit()
    db.refresh(offer)
    _run(background_tasks, [job])
    return ps.offer_out(offer, today)


@router.delete("/businesses/{business_id}/offers/{offer_id}",
               status_code=status.HTTP_204_NO_CONTENT, response_class=Response,
               summary="Delete an offer")
def delete_offer(
    business_id: int,
    offer_id: int,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> Response:
    """Soft delete (SDD ER `deleted_at`). Campaigns that linked it simply stop showing it."""
    b = _owned_business(db, business_id, owner)
    offer = _offer(b, offer_id)
    offer.deleted_at = _now()
    offer.is_active = False
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ─────────────── promotional campaigns ───────────────
def campaign_banner(c: Campaign, today) -> CampaignBanner:
    live = ps.campaign_live_offers(c, today)
    return CampaignBanner(
        id=c.id, name=c.name, message=c.message, banner=photo_out(c.banner),
        tone=c.business.tone, start_date=c.start_date, end_date=c.end_date,
        business_id=c.business_id, business_name=c.business.name, offer_count=len(live),
        top_deal=ps.deal_label(live[0]) if live else None,
    )


def feed_banners(db: Session, now: datetime, *, limit: int = 8) -> list[CampaignBanner]:
    """Live campaigns for Home. New businesses first (SRS BR-6), then the soonest ending."""
    today = ps.local_today(now)
    campaigns = ps.campaigns_for_feed(db, today)
    campaigns.sort(key=lambda c: (not is_new_business(c.business, now), c.end_date, c.id))
    return [campaign_banner(c, today) for c in campaigns[:limit]]


def campaign_out(c: Campaign, today, *, for_owner: bool) -> CampaignOut:
    offers = [o for o in c.offers if o.deleted_at is None]
    if not for_owner:
        offers = ps.live_offers(offers, today)
    return CampaignOut(
        id=c.id,
        name=c.name,
        description=c.description,
        message=c.message,
        banner=photo_out(c.banner),
        start_date=c.start_date,
        end_date=c.end_date,
        terms=c.terms,
        is_published=c.is_published,
        notify_savers=c.notify_savers,
        status=ps.campaign_state(c, today).value,
        is_visible=ps.campaign_is_visible(c, today),
        offers=[ps.offer_out(o, today) for o in offers],
        services=[ServiceOut.model_validate(s) for s in c.services],
        business=to_card(c.business),
    )


def _campaign(b: BusinessProfile, campaign_id: int) -> Campaign:
    c = next((c for c in b.campaigns if c.id == campaign_id and c.deleted_at is None), None)
    if c is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Campaign not found")
    return c


def _link_offers(c: Campaign, b: BusinessProfile, offer_ids: list[int]) -> None:
    mine = {o.id: o for o in ps.current_offers(b.offers)}
    if len(set(offer_ids)) != len(offer_ids) or any(i not in mine for i in offer_ids):
        raise HTTPException(status_code=UNPROCESSABLE,
                            detail="Pick offers from your own offers list.")
    sync_links(c.offer_links, [mine[i] for i in offer_ids], "offer_id",
               lambda o, n: CampaignOffer(offer_id=o.id, offer=o, position=n))


def _link_services(c: Campaign, b: BusinessProfile, service_ids: list[int]) -> None:
    mine: dict[int, Service] = {s.id: s for s in b.services}
    if len(set(service_ids)) != len(service_ids) or any(i not in mine for i in service_ids):
        raise HTTPException(status_code=UNPROCESSABLE,
                            detail="Pick featured services from your own services.")
    sync_links(c.service_links, [mine[i] for i in service_ids], "service_id",
               lambda s, n: CampaignService(service_id=s.id, service=s, position=n))


def _set_banner(db: Session, c: Campaign, key: str | None, owner: User) -> set[int]:
    """Point the campaign at an uploaded photo; returns media that may now be unused."""
    previous = c.banner_media_id
    if key is None:
        c.banner_media_id, c.banner = None, None
    else:
        attached = {previous} if previous else set()
        try:
            (media,) = resolve_keys(db, [key], allowed_owner=owner.id, already_attached=attached)
        except UnknownPhotos:
            raise HTTPException(status_code=UNPROCESSABLE,
                                detail="The banner photo couldn't be found. Please upload it "
                                       "again.") from None
        c.banner_media_id, c.banner = media.id, media
    return {previous} if previous and previous != c.banner_media_id else set()


def _check_campaign(db: Session, c: Campaign, today) -> None:
    problem = ps.campaign_problem(c)
    if problem:
        raise HTTPException(status_code=UNPROCESSABLE, detail=problem)
    if c.is_published:
        blocked = ps.publish_problem(db, c, today)
        if blocked:
            raise HTTPException(status_code=blocked[0], detail=blocked[1])


@router.get("/businesses/{business_id}/campaigns", response_model=list[CampaignOut],
            summary="A business's campaigns (the owner sees all, others only the live one)")
def list_campaigns(
    business_id: int,
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
) -> list[CampaignOut]:
    b = _business(db, business_id)
    today = ps.local_today()
    owner = _owns(user, b)
    campaigns = [c for c in b.campaigns if c.deleted_at is None
                 and (owner or ps.campaign_is_visible(c, today))]
    return [campaign_out(c, today, for_owner=owner) for c in campaigns]


@router.post("/businesses/{business_id}/campaigns", response_model=CampaignOut,
             status_code=status.HTTP_201_CREATED, summary="Create a campaign")
def create_campaign(
    business_id: int,
    payload: CampaignIn,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> CampaignOut:
    b = _owned_business(db, business_id, owner)
    today, now = ps.local_today(), _now()
    data = payload.model_dump(exclude={"banner", "offer_ids", "service_ids"})
    c = Campaign(business_id=b.id, **data)
    c.business = b
    _link_offers(c, b, payload.offer_ids)
    _link_services(c, b, payload.service_ids)
    _set_banner(db, c, payload.banner, owner)
    _check_campaign(db, c, today)
    db.add(c)
    db.flush()
    rules.check_campaign(db, c)
    job = ps.campaign_notice(db, c, today, now)
    db.commit()
    db.refresh(c)
    _run(background_tasks, [job])
    return campaign_out(c, today, for_owner=True)


@router.patch("/businesses/{business_id}/campaigns/{campaign_id}", response_model=CampaignOut,
              summary="Edit, publish or unpublish a campaign")
def update_campaign(
    business_id: int,
    campaign_id: int,
    payload: CampaignUpdate,
    background_tasks: BackgroundTasks,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> CampaignOut:
    b = _owned_business(db, business_id, owner)
    c = _campaign(b, campaign_id)
    today, now = ps.local_today(), _now()
    changes = payload.model_dump(exclude_unset=True)
    unused: set[int] = set()
    for field in ("name", "description", "message", "start_date", "end_date", "terms",
                  "is_published", "notify_savers"):
        if changes.get(field) is not None:
            setattr(c, field, changes[field])
    if changes.get("offer_ids") is not None:
        _link_offers(c, b, changes["offer_ids"])
    if changes.get("service_ids") is not None:
        _link_services(c, b, changes["service_ids"])
    if "banner" in changes:
        unused = _set_banner(db, c, changes["banner"], owner)
    _check_campaign(db, c, today)
    c.updated_at = now
    db.flush()
    delete_if_unused(db, unused)
    rules.check_campaign(db, c)
    job = ps.campaign_notice(db, c, today, now)
    db.commit()
    db.refresh(c)
    _run(background_tasks, [job])
    return campaign_out(c, today, for_owner=True)


@router.delete("/businesses/{business_id}/campaigns/{campaign_id}",
               status_code=status.HTTP_204_NO_CONTENT, response_class=Response,
               summary="Delete a campaign")
def delete_campaign(
    business_id: int,
    campaign_id: int,
    owner: User = Depends(get_current_owner),
    db: Session = Depends(get_db),
) -> Response:
    """Soft delete. Its offers are untouched: a campaign only links them."""
    b = _owned_business(db, business_id, owner)
    c = _campaign(b, campaign_id)
    c.deleted_at = _now()
    c.is_published = False
    banner = {c.banner_media_id} if c.banner_media_id else set()
    c.banner_media_id = None
    db.flush()
    delete_if_unused(db, banner)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/campaigns/{campaign_id}", response_model=CampaignOut,
            summary="Campaign details (customers: only while it's live)")
def campaign_detail(
    campaign_id: int,
    db: Session = Depends(get_db),
    user: User | None = Depends(get_optional_user),
) -> CampaignOut:
    c = db.get(Campaign, campaign_id)
    today = ps.local_today()
    if c is None or c.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Campaign not found")
    owner = _owns(user, c.business)
    if not owner and not ps.campaign_is_visible(c, today):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="This promotion has ended.")
    return campaign_out(c, today, for_owner=owner)
