"""Seed demo data so the feed, search and dashboard look alive.

    python -m app.db.seed           # safe anywhere, including the shared team database
    python -m app.db.seed --reset   # local databases only: wipes every user and business first

The default mode only adds and refreshes demo data; it never deletes a user, a review, a
save, or a business that isn't one of the demo owner's catalogue businesses. It:

* adds missing categories and demo accounts (existing accounts, passwords included, are
  left alone);
* refreshes the demo owner's businesses whose names are in the catalogue below (address,
  map pin, tagline, price range, verification, age, opening hours and services) and adds
  catalogue businesses that don't exist yet. Views and saves are kept;
* adds catalogue offers, saved lists and search history only where none exist;
* adds demo reviewer accounts and their reviews (with owner replies and helpful votes) to
  catalogue businesses that have none from them yet;
* recalculates every business's rating and review count from its real reviews (SDD
  Algorithm 7), so no made-up totals remain;
* adds demo chat conversations between the demo customer and three catalogue businesses
  (Module 9), and a few Notifications-list entries for the demo customer, where none exist.

The catalogue is deliberately varied so Module 4 search, filters and comparison have
something to work with: several Islamabad areas plus Abbottabad (the four tailors mirror
the SDD "Search & compare" mockup), rupee price ranges, different opening hours
(including overnight), some unverified and some newly opened businesses, and a little
search history for "Popular searches".
"""
from __future__ import annotations

import random
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.core.database import SessionLocal, engine
from app.core.security import hash_password
from app.db.schema_check import schema_problem
from app.models.business import (
    BusinessProfile,
    Category,
    Offer,
    OfferStatus,
    OpeningHours,
    Service,
)
from app.models.chat import Conversation, ConversationReport, Message
from app.models.engagement import BusinessView, SavedBusiness, SavedList
from app.models.notification import DeviceToken, Notification, NotificationKind
from app.models.review import Review, ReviewPhoto, ReviewReport, ReviewVote
from app.models.search import SearchQuery
from app.models.user import User, UserRole
from app.services.review_service import refresh_rating

DEMO_PASSWORD = "password123"
OWNER_EMAIL = "owner@khojlo.app"
CUSTOMER_EMAIL = "customer@khojlo.app"
DEMO_USERS = [
    dict(email=OWNER_EMAIL, full_name="Sara Owner", role=UserRole.business_owner,
         avatar_tone="plum"),
    dict(email=CUSTOMER_EMAIL, full_name="Ali Customer", role=UserRole.customer,
         avatar_tone="gold", interests=["cafes", "restaurants"]),
    dict(email="admin@khojlo.app", full_name="Admin", role=UserRole.admin),
]

# (slug, name, emoji, group, tone, sort order, search keywords). The migration
# b7d3f1a9c2e4 installs the same catalogue; `--reset` recreates it from here.
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

# ── weekly opening-hour presets: {day_of_week: (opens, closes)}, missing day = closed ──
DAILY = range(7)
MON_SAT = range(6)
MON_FRI = range(5)


def _week(days, opens: str, closes: str, extra: dict | None = None) -> dict[int, tuple[str, str]]:
    hours = {d: (opens, closes) for d in days}
    hours.update(extra or {})
    return hours


CAFE_HOURS = _week(DAILY, "08:00", "23:00")
LATE_NIGHT = _week(DAILY, "12:00", "01:00")  # closes after midnight
DINNER = _week(DAILY, "18:00", "02:00")
STANDARD = _week(MON_SAT, "10:00", "22:00")
GYM_HOURS = _week(MON_SAT, "06:00", "23:00", {6: ("08:00", "14:00")})
CLINIC_HOURS = _week(MON_SAT, "08:00", "20:00")
ARENA_HOURS = _week(DAILY, "14:00", "02:00")
SHOP_HOURS = _week(MON_SAT, "10:00", "21:00")
MORNING_ONLY = _week(MON_FRI, "10:00", "14:00")
ROUND_THE_CLOCK = _week(DAILY, "00:00", "00:00")  # equal times = open 24 hours

ISB = "Islamabad"
ABT = "Abbottabad"

# Each business: category, tone, tagline, tier, PKR range, area, coordinates, rating (the
# average its seeded reviews aim for), reviews (sets the demo view count), saves, age in
# days (<= 30 counts as new), verified, hours, services (name, Rs).
BUSINESSES: list[dict] = [
    dict(name="Brew & Bloom", cat="cafes", tone="emerald",
         tagline="Specialty coffee & a wall of plants", price="$$", pmin=450, pmax=1500,
         address=f"F-7 Markaz, {ISB}", lat=33.7206, lng=73.0551, rating=4.8, reviews=214,
         saves=96, age=12, verified=True, hours=CAFE_HOURS,
         services=[("Pour over", 650), ("Flat white", 550), ("Plant of the month", 1200)]),
    dict(name="The Reading Room", cat="cafes", tone="gold",
         tagline="Quiet corners, slow mornings", price="$$", pmin=350, pmax=1100,
         address=f"Blue Area, {ISB}", lat=33.7095, lng=73.0561, rating=4.7, reviews=132,
         saves=61, age=160, verified=True, hours=_week(DAILY, "09:00", "22:00"),
         services=[("Filter coffee", 400), ("Study table (2 hrs)", 600), ("Cheesecake", 750)]),
    dict(name="Scoops & Swirls", cat="bakeries", tone="emerald",
         tagline="Small-batch dessert bar", price="$", pmin=250, pmax=800,
         address=f"F-6 Super Market, {ISB}", lat=33.7273, lng=73.0768, rating=4.9, reviews=88,
         saves=40, age=6, verified=False, hours=_week(DAILY, "13:00", "00:00"),
         services=[("Single scoop", 250), ("Waffle sundae", 650), ("Kulfi falooda", 450)]),
    dict(name="Forno Italiano", cat="restaurants", tone="gold",
         tagline="Wood-fired Neapolitan pizza", price="$$", pmin=900, pmax=2800,
         address=f"Kohsar Market, F-6/3, {ISB}", lat=33.7318, lng=73.0707, rating=4.7,
         reviews=301, saves=120, age=240, verified=True, hours=STANDARD,
         services=[("Margherita pizza", 1400), ("Truffle pasta", 2200), ("Tiramisu", 900)]),
    dict(name="Ramen no Michi", cat="restaurants", tone="gold",
         tagline="18-hour tonkotsu broth", price="$$", pmin=1200, pmax=2400,
         address=f"F-7 Markaz, {ISB}", lat=33.7219, lng=73.0536, rating=4.8, reviews=176,
         saves=84, age=45, verified=True, hours=LATE_NIGHT,
         services=[("Tonkotsu ramen", 1800), ("Gyoza (6 pcs)", 1200), ("Matcha ice cream", 700)]),
    dict(name="Ember & Oak", cat="restaurants", tone="coral",
         tagline="Live-fire seasonal plates", price="$$$", pmin=2500, pmax=7000,
         address=f"E-7, {ISB}", lat=33.7298, lng=73.0572, rating=4.6, reviews=143,
         saves=52, age=300, verified=True, hours=DINNER,
         services=[("Chef's tasting menu", 6500), ("Smoked short rib", 4200)]),
    dict(name="The Dumpling Cart", cat="street-food", tone="gold",
         tagline="Hand-folded, steamed to order", price="$", pmin=300, pmax=900,
         address=f"G-9 Markaz, {ISB}", lat=33.6932, lng=73.0293, rating=4.9, reviews=190,
         saves=77, age=3, verified=False, hours=_week(DAILY, "12:00", "23:00"),
         services=[("Chicken dumplings (8 pcs)", 550), ("Chilli oil wontons", 650)]),
    dict(name="Mornings Café", cat="cafes", tone="coral",
         tagline="All-day brunch & filter coffee", price="$$", pmin=500, pmax=1600,
         address=f"F-10 Markaz, {ISB}", lat=33.6953, lng=73.0138, rating=4.6, reviews=108,
         saves=51, age=90, verified=True, hours=_week(DAILY, "07:30", "16:00"),
         services=[("Desi breakfast", 950), ("Eggs Benedict", 1400), ("Cold brew", 600)]),
    dict(name="Iron & Ash Gym", cat="gym", tone="emerald",
         tagline="Strength-first, no crowds", price="$$", pmin=4000, pmax=9000,
         address=f"I-8 Markaz, {ISB}", lat=33.6678, lng=73.0756, rating=4.6, reviews=74,
         saves=33, age=120, verified=True, hours=GYM_HOURS,
         services=[("Monthly membership", 6000), ("Personal training session", 2500)]),
    dict(name="Glow Studio", cat="beauty", tone="coral",
         tagline="Skin, nails & slow beauty", price="$$", pmin=1500, pmax=6000,
         address=f"F-7 Markaz, {ISB}", lat=33.7211, lng=73.0544, rating=4.8, reviews=121,
         saves=58, age=20, verified=True, hours=STANDARD,
         services=[("Hydrating facial", 4500), ("Gel manicure", 2000), ("Brow shaping", 1500)]),
    dict(name="Pixel Arena", cat="gaming", tone="ink",
         tagline="Next-gen consoles & LAN nights", price="$", pmin=300, pmax=1500,
         address=f"G-9 Markaz, {ISB}", lat=33.6926, lng=73.0281, rating=4.5, reviews=66,
         saves=29, age=75, verified=True, hours=ARENA_HOURS,
         services=[("PS5 per hour", 400), ("LAN night pass", 1500)]),
    dict(name="Northlight Clinic", cat="healthcare", tone="emerald",
         tagline="Same-day family care", price="$$", pmin=1500, pmax=5000,
         address=f"Blue Area, {ISB}", lat=33.7088, lng=73.0579, rating=4.7, reviews=89,
         saves=21, age=200, verified=True, hours=CLINIC_HOURS,
         services=[("GP consultation", 2000), ("Blood test panel", 3500)]),
    dict(name="CarePoint Pharmacy", cat="pharmacy", tone="emerald",
         tagline="Open 24 hours, delivery on call", price="$", pmin=None, pmax=None,
         address=f"F-8 Markaz, {ISB}", lat=33.7093, lng=73.0379, rating=4.4, reviews=39,
         saves=12, age=15, verified=False, hours=ROUND_THE_CLOCK,
         services=[("Prescription refill", None), ("BP check", 200)]),
    dict(name="Verse Bookshop", cat="books", tone="gold",
         tagline="Indie press & study loft", price="$", pmin=500, pmax=3000,
         address=f"F-6 Super Market, {ISB}", lat=33.7266, lng=73.0781, rating=4.8, reviews=54,
         saves=44, age=400, verified=True, hours=_week(DAILY, "10:00", "22:00", {4: ("15:00", "22:00")}),
         services=[("Study loft day pass", 500), ("Urdu poetry collection", 1200)]),
    # ── Abbottabad — the SDD "unstitched fabric" search mockup ──
    dict(name="Zilli Tailors", cat="tailors", tone="emerald",
         tagline="Unstitched fabric & made-to-measure suits", price="$", pmin=800, pmax=2500,
         address=f"Jinnah Road, {ABT}", lat=34.1519, lng=73.2157, rating=4.7, reviews=58,
         saves=31, age=9, verified=True, hours=SHOP_HOURS,
         services=[("Unstitched lawn (3 pc)", 1800), ("Suit stitching", 2500), ("Alterations", 800)]),
    dict(name="Al-Rehman Cloth House", cat="tailors", tone="plum",
         tagline="Unstitched fabric by the metre", price="$", pmin=600, pmax=1800,
         address=f"Jinnah Road, {ABT}", lat=34.1568, lng=73.2160, rating=4.5, reviews=41,
         saves=18, age=150, verified=True, hours=SHOP_HOURS,
         services=[("Cotton fabric (per metre)", 600), ("Unstitched khaddar suit", 1800)]),
    dict(name="Threadwork Studio", cat="tailors", tone="gold",
         tagline="Hand embroidery & bridal stitching", price="$$", pmin=1200, pmax=4000,
         address=f"Supply Bazaar, {ABT}", lat=34.1604, lng=73.2158, rating=4.6, reviews=27,
         saves=14, age=26, verified=False, hours=MORNING_ONLY,
         services=[("Embroidered unstitched suit", 4000), ("Custom stitching", 1200)]),
    dict(name="Heritage Textiles", cat="tailors", tone="emerald",
         tagline="Pure silk, lawn & unstitched fabric", price="$$", pmin=900, pmax=3000,
         address=f"Main Bazaar, {ABT}", lat=34.1649, lng=73.2163, rating=4.4, reviews=33,
         saves=11, age=500, verified=True, hours=SHOP_HOURS,
         services=[("Unstitched silk (3 pc)", 3000), ("Lawn fabric (per metre)", 900)]),
    # ── one or two per newer category, so none of them is empty in a demo ──
    dict(name="Smash & Stack", cat="fast-food", tone="coral",
         tagline="Smashed burgers & loaded fries", price="$", pmin=450, pmax=1800,
         address=f"F-10 Markaz, {ISB}", lat=33.6960, lng=73.0145, rating=4.6, reviews=97,
         saves=38, age=10, verified=False, hours=LATE_NIGHT,
         services=[("Double smash burger", 950), ("Loaded fries", 650), ("Chicken shawarma", 450)]),
    dict(name="Resham Boutique", cat="clothing", tone="plum",
         tagline="Hand-finished lawn & formal wear", price="$$", pmin=3500, pmax=18000,
         address=f"Jinnah Super, F-7, {ISB}", lat=33.7190, lng=73.0560, rating=4.7, reviews=64,
         saves=45, age=40, verified=True, hours=SHOP_HOURS,
         services=[("Ready-to-wear lawn (3 pc)", 6500), ("Formal dress", 18000), ("Dupatta", 3500)]),
    dict(name="Daily Basket Mart", cat="grocery", tone="emerald",
         tagline="Fresh produce & everyday groceries", price="$", pmin=100, pmax=5000,
         address=f"G-11 Markaz, {ISB}", lat=33.6682, lng=72.9990, rating=4.3, reviews=52,
         saves=12, age=200, verified=True, hours=_week(DAILY, "08:00", "23:30"),
         services=[("Home delivery", 150), ("Fresh fruit box", 1800)]),
    dict(name="Fix-It Mobile Lab", cat="electronics", tone="ink",
         tagline="Same-day phone & laptop repairs", price="$", pmin=500, pmax=8000,
         address=f"Blue Area, {ISB}", lat=33.7102, lng=73.0590, rating=4.5, reviews=81,
         saves=20, age=22, verified=False, hours=STANDARD,
         services=[("Screen replacement", 6500), ("Battery replacement", 3500), ("Laptop service", 2500)]),
    dict(name="The Gentleman's Chair", cat="barbers", tone="ink",
         tagline="Classic cuts & hot-towel shaves", price="$$", pmin=800, pmax=3000,
         address=f"F-6 Super Market, {ISB}", lat=33.7280, lng=73.0760, rating=4.8, reviews=143,
         saves=57, age=60, verified=True, hours=_week(DAILY, "10:00", "22:00"),
         services=[("Haircut", 1200), ("Hot-towel shave", 900), ("Beard styling", 800)]),
    dict(name="HandyFix Home Services", cat="home-services", tone="ink",
         tagline="Plumbers, electricians & AC repair on call", price="$", pmin=1000, pmax=6000,
         address=f"I-8 Markaz, {ISB}", lat=33.6690, lng=73.0770, rating=4.4, reviews=58,
         saves=16, age=18, verified=False, hours=_week(MON_SAT, "08:00", "20:00"),
         services=[("AC service", 3500), ("Plumbing visit", 1500), ("Electrician visit", 1500)]),
    dict(name="Shine Auto Care", cat="auto", tone="ink",
         tagline="Car wash, detailing & quick repairs", price="$$", pmin=800, pmax=15000,
         address=f"I-9 Industrial Area, {ISB}", lat=33.6560, lng=73.0550, rating=4.5, reviews=72,
         saves=19, age=130, verified=True, hours=_week(DAILY, "09:00", "21:00"),
         services=[("Full car wash", 1200), ("Interior detailing", 6000), ("Oil change", 4500)]),
    dict(name="Fresh Fold Laundry", cat="laundry", tone="emerald",
         tagline="Wash, dry-clean & press with free pickup", price="$", pmin=150, pmax=1500,
         address=f"G-10 Markaz, {ISB}", lat=33.6845, lng=73.0135, rating=4.6, reviews=45,
         saves=14, age=8, verified=False, hours=_week(MON_SAT, "09:00", "21:00"),
         services=[("Shalwar kameez wash & press", 250), ("Suit dry-clean", 900), ("Duvet cleaning", 1500)]),
    dict(name="Frame & Flower Studio", cat="events", tone="plum",
         tagline="Wedding photography & floral décor", price="$$$", pmin=25000, pmax=250000,
         address=f"E-7, {ISB}", lat=33.7285, lng=73.0590, rating=4.9, reviews=37,
         saves=29, age=90, verified=True, hours=_week(MON_SAT, "11:00", "19:00"),
         services=[("Mehndi photography", 45000), ("Stage décor", 120000)]),
    dict(name="Paws & Whiskers", cat="pets", tone="coral",
         tagline="Vet clinic, grooming & pet supplies", price="$$", pmin=1000, pmax=8000,
         address=f"F-11 Markaz, {ISB}", lat=33.6850, lng=72.9875, rating=4.7, reviews=61,
         saves=34, age=28, verified=True, hours=CLINIC_HOURS,
         services=[("Vet consultation", 2000), ("Cat grooming", 3500), ("Vaccination", 2500)]),
    dict(name="Margalla View Guest House", cat="hotels", tone="gold",
         tagline="Quiet rooms with a view of the hills", price="$$", pmin=7000, pmax=15000,
         address=f"E-7, {ISB}", lat=33.7310, lng=73.0555, rating=4.6, reviews=49,
         saves=22, age=250, verified=True, hours=ROUND_THE_CLOCK,
         services=[("Standard room (per night)", 7000), ("Deluxe room (per night)", 12000)]),
    dict(name="Qalam Calligraphy Studio", cat="other", custom="Calligraphy studio", tone="gold",
         tagline="Urdu & Arabic calligraphy: classes and commissions", price="$$",
         pmin=1500, pmax=20000, address=f"F-6 Super Market, {ISB}", lat=33.7268, lng=73.0775,
         rating=4.9, reviews=23, saves=18, age=14, verified=False,
         hours=_week(MON_SAT, "12:00", "20:00"),
         services=[("Beginner class (4 sessions)", 6000), ("Name in calligraphy (framed)", 4500)]),
    dict(name="Mountain Chai Dhaba", cat="street-food", tone="gold",
         tagline="Doodh patti, parathas & a view of the valley", price="$", pmin=150, pmax=700,
         address=f"Mansehra Road, {ABT}", lat=34.1700, lng=73.2230, rating=4.7, reviews=88,
         saves=41, age=5, verified=False, hours=_week(DAILY, "06:00", "02:00"),
         services=[("Doodh patti", 150), ("Aloo paratha", 250), ("Chicken karahi (half)", 700)]),
]

OFFERS = {
    "Brew & Bloom": [("Buy one, plant one — free seedling", "Jul 1", "Jul 20", OfferStatus.active, "emerald", 96, 40)],
    "Forno Italiano": [("Family pizza night — 25% off", "Jul 5", "Aug 5", OfferStatus.active, "gold", 210, 33)],
    "Scoops & Swirls": [("2-for-1 sundaes on weekdays", "Sep 1", "Oct 15", OfferStatus.active, "emerald", 64, 20)],
    "Iron & Ash Gym": [("First week free", "Sep 10", "Oct 10", OfferStatus.active, "emerald", 48, 9)],
    "Glow Studio": [("15% off your first facial", "Sep 1", "Sep 30", OfferStatus.active, "gold", 72, 14)],
    "Zilli Tailors": [("Free alterations this month", "Sep 1", "Sep 30", OfferStatus.active, "emerald", 30, 6)],
    "Ember & Oak": [("Summer tasting menu", "Jun 1", "Jul 1", OfferStatus.ended, "gold", 140, 22)],
}

# Module 5: demo reviewers. Each writes at most one review per business (BR-4). About two
# thirds have a verified email, so the "Verified" badge and ordering show up in the demo.
REVIEWERS = [
    ("ayesha.khan@khojlo.app", "Ayesha Khan", "plum", True),
    ("bilal.raza@khojlo.app", "Bilal Raza", "emerald", True),
    ("sana.malik@khojlo.app", "Sana Malik", "gold", False),
    ("hamza.tariq@khojlo.app", "Hamza Tariq", "coral", True),
    ("zainab.ali@khojlo.app", "Zainab Ali", "emerald", True),
    ("usman.shah@khojlo.app", "Usman Shah", "gold", False),
    ("mahnoor.iqbal@khojlo.app", "Mahnoor Iqbal", "plum", True),
    ("hassan.riaz@khojlo.app", "Hassan Riaz", "coral", True),
    ("fatima.noor@khojlo.app", "Fatima Noor", "gold", True),
    ("omer.farooq@khojlo.app", "Omer Farooq", "emerald", False),
    ("hira.javed@khojlo.app", "Hira Javed", "coral", True),
    ("ahmed.butt@khojlo.app", "Ahmed Butt", "plum", False),
]

# Review text by star rating; {thing} is filled with a category-specific detail.
REVIEW_OPENERS = {
    5: ["Absolutely loved it — {thing}.", "Genuinely one of the best finds on Khojlo: {thing}.",
        "Went on a friend's recommendation and wasn't disappointed. {thing}.",
        "Can't fault it. {thing}, and the staff were lovely."],
    4: ["Really good overall — {thing}.", "Solid experience. {thing}, will come back.",
        "Pleasantly surprised: {thing}. Only small things to improve."],
    3: ["Decent, but not memorable. {thing}.", "Mixed visit — {thing}, though service was slow.",
        "Okay for the price. {thing}."],
    2: ["Expected more. {thing}, but the wait was long.", "Not great this time — {thing}."],
    1: ["Disappointing visit. {thing}, but I wouldn't go back."],
}
REVIEW_DETAILS = {
    "food": ["the food came out hot and full of flavour", "portions were generous",
             "the coffee is properly made", "it's spotless and cosy inside",
             "prices are fair for the quality"],
    "shopping": ["the fabric quality is excellent", "they had exactly what I was looking for",
                 "prices were fair and they didn't haggle", "the shopkeeper was patient and honest",
                 "alterations were done on time"],
    "services": ["they were on time and professional", "the place is clean and well organised",
                 "they explained everything clearly", "booking was easy over the phone",
                 "worth every rupee"],
}
FOOD = {"cafes", "bakeries", "restaurants", "street-food", "fast-food"}
SHOPPING = {"tailors", "clothing", "grocery", "electronics", "books"}
OWNER_REPLIES = {
    5: "Thank you so much! We're glad you enjoyed it — see you again soon.",
    4: "Thanks for the kind words! Tell us what would make it five stars next time.",
    3: "Thanks for the honest feedback. We're working on speeding things up.",
    2: "Sorry we let you down. Please message us so we can make it right.",
    1: "We're really sorry about your visit. Please get in touch so we can fix this.",
}
# The demo customer's own review, so "My reviews" has something to show.
CUSTOMER_REVIEW = ("The Reading Room", 5,
                   "My favourite place to read on a weekday afternoon. Quiet, warm and the chai is great.")

# Popular searches: (query, times searched in the last few days).
SEARCH_HISTORY = [
    ("coffee", 9), ("pizza", 6), ("unstitched fabric", 5), ("ramen", 4),
    ("study spot", 3), ("gym", 3), ("dessert", 2), ("facial", 2),
]
# Recent searches for the demo customer, oldest first.
CUSTOMER_SEARCHES = ["late-night ramen", "unstitched fabric", "quiet cafés"]

# Module 9 demo chats with the demo customer: business → [(sent by the business?, text,
# minutes ago)]. The owner hasn't read Forno Italiano's last message and the customer
# hasn't read Glow Studio's reply, so both sides see an unread badge.
CONVERSATIONS = {
    "Brew & Bloom": [
        (False, "Hi! Do you have oat milk?", 185),
        (True, "Yes, oat and almond, at no extra charge 🌿", 180),
        (False, "Perfect, see you on Saturday.", 176),
    ],
    "Forno Italiano": [
        (False, "Do you take table bookings for 6 on Friday night?", 64),
        (True, "We do! Would you like the terrace or indoors?", 58),
        (False, "Terrace, please. Around 8 PM.", 12),
    ],
    "Glow Studio": [
        (False, "How long does the signature facial take?", 1500),
        (True, "About 60 minutes. Weekday mornings are quietest if you'd like a slot.", 1440),
    ],
}
CONVERSATIONS_UNREAD_BY_OWNER = {"Forno Italiano"}
CONVERSATIONS_UNREAD_BY_CUSTOMER = {"Glow Studio"}

# The demo customer's Notifications list: (kind, business, title, body, hours ago, read).
CUSTOMER_NOTIFICATIONS = [
    (NotificationKind.offer, "Forno Italiano", "New offer at Forno Italiano",
     "Family pizza night — 25% off", 2, False),
    (NotificationKind.trending, "Brew & Bloom", "Trending in Cafés",
     "Brew & Bloom is popular this week", 26, True),
]


@dataclass
class SeedReport:
    categories_added: int = 0
    users_added: int = 0
    businesses_added: int = 0
    businesses_refreshed: int = 0
    offers_added: int = 0
    reviews_added: int = 0
    searches_added: int = 0
    conversations_added: int = 0
    notifications_added: int = 0

    def __str__(self) -> str:
        return (
            f"Businesses: {self.businesses_added} added, {self.businesses_refreshed} refreshed. "
            f"Also added {self.categories_added} categories, {self.users_added} demo accounts, "
            f"{self.offers_added} offers, {self.reviews_added} reviews, "
            f"{self.searches_added} searches, {self.conversations_added} conversations, "
            f"{self.notifications_added} notifications."
        )


def reset(db: Session) -> None:
    """Delete every user, business and search. Never run this on a shared database."""
    for model in (
        Notification, DeviceToken, ConversationReport, Message, Conversation,
        SearchQuery, BusinessView, SavedBusiness, SavedList, ReviewReport, ReviewVote,
        ReviewPhoto, Review, Offer, Service,
        OpeningHours, BusinessProfile, Category,
    ):
        db.execute(delete(model))
    db.execute(delete(User))
    db.commit()


def _ensure_categories(db: Session, report: SeedReport) -> dict[str, Category]:
    cats = {c.slug: c for c in db.scalars(select(Category))}
    for slug, name, emoji, group, tone, sort_order, keywords in CATEGORIES:
        c = cats.get(slug)
        if c is None:
            c = cats[slug] = Category(slug=slug, tone=tone)
            db.add(c)
            report.categories_added += 1
        c.name, c.emoji, c.group_name = name, emoji, group
        c.sort_order, c.keywords = sort_order, keywords
    db.flush()
    return cats


def _ensure_users(db: Session, report: SeedReport) -> dict[str, User]:
    users = {}
    for spec in DEMO_USERS:
        user = db.scalar(select(User).where(User.email == spec["email"]))
        if user is None:
            user = User(hashed_password=hash_password(DEMO_PASSWORD), **spec)
            db.add(user)
            report.users_added += 1
        users[spec["email"]] = user
    db.flush()
    return users


def demo_phone(index: int) -> str:
    """Islamabad-format numbers whose subscriber part starts with 0, which no real line
    uses, so tapping Call in a demo can't ring a stranger."""
    return f"051 000 {index + 1:04d}"


def _apply_catalogue(
    b: BusinessProfile, spec: dict, cats: dict[str, Category], now: datetime, index: int
) -> None:
    """Copy a catalogue entry's descriptive fields, hours and services onto a business."""
    b.category_id = cats[spec["cat"]].id
    b.custom_category = spec.get("custom")
    b.phone = demo_phone(index)
    b.tone = spec["tone"]
    b.tagline = spec["tagline"]
    b.description = f"{spec['tagline']}. {spec['name']} is one of the newest finds on Khojlo."
    b.price_level = spec["price"]
    b.price_min = spec["pmin"]
    b.price_max = spec["pmax"]
    b.address = spec["address"]
    b.latitude = spec["lat"]
    b.longitude = spec["lng"]
    b.is_verified = spec["verified"]
    b.created_at = now - timedelta(days=spec["age"])
    for day in range(7):
        if day in spec["hours"]:
            opens, closes = spec["hours"][day]
            b.hours.append(OpeningHours(day_of_week=day, opens=opens, closes=closes))
        else:
            b.hours.append(OpeningHours(day_of_week=day, is_closed=True))
    for service_name, amount in spec["services"]:
        b.services.append(
            Service(
                name=service_name,
                price=f"Rs {amount:,}" if amount is not None else "",
                price_amount=amount,
            )
        )


def _sync_businesses(
    db: Session, owner: User, cats: dict[str, Category], now: datetime, report: SeedReport
) -> dict[str, BusinessProfile]:
    existing = {
        b.name: b
        for b in db.scalars(select(BusinessProfile).where(BusinessProfile.owner_id == owner.id))
    }
    by_name: dict[str, BusinessProfile] = {}
    for index, spec in enumerate(BUSINESSES):
        b = existing.get(spec["name"])
        if b is None:
            b = BusinessProfile(
                owner_id=owner.id,
                name=spec["name"],
                images=[],
                save_count=spec["saves"],
                view_count=spec["reviews"] * 6,
            )
            db.add(b)
            report.businesses_added += 1
        else:
            # Remove the old hours/services in their own flush, before the new rows go in.
            b.hours.clear()
            b.services.clear()
            db.flush()
            report.businesses_refreshed += 1
        _apply_catalogue(b, spec, cats, now, index)
        by_name[spec["name"]] = b
    db.flush()
    return by_name


def _add_offers(db: Session, biz: dict[str, BusinessProfile], report: SeedReport) -> None:
    have = set(db.execute(select(Offer.business_id, Offer.title)).tuples())
    for bname, offers in OFFERS.items():
        for title, starts, ends, status_, tone, views, redemptions in offers:
            if (biz[bname].id, title) in have:
                continue
            db.add(Offer(business_id=biz[bname].id, title=title, starts_on=starts,
                         ends_on=ends, status=status_, tone=tone, views=views,
                         redemptions=redemptions))
            report.offers_added += 1


def _ensure_reviewers(db: Session, report: SeedReport) -> list[User]:
    hashed = None
    reviewers = []
    for email, name, tone, verified in REVIEWERS:
        user = db.scalar(select(User).where(User.email == email))
        if user is None:
            hashed = hashed or hash_password(DEMO_PASSWORD)
            user = User(email=email, full_name=name, avatar_tone=tone, is_verified=verified,
                        role=UserRole.customer, hashed_password=hashed)
            db.add(user)
            report.users_added += 1
        reviewers.append(user)
    db.flush()
    return reviewers


def _stars(target: float, n: int, rng: random.Random) -> list[int]:
    """`n` star ratings averaging close to `target`, in a stable random order."""
    base = max(1, min(5, int(target)))
    highs = round((target - base) * n)
    stars = [min(base + 1, 5)] * highs + [base] * (n - highs)
    if n >= 6 and base >= 4:
        stars[-1] = base - 1  # one more critical voice keeps a long list believable
    rng.shuffle(stars)
    return stars


def _sentence_case(text: str) -> str:
    return ". ".join(part[:1].upper() + part[1:] for part in text.split(". "))


def _review_text(rating: int, category: str, rng: random.Random) -> str:
    if rng.random() < 0.12:
        return ""  # a rating on its own is a valid review
    group = "food" if category in FOOD else "shopping" if category in SHOPPING else "services"
    thing = rng.choice(REVIEW_DETAILS[group])
    return _sentence_case(rng.choice(REVIEW_OPENERS[rating]).format(thing=thing))


def _add_reviews(
    db: Session,
    biz: dict[str, BusinessProfile],
    reviewers: list[User],
    customer: User,
    now: datetime,
    report: SeedReport,
) -> None:
    """3–8 reviews per catalogue business from the demo reviewers, where they have none yet."""
    demo_ids = [u.id for u in reviewers]
    reviewed = set(db.scalars(select(Review.business_id).where(Review.user_id.in_(demo_ids))))
    for spec in BUSINESSES:
        b = biz[spec["name"]]
        if b.id in reviewed:
            continue
        rng = random.Random(f"reviews:{spec['name']}")
        n = 3 + rng.randrange(6)
        authors = rng.sample(reviewers, n)
        span_days = max(1, min(spec["age"], 150))
        for author, rating in zip(authors, _stars(spec["rating"], n, rng)):
            created = now - timedelta(days=rng.uniform(0, span_days))
            review = Review(business_id=b.id, user_id=author.id, rating=rating,
                            comment=_review_text(rating, spec["cat"], rng), created_at=created)
            if rating <= 3 or rng.random() < 0.3:
                review.owner_reply = OWNER_REPLIES[rating]
                review.owner_reply_at = min(now, created + timedelta(hours=rng.uniform(2, 48)))
            db.add(review)
            db.flush()
            voters = rng.sample([u for u in reviewers if u.id != author.id], rng.randrange(5))
            for voter in voters:
                db.add(ReviewVote(review_id=review.id, user_id=voter.id))
            review.helpful_count = len(voters)
            report.reviews_added += 1

    name, rating, comment = CUSTOMER_REVIEW
    has_own = select(Review.id).where(Review.user_id == customer.id, Review.deleted_at.is_(None))
    if name in biz and db.scalar(has_own) is None:
        db.add(Review(business_id=biz[name].id, user_id=customer.id, rating=rating,
                      comment=comment, created_at=now - timedelta(days=3)))
        report.reviews_added += 1
    db.flush()


def _refresh_ratings(db: Session) -> None:
    """Every business's rating and count come from its real reviews (SDD Algorithm 7)."""
    for b in db.scalars(select(BusinessProfile)):
        refresh_rating(db, b)


def _add_saved_lists(db: Session, customer: User, biz: dict[str, BusinessProfile]) -> None:
    owned = select(func.count()).select_from(SavedList).where(SavedList.user_id == customer.id)
    if db.scalar(owned):
        return
    weekend = SavedList(user_id=customer.id, name="Weekend", tone="gold")
    weekend.items.append(SavedBusiness(business_id=biz["Brew & Bloom"].id))
    weekend.items.append(SavedBusiness(business_id=biz["Forno Italiano"].id))
    coffee = SavedList(user_id=customer.id, name="Coffee tour", tone="emerald")
    coffee.items.append(SavedBusiness(business_id=biz["The Reading Room"].id))
    db.add_all([weekend, coffee])


def _add_search_history(db: Session, customer: User, now: datetime, report: SeedReport) -> None:
    """Popular searches, plus the demo customer's recent searches, where there are none yet."""
    if not db.scalar(select(func.count()).select_from(SearchQuery)):
        minutes = 0
        for query, times in SEARCH_HISTORY:
            for _ in range(times):
                minutes += 37
                db.add(SearchQuery(query=query, normalized=query, filters={}, result_count=3,
                                   created_at=now - timedelta(minutes=minutes)))
                report.searches_added += 1
    mine = select(func.count()).select_from(SearchQuery).where(SearchQuery.user_id == customer.id)
    if not db.scalar(mine):
        for i, query in enumerate(CUSTOMER_SEARCHES):
            db.add(SearchQuery(user_id=customer.id, query=query, normalized=query, filters={},
                               result_count=2,
                               created_at=now - timedelta(hours=len(CUSTOMER_SEARCHES) - i)))
            report.searches_added += 1


def _add_conversations(db: Session, customer: User, biz: dict[str, BusinessProfile],
                       now: datetime, report: SeedReport) -> None:
    """Demo chats (Module 9), only with businesses the customer hasn't talked to yet."""
    for name, lines in CONVERSATIONS.items():
        b = biz[name]
        exists = select(Conversation.id).where(Conversation.customer_id == customer.id,
                                               Conversation.business_id == b.id)
        if db.scalar(exists) is not None:
            continue
        conversation = Conversation(customer_id=customer.id, business_id=b.id,
                                    created_at=now - timedelta(minutes=lines[0][2]))
        db.add(conversation)
        db.flush()
        sent = []
        for from_business, text, minutes_ago in lines:
            message = Message(conversation_id=conversation.id,
                              sender_id=b.owner_id if from_business else customer.id,
                              from_business=from_business, body=text,
                              created_at=now - timedelta(minutes=minutes_ago))
            db.add(message)
            db.flush()
            sent.append(message)
        conversation.last_message_at = sent[-1].created_at

        def last_read(read_all: bool, by_business: bool) -> int | None:
            if read_all:
                return sent[-1].id
            own = [m.id for m in sent if m.from_business == by_business]
            return own[-1] if own else None  # read up to their own last message

        conversation.business_last_read_id = last_read(
            name not in CONVERSATIONS_UNREAD_BY_OWNER, by_business=True)
        conversation.customer_last_read_id = last_read(
            name not in CONVERSATIONS_UNREAD_BY_CUSTOMER, by_business=False)
        report.conversations_added += 1


def _add_notifications(db: Session, customer: User, biz: dict[str, BusinessProfile],
                       now: datetime, report: SeedReport) -> None:
    has_any = select(func.count()).select_from(Notification).where(
        Notification.user_id == customer.id)
    if db.scalar(has_any):
        return
    for kind, name, title, body, hours_ago, read in CUSTOMER_NOTIFICATIONS:
        created = now - timedelta(hours=hours_ago)
        db.add(Notification(user_id=customer.id, kind=kind, title=title, body=body,
                            route=f"/business/{biz[name].id}", created_at=created,
                            read_at=created + timedelta(minutes=5) if read else None))
        report.notifications_added += 1


def seed(db: Session, *, now: datetime | None = None) -> SeedReport:
    """Add and refresh the demo data in one transaction (see the module docstring)."""
    now = now or datetime.now(timezone.utc)
    report = SeedReport()
    cats = _ensure_categories(db, report)
    users = _ensure_users(db, report)
    reviewers = _ensure_reviewers(db, report)
    biz = _sync_businesses(db, users[OWNER_EMAIL], cats, now, report)
    _add_offers(db, biz, report)
    _add_reviews(db, biz, reviewers, users[CUSTOMER_EMAIL], now, report)
    _refresh_ratings(db)
    _add_saved_lists(db, users[CUSTOMER_EMAIL], biz)
    db.flush()
    _add_search_history(db, users[CUSTOMER_EMAIL], now, report)
    _add_conversations(db, users[CUSTOMER_EMAIL], biz, now, report)
    _add_notifications(db, users[CUSTOMER_EMAIL], biz, now, report)
    db.commit()
    return report


def run(*, wipe: bool = False) -> None:
    problem = schema_problem(engine)
    if problem:
        sys.exit(problem)
    db = SessionLocal()
    try:
        if wipe:
            reset(db)
        print(seed(db))
    finally:
        db.close()


if __name__ == "__main__":
    run(wipe="--reset" in sys.argv[1:])
