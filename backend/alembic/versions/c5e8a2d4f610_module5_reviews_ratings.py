"""module 5: reviews and ratings

Turns the prototype `reviews` table into real reviews written by users (SDD ER diagram
`REVIEW`), and adds review photos, helpful votes and reports.

* The prototype rows had an author *name* but no account. They can't satisfy BR-4 (one
  review per business per user) or be edited by anyone, so they're removed; the seed
  script writes genuine demo reviews instead.
* `businesses.rating` / `review_count` were seeded numbers. They're recalculated here from
  the remaining reviews (SDD Algorithm 7), so every total shown matches real reviews.

Builds from before this revision only touched `reviews` in the seed script, which inserts
reviews just for catalogue businesses that have none; pull before seeding.

Revision ID: c5e8a2d4f610
Revises: b7d3f1a9c2e4
Create Date: 2026-09-27 18:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c5e8a2d4f610"
down_revision: Union[str, None] = "b7d3f1a9c2e4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("DELETE FROM reviews")

    with op.batch_alter_table("reviews") as batch:
        batch.drop_column("author_name")
        batch.drop_column("author_tone")
        batch.alter_column("body", new_column_name="comment", existing_type=sa.Text(),
                           existing_nullable=False)
        batch.add_column(sa.Column("user_id", sa.Integer(), nullable=False))
        batch.add_column(sa.Column("is_approved", sa.Boolean(), nullable=False,
                                   server_default=sa.text("true")))
        batch.add_column(sa.Column("helpful_count", sa.Integer(), nullable=False,
                                   server_default=sa.text("0")))
        batch.add_column(sa.Column("owner_reply", sa.Text(), nullable=True))
        batch.add_column(sa.Column("owner_reply_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True))
        batch.add_column(sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
        batch.create_foreign_key("fk_reviews_user_id_users", "users", ["user_id"], ["id"],
                                 ondelete="CASCADE")
        batch.create_check_constraint("ck_reviews_rating_range", "rating BETWEEN 1 AND 5")
    op.create_index("ix_reviews_user_id", "reviews", ["user_id"])
    op.create_index("ix_reviews_created_at", "reviews", ["created_at"])
    op.create_index("uq_reviews_user_business_active", "reviews", ["user_id", "business_id"],
                    unique=True, postgresql_where=sa.text("deleted_at IS NULL"),
                    sqlite_where=sa.text("deleted_at IS NULL"))

    op.create_table(
        "review_photos",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("review_id", sa.Integer(), nullable=False),
        sa.Column("media_id", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["review_id"], ["reviews.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["media_id"], ["media.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("review_id", "media_id", name="uq_review_photo"),
    )
    op.create_index("ix_review_photos_review_id", "review_photos", ["review_id"])
    op.create_index("ix_review_photos_media_id", "review_photos", ["media_id"])

    op.create_table(
        "review_votes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("review_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["review_id"], ["reviews.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("review_id", "user_id", name="uq_review_vote"),
    )
    op.create_index("ix_review_votes_review_id", "review_votes", ["review_id"])
    op.create_index("ix_review_votes_user_id", "review_votes", ["user_id"])

    op.create_table(
        "review_reports",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("review_id", sa.Integer(), nullable=False),
        sa.Column("reporter_id", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=16), nullable=False),
        sa.Column("note", sa.String(length=500), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["review_id"], ["reviews.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("review_id", "reporter_id", name="uq_review_report"),
    )
    op.create_index("ix_review_reports_review_id", "review_reports", ["review_id"])
    op.create_index("ix_review_reports_reporter_id", "review_reports", ["reporter_id"])
    op.create_index("ix_review_reports_status", "review_reports", ["status"])

    # No reviews remain, so every business starts from real (empty) totals.
    op.execute("UPDATE businesses SET rating = 0, review_count = 0")


def downgrade() -> None:
    op.drop_table("review_reports")
    op.drop_table("review_votes")
    op.drop_table("review_photos")
    op.drop_index("uq_reviews_user_business_active", table_name="reviews")
    op.drop_index("ix_reviews_created_at", table_name="reviews")
    op.drop_index("ix_reviews_user_id", table_name="reviews")
    op.execute("DELETE FROM reviews")
    with op.batch_alter_table("reviews") as batch:
        batch.drop_constraint("ck_reviews_rating_range", type_="check")
        batch.drop_constraint("fk_reviews_user_id_users", type_="foreignkey")
        for column in ("deleted_at", "updated_at", "owner_reply_at", "owner_reply",
                       "helpful_count", "is_approved", "user_id"):
            batch.drop_column(column)
        batch.alter_column("comment", new_column_name="body", existing_type=sa.Text(),
                           existing_nullable=False)
        batch.add_column(sa.Column("author_name", sa.String(length=120), nullable=False,
                                   server_default=""))
        batch.add_column(sa.Column("author_tone", sa.String(length=16), nullable=False,
                                   server_default="gold"))
