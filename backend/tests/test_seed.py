"""The default seed must be safe on the shared database: add and refresh, never delete."""
from sqlalchemy import func, select

from app.core.security import hash_password
from app.db import seed as seed_module
from app.models.business import BusinessProfile, Category, OpeningHours, Service
from app.models.engagement import SavedList
from app.models.review import Review
from app.models.search import SearchQuery
from app.models.user import User, UserRole
from tests.conftest import TestingSessionLocal, login
from tests.factories import FROZEN_NOW

CATALOGUE = {spec["name"]: spec for spec in seed_module.BUSINESSES}


def count(db, model, *where):
    return db.scalar(select(func.count()).select_from(model).where(*where))


def test_seed_fills_an_empty_database():
    db = TestingSessionLocal()
    report = seed_module.seed(db, now=FROZEN_NOW)

    assert report.businesses_added == len(seed_module.BUSINESSES)
    assert report.businesses_refreshed == 0
    assert count(db, BusinessProfile) == len(seed_module.BUSINESSES)
    assert count(db, Category) == len(seed_module.CATEGORIES)
    assert count(db, User) == len(seed_module.DEMO_USERS) + len(seed_module.REVIEWERS)
    assert count(db, OpeningHours) == 7 * len(seed_module.BUSINESSES)
    assert count(db, Review) == report.reviews_added
    assert count(db, SavedList) == 2
    assert count(db, SearchQuery) > 0
    db.close()


def test_seed_twice_changes_nothing():
    db = TestingSessionLocal()
    seed_module.seed(db, now=FROZEN_NOW)
    before = {m: count(db, m) for m in (BusinessProfile, Service, OpeningHours, Review,
                                          SavedList, SearchQuery, User, Category)}
    report = seed_module.seed(db, now=FROZEN_NOW)

    assert report.businesses_added == 0
    assert report.businesses_refreshed == len(seed_module.BUSINESSES)
    assert (report.offers_added, report.reviews_added, report.searches_added) == (0, 0, 0)
    assert {m: count(db, m) for m in before} == before
    db.close()


def test_seed_upgrades_old_placeholder_data_and_keeps_everything_else(client):
    """The Module 3 seed left one "Signature experience" service and no price range."""
    db = TestingSessionLocal()
    cafes = Category(slug="cafes", name="Cafés", tone="emerald")
    owner = User(email=seed_module.OWNER_EMAIL, full_name="Sara Owner",
                 hashed_password=hash_password("owner-changed-this"),
                 role=UserRole.business_owner)
    real = User(email="someone@gmail.com", full_name="Real Person",
                hashed_password=hash_password("password123"), role=UserRole.business_owner)
    db.add_all([cafes, owner, real])
    db.flush()
    old = BusinessProfile(owner_id=owner.id, category_id=cafes.id, name="Brew & Bloom",
                          address="Blue Area, Islamabad", price_level="$$", view_count=999,
                          save_count=97, rating=4.8, review_count=214)
    old.services.append(Service(name="Signature experience", price="$$"))
    theirs = BusinessProfile(owner_id=real.id, category_id=cafes.id, name="Real Café",
                             address="Saddar, Rawalpindi")
    db.add_all([old, theirs])
    db.commit()

    report = seed_module.seed(db, now=FROZEN_NOW)
    db.expire_all()

    assert report.businesses_refreshed == 1
    # customer + admin + the Module 8 demo spammer + demo reviewers; the owner already existed
    assert report.users_added == 3 + len(seed_module.REVIEWERS)
    brew = db.scalar(select(BusinessProfile).where(BusinessProfile.name == "Brew & Bloom"))
    spec = CATALOGUE["Brew & Bloom"]
    assert (brew.price_min, brew.price_max, brew.address) == (spec["pmin"], spec["pmax"],
                                                              spec["address"])
    assert [s.name for s in brew.services] == [name for name, _ in spec["services"]]
    assert all(s.price_amount for s in brew.services)
    assert len(brew.hours) == 7
    assert (brew.view_count, brew.save_count) == (999, 97)  # engagement is kept
    # The made-up "4.8 from 214 reviews" is replaced by totals from real reviews.
    reviews = db.scalars(select(Review).where(Review.business_id == brew.id)).all()
    assert brew.review_count == len(reviews) != 214
    assert brew.rating == round(sum(r.rating for r in reviews) / len(reviews), 2)

    # Nobody else's data is touched, and existing accounts keep their passwords.
    assert db.scalar(select(BusinessProfile).where(BusinessProfile.name == "Real Café"))
    assert db.scalar(select(User).where(User.email == "someone@gmail.com"))
    r = client.post("/api/v1/auth/login",
                    json={"email": seed_module.OWNER_EMAIL, "password": "owner-changed-this"})
    assert r.status_code == 200
    db.close()


def test_seeded_data_is_searchable(client):
    db = TestingSessionLocal()
    seed_module.seed(db)
    db.close()
    token = login(client, seed_module.CUSTOMER_EMAIL)

    r = client.get("/api/v1/search", params={"q": "unstitched fabric", "lat": 34.1487,
                                              "lng": 73.2157, "sort": "distance"})
    assert r.status_code == 200
    names = [b["name"] for b in r.json()["items"]]
    assert names[:2] == ["Zilli Tailors", "Al-Rehman Cloth House"]

    ids = [b["id"] for b in r.json()["items"][:3]]
    r = client.get("/api/v1/compare", params={"ids": ids})
    assert r.status_code == 200
    assert len(r.json()["items"]) == 3

    r = client.get("/api/v1/feed", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200


def test_seeded_reviews_are_real_and_follow_br4():
    db = TestingSessionLocal()
    seed_module.seed(db, now=FROZEN_NOW)
    for b in db.scalars(select(BusinessProfile)):
        reviews = db.scalars(select(Review).where(Review.business_id == b.id)).all()
        authors = [r.user_id for r in reviews]
        assert len(authors) == len(set(authors))  # BR-4: one review per business per user
        assert b.review_count == len(reviews) >= 3
        assert 1 <= min(r.rating for r in reviews) and max(r.rating for r in reviews) <= 5
        assert abs(b.rating - sum(r.rating for r in reviews) / len(reviews)) < 0.01
    customer = db.scalar(select(User).where(User.email == seed_module.CUSTOMER_EMAIL))
    assert count(db, Review, Review.user_id == customer.id) == 1
    db.close()
