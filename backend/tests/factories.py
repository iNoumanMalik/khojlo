"""Test data for the Module 4 search / compare tests.

Businesses are inserted straight into the test database so tests can control fields the
public API doesn't expose (rating, verification, age).
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from app.models.business import (
    BusinessProfile,
    Category,
    Offer,
    OpeningHours,
    Service,
)
from app.models.user import User, UserRole
from tests.conftest import TestingSessionLocal

# Wednesday 23 Sep 2026, 12:00 in Asia/Karachi (UTC+5).
FROZEN_NOW = datetime(2026, 9, 23, 7, 0, tzinfo=timezone.utc)
# Wednesday 01:00 in Karachi — the small hours after Tuesday night.
WEDNESDAY_1AM = datetime(2026, 9, 22, 20, 0, tzinfo=timezone.utc)

# Searcher standing in F-7 Markaz, Islamabad.
F7 = (33.7215, 73.0527)


def every_day(opens: str, closes: str) -> dict[int, tuple[str, str]]:
    return {day: (opens, closes) for day in range(7)}


def weekdays_and_saturday(opens: str, closes: str) -> dict[int, tuple[str, str]]:
    return {day: (opens, closes) for day in range(6)}


def make_world() -> dict[str, int]:
    """Six published businesses (plus one unpublished) with distinct attributes.

    ============== ========= ===== ========== ====== ===== ======== =====================
    name           category  tier  PKR range  rating  new  verified open Wed 12:00
    ============== ========= ===== ========== ====== ===== ======== =====================
    Brew & Bloom   cafes     $$    450–1500   4.8     yes  yes      yes (08–23), offer
    Reading Room   cafes     $$    350–1100   4.7     no   yes      no (13–22)
    Forno Italiano restaurant $$$  1200–4500  4.6     no   no       no (18–02 overnight)
    Zilli Tailors  shopping  $     800–2500   4.5     yes  yes      yes (10–21)
    Night Owl      restaurant $$   —          0       no   yes      unknown (no hours)
    Coffee Lab     cafes     $     —          4.2     no   yes      yes (07–15)
    Hidden Draft   cafes     unpublished
    ============== ========= ===== ========== ====== ===== ======== =====================
    """
    db = TestingSessionLocal()
    try:
        owner = User(
            email="world-owner@khojlo.app", full_name="World Owner", role=UserRole.business_owner
        )
        db.add(owner)
        db.flush()

        cats = {
            slug: Category(slug=slug, name=name, tone="gold")
            for slug, name in (("cafes", "Cafés"), ("restaurants", "Restaurants"),
                               ("shopping", "Shopping"))
        }
        db.add_all(cats.values())
        db.flush()

        created: list[BusinessProfile] = []

        def biz(name: str, cat: str, *, tagline: str = "", description: str = "",
                address: str = "", price: str = "$$", pmin: int | None = None,
                pmax: int | None = None, coords: tuple[float, float] | None = None,
                rating: float = 0.0, saves: int = 0, age_days: int = 100,
                verified: bool = True, published: bool = True,
                hours: dict[int, tuple[str, str]] | None = None,
                services: tuple = (), offers: tuple = ()) -> None:
            b = BusinessProfile(
                owner_id=owner.id,
                category_id=cats[cat].id,
                name=name,
                tagline=tagline,
                description=description,
                address=address,
                price_level=price,
                price_min=pmin,
                price_max=pmax,
                latitude=coords[0] if coords else None,
                longitude=coords[1] if coords else None,
                rating=rating,
                review_count=int(rating * 10),
                save_count=saves,
                is_verified=verified,
                is_published=published,
                created_at=FROZEN_NOW - timedelta(days=age_days),
            )
            for day, (opens, closes) in (hours or {}).items():
                b.hours.append(OpeningHours(day_of_week=day, opens=opens, closes=closes))
            for service_name, amount in services:
                b.services.append(
                    Service(name=service_name, price=f"Rs {amount}", price_amount=amount)
                )
            for title, live in offers:
                # Live: switched on and open-ended from January. Ended: expired in June.
                # Either way the result doesn't depend on today's date.
                b.offers.append(Offer(
                    title=title, deal_text="Special", is_active=live,
                    start_date=date(2026, 1, 1),
                    end_date=None if live else date(2026, 6, 1),
                ))
            db.add(b)
            created.append(b)

        biz("Brew & Bloom", "cafes", tagline="Specialty coffee & plants",
            address="F-7 Markaz, Islamabad", pmin=450, pmax=1500, coords=F7, rating=4.8,
            saves=90, age_days=10, hours=every_day("08:00", "23:00"),
            services=(("Pour over", 650), ("Flat white", 550)),
            offers=(("Free seedling", True),))
        biz("The Reading Room", "cafes", tagline="Quiet corners",
            description="Slow coffee for readers", address="Blue Area, Islamabad",
            pmin=350, pmax=1100, coords=(33.7095, 73.0561), rating=4.7, saves=60,
            age_days=200, hours=weekdays_and_saturday("13:00", "22:00"),
            services=(("Filter coffee", 400),))
        biz("Forno Italiano", "restaurants", tagline="Wood-fired pizza", price="$$$",
            address="F-6, Islamabad", pmin=1200, pmax=4500, coords=(33.7273, 73.0768),
            rating=4.6, saves=70, age_days=90, verified=False,
            hours={1: ("18:00", "02:00"), 2: ("18:00", "02:00")},
            services=(("Margherita pizza", 1400),),
            offers=(("Summer menu", False),))
        biz("Zilli Tailors", "shopping", tagline="Unstitched fabric & suits", price="$",
            address="Jinnah Road, Abbottabad", pmin=800, pmax=2500,
            coords=(34.1519, 73.2157), rating=4.5, saves=30, age_days=5,
            hours=weekdays_and_saturday("10:00", "21:00"),
            services=(("Unstitched lawn", 1800), ("Suit stitching", 2500)))
        biz("Night Owl Ramen", "restaurants", tagline="Late ramen",
            description="Ramen, bao and the odd pizza slice", age_days=400)
        biz("Coffee Lab", "cafes", tagline="Experimental brews", price="$",
            address="F-7/2, Islamabad", coords=(33.7150, 73.0540), rating=4.2, saves=5,
            age_days=300, hours=every_day("07:00", "15:00"))
        biz("Hidden Draft", "cafes", tagline="Secret coffee", published=False)

        db.commit()
        return {b.name: b.id for b in created}
    finally:
        db.close()


def make_many(count: int) -> None:
    """Bulk filler businesses for the response-time smoke test."""
    db = TestingSessionLocal()
    try:
        owner = User(email="bulk@khojlo.app", full_name="Bulk Owner", role=UserRole.business_owner)
        cat = Category(slug="bulk", name="Bulk", tone="gold")
        db.add_all([owner, cat])
        db.flush()
        for i in range(count):
            b = BusinessProfile(
                owner_id=owner.id,
                category_id=cat.id,
                name=f"Place {i}",
                tagline="coffee and cake" if i % 3 == 0 else "tea house",
                address="Islamabad",
                price_level=("$", "$$", "$$$")[i % 3],
                price_min=300 + i,
                price_max=900 + i,
                latitude=33.70 + (i % 50) * 0.001,
                longitude=73.05 + (i // 50) * 0.001,
                rating=3.5 + (i % 15) / 10,
                created_at=FROZEN_NOW - timedelta(days=i % 90),
            )
            for day in range(7):
                b.hours.append(OpeningHours(day_of_week=day, opens="09:00", closes="21:00"))
            b.services.append(Service(name="Signature item", price="Rs 500", price_amount=500))
            db.add(b)
        db.commit()
    finally:
        db.close()
