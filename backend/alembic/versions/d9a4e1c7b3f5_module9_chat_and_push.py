"""module 9: chat and messaging, plus push notifications (module 3)

Adds conversations and messages between customers and businesses (SDD `MESSAGE`), reports
of conversations for the Module 8 queue, the devices that receive push notifications, the
in-app Notifications list, and each user's notification settings.

Additive only: builds from before this revision keep working against the same database.

Revision ID: d9a4e1c7b3f5
Revises: c5e8a2d4f610
Create Date: 2026-09-28 18:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d9a4e1c7b3f5"
down_revision: Union[str, None] = "c5e8a2d4f610"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "conversations",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("customer_id", sa.Integer(), nullable=False),
        sa.Column("business_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("customer_last_read_id", sa.Integer(), nullable=True),
        sa.Column("business_last_read_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["customer_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["business_id"], ["businesses.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("customer_id", "business_id",
                            name="uq_conversation_customer_business"),
    )
    op.create_index("ix_conversations_customer_id", "conversations", ["customer_id"])
    op.create_index("ix_conversations_business_id", "conversations", ["business_id"])
    op.create_index("ix_conversations_last_message_at", "conversations", ["last_message_at"])

    op.create_table(
        "messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("conversation_id", sa.Integer(), nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=False),
        sa.Column("from_business", sa.Boolean(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("media_id", sa.Integer(), nullable=True),
        sa.Column("client_id", sa.String(length=36), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["conversation_id"], ["conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["sender_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["media_id"], ["media.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("conversation_id", "client_id", name="uq_message_client_id"),
    )
    op.create_index("ix_messages_conversation_id", "messages", ["conversation_id"])
    op.create_index("ix_messages_created_at", "messages", ["created_at"])

    op.create_table(
        "conversation_reports",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("conversation_id", sa.Integer(), nullable=False),
        sa.Column("reporter_id", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=16), nullable=False),
        sa.Column("note", sa.String(length=500), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default=sa.text("'open'")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["conversation_id"], ["conversations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("conversation_id", "reporter_id", name="uq_conversation_report"),
    )
    op.create_index("ix_conversation_reports_conversation_id", "conversation_reports",
                    ["conversation_id"])
    op.create_index("ix_conversation_reports_status", "conversation_reports", ["status"])

    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", sa.String(length=16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token"),
    )
    op.create_index("ix_device_tokens_user_id", "device_tokens", ["user_id"])

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("body", sa.String(length=500), nullable=False),
        sa.Column("route", sa.String(length=200), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_created_at", "notifications", ["created_at"])

    with op.batch_alter_table("users") as batch:
        batch.add_column(sa.Column("notification_prefs", sa.JSON(), nullable=False,
                                   server_default=sa.text("'{}'")))


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.drop_column("notification_prefs")
    op.drop_table("notifications")
    op.drop_table("device_tokens")
    op.drop_table("conversation_reports")
    op.drop_table("messages")
    op.drop_table("conversations")
