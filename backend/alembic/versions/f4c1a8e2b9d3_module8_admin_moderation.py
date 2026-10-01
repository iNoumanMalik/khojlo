"""Module 8: admin and moderation

Adds, without changing or dropping anything that exists:
* businesses: verification status and note, who verified it and when, the storefront
  photo, and suspension;
* users: ban and suspension;
* conversations: blocking, and closing by a moderator;
* review and conversation reports: who resolved them and when;
* new tables: business_reports, moderation_flags (the automatic rules) and
  moderation_actions (the audit log).

Businesses that already have the Verified badge get the "verified" status (dated from
when they joined), so nobody loses a badge. Everyone else starts "unverified" and is
verified automatically once they pass the checks.

Revision ID: f4c1a8e2b9d3
Revises: e7c2a9f4b1d8
Create Date: 2026-09-30 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "f4c1a8e2b9d3"
down_revision: Union[str, None] = "e7c2a9f4b1d8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("businesses") as batch:
        batch.add_column(sa.Column("verification_status", sa.String(length=16), nullable=False,
                                   server_default="unverified"))
        batch.add_column(sa.Column("verification_note", sa.String(length=500), nullable=False,
                                   server_default=""))
        batch.add_column(sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("verified_by_id", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("storefront_media_id", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("storefront_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("suspended_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("suspension_reason", sa.String(length=16), nullable=True))
        batch.create_foreign_key("fk_businesses_verified_by_id_users", "users",
                                 ["verified_by_id"], ["id"], ondelete="SET NULL")
        batch.create_foreign_key("fk_businesses_storefront_media_id_media", "media",
                                 ["storefront_media_id"], ["id"], ondelete="SET NULL")
        batch.create_index("ix_businesses_verification_status", ["verification_status"])

    # Keep every existing badge.
    op.execute(
        "UPDATE businesses SET verification_status = 'verified', verified_at = created_at "
        "WHERE is_verified"
    )

    with op.batch_alter_table("users") as batch:
        batch.add_column(sa.Column("is_banned", sa.Boolean(), nullable=False,
                                   server_default=sa.false()))
        batch.add_column(sa.Column("suspended_until", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("suspension_reason", sa.String(length=16), nullable=True))

    with op.batch_alter_table("conversations") as batch:
        batch.add_column(sa.Column("blocked_by", sa.String(length=16), nullable=True))
        batch.add_column(sa.Column("blocked_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True))

    for table in ("review_reports", "conversation_reports"):
        with op.batch_alter_table(table) as batch:
            batch.add_column(sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True))
            batch.add_column(sa.Column("resolved_by_id", sa.Integer(), nullable=True))
            batch.create_foreign_key(f"fk_{table}_resolved_by_id_users", "users",
                                     ["resolved_by_id"], ["id"], ondelete="SET NULL")

    op.create_table(
        "business_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("business_id", sa.Integer(),
                  sa.ForeignKey("businesses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reporter_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False),
        sa.Column("reason", sa.String(length=16), nullable=False),
        sa.Column("note", sa.String(length=500), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_by_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.UniqueConstraint("business_id", "reporter_id", name="uq_business_report"),
    )
    op.create_index("ix_business_reports_business_id", "business_reports", ["business_id"])
    op.create_index("ix_business_reports_status", "business_reports", ["status"])

    op.create_table(
        "moderation_flags",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("target_type", sa.String(length=16), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column("business_id", sa.Integer(),
                  sa.ForeignKey("businesses.id", ondelete="CASCADE"), nullable=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=True),
        sa.Column("rule", sa.String(length=40), nullable=False),
        sa.Column("label", sa.String(length=16), nullable=False),
        sa.Column("detail", sa.String(length=300), nullable=False),
        sa.Column("excerpt", sa.String(length=300), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_by_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
    )
    op.create_index("ix_moderation_flags_target", "moderation_flags",
                    ["target_type", "target_id"])
    op.create_index("ix_moderation_flags_business_id", "moderation_flags", ["business_id"])
    op.create_index("ix_moderation_flags_user_id", "moderation_flags", ["user_id"])
    op.create_index("ix_moderation_flags_status", "moderation_flags", ["status"])
    op.create_index("ix_moderation_flags_created_at", "moderation_flags", ["created_at"])

    op.create_table(
        "moderation_actions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("admin_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"),
                  nullable=True),
        sa.Column("action", sa.String(length=32), nullable=False),
        sa.Column("target_type", sa.String(length=16), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column("subject_user_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("reason", sa.String(length=16), nullable=True),
        sa.Column("note", sa.String(length=1000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_moderation_actions_action", "moderation_actions", ["action"])
    op.create_index("ix_moderation_actions_subject_user_id", "moderation_actions",
                    ["subject_user_id"])
    op.create_index("ix_moderation_actions_created_at", "moderation_actions", ["created_at"])


def downgrade() -> None:
    op.drop_table("moderation_actions")
    op.drop_table("moderation_flags")
    op.drop_table("business_reports")
    for table in ("conversation_reports", "review_reports"):
        with op.batch_alter_table(table) as batch:
            batch.drop_constraint(f"fk_{table}_resolved_by_id_users", type_="foreignkey")
            batch.drop_column("resolved_by_id")
            batch.drop_column("resolved_at")
    with op.batch_alter_table("conversations") as batch:
        batch.drop_column("closed_at")
        batch.drop_column("blocked_at")
        batch.drop_column("blocked_by")
    with op.batch_alter_table("users") as batch:
        batch.drop_column("suspension_reason")
        batch.drop_column("suspended_until")
        batch.drop_column("is_banned")
    with op.batch_alter_table("businesses") as batch:
        batch.drop_index("ix_businesses_verification_status")
        batch.drop_constraint("fk_businesses_storefront_media_id_media", type_="foreignkey")
        batch.drop_constraint("fk_businesses_verified_by_id_users", type_="foreignkey")
        for column in ("suspension_reason", "suspended_at", "storefront_at",
                       "storefront_media_id", "verified_by_id", "verified_at",
                       "verification_note", "verification_status"):
            batch.drop_column(column)
