"""privacy consent and account deletion

Records which privacy policy version each user agreed to, and when. Lets profile views
outlive the viewer's account (`business_views.viewer_id` becomes null instead of blocking
the delete), so users can delete their accounts.

Additive only: builds from before this revision keep working against the same database.

Revision ID: e3b7c9a1f2d4
Revises: f4c1a8e2b9d3
Create Date: 2026-09-30 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e3b7c9a1f2d4"
down_revision: Union[str, None] = "f4c1a8e2b9d3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# PostgreSQL's name for the unnamed constraint the initial schema created.
VIEWER_FK = "business_views_viewer_id_fkey"


def upgrade() -> None:
    op.add_column("users", sa.Column("privacy_policy_version", sa.String(length=32), nullable=True))
    op.add_column(
        "users", sa.Column("privacy_consent_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.drop_constraint(VIEWER_FK, "business_views", type_="foreignkey")
    op.create_foreign_key(
        VIEWER_FK, "business_views", "users", ["viewer_id"], ["id"], ondelete="SET NULL"
    )


def downgrade() -> None:
    op.drop_constraint(VIEWER_FK, "business_views", type_="foreignkey")
    op.create_foreign_key(VIEWER_FK, "business_views", "users", ["viewer_id"], ["id"])
    op.drop_column("users", "privacy_consent_at")
    op.drop_column("users", "privacy_policy_version")
