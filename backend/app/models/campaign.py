"""Promotional campaigns: how a business promotes one or more of its offers for a period.

A campaign never copies offer data; it links existing offers (`CampaignOffer`) and,
optionally, some of the business's services to feature. Like offers, whether it's draft,
scheduled, active or expired follows from `is_published` and the dates
(`promotion_service.campaign_state`).
"""
from datetime import date, datetime, timezone

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Campaign(Base):
    __tablename__ = "campaigns"

    id: Mapped[int] = mapped_column(primary_key=True)
    business_id: Mapped[int] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    # Short line for banners: "Special deals all weekend!"
    message: Mapped[str] = mapped_column(String(160), default="")
    banner_media_id: Mapped[int | None] = mapped_column(
        ForeignKey("media.id", ondelete="SET NULL"), nullable=True
    )
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date] = mapped_column(Date)
    terms: Mapped[str] = mapped_column(Text, default="")
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    # Owner opted in to telling people who saved the business when it goes live.
    notify_savers: Mapped[bool] = mapped_column(Boolean, default=False)
    notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    business = relationship("BusinessProfile", back_populates="campaigns")
    banner = relationship("Media", lazy="joined")
    offer_links = relationship(
        "CampaignOffer", cascade="all, delete-orphan", order_by="CampaignOffer.position",
        lazy="selectin",
    )
    service_links = relationship(
        "CampaignService", cascade="all, delete-orphan", order_by="CampaignService.position",
        lazy="selectin",
    )

    @property
    def offers(self) -> list:
        return [link.offer for link in self.offer_links]

    @property
    def services(self) -> list:
        return [link.service for link in self.service_links]


def sync_links(links: list, wanted: list, key: str, make) -> None:
    """Make `links` point at `wanted` (in order), reusing rows for items that stay.

    Replacing the whole list would insert the new rows before deleting the old ones and
    trip the (campaign, item) unique constraint, so kept rows are only re-positioned.
    """
    order = {item.id: n for n, item in enumerate(wanted)}
    for link in list(links):
        if getattr(link, key) in order:
            link.position = order.pop(getattr(link, key))
        else:
            links.remove(link)
    for item in wanted:
        if item.id in order:
            links.append(make(item, order[item.id]))
    links.sort(key=lambda link: link.position)


class CampaignOffer(Base):
    __tablename__ = "campaign_offers"
    __table_args__ = (UniqueConstraint("campaign_id", "offer_id", name="uq_campaign_offer"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    campaign_id: Mapped[int] = mapped_column(
        ForeignKey("campaigns.id", ondelete="CASCADE"), index=True
    )
    offer_id: Mapped[int] = mapped_column(ForeignKey("offers.id", ondelete="CASCADE"), index=True)
    position: Mapped[int] = mapped_column(Integer, default=0)

    offer = relationship("Offer", lazy="joined")


class CampaignService(Base):
    """A service the campaign features ("featured products/services")."""

    __tablename__ = "campaign_services"
    __table_args__ = (UniqueConstraint("campaign_id", "service_id", name="uq_campaign_service"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    campaign_id: Mapped[int] = mapped_column(
        ForeignKey("campaigns.id", ondelete="CASCADE"), index=True
    )
    service_id: Mapped[int] = mapped_column(
        ForeignKey("services.id", ondelete="CASCADE"), index=True
    )
    position: Mapped[int] = mapped_column(Integer, default=0)

    service = relationship("Service", lazy="joined")
