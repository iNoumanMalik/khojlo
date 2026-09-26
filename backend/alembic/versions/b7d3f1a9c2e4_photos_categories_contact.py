"""photos, specific categories, phone numbers and profile photos

Additive, so builds from before this revision keep working against the same database:
new tables (media, business_photos), new nullable columns, category columns with
defaults. Categories are upserted by slug: existing ones keep their ids (and so their
businesses) and get their new display names; the rest are inserted.

Revision ID: b7d3f1a9c2e4
Revises: 71c2ae544c86
Create Date: 2026-09-27 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7d3f1a9c2e4"
down_revision: Union[str, None] = "71c2ae544c86"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# (slug, name, emoji, group, tone, sort_order, search keywords)
CATEGORIES = [
    ("restaurants", "Restaurants", "🍽️", "Food & Drink", "gold", 10,
     "restaurant, dining, dinner, lunch, karahi, biryani, bbq, desi food"),
    ("cafes", "Cafés", "☕", "Food & Drink", "emerald", 11,
     "cafe, coffee, tea, chai, brunch, breakfast"),
    ("bakeries", "Bakeries & Sweets", "🧁", "Food & Drink", "coral", 12,
     "bakery, cake, sweets, mithai, dessert, ice cream, pastry"),
    ("street-food", "Street Food & Dhabas", "🍢", "Food & Drink", "gold", 13,
     "dhaba, chaat, samosa, paratha, gol gappay, food cart, street food"),
    ("fast-food", "Fast Food & Takeaway", "🍔", "Food & Drink", "coral", 14,
     "burger, pizza, shawarma, fries, takeaway, delivery"),
    ("clothing", "Clothing & Boutiques", "👗", "Shopping", "plum", 20,
     "clothes, boutique, fashion, dresses, shalwar kameez, shoes"),
    ("tailors", "Tailors & Fabric", "🧵", "Shopping", "emerald", 21,
     "tailor, darzi, stitching, alterations, fabric, cloth, unstitched"),
    ("grocery", "Grocery & Marts", "🛒", "Shopping", "emerald", 22,
     "grocery, kiryana, mart, supermarket, general store"),
    ("electronics", "Electronics & Mobiles", "📱", "Shopping", "ink", 23,
     "mobile, phone repair, laptop, computer, electronics, accessories"),
    ("books", "Books & Stationery", "📚", "Shopping", "gold", 24,
     "books, bookshop, stationery, printing, photocopy"),
    ("home-furniture", "Home & Furniture", "🛋️", "Shopping", "gold", 25,
     "furniture, home decor, kitchen, crockery, carpets"),
    ("shopping", "Shopping & Retail", "🛍️", "Shopping", "plum", 26,
     "shop, store, retail, gifts, handicrafts"),
    ("beauty", "Beauty & Salons", "💅", "Health & Beauty", "coral", 30,
     "salon, parlour, makeup, bridal, facial, nails, spa"),
    ("barbers", "Barbers & Grooming", "💈", "Health & Beauty", "ink", 31,
     "barber, haircut, hair salon, shave, beard, grooming"),
    ("gym", "Fitness & Gyms", "💪", "Health & Beauty", "emerald", 32,
     "gym, fitness, workout, yoga, martial arts, swimming"),
    ("healthcare", "Clinics & Doctors", "🩺", "Health & Beauty", "emerald", 33,
     "clinic, doctor, hospital, dentist, lab, physiotherapy, healthcare"),
    ("pharmacy", "Pharmacies", "💊", "Health & Beauty", "emerald", 34,
     "pharmacy, chemist, medical store, medicine"),
    ("education", "Education & Tutoring", "🎓", "Services", "gold", 40,
     "tuition, tutor, academy, school, courses, coaching"),
    ("home-services", "Home Services", "🔧", "Services", "ink", 41,
     "plumber, electrician, carpenter, ac repair, cleaning, painter"),
    ("auto", "Auto Repair & Car Wash", "🚗", "Services", "ink", 42,
     "mechanic, workshop, car wash, tyres, denting, bike repair"),
    ("laundry", "Laundry & Dry Cleaning", "🧺", "Services", "emerald", 43,
     "laundry, dry cleaning, dhobi, ironing"),
    ("events", "Events & Photography", "📸", "Services", "plum", 44,
     "wedding, catering, decor, photographer, marquee, event planner"),
    ("pets", "Pets & Vets", "🐾", "Services", "coral", 45,
     "pet shop, vet, veterinary, pet food, pet grooming"),
    ("gaming", "Gaming & Entertainment", "🎮", "Leisure", "ink", 50,
     "gaming, arcade, playstation, snooker, bowling, cinema"),
    ("hotels", "Hotels & Stays", "🏨", "Leisure", "gold", 51,
     "hotel, guest house, hostel, stay, rooms"),
    ("other", "Other", "✨", "Other", "ink", 99, ""),
]

# Display names before this revision, restored on downgrade.
PREVIOUS_NAMES = {
    "cafes": "Cafés", "restaurants": "Restaurants", "beauty": "Beauty", "gym": "Fitness",
    "healthcare": "Healthcare", "gaming": "Gaming", "education": "Education",
    "shopping": "Shopping",
}

UPSERT = sa.text(
    "INSERT INTO categories (slug, name, tone, emoji, group_name, sort_order, keywords) "
    "VALUES (:slug, :name, :tone, :emoji, :group_name, :sort_order, :keywords) "
    "ON CONFLICT (slug) DO UPDATE SET name = excluded.name, emoji = excluded.emoji, "
    "group_name = excluded.group_name, sort_order = excluded.sort_order, "
    "keywords = excluded.keywords"
)


def upgrade() -> None:
    # ── categories: presentation + search fields ──
    op.add_column("categories", sa.Column("emoji", sa.String(length=16), nullable=False,
                                          server_default=""))
    op.add_column("categories", sa.Column("group_name", sa.String(length=40), nullable=False,
                                          server_default=""))
    op.add_column("categories", sa.Column("sort_order", sa.Integer(), nullable=False,
                                          server_default="0"))
    op.add_column("categories", sa.Column("keywords", sa.Text(), nullable=False,
                                          server_default=""))

    # ── contact details and the "Other" description ──
    op.add_column("businesses", sa.Column("custom_category", sa.String(length=60), nullable=True))
    op.add_column("businesses", sa.Column("phone", sa.String(length=24), nullable=True))
    op.add_column("users", sa.Column("phone", sa.String(length=24), nullable=True))
    op.add_column("users", sa.Column("avatar_media_id", sa.Integer(), nullable=True))

    # ── photos ──
    op.create_table(
        "media",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(length=32), nullable=False),
        sa.Column("owner_id", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(length=32), nullable=False),
        sa.Column("width", sa.Integer(), nullable=False),
        sa.Column("height", sa.Integer(), nullable=False),
        sa.Column("focal_x", sa.Float(), nullable=False),
        sa.Column("focal_y", sa.Float(), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("data", sa.LargeBinary(), nullable=False),
        sa.Column("thumb", sa.LargeBinary(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_media_key"), "media", ["key"], unique=True)
    op.create_index(op.f("ix_media_owner_id"), "media", ["owner_id"], unique=False)
    op.create_index(op.f("ix_media_created_at"), "media", ["created_at"], unique=False)

    op.create_table(
        "business_photos",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("business_id", sa.Integer(), nullable=False),
        sa.Column("media_id", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["business_id"], ["businesses.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["media_id"], ["media.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("business_id", "media_id", name="uq_business_photo"),
    )
    op.create_index(op.f("ix_business_photos_business_id"), "business_photos", ["business_id"],
                    unique=False)
    op.create_index(op.f("ix_business_photos_media_id"), "business_photos", ["media_id"],
                    unique=False)

    op.create_foreign_key("fk_users_avatar_media", "users", "media", ["avatar_media_id"], ["id"],
                          ondelete="SET NULL")

    # ── the category catalogue (SRS SCA-1: categories are data, not code) ──
    for slug, name, emoji, group, tone, sort_order, keywords in CATEGORIES:
        op.execute(UPSERT.bindparams(slug=slug, name=name, tone=tone, emoji=emoji,
                                     group_name=group, sort_order=sort_order,
                                     keywords=keywords))


def downgrade() -> None:
    added = [slug for slug, *_ in CATEGORIES if slug not in PREVIOUS_NAMES]
    op.execute(
        sa.text(
            "DELETE FROM categories WHERE slug IN :slugs AND NOT EXISTS "
            "(SELECT 1 FROM businesses WHERE businesses.category_id = categories.id)"
        ).bindparams(sa.bindparam("slugs", value=added, expanding=True))
    )
    for slug, name in PREVIOUS_NAMES.items():
        op.execute(sa.text("UPDATE categories SET name = :name WHERE slug = :slug")
                   .bindparams(name=name, slug=slug))

    op.drop_constraint("fk_users_avatar_media", "users", type_="foreignkey")
    op.drop_index(op.f("ix_business_photos_media_id"), table_name="business_photos")
    op.drop_index(op.f("ix_business_photos_business_id"), table_name="business_photos")
    op.drop_table("business_photos")
    op.drop_index(op.f("ix_media_created_at"), table_name="media")
    op.drop_index(op.f("ix_media_owner_id"), table_name="media")
    op.drop_index(op.f("ix_media_key"), table_name="media")
    op.drop_table("media")
    op.drop_column("users", "avatar_media_id")
    op.drop_column("users", "phone")
    op.drop_column("businesses", "phone")
    op.drop_column("businesses", "custom_category")
    op.drop_column("categories", "keywords")
    op.drop_column("categories", "sort_order")
    op.drop_column("categories", "group_name")
    op.drop_column("categories", "emoji")
