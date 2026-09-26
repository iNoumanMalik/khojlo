"""module 4: search, filtering and comparison

Adds the PKR price range to businesses, a numeric price to services, search-history
storage, and indexes for the columns search filters and sorts on. Additive only.

Revision ID: 71c2ae544c86
Revises: 4ff96035ae0a
Create Date: 2026-09-26 20:00:00.000000

"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '71c2ae544c86'
down_revision: str | None = '4ff96035ae0a'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('businesses', sa.Column('price_min', sa.Integer(), nullable=True))
    op.add_column('businesses', sa.Column('price_max', sa.Integer(), nullable=True))
    op.add_column('services', sa.Column('price_amount', sa.Integer(), nullable=True))

    op.create_index(op.f('ix_businesses_category_id'), 'businesses', ['category_id'], unique=False)
    op.create_index(op.f('ix_businesses_created_at'), 'businesses', ['created_at'], unique=False)
    op.create_index(op.f('ix_businesses_is_published'), 'businesses', ['is_published'], unique=False)

    op.create_table(
        'search_queries',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('query', sa.String(length=100), nullable=False),
        sa.Column('normalized', sa.String(length=100), nullable=False),
        sa.Column('filters', sa.JSON(), nullable=False),
        sa.Column('result_count', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_search_queries_user_id'), 'search_queries', ['user_id'], unique=False)
    op.create_index(op.f('ix_search_queries_normalized'), 'search_queries', ['normalized'], unique=False)
    op.create_index(op.f('ix_search_queries_created_at'), 'search_queries', ['created_at'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_search_queries_created_at'), table_name='search_queries')
    op.drop_index(op.f('ix_search_queries_normalized'), table_name='search_queries')
    op.drop_index(op.f('ix_search_queries_user_id'), table_name='search_queries')
    op.drop_table('search_queries')

    op.drop_index(op.f('ix_businesses_is_published'), table_name='businesses')
    op.drop_index(op.f('ix_businesses_created_at'), table_name='businesses')
    op.drop_index(op.f('ix_businesses_category_id'), table_name='businesses')

    op.drop_column('services', 'price_amount')
    op.drop_column('businesses', 'price_max')
    op.drop_column('businesses', 'price_min')
