"""Seed the database with demo data so the feed and dashboard look alive.

Run with:  python -m app.db.seed
Idempotent: clears existing demo rows first.
"""
from __future__ import annotations

from sqlalchemy import delete, select

from app.core.database import Base, SessionLocal, engine
from app.core.security import hash_password
from app.models.business import (
    BusinessProfile,
    Category,
    Offer,
    OfferStatus,
    OpeningHours,
    Service,
)
from app.models.engagement import Review, SavedBusiness, SavedList
from app.models.user import User, UserRole

CATEGORIES = [
    ("cafes", "Cafés", "emerald"),
    ("restaurants", "Restaurants", "gold"),
    ("beauty", "Beauty", "coral"),
    ("gym", "Fitness", "emerald"),
    ("healthcare", "Healthcare", "emerald"),
    ("gaming", "Gaming", "ink"),
    ("education", "Education", "gold"),
]

# name, category slug, tone, tagline, price, lat, lng, rating, reviews, saves
BUSINESSES = [
    ("Brew & Bloom", "cafes", "emerald", "Specialty coffee & a wall of plants", "$$", 33.6844, 73.0479, 4.8, 214, 96),
    ("The Reading Room", "cafes", "gold", "Quiet corners, slow mornings", "$$", 33.6870, 73.0510, 4.7, 132, 61),
    ("Scoops & Swirls", "cafes", "emerald", "Small-batch dessert bar", "$", 33.6900, 73.0450, 4.9, 88, 40),
    ("Forno Italiano", "restaurants", "gold", "Wood-fired Neapolitan pizza", "$$", 33.6810, 73.0530, 4.7, 301, 120),
    ("Ramen no Michi", "restaurants", "gold", "18-hour tonkotsu broth", "$$", 33.6790, 73.0490, 4.8, 176, 84),
    ("Ember & Oak", "restaurants", "coral", "Live-fire seasonal plates", "$$$", 33.6930, 73.0470, 4.6, 143, 52),
    ("Iron & Ash Gym", "gym", "emerald", "Strength-first, no crowds", "$$", 33.6905, 73.0520, 4.6, 74, 33),
    ("Glow Studio", "beauty", "coral", "Skin, nails & slow beauty", "$$", 33.6865, 73.0465, 4.8, 121, 58),
    ("Pixel Arena", "gaming", "ink", "Next-gen consoles & LAN nights", "$", 33.6885, 73.0535, 4.5, 66, 29),
    ("Northlight Clinic", "healthcare", "emerald", "Same-day family care", "$$", 33.6840, 73.0420, 4.7, 89, 21),
    ("Verse Bookshop", "education", "gold", "Indie press & study loft", "$", 33.6912, 73.0498, 4.8, 54, 44),
    ("Mornings Café", "cafes", "coral", "All-day brunch & filter coffee", "$$", 33.6798, 73.0468, 4.6, 108, 51),
    ("The Dumpling Cart", "restaurants", "gold", "Hand-folded, steamed to order", "$", 33.6875, 73.0482, 4.9, 190, 77),
]

OFFERS = {
    "Brew & Bloom": [
        ("Buy one, plant one — free seedling", "Jul 1", "Jul 20", OfferStatus.active, "emerald", 96, 40),
    ],
    "Forno Italiano": [
        ("Family pizza night — 25% off", "Jul 5", "Aug 5", OfferStatus.active, "gold", 210, 33),
    ],
}

REVIEWS = [
    ("Ayesha K.", "plum", 5, "Cosy spot with genuinely great coffee — quickly became my go-to for slow mornings."),
    ("Bilal R.", "emerald", 5, "Coffee is on another level and the staff remembered my order."),
    ("Sana M.", "gold", 4, "Cosy and quiet — perfect for getting work done."),
    ("Hamza T.", "coral", 5, "Found this through Khojlo before it blew up. Hidden gem for real."),
]


def reset(db) -> None:
    for model in (SavedBusiness, SavedList, Review, Offer, Service, OpeningHours, BusinessProfile, Category):
        db.execute(delete(model))
    db.execute(delete(User))
    db.commit()


def run() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        reset(db)

        cats = {}
        for slug, name, tone in CATEGORIES:
            c = Category(slug=slug, name=name, tone=tone)
            db.add(c)
            cats[slug] = c
        db.flush()

        owner = User(
            email="owner@khojlo.app",
            full_name="Sara Owner",
            hashed_password=hash_password("password123"),
            role=UserRole.business_owner,
            avatar_tone="plum",
        )
        customer = User(
            email="customer@khojlo.app",
            full_name="Ali Customer",
            hashed_password=hash_password("password123"),
            role=UserRole.customer,
            avatar_tone="gold",
            interests=["cafes", "restaurants"],
        )
        admin = User(
            email="admin@khojlo.app",
            full_name="Admin",
            hashed_password=hash_password("password123"),
            role=UserRole.admin,
        )
        db.add_all([owner, customer, admin])
        db.flush()

        biz_by_name: dict[str, BusinessProfile] = {}
        for name, slug, tone, tagline, price, lat, lng, rating, reviews, saves in BUSINESSES:
            b = BusinessProfile(
                owner_id=owner.id,
                category_id=cats[slug].id,
                name=name,
                tone=tone,
                tagline=tagline,
                description=f"{tagline}. {name} is one of the city's newest finds on Khojlo.",
                price_level=price,
                address="Blue Area, Islamabad",
                latitude=lat,
                longitude=lng,
                rating=rating,
                review_count=reviews,
                save_count=saves,
                view_count=reviews * 6,
                is_verified=True,
                images=[],
            )
            for day in range(7):
                b.hours.append(
                    OpeningHours(day_of_week=day, opens="09:00", closes="22:00", is_closed=day == 6)
                )
            b.services.append(Service(name="Signature experience", price=price))
            db.add(b)
            biz_by_name[name] = b
        db.flush()

        for bname, offers in OFFERS.items():
            for title, s, e, status_, tone, views, red in offers:
                db.add(
                    Offer(
                        business_id=biz_by_name[bname].id,
                        title=title,
                        starts_on=s,
                        ends_on=e,
                        status=status_,
                        tone=tone,
                        views=views,
                        redemptions=red,
                    )
                )

        for i, (author, tone, rating, body) in enumerate(REVIEWS):
            target = list(biz_by_name.values())[i]
            db.add(
                Review(
                    business_id=target.id,
                    author_name=author,
                    author_tone=tone,
                    rating=rating,
                    body=body,
                )
            )

        # a saved list for the demo customer
        weekend = SavedList(user_id=customer.id, name="Weekend", tone="gold")
        weekend.items.append(SavedBusiness(business_id=biz_by_name["Brew & Bloom"].id))
        weekend.items.append(SavedBusiness(business_id=biz_by_name["Forno Italiano"].id))
        coffee = SavedList(user_id=customer.id, name="Coffee tour", tone="emerald")
        coffee.items.append(SavedBusiness(business_id=biz_by_name["The Reading Room"].id))
        db.add_all([weekend, coffee])

        db.commit()
        print(f"Seeded {len(BUSINESSES)} businesses, {len(CATEGORIES)} categories, 3 users.")
    finally:
        db.close()


if __name__ == "__main__":
    run()
