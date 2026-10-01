"""Shared helpers for the Module 8 (admin and moderation) tests."""
from __future__ import annotations

import io

from PIL import Image

from app.models.business import BusinessProfile, Category
from app.models.user import User, UserRole
from tests.conftest import TestingSessionLocal, auth, login, register

P = "/api/v1"


def make_user(client, email, *, name="Test User", role="customer") -> dict:
    r = register(client, email, role=role, full_name=name)
    assert r.status_code == 201, r.text
    return auth(login(client, email))


def make_admin(client, email="admin@khojlo.app", name="Asma Admin") -> dict:
    """Admins can't sign up (SEC-3): promote a registered account in the database."""
    register(client, email, full_name=name)
    db = TestingSessionLocal()
    user = db.query(User).filter(User.email == email).one()
    user.role = UserRole.admin
    db.commit()
    db.close()
    return auth(login(client, email))


def user_id(client, headers) -> int:
    return client.get(f"{P}/users/me", headers=headers).json()["id"]


def verify_email(client, headers, sent_emails) -> None:
    """Complete the real email-verification flow with the code sign-up emailed (conftest
    captures it)."""
    email = client.get(f"{P}/users/me", headers=headers).json()["email"]
    code = next(c for kind, to, c in reversed(sent_emails) if kind == "verify_email" and to == email)
    r = client.post(f"{P}/auth/email/verify", headers=headers, json={"code": code})
    assert r.status_code == 200, r.text


def jpeg(color=(200, 120, 60), size=(800, 600)) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", size, color).save(out, "JPEG")
    return out.getvalue()


def upload(client, headers, color=(200, 120, 60)) -> str:
    r = client.post(f"{P}/media", headers=headers,
                    files={"file": ("photo.jpg", jpeg(color), "image/jpeg")})
    assert r.status_code == 201, r.text
    return r.json()["key"]


def category_id(slug="cafes", name="Cafés") -> int:
    db = TestingSessionLocal()
    c = db.query(Category).filter(Category.slug == slug).one_or_none()
    if c is None:
        c = Category(slug=slug, name=name, tone="gold")
        db.add(c)
        db.commit()
    cid = c.id
    db.close()
    return cid


def complete_business(client, headers, *, name="Brew & Bloom", phone="0300 1112233",
                      description="Specialty coffee, fresh pastries and a quiet corner to work.",
                      lat=33.7215, lng=73.0527, **extra) -> dict:
    """A listing that passes the "complete profile" check."""
    payload = {
        "name": name,
        "tagline": "Coffee and quiet corners",
        "description": description,
        "address": "F-7 Markaz, Islamabad",
        "phone": phone,
        "latitude": lat,
        "longitude": lng,
        "category_id": category_id(),
        "hours": [{"day_of_week": d, "opens": "09:00", "closes": "22:00"} for d in range(7)],
        "photos": [upload(client, headers)],
        **extra,
    }
    r = client.post(f"{P}/businesses", headers=headers, json=payload)
    assert r.status_code == 201, r.text
    return r.json()


def verification(client, headers, business_id) -> dict:
    r = client.get(f"{P}/businesses/{business_id}/verification", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()


def take_storefront(client, headers, business_id) -> dict:
    key = upload(client, headers, color=(30, 110, 90))
    r = client.put(f"{P}/businesses/{business_id}/verification/storefront", headers=headers,
                   json={"photo": key})
    assert r.status_code == 200, r.text
    return r.json()


def business_row(business_id) -> BusinessProfile:
    db = TestingSessionLocal()
    b = db.get(BusinessProfile, business_id)
    db.expunge(b)
    db.close()
    return b


def inbox_titles(client, headers) -> list[str]:
    r = client.get(f"{P}/notifications", headers=headers)
    assert r.status_code == 200, r.text
    return [n["title"] for n in r.json()["items"]]
