"""offers and promotional campaigns

Offers get the SDD's fields (description, discount as a deal type + value, real start and
end dates, terms), an on/off switch instead of a stored status, and soft delete. Campaigns
link existing offers (and optionally featured services) for a period.

Existing offers are converted, not dropped:
* the old free-text dates ("Jul 1") become real dates where they parse (in the year the
  offer was created), otherwise the offer starts on the day it was created, open-ended;
* Active / Scheduled → switched on; Ended → switched off and expired (end date in the past);
* "25% off" in a title becomes a percent deal; anything else a "Special offer" label;
* all of them count as already announced, so nobody is re-notified about old offers.

Revision ID: e7c2a9f4b1d8
Revises: d9a4e1c7b3f5
Create Date: 2026-09-29 12:00:00.000000

"""
import re
from datetime import date, datetime, timedelta, timezone
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e7c2a9f4b1d8"
down_revision: Union[str, None] = "d9a4e1c7b3f5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_PERCENT = re.compile(r"(\d{1,3})\s*%")


def _parse(text: str, year: int) -> date | None:
    text = (text or "").strip()
    if not text:
        return None
    for fmt in ("%Y-%m-%d", "%d %b %Y", "%b %d %Y", "%b %d, %Y"):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            pass
    for fmt in ("%b %d", "%B %d", "%d %b", "%d %B"):
        try:
            return datetime.strptime(f"{text} {year}", f"{fmt} %Y").date()
        except ValueError:
            pass
    return None


def upgrade() -> None:
    with op.batch_alter_table("offers") as batch:
        batch.add_column(sa.Column("description", sa.Text(), nullable=False, server_default=""))
        batch.add_column(sa.Column("deal_type", sa.String(length=16), nullable=False,
                                   server_default="other"))
        batch.add_column(sa.Column("deal_value", sa.Float(), nullable=True))
        batch.add_column(sa.Column("deal_text", sa.String(length=60), nullable=False,
                                   server_default=""))
        batch.add_column(sa.Column("start_date", sa.Date(), nullable=True))
        batch.add_column(sa.Column("end_date", sa.Date(), nullable=True))
        batch.add_column(sa.Column("terms", sa.Text(), nullable=False, server_default=""))
        batch.add_column(sa.Column("is_active", sa.Boolean(), nullable=False,
                                   server_default=sa.false()))
        batch.add_column(sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("notified_at", sa.DateTime(timezone=True), nullable=True))

    bind = op.get_bind()
    today = datetime.now(timezone.utc).date()
    rows = bind.execute(sa.text(
        "SELECT id, title, starts_on, ends_on, status, created_at FROM offers")).all()
    for oid, title, starts_on, ends_on, status, created_at in rows:
        created = created_at if isinstance(created_at, datetime) else datetime.now(timezone.utc)
        year = created.year
        start = _parse(starts_on, year) or created.date()
        end = _parse(ends_on, year)
        if end is not None and end < start:
            end = end.replace(year=end.year + 1)  # "Dec 20 – Jan 5"
        ended = str(status).lower() == "ended"
        if ended and (end is None or end >= today):
            end = today - timedelta(days=1)
            start = min(start, end)
        match = _PERCENT.search(title or "")
        deal_type, value, text = ("percent_off", float(match.group(1)), "") if match and \
            1 <= int(match.group(1)) <= 100 else ("other", None, "Special offer")
        bind.execute(sa.text(
            "UPDATE offers SET start_date=:start, end_date=:end, is_active=:active, "
            "deal_type=:dtype, deal_value=:value, deal_text=:text, notified_at=:notified "
            "WHERE id=:id"),
            {"start": start, "end": end, "active": not ended, "dtype": deal_type,
             "value": value, "text": text, "notified": created, "id": oid})

    with op.batch_alter_table("offers") as batch:
        batch.alter_column("start_date", existing_type=sa.Date(), nullable=False)
        batch.drop_column("starts_on")
        batch.drop_column("ends_on")
        batch.drop_column("status")

    op.create_table(
        "campaigns",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("business_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("message", sa.String(length=160), nullable=False),
        sa.Column("banner_media_id", sa.Integer(), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("terms", sa.Text(), nullable=False),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column("notify_savers", sa.Boolean(), nullable=False),
        sa.Column("notified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["business_id"], ["businesses.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["banner_media_id"], ["media.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_campaigns_business_id", "campaigns", ["business_id"])
    op.create_index("ix_campaigns_is_published", "campaigns", ["is_published"])

    op.create_table(
        "campaign_offers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("campaign_id", sa.Integer(), nullable=False),
        sa.Column("offer_id", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["campaign_id"], ["campaigns.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["offer_id"], ["offers.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("campaign_id", "offer_id", name="uq_campaign_offer"),
    )
    op.create_index("ix_campaign_offers_campaign_id", "campaign_offers", ["campaign_id"])
    op.create_index("ix_campaign_offers_offer_id", "campaign_offers", ["offer_id"])

    op.create_table(
        "campaign_services",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("campaign_id", sa.Integer(), nullable=False),
        sa.Column("service_id", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["campaign_id"], ["campaigns.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["service_id"], ["services.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("campaign_id", "service_id", name="uq_campaign_service"),
    )
    op.create_index("ix_campaign_services_campaign_id", "campaign_services", ["campaign_id"])
    op.create_index("ix_campaign_services_service_id", "campaign_services", ["service_id"])


def downgrade() -> None:
    op.drop_table("campaign_services")
    op.drop_table("campaign_offers")
    op.drop_table("campaigns")
    with op.batch_alter_table("offers") as batch:
        batch.add_column(sa.Column("starts_on", sa.String(length=40), nullable=False,
                                   server_default=""))
        batch.add_column(sa.Column("ends_on", sa.String(length=40), nullable=False,
                                   server_default=""))
        batch.add_column(sa.Column("status", sa.String(length=16), nullable=False,
                                   server_default="Active"))
    bind = op.get_bind()
    today = datetime.now(timezone.utc).date()
    rows = bind.execute(sa.text(
        "SELECT id, start_date, end_date, is_active, deleted_at FROM offers")).all()
    for oid, start, end, active, deleted in rows:
        status = ("Ended" if deleted or not active or (end and end < today)
                  else "Scheduled" if start > today else "Active")
        bind.execute(sa.text(
            "UPDATE offers SET starts_on=:s, ends_on=:e, status=:st WHERE id=:id"),
            {"s": f"{start:%b} {start.day}", "e": f"{end:%b} {end.day}" if end else "",
             "st": status, "id": oid})
    with op.batch_alter_table("offers") as batch:
        for column in ("notified_at", "deleted_at", "updated_at", "is_active", "terms",
                       "end_date", "start_date", "deal_text", "deal_value", "deal_type",
                       "description"):
            batch.drop_column(column)
