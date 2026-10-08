# KHOJLO — Project Mastery Handbook

> Your technical memory for the FYP defense. Everything here was checked against the actual code
> on the `dev` branch (commit `5b7ca3d`, 5 October 2026), not against what a Flutter/FastAPI project
> "usually" has.

| | |
|---|---|
| **Project** | Khojlo: a local business discovery platform (Final Year Project, BS Software Engineering 2023–2027, COMSATS University Islamabad, Abbottabad Campus) |
| **Team** (from the SRS) | Sayyam Tahir (SP23-BSE-014), Nouman Khan (SP23-BSE-012), Kazim Shauket (SP23-BSE-024) |
| **Supervisor** | Muhammad Tariq Baloch |
| **Code baseline** | Branch `dev`, which contains every other branch. `main` is **29 commits behind** `dev` (see Known Inconsistencies & Risks). |
| **Stack in one line** | Flutter + Riverpod app → FastAPI + SQLAlchemy API → PostgreSQL (hosted on Supabase), with Firebase Cloud Messaging for push and MapLibre + OpenStreetMap for maps |

## How to read the labels

| Label | Meaning |
|---|---|
| ✅ Implemented | The code exists, is wired end to end and has tests |
| 🟡 Partial | Some of it exists |
| 🎨 Prototype | Screens only, with sample data |
| 📝 Planned | Described in the documents but not in the code |
| **Not confirmed from codebase** | I could not prove it from the repository |
| **Inference** | My reasoning from the code, not something the code states directly |

Paths are relative to the repository root (`backend/...`, `frontend/...`, `docs/...`). Inside the
app, `lib/...` means `frontend/lib/...`. This handbook never shows secret values; it only names
the keys (for example `SECRET_KEY`).

## How to use this handbook before your viva

- **30 minutes:** Part 43 (mental model) → Part 44 (checklist) → Part 40 (trick questions) →
  Known Inconsistencies & Risks.
- **2 hours:** add Parts 1, 3, 5, 12, 15, 16 and 39.
- **A full day:** follow the 7-level study plan in Part 45, and do the traces in Part 42 with the
  code open next to you.

## Table of contents

- [Part 1: Understand the Idea First](#part-1-understand-the-idea-first)
- [Part 2: Product Features](#part-2-product-features)
- [Part 3: Modules](#part-3-modules)
- [Part 4: SRS Comparison](#part-4-srs-comparison)
- [Part 5: Complete System Architecture](#part-5-complete-system-architecture)
- [Part 6: Folder Structure](#part-6-folder-structure)
- [Part 7: Frontend Deep Dive](#part-7-frontend-deep-dive)
- [Part 8: Flutter Architecture](#part-8-flutter-architecture)
- [Part 9: Backend Deep Dive](#part-9-backend-deep-dive)
- [Part 10: Database Deep Dive](#part-10-database-deep-dive)
- [Part 11: Database Query Defense](#part-11-database-query-defense)
- [Part 12: Authentication](#part-12-authentication)
- [Part 13: Security](#part-13-security)
- [Part 14: Reviews and Fake Content](#part-14-reviews-and-fake-content)
- [Part 15: Chat and Messaging](#part-15-chat-and-messaging)
- [Part 16: Push Notifications](#part-16-push-notifications)
- [Part 17: Firebase Files](#part-17-firebase-files)
- [Part 18: Environment Variables](#part-18-environment-variables)
- [Part 19: Maps (Google Maps and What Is Actually Used)](#part-19-maps-google-maps-and-what-is-actually-used)
- [Part 20: Other External APIs and Services](#part-20-other-external-apis-and-services)
- [Part 21: Docker](#part-21-docker)
- [Part 22: Ports](#part-22-ports)
- [Part 23: API Inventory](#part-23-api-inventory)
- [Part 24: Control Flow](#part-24-control-flow)
- [Part 25: Data Flow](#part-25-data-flow)
- [Part 26: Error Handling](#part-26-error-handling)
- [Part 27: Testing](#part-27-testing)
- [Part 28: Documentation](#part-28-documentation)
- [Part 29: Tech Stack Master Table](#part-29-tech-stack-master-table)
- [Part 30: Library and Dependency Master Table](#part-30-library-and-dependency-master-table)
- [Part 31: Why These Technologies](#part-31-why-these-technologies)
- [Part 32: Product USPs](#part-32-product-usps)
- [Part 33: AI Opportunities](#part-33-ai-opportunities)
- [Part 34: Datasets and Research](#part-34-datasets-and-research)
- [Part 35: Limitations](#part-35-limitations)
- [Part 36: Scalability](#part-36-scalability)
- [Part 37: Deployment](#part-37-deployment)
- [Part 38: Git and Project Management](#part-38-git-and-project-management)
- [Part 39: Viva and Defense Question Bank](#part-39-viva-and-defense-question-bank)
- [Part 40: Trick Questions](#part-40-trick-questions)
- [Part 41: Real Code Examples](#part-41-real-code-examples)
- [Part 42: Trace This Feature Exercises](#part-42-trace-this-feature-exercises)
- [Part 43: Final Mental Model](#part-43-final-mental-model)
- [Part 44: What I Should Be Able to Answer After Studying](#part-44-what-i-should-be-able-to-answer-after-studying)
- [Part 45: Study Plan](#part-45-study-plan)
- [Known Inconsistencies & Risks](#known-inconsistencies--risks)

---

# Part 1: Understand the Idea First

## 1.1 Product overview

### What is Khojlo?

**Simple version.** Khojlo is a mobile and web app that helps people find local businesses,
especially new, small and underrated ones, and helps those businesses get noticed. The name comes
from the Urdu *"khoj lo"*, roughly "go find it" (general Urdu
meaning; the repository itself doesn't explain the name).

The project README describes it as *"An AI-powered platform to discover, promote, and connect local
businesses and customers. Khojlo surfaces the new, the unusual and the underrated — before
everyone else finds them."*

> **Be careful in the viva:** no AI model runs in Khojlo today. "AI-powered" refers to the planned
> Module 7 (RAG chatbot) and Module 10 (recommendations). Present the AI as planned work
> (Part 33), never as finished work.

### What problem does it solve?

The SRS (§2.1 Product Perspective) states the problem. Platforms like Google Maps and Yelp mostly
promote well-established, highly rated businesses. A tailor who opened last month in G-9, or a new
café in F-7, has no reviews yet, so it ranks below places with hundreds of reviews and stays
invisible. Customers who want something new, affordable or unique have no easy way to find it, and
owners have no cheap way to get noticed.

Khojlo's answer, as it appears in the code:

- **Give new businesses a fair chance** (SRS BR-6, "New businesses prioritized"):
  - The Home "Featured find" is picked from the **8 newest** businesses, weighted towards the
    newest (`_featured()` in `backend/app/api/feed.py`).
  - When two search results are equally relevant, the **newer business wins**
    (`backend/app/services/search/ranking.py`).
  - Businesses get a **"New" badge** for 30 days (`NEW_BUSINESS_DAYS` in
    `backend/app/core/config.py`).
  - Ratings used for ranking are **count-weighted** (a Bayesian average), so one 5★ review can't
    outrank a business with 200 good reviews, and a single bad review can't bury a new business
    (`ranking_score()` in `backend/app/services/review_service.py`).
- **Make choices easy:** keyword search (including local words like *darzi* and *dhaba*), filters
  (price in rupees, rating, distance, open now, offers, verified), and **side-by-side comparison**
  of 2–3 places.
- **Connect people:** customers can **chat** with the business directly, and get **push
  notifications** about replies, offers and new places.
- **Keep it trustworthy:** reviews and ratings, **automatic verification** with an in-app storefront
  photo, reporting, rule-based spam flags and an admin moderation panel.

What Khojlo deliberately does **not** do (SRS CO-10): online ordering, payments and delivery.

### Who are the target users?

| User | What they do in Khojlo | How the code knows them |
|---|---|---|
| **Customer** | Discover, search, filter, compare, save, review, message businesses, get notifications | `users.role = "customer"` |
| **Business owner** | Register and manage listings (photos, hours, services, prices, map pin), create offers and campaigns, reply to reviews and messages, see analytics, get verified | `users.role = "business_owner"` |
| **Admin** | Review verification referrals, handle reports and automatic flags, warn, suspend or ban accounts, read the audit log | `users.role = "admin"` (can't be created through sign-up; SRS SEC-3) |

The roles live in `UserRole` (`backend/app/models/user.py`). Users choose customer or business
owner on the sign-up screen (`lib/features/auth/presentation/auth_screen.dart`). The API refuses
`role = admin` at sign-up (`_no_self_service_admin` in `backend/app/schemas/auth.py`).

### What problem exists in the current market?

*(This is product reasoning from the SRS and Feasibility Report, not something code can prove.)*

- Discovery is dominated by big platforms and by word of mouth. Small Pakistani businesses (a
  *darzi*, a *dhaba*, a *kiryana* store) often exist only on a Facebook or Instagram page, or not
  online at all.
- Rating-based ranking favours old businesses, which gives new ones a "cold start" problem.
- Customers compare places by phoning around or visiting.

The local Pakistani focus is visible in the code:

- Demo data uses Islamabad sectors (F-7, G-9 …) and Abbottabad (`backend/app/db/seed.py`).
- Prices are in rupees (PKR), and "open now" uses the `Asia/Karachi` timezone.
- Category keywords include *darzi, dhaba, kiryana, dhobi*.
- The moderation rules understand **Roman Urdu** (`backend/app/services/moderation_rules.py`).
- Address search is limited to Pakistan (`GEOCODING_REGION=pk`).

### What is the core idea?

> **Discover → compare → contact → review**, with new businesses getting a fair share of
> visibility.

### What makes Khojlo different? (honestly)

Part 32 covers this properly. In short, the genuinely distinctive parts are:

- new-first featuring and ranking;
- 2–3 way comparison;
- local-language keyword search;
- chat with the business inside the discovery app;
- automatic verification based on an in-app storefront photo;
- offers and campaigns for small businesses, free of charge.

Reviews, maps, search and push notifications are standard features that every competitor has.

### Main use cases (SRS v1.2)

| Use case | Who |
|---|---|
| UC-1 Login (including Google) | All |
| UC-2 Manage Profile | Customer, Owner |
| UC-3 Browse Business Feed | Customer |
| UC-4 Search Businesses | Customer |
| UC-5 Filter and Compare Businesses | Customer |
| UC-6 View Business Details | Customer |
| UC-7 Submit Reviews and Ratings | Customer (in code: any signed-in user except the owner) |
| UC-8 Use AI Chatbot | Customer (🎨 prototype only) |
| UC-9 View Maps | Customer |
| UC-10 Register Business | Owner |
| UC-11 Manage Offers | Owner |
| UC-12 Verify Business | System + Admin |
| UC-13 Message a Business | Customer |
| UC-14 Respond to Customer Messages | Owner |
| UC-15 Receive Notifications | Customer, Owner |
| UC-16 Manage Content | Admin |
| UC-17 Manage Users | Admin |
| UC-18 Monitor System | Admin |

### The user journeys

**Customer:**

```text
Open app → onboarding → sign up (customer) → agree to privacy policy → pick interests
   → Home feed (featured, "because you like…", trending, nearby, campaign banners)
   → search "darzi" in Explore → filter (open now, < Rs 2,000) → compare 2–3 tailors
   → open a business → see photos, hours, prices, offers, reviews, map
   → save it / message it / get a route / write a review
   → get a push when the owner replies
```

**Business owner:**

```text
Sign up (business owner) → Business tab → "Register your business"
   → 8-step stepper: name & colour → category → location & contact → photos → about & prices
     → opening hours → services → review & publish
   → dashboard: views chart, saves, messages, rating, "N awaiting reply"
   → verification checklist: verify email, complete listing, take storefront photo → ✅ Verified badge
   → create offers and a campaign → customers who saved the business get notified
   → reply to reviews and chat messages
```

**Admin:**

```text
Sign in as admin → Profile → Admin panel → overview (queues, today's numbers, 14-day chart)
   → verification queue / reports / spam & flags / users / businesses / activity (audit log)
   → open an item → Decide: remove or keep, optionally warn, suspend or ban the account
```

## 1.2 Pitching Khojlo to five audiences

**1. To a non-technical person.**
"You know how new shops near you are hard to find online, because the apps only show the famous
places? Khojlo is an app that shows you the new and hidden places first. You can compare prices,
see if they're open right now, read honest reviews, and message the shop before you go."

**2. To a university evaluator.**
"Khojlo is a Flutter mobile and web application with a FastAPI backend and a PostgreSQL database.
It implements 8 of our 10 planned modules end to end: authentication, business management, the
discovery feed with push notifications, search and comparison, reviews, maps, admin moderation, and
real-time chat. Each module traces to SRS requirements, and the work is covered by automated
backend and Flutter tests. The two AI modules are planned for the final iteration, and the AI
module is currently a high-fidelity prototype."

**3. To a software engineer.**
"It's a monorepo:

- **Frontend:** Flutter with Riverpod for state, go_router for navigation, and Dio with a
  JWT-refresh interceptor.
- **Backend:** FastAPI with SQLAlchemy 2.0 and Alembic migrations on PostgreSQL. Auth uses bcrypt
  password hashing and HS256 JWTs (30-minute access, 14-day refresh).
- **Chat:** REST writes plus a single authenticated WebSocket for live events.
- **Push:** FCM HTTP v1 called directly with a service account.
- **Search:** the Strategy pattern, with SQL pre-filtering and Python ranking.
- **Maps:** MapLibre with OpenStreetMap vector tiles; geocoding and routing are proxied through the
  backend, which caches and rate-limits them."

**4. To a potential investor.**
"Local discovery in Pakistan is still word of mouth and Instagram. Every month, thousands of small
businesses open with no way to get noticed. Khojlo gives them a free listing, a verification badge,
offers and campaigns, and a direct chat with customers, while customers get a feed that favours
new places. Later revenue could come from promoted placements and analytics for owners (the
current scope deliberately has no payments)."

**5. To a business owner.**
"Register your shop in a few minutes. Add photos, prices, hours and your map location. Get a free
Verified badge by taking a photo of your shop front. Create offers and campaigns that go to people
who saved your business. Customers can message you directly, and you'll see how many people viewed
your page this week."

---

# Part 2: Product Features

How this inventory was built: every feature below was checked in the code (routes, screens,
tables). The status reflects what the code does, not what the documents say.

## 2.1 Implemented features

Each feature has the same fields: what it does, who uses it, frontend, backend, database, external
services, and status.

### Accounts and profile (Module 1)

**F1. Email sign-up with role choice and privacy consent** ✅

- **What and why:** create an account as a *customer* or *business owner*. A privacy-consent
  checkbox must be ticked; it's never pre-ticked (SRS FR-1, FR-31, BR-21).
- **Who:** customers and owners.
- **Frontend:** `lib/features/auth/presentation/auth_screen.dart` → `AuthController.register()` →
  `AuthRepository.register()`.
- **Backend:** `POST /api/v1/auth/register` (`register()` in `backend/app/api/auth.py`).
- **Database:** `users` (bcrypt hash, role, interests, privacy version) and `otp_codes`.
- **External:** SMTP email for the verification code.
- **Status:** ✅

**F2. Login and session restore** ✅

- **What and why:** email and password login returns two JWTs. The app keeps them in secure
  storage, so the next launch skips the login screen (FR-2).
- **Frontend:** `AuthController.login()` / `bootstrap()` (`lib/features/auth/auth_controller.dart`)
  and `TokenStorage` (`lib/core/storage/token_storage.dart`).
- **Backend:** `POST /auth/login`, `POST /auth/refresh` and `GET /users/me`.
- **Database:** `users`.
- **Status:** ✅

**F3. Google Sign-In** ✅

- **What and why:** one-tap login with a Google account. The backend verifies Google's **ID token**
  and links the account or creates one (UC-1 alternative flow).
- **Frontend:** `google_sign_in` (`AuthRepository.signInWithGoogle()`), and on the web Google's
  rendered button (`google_sign_in_web`, `lib/features/auth/presentation/google_web_button_web.dart`).
- **Backend:** `POST /auth/google` (`google_login()`) and `verify_google_id_token()`
  (`backend/app/core/security.py`).
- **Database:** `users.google_id`.
- **External:** Google OAuth (ID token signature checked against Google's public keys).
- **Status:** ✅

**F4. Email verification by one-time code** ✅

- **What and why:** a 6-digit code is emailed to prove the user owns the address (FR-17). A
  verified email is also one of the business verification checks.
- **Frontend:** `email_verification_sheet.dart` (using the `pinput` package).
- **Backend:** `POST /auth/email/verify/send` and `POST /auth/email/verify` (`otp_service.py`).
- **Database:** `otp_codes` (only a hash of the code is stored).
- **External:** SMTP.
- **Status:** ✅

**F5. Forgot and reset password** ✅

- **What and why:** request a code, enter it to get a short-lived reset token, then set a new
  password (FR-17).
- **Frontend:** `forgot_password_screen.dart`.
- **Backend:** `POST /auth/password/forgot`, then `/password/forgot/verify`, then
  `/password/reset`.
- **Database:** `otp_codes` and `users.hashed_password`.
- **Status:** ✅

**F6. Privacy policy and consent screen** ✅

- **What and why:** the policy text lives in the app. The server records which version each user
  agreed to and when. Changing the version asks everyone again (FR-31).
- **Frontend:**
  - `lib/features/legal/privacy_policy.dart` (the text and `kPrivacyPolicyVersion`);
  - `privacy_consent_screen.dart` and `privacy_policy_screen.dart`;
  - the router forces `/privacy-consent` until the user agrees.
- **Backend:** `POST /users/me/privacy-consent` and `backend/app/core/privacy.py`
  (`PRIVACY_POLICY_VERSION = "2026-09-30"`).
- **Database:** `users.privacy_policy_version` and `users.privacy_consent_at`.
- **Status:** ✅

**F7. Delete account** ✅

- **What and why:** permanently deletes the user and everything they own, then recalculates the
  counters that depended on them (FR-32, Google Play requirement).
- **Frontend:** `lib/features/account/presentation/delete_account_sheet.dart`.
- **Backend:** `DELETE /users/me` → `delete_account()` (`backend/app/services/account_service.py`).
- **Database:** `ON DELETE CASCADE` across many tables; `business_views.viewer_id` is `SET NULL`.
- **Status:** ✅

**F8. Edit profile** ✅

- **What:** name, phone number, profile photo, avatar colour and interests (FR-16).
- **Frontend:** `edit_profile_screen.dart`.
- **Backend:** `PATCH /users/me` and `PUT /users/me/interests`.
- **Database:** `users` and `media`.
- **Status:** ✅

**F9. Interest selection** ✅

- **What and why:** new customers pick categories they like. This powers the "Because you like…"
  row and the new-business notifications.
- **Frontend:** `interests_screen.dart`.
- **Backend:** `PUT /users/me/interests`.
- **Database:** `users.interests` (a JSON list of category slugs).
- **Status:** ✅

**F10. Saved lists (favourites)** ✅

- **What:** save businesses into named lists (FR-7).
- **Frontend:** `saved_screen.dart` and the Save button on the business page.
- **Backend:** `POST/DELETE /businesses/{id}/save`, `GET/POST /users/me/saved` and
  `DELETE /users/me/saved/{list_id}`.
- **Database:** `saved_lists`, `saved_businesses` and the `businesses.save_count` counter.
- **Status:** ✅

### Business management (Module 2)

**F11. Business registration stepper** ✅

- **What:** an 8-step form: name and colour → category → location and contact → photos → about
  and prices → hours → services → review and publish (FR-8, UC-10).
- **Frontend:** `lib/features/business/presentation/registration_stepper.dart` (`_publish()` calls
  `BusinessRepository.create()`).
- **Backend:** `POST /businesses` (`create_business()`, owner role required).
- **Database:** `businesses`, `services`, `opening_hours` and `business_photos`.
- **Status:** ✅

**F12. Edit business, hours, photos and map pin** ✅

- **What:** owners keep the listing up to date (FR-9). Changing the name, address or pin removes
  the Verified badge until a new storefront photo is taken.
- **Frontend:** `edit_business_screen.dart`, `edit_hours_screen.dart`, `edit_photos_screen.dart`
  and `location_picker_screen.dart`.
- **Backend:** `PATCH /businesses/{id}`, `PUT /businesses/{id}/hours` and
  `PUT /businesses/{id}/photos`.
- **Status:** ✅

**F13. Photos** ✅

- **What:** uploads are checked, turned upright, stripped of metadata (including GPS), resized into
  a large version and a thumbnail, and given a "focal point" so automatic crops keep the subject.
  Each business has up to 10 photos, and the first is the cover.
- **Backend:** `POST /media`, `GET /media/{key}` and `GET /media/{key}/thumb`
  (`backend/app/services/media_service.py`, using **Pillow**).
- **Database:** `media` (the image bytes are stored **in PostgreSQL**) and `business_photos`.
- **Status:** ✅

**F14. Categories** ✅

- **What:** 25 specific categories in 5 groups, plus "Other" (the owner describes the business).
  They're stored as **rows in the database**, so new ones need no code change (SRS SCA-1).
- **Backend:** `GET /categories`.
- **Database:** `categories` (`slug`, `emoji`, `group_name`, `sort_order`, `keywords`).
- **Status:** ✅

**F15. Owner dashboard and analytics** ✅

- **What:** profile views per day for the last 7 days, this week vs last week, saves, customer
  messages (this week and unread), and the rating with the number of reviews awaiting a reply
  (FR-20).
- **Frontend:** `dashboard_screen.dart`.
- **Backend:** `GET /businesses/{id}/analytics` (`build_analytics()` in `business_service.py`).
- **Database:** `business_views` (one row per view) and `messages`.
- **Status:** ✅

**F16. Offers and promotional campaigns** ✅

- **What:**
  - **Offers** have a deal type (% off, Rs off, buy-1-get-1, free item, other), real start and end
    dates, terms, and the states Draft / Scheduled / Active / Expired.
  - **Campaigns** promote one or more offers for a period, with a banner photo, a message and
    featured services.
  - Customers see Home banners, an "Active promotion" badge and an "On now" strip (FR-10, UC-11).
- **Frontend:** `lib/features/promotions/` (editors, the campaign screen) and `promotion_badge.dart`.
- **Backend:** `backend/app/api/promotions.py` and `backend/app/services/promotion_service.py`.
- **Database:** `offers`, `campaigns`, `campaign_offers` and `campaign_services`.
- **Rule:** activating an offer or publishing a campaign needs a **verified** business (the UC-11
  precondition).
- **Status:** ✅

**F17. Automatic business verification** ✅

- **What:** the system gives the Verified badge when four checks pass:
  1. The owner's email is verified.
  2. The listing is complete.
  3. The owner took a **storefront photo in the app**.
  4. There is no open report or flag.

  If everything passes except the last check, the business is referred to an admin (FR-14,
  UC-12).
- **Frontend:** `verification_screen.dart`.
- **Backend:** `GET /businesses/{id}/verification`, `PUT …/verification/storefront`,
  `POST …/verification/review` and `backend/app/services/verification_service.py`.
- **Database:** the `businesses.verification_status` and `storefront_media_id` columns, and
  `moderation_actions` (the audit log).
- **Status:** ✅

### Discovery (Module 3)

**F18. Home discovery feed** ✅

- **What:**
  - a greeting ("Good evening, Ali") and a headline ("3 hidden gems opened this week");
  - category chips and campaign banners;
  - "Featured find" (newest first);
  - "Because you like …" (your interests) or "Worth exploring";
  - "Trending today";
  - "Nearby" (when location is allowed).

  Pull to refresh rotates the rows (FR-11, UC-3, BR-6).
- **Frontend:** `home_screen.dart` and `feedProvider` / `feedSeedProvider`
  (`lib/features/discovery/discovery_providers.dart`).
- **Backend:** `GET /feed` (`get_feed()` in `backend/app/api/feed.py`).
- **Status:** ✅

**F19. Surprise me** ✅

- **What:** a swipeable stack of every listed business in random order.
- **Frontend:** `lib/features/prototype/surprise_screen.dart`. The file is in the prototype folder,
  but it calls the **real** API.
- **Backend:** `GET /feed/surprise`.
- **Status:** ✅

**F20. Business detail page** ✅

- **What:**
  - photos and the gallery viewer, services and prices, hours and "open now", live offers, the
    campaign strip;
  - the reviews section, a small live map, and the Directions, **Call** (`tel:`) and **Share**
    (`share_plus`) buttons;
  - Compare, **Message**, Save, and "Report this business" (FR-5, UC-6).
- **Frontend:** `lib/features/discovery/presentation/business_detail_screen.dart`.
- **Backend:** `GET /businesses/{id}`, which also counts a profile view in the background.
- **Status:** ✅

**F21. Push notifications** ✅

Covered in Part 16. Formally part of Module 3 (FR-21, UC-15).

### Search and compare (Module 4)

**F22. Keyword search, typeahead, recent and popular searches** ✅

- **What:**
  - keyword search across name, category (and its local keywords), services, tagline, address
    and description;
  - accent-insensitive ("cafe" finds "Cafés");
  - falls back to "any word" when an all-words search finds nothing.
- **Frontend:** `lib/features/search/` (`SearchNotifier` debounces typing by 350 ms).
- **Backend:** `GET /search`, `/search/suggestions`, `/search/popular`, `/search/history` and
  `DELETE /search/history`.
- **Database:** `search_queries`.
- **Status:** ✅

**F23. Filters and sorting** ✅

- **Filters:** category, price tier ($/$$/$$$), rupee budget, minimum rating, distance radius,
  open now, has an offer, verified only.
- **Sort orders:** relevance, distance, rating, price low or high, newest, popular.
- **Frontend:** `filter_sheet.dart`.
- **Backend:** the strategies in `backend/app/services/search/strategies.py`.
- **Status:** ✅

**F24. Compare 2–3 businesses** ✅

- **What:** side-by-side rows (price, rating, distance, open now, services, offers, category,
  saves, verified) with the best value in each row highlighted (FR-18, BR-12).
- **Frontend:** `compare_screen.dart` and `CompareController`.
- **Backend:** `GET /compare?ids=…` (`build_comparison()` in `compare_service.py`).
- **Status:** ✅

### Reviews (Module 5)

**F25. Reviews and ratings** ✅

- **What:**
  - 1–5★ with an optional comment (up to 1,000 characters) and up to 3 photos;
  - one review per business per user;
  - edit (marked "edited") and delete (a soft delete);
  - "Most relevant" ordering puts verified-email reviewers first;
  - "With photos" and star filters.

  The business rating is recalculated on every change (FR-6, UC-7, BR-4).
- **Frontend:** `lib/features/reviews/` (with confetti on submit).
- **Backend:** `backend/app/api/reviews.py` and `review_service.py`.
- **Database:** `reviews`, `review_photos`, `review_votes` and `review_reports`.
- **Status:** ✅

**F26. Owner replies, helpful votes, reporting reviews** ✅

- **What:** one public reply per review from the owner, "Helpful" votes, and reports (spam, fake,
  offensive, other) that go to the admin queue (FR-19).
- **Status:** ✅

### Maps (Module 6)

**F27. Map tab** ✅

- **What:**
  - an interactive map (MapLibre with OpenStreetMap vector tiles) with Khojlo-coloured pins;
  - a preview card for the tapped pin and a nearby carousel;
  - results reload when the map stops moving;
  - it shares one search with Explore, with a List | Map switch (FR-12, UC-9).
- **Frontend:** `lib/features/maps/presentation/map_screen.dart`, `map_providers.dart` and
  `lib/core/maps/`.
- **Backend:** `GET /search` with `north`, `south`, `east` and `west` (the `AreaSearch` strategy).
- **External:** OpenFreeMap tiles.
- **Status:** ✅

**F28. Pin picker, address lookup and location indicator** ✅

- **What:** owners drag the map under a fixed pin, and the address fills in. Home shows "Near F-7
  Markaz, Islamabad".
- **Backend:** `GET /geo/reverse` and `GET /geo/search` (`backend/app/services/geocoding.py`).
- **External:** OpenStreetMap **Nominatim** (reverse) and **Photon** (search), through the backend.
- **Status:** ✅

**F29. Route preview and directions** ✅

- **What:** an in-app route line with Car / Walk and "~11 min · 4.3 km". **Start in Google Maps**
  opens turn-by-turn navigation.
- **Frontend:** `route_screen.dart` (`showRoute()`).
- **Backend:** `GET /geo/route` (`backend/app/services/routing.py`).
- **External:** **openrouteservice**, plus a Google Maps URL (no key needed).
- **Status:** ✅

### Admin and moderation (Module 8)

**F30. Admin panel** ✅

- **What:** overview, verification queue, reports, spam and flags, users, businesses, and an
  activity timeline (the audit log) (UC-16–UC-18).
- **Frontend:** `lib/features/admin/`.
- **Backend:** `backend/app/api/admin.py` (15 routes, admin-only).
- **Status:** ✅

**F31. Reporting** ✅

- **What:** report a review, a conversation (which shares it with moderators) or a business. Each
  user can report each item once (FR-19, BR-13).
- **Status:** ✅

**F32. Rule-based automatic flags** ✅

- **What:** English and Roman Urdu rules for spam, scams, adult or prohibited content, fake-review
  bursts, duplicate listings, extreme discounts and mass messaging. **A flag never hides
  anything**; an admin decides (FR-27, BR-18).
- **Backend:** `backend/app/services/moderation_rules.py`.
- **Status:** ✅

**F33. Account moderation** ✅

- **What:** warn, suspend (1–365 days), ban or lift. Suspended and banned accounts get a 403 on
  every request and can't open a chat socket (FR-26, SEC-6).
- **Status:** ✅

**F34. Blocking a conversation and the Community Guidelines** ✅

FR-28, FR-29. `guidelines_screen.dart` and `POST/DELETE /conversations/{id}/block`.

### Chat (Module 9)

**F35. Customer ↔ business chat** ✅

- **What:**
  - a conversation list with unread counts and a Chat tab badge;
  - live delivery over a WebSocket, "Seen" receipts and "typing…";
  - photo messages, suggested replies, and the business's offers inside the chat;
  - report and block (FR-23–FR-25, UC-13, UC-14).

  See Part 15.
- **Status:** ✅

### Notifications

**F36. Notifications list and settings** ✅

- **What:** a bell screen (Today / Earlier, mark read) and five on/off switches: messages, reviews,
  offers, new places, trending (BR-14).
- **Status:** ✅

**F37. Trending digest** ✅ (run by hand)

- **What:** `python -m app.jobs.trending_digest` sends each user one "Trending in &lt;category&gt;"
  notification, at most once per 20 hours.
- **Status:** ✅. Nothing schedules it automatically.

### Polish

**F38. Location explanation before the permission prompt** ✅

`lib/core/location/location_rationale.dart` (SEC-7). The location is **never stored** on the
server.

**F39. Branding and splash animation** ✅

`lib/core/ui/splash_overlay.dart` and the launcher icons.

## 2.2 Partially implemented

| Feature | What exists | What's missing |
|---|---|---|
| **Module 10: personalization** 🟡 | The feed's "Because you like X" row picks from your interest categories (`get_feed()` in `backend/app/api/feed.py`). Search history is stored in `search_queries` for future use. | FR-22 says "based on interests **and activity, such as saves, views and searches**". Activity isn't used yet. |
| **Module 7: Kai chatbot** 🎨 | A chat-style screen (`lib/features/prototype/kai_screen.dart`) whose own comment says *"prototype with canned grounded answers"*. Kai is pinned at the top of the Chat tab. | No language model, no retrieval (RAG), no backend endpoint. |
| **"AI summary" in search** 🟡 | A **rule-based** summary line ("3 places · mostly $ · 2 open now · avg ★ 4.6 · nearest 0.4 km") from `summarize()` in `backend/app/services/search/engine.py`. | An AI-written summary (planned with Module 7). |
| **Multiple businesses per owner** 🟡 | The API supports any number (`GET /businesses/mine`). | The Business tab dashboard opens only the **first** business (`business_tab_screen.dart`). |

## 2.3 Planned or not implemented

| Item | Where it's planned | Status |
|---|---|---|
| RAG chatbot answering from platform data (FR-13, CO-6, UC-8) | `implementation_plan.md` Phase 3 | 📝 |
| Recommendations from saves, views and searches (FR-22) | Phase 3 | 📝 |
| AI moderation classifier (Claude, measured against admin decisions) | `module8_admin_moderation_plan.md` Tier 3 | 📝 |
| Trust Score (SDD Screen 3) | Open decision 7 in `document_review.md` | 📝 |
| Appeals and reporter credibility | Module 8 Tier 3 | 📝 |
| HTTPS/WSS deployment (SEC-4) and performance testing (PER-1–PER-6) | Phase 3 | 📝 |
| iOS push notifications | Out of scope (SRS CO-11: needs a paid Apple account) | ❌ |
| "Save draft" during business registration (UC-10 alternative flow) | SRS UC-10 | ❌ Businesses publish immediately; only offers and campaigns have drafts |
| Uploading verification documents (UC-10 "Upload docs") | SRS UC-10 | Replaced by the in-app storefront photo (Module 8 decision) |
| Online ordering, payments, delivery, bookings | Never planned (SRS CO-10) | ❌ by design |

## 2.4 Future ideas

AI ideas are in Part 33. Product ideas that fit the current architecture:

- Verified-visit reviews: a QR code at the shop, or the chat history as proof of contact.
- Paid promoted placements as a revenue model.
- An owner web dashboard.
- Multi-city expansion (SRS SCA-2), and Urdu-script UI.
- Business hours exceptions (holidays, Ramadan timings).

---

# Part 3: Modules

## 3.1 How many modules are there?

**Ten.** They're defined in the Feasibility Report, and SRS Appendix A maps each one to use cases
and functional requirements.

## 3.2 Module table

| # | Module | Purpose | Status | Frontend | Backend | Database | External services |
|---|---|---|---|---|---|---|---|
| 1 | User Authentication & Profile | Sign-up, login, Google, OTP, profile, saved lists, consent, delete account | ✅ | `features/auth`, `features/account`, `features/legal` | `api/auth.py`, `api/users.py`, `services/otp_service.py`, `services/account_service.py` | `users`, `otp_codes`, `saved_lists`, `saved_businesses` | Google OAuth, SMTP |
| 2 | Business Registration & Management | Listings, photos, hours, services, analytics, offers and campaigns | ✅ | `features/business`, `features/promotions` | `api/businesses.py`, `api/promotions.py`, `api/media.py`, `services/business_service.py`, `services/promotion_service.py`, `services/media_service.py` | `businesses`, `services`, `opening_hours`, `media`, `business_photos`, `offers`, `campaigns` (+2 link tables), `business_views` | — |
| 3 | Business Discovery Feed (+ push) | Home feed, business page, surprise, push notifications | ✅ | `features/discovery`, `features/notifications`, `core/push` | `api/feed.py`, `api/notifications.py`, `services/notification_service.py`, `services/push.py`, `jobs/` | `notifications`, `device_tokens` | Firebase Cloud Messaging |
| 4 | Search, Filtering & Comparison | Keyword search, filters, sort, compare | ✅ | `features/search` | `api/search.py`, `api/compare.py`, `services/search/`, `services/compare_service.py` | `search_queries` | — |
| 5 | Reviews & Ratings | Reviews, replies, helpful votes, reports | ✅ | `features/reviews` | `api/reviews.py`, `services/review_service.py` | `reviews`, `review_photos`, `review_votes`, `review_reports` | — |
| 6 | Maps & Location | Map tab, pins, pin picker, geocoding, routes | ✅ | `features/maps`, `core/maps`, `core/location` | `api/geo.py`, `services/geocoding.py`, `services/routing.py` | (coordinates on `businesses`) | OpenFreeMap, Photon, Nominatim, openrouteservice; Google Maps optional |
| 7 | AI Chatbot (Kai, RAG) | Answer questions about businesses | 🎨 Prototype | `features/prototype/kai_screen.dart` | — | — | — (planned: an LLM) |
| 8 | Admin & Moderation | Verification, reports, flags, account actions, audit log | ✅ (AI at 100%) | `features/admin`, `verification_screen.dart`, `report_business_sheet.dart`, `guidelines_screen.dart` | `api/admin.py`, `services/verification_service.py`, `services/moderation_service.py`, `services/moderation_rules.py` | `business_reports`, `moderation_flags`, `moderation_actions` (+ columns on `users` and `businesses`) | SMTP (suspension emails) |
| 9 | Chat & Messaging | Customer ↔ business messages, live events | ✅ | `features/chat`, `core/realtime` | `api/chat.py`, `services/chat_service.py`, `services/realtime.py` | `conversations`, `messages`, `conversation_reports` | FCM (offline pushes) |
| 10 | AI Personalization & Recommendation | Personalized feed | 🟡 Basic (interest row) | `home_screen.dart` | `api/feed.py` | `users.interests` | — |

In this table, frontend paths are under `frontend/lib/` and backend paths are under
`backend/app/`.

## 3.3 How much is implemented in the 60% iteration?

- **By module:** 8 of 10 modules are production-ready (1, 2, 3, 4, 5, 6, 8, 9). Module 10 has a
  basic version, and Module 7 is a prototype.
- **By the committee's 60% slide:** all **8 items** on the second-iteration slide are implemented.
  They're listed in `docs/development_roadmap/implementation_plan.md` ("Phase 2 – 60% Evaluation"):
  1. User reviews and ratings (M5)
  2. Business search and advanced filtering (M4)
  3. Business comparison (M4)
  4. Admin moderation panel (M8)
  5. Maps and location services (M6)
  6. Offers and promotional campaigns (M2)
  7. Push notification system (M3)
  8. Chat and messaging (M9)

> **Don't invent a percentage of code.** If asked "how much is done?", answer by module (8/10
> production, 1 partial, 1 prototype) and by the slide (8/8 items).

### How was the 60% scope decided?

- The **Feasibility Report's Gantt chart** set the milestones (30% → 60% → 100%). The 60%
  milestone is dated **6 October 2026**.
- The **committee's second-iteration slide** listed what 60% must contain. The roadmap was aligned
  to that slide (document review item G5).
- Modules 7 and 10 were on earlier plans for 60%, but they aren't on the slide, so they moved to
  100% (`document_review.md`, decision 4).
- Modules **1–3** were the **30% build**. Module 4 was planned as a prototype at 30% but was
  finished early.

## 3.4 Who built what (from git history)

The git log shows commits from two authors. Know this so you can explain contributions honestly.

| Work | Commits (author) |
|---|---|
| Initial project, Modules 1–3 (30% build), Google Sign-In, email verification and password reset | Nouman (Jul 2026) |
| Module 4 search/filter/compare; photos, categories, phone and Call, edit profile | Sayyam (27 Sep) |
| Module 5 reviews (this commit also added the Google-based Module 6 maps) | Sayyam (27 Sep) |
| Module 9 chat + push notifications, and the how-it-works guide | Nouman (28–29 Sep, PR #15) |
| Offers and campaigns | Sayyam (29 Sep) |
| Privacy consent and account deletion | Nouman (30 Sep, PR #18) |
| Module 8 admin and moderation | Sayyam (1 Oct, PR #17) |
| Branding, feed rotation seed | Nouman (2–4 Oct, PR #19) |
| MapLibre/OpenStreetMap switch, OSM geocoding, openrouteservice route preview, splash animation | Nouman (4–5 Oct, PR #20) |
| Google Sign-In web support, document uploads (SRS/SDD/Feasibility) | Sayyam (25 Sep) |

The Feasibility Report's work-division table is out of date (see Known Inconsistencies & Risks).

## 3.5 The implemented modules in detail

### Module 1: Authentication and profile

- **Accounts:** email and password accounts; passwords are hashed with **bcrypt**.
- **Tokens:** JWT **access tokens (30 min)** and **refresh tokens (14 days)**, signed with
  `SECRET_KEY` using HS256 (`backend/app/core/security.py`).
- **Google Sign-In:** the backend verifies Google's ID token; this is *not* Firebase Auth.
- **Email codes:** 6-digit codes for verification and password reset, with cooldowns and limits.
- **Profile:** name, phone, photo, colour, interests.
- **Saved lists, privacy consent and account deletion.**
- The router enforces three gates: signed-out users go to onboarding, users without consent go to
  the consent screen, and non-admins can't open admin screens.

### Module 2: Business registration and management

- **Listing:** the 8-step stepper, rupee price ranges, services with prices, weekly hours
  (including overnight and 24-hour days), a map pin, and a phone number for Call.
- **Photos:** stored in PostgreSQL with a thumbnail and a focal point.
- **Dashboard:** views per day, saves, messages and rating.
- **Offers and campaigns:** described above.
- **Verification:** the owner side of automatic verification (the checklist and the storefront
  photo).

### Module 3: Discovery feed and push

The feed has four rows plus campaign banners, a greeting, and a headline computed from real data.
The business page is described above. Push notifications go out for messages, reviews, replies,
offers, new businesses in your interests, and the trending digest.

### Module 4: Search, filter and compare

- **Design:** the SDD's **Strategy pattern**. `SearchEngine` runs a list of `SearchStrategy`
  objects (`KeywordSearch`, `CategorySearch`, `LocationSearch`, `AreaSearch` and filters).
- **Two-stage matching:** SQL narrows the candidates first, then Python confirms what SQL can't do
  portably (accents, exact distance, open now).
- **Ranking:** weighted relevance, then new, then near, then rated.
- **Compare:** 2–3 places, with the winners highlighted.

### Module 5: Reviews and ratings

- One review per user per business, enforced twice: by the API (a 409 response) and by a
  **partial unique index** in the database.
- Ratings are recalculated in the same transaction (SDD Algorithm 7).
- Sorting by rating uses a **Bayesian rating** (prior mean 3.5, weight 3).
- Owner replies, helpful votes, reports and photo reviews.

### Module 6: Maps and location

- **Map:** `MapService` (an SDD interface) with MapLibre, Google and Sketch implementations. The
  default is **MapLibre + OpenStreetMap tiles from OpenFreeMap** (no key).
- **Search on the map:** map-area search plugs into Module 4.
- **Pin picker and indicator:** geocoding goes through the backend (Photon and Nominatim), and
  Home shows the location indicator.
- **Routes:** the route preview uses openrouteservice. Directions open Google Maps.
- **BR-7:** valid coordinates only; (0, 0) is rejected.

### Module 8: Admin and moderation

- **Automatic verification:** four checks, with the business lifecycle Unverified → Pending Review
  → Verified / Needs Info / Rejected, plus Suspended.
- **Reports:** queues for reviews, conversations and businesses.
- **Flags:** rule-based, and they never hide content.
- **Accounts:** warn, suspend or ban. Blocking in chat. The Community Guidelines.
- **Audit log:** every decision.
- **Notices:** sent for every decision, and they can't be switched off.

### Module 9: Chat and messaging

- **Writes over REST:** sending, reading and history.
- **Live events over one WebSocket:** `message.new`, `conversation.read`, `typing`.
- **Delivery choice:** if the recipient has no open socket, they get an FCM push instead.
- **Reliability:** `client_id` makes retries safe; read markers drive unread counts and "Seen".
- **Fallback:** the app polls every 8 seconds while the socket is down.

---

# Part 4: SRS Comparison

## 4.1 Which documents exist

| Document | File | Status |
|---|---|---|
| SRS v1.0 (submitted) | `docs/requirements/SRS.pdf` | Read-only record of the submission |
| SRS v1.2 (working draft) | `docs/requirements/SRS.md` | Editable copy. Marks v1.1 and v1.2 changes. Adds FR-16 to FR-32 and UC-13 to UC-18. |
| SDD | `docs/requirements/SDD.pdf` | Architecture, class diagrams, algorithms. Corrections are listed but not yet applied to the Word file. |
| Feasibility Report | `docs/requirements/Feasibility_Report.pdf` | Problem, modules, tools, work division, Gantt chart |
| Documentation review | `docs/requirements/document_review.md` | Every inconsistency found, with a fix and the open decisions |

The rule the team agreed (`docs/README.md`): requirements decide **what** the system does; the
design bundle decides how screens look; the module records describe **what was actually built**.

## 4.2 Requirement-by-requirement comparison

| SRS requirement | Original plan (v1.0 / Feasibility) | Current implementation | Difference | Reason |
|---|---|---|---|---|
| OE-5 / CO-2 Python | Python 3.12 | Python **3.14** locally ("3.12 or later" in v1.1) | Newer version | The team's machines run 3.14 only |
| OE-6 PostgreSQL | 18.3 or later | Works on **14+** (shared Supabase DB; local `postgresql@14` or `postgres:16` in Docker) | Lower minimum | 18.3 was unrealistic for the shared and local databases |
| CO-1 Flutter | Flutter 3.24 / Dart 3.5 | Flutter **3.41+**, Dart **3.11+** (`pubspec.yaml`: `sdk: ^3.11.1`) | Newer | Dependencies require it |
| CO-4 Communication | REST only | REST **plus one WebSocket** (`/api/v1/ws`) for live chat events | Added a real-time channel | REST alone can't push messages instantly (PER-6) |
| OE-8 / CO-5 / UC-9 Maps | Google Maps SDK and APIs | **MapLibre + OpenStreetMap (OpenFreeMap tiles)** by default; Google Maps is opt-in (`MAP_PROVIDER=google`). Address lookup uses **Photon and Nominatim**; routes use **openrouteservice**; Directions opens a Google Maps link. | Provider changed | Google Maps needs a billing account, which the team couldn't set up. The SDD's `MapService` interface made the switch possible without touching the screens. **The SRS text still says Google Maps.** |
| FR-14 / BR-9 Verification | "Admin shall verify business profiles **before publication**" | Businesses are listed immediately. The **system** verifies automatically (email + complete listing + in-app storefront photo + clean record), and admins only review referrals. | Automated | An admin can't be on duty around the clock (decision 1, SRS v1.2) |
| BR-3 / FR-5 / UC-6 | "Only verified business profiles displayed" | All **published, non-suspended** businesses are shown. Verified ones get a badge, and there's a "Verified only" filter. | Relaxed | Follows the new verification model (v1.2) |
| UC-3 rule | "Verified prioritized" (contradicted BR-6) | **New businesses prioritized** (featured and ranking ties) | Conflict resolved | v1.1 fix R14 |
| UC-10 Register Business | "Upload docs", "Save draft" | No document upload. Verification uses an **in-app storefront photo**. **No draft**: a business is published when the stepper finishes. | Changed / not implemented | Photos are simpler to check than documents; drafts weren't prioritized |
| UC-7 / FR-6 Reviews | One review per business; assumes the customer visited | One review per business per user ✅. **No visit check.** Any signed-in user except the owner can review. Edits and deletes are allowed. | Assumption not enforced | The app can't prove a visit (Module 5, decision 2) |
| FR-19 Report content (v1.1) | Report reviews | Reviews, **conversations and businesses** (v1.2) | Extended | Module 8 needed these queues |
| FR-10 / UC-11 Offers | Offer with title, dates, status (SDD: discount, description) | Offers with **deal type + value**, description, terms, **real dates** (end ≥ start), and derived Draft/Scheduled/Active/Expired. **Campaigns are new.** | Richer than planned | 60% slide item "Offers and promotional campaigns"; decision 3 |
| FR-21 Push (v1.1) | In Module 3's description, but no FR in v1.0 | ✅ FCM on Android and web; 6 trigger types plus admin notices | Added as an FR in v1.1 | The 60% slide |
| FR-23–25 Chat (v1.1) | Module 9 in the Feasibility Report, no FRs in v1.0 | ✅ REST + WebSocket, read receipts, typing, photos, block, report | Added in v1.1 | The 60% slide |
| FR-13 / CO-6 / UC-8 Chatbot | RAG chatbot using platform data only | 🎨 Prototype with canned answers | Postponed to 100% | Not on the 60% slide |
| FR-22 Personalization (v1.1) | Recommendations from interests and activity | 🟡 Interest-based row only | Postponed | Planned for 100% |
| FR-17 Email verification and reset (v1.1) | — | ✅ 6-digit codes, 10-minute expiry, cooldowns and limits | New requirement | It was built in the 30% build and needed an FR |
| FR-31 / FR-32 Privacy and deletion (v1.2) | — | ✅ Consent versions, hard delete with cascades | New | Users' rights and Google Play policy |
| FR-26–FR-30 (v1.2) | — | ✅ Account moderation, auto-flagging, blocking, guidelines, audit log | New | Module 8 design |
| SEC-1 Passwords | "Stored in **encrypted** form" | **Hashed** with bcrypt (one-way, salted) | Wording is technically wrong | Say "hashed" in the viva (Part 40) |
| SEC-4 HTTPS / WSS | All traffic over HTTPS (and WSS) | Local development uses **http://** and **ws://**; the app switches to `wss://` automatically when the API URL is `https://` | Deferred | No deployment yet (Phase 3) |
| SEC-5 Chat privacy | Only participants can read | ✅ Non-participants get **404**. Exception: admins can read a conversation **after** a participant reports it (v1.2). | Exception added | Moderation needs evidence |
| USE-5 | Chatbot reachable from the main navigation | Kai is pinned at the top of the **Chat** tab (prototype) | Partially | Module 7 at 100% |
| PER-6 Chat latency | Under 2 s for 90% of messages | Measured ~20 ms on a local server (Module 9 record) | Met locally | — |
| REL-5 Offline recipient | Messages stored and shown later | ✅ Messages are saved before delivery; push and polling cover offline cases | — | — |
| SCA-1 New categories | Without major code changes | ✅ Categories are database rows | — | — |
| SDD IDs | UUIDs | **Auto-increment integers** everywhere | Changed | Simpler; noted in review D5 |
| SDD ER diagram | Separate ADMIN / CUSTOMER / BUSINESS_OWNER tables | **One `users` table with a `role` column** | Simplified | Review D6 |
| Navigation (SDD screens) | 4 tabs: Home, Discover, Chat, Saved | **5 tabs: Home · Explore · Map · Chat · Business** | Changed | The design bundle is the source of truth |

## 4.3 Grouped summary

- **Planned and implemented:** FR-1–FR-12, FR-14–FR-21, FR-23–FR-32. The details are in the table
  above.
- **Changed:**
  - maps provider;
  - verification model (admin-first → automatic);
  - "only verified shown" → all published shown with a badge;
  - offers became richer;
  - reporting now covers three kinds of content.
- **Removed or replaced:**
  - "Upload docs" → storefront photo;
  - the SDD's 4-tab navigation → 5 tabs;
  - onboarding "AI-powered" → plain interest selection.
- **Newly introduced:** campaigns, blocking, the audit log, Community Guidelines, privacy consent,
  account deletion, the route preview, Surprise me, the business-photo pipeline, search history
  and popular searches.
- **Simplified:**
  - one users table;
  - integer IDs;
  - a rule-based search "summary" instead of AI;
  - the "Verified" review badge means "verified email", not "verified visit".
- **Postponed:** RAG chatbot, recommendations, AI moderation, Trust Score, appeals, deployment with
  HTTPS/WSS, performance tests, iOS push.

## 4.4 Architecture changes

1. **REST-only became REST + WebSocket** (CO-4 in v1.1). Writes still go through REST; the socket
   only *announces* events.
2. **A push notification service was added:** `PushSender` → `FcmSender` / `NullSender`, plus
   `NotificationService`. The SDD additions are drafted in
   `docs/development_roadmap/module9_chat_and_push_plan.md`.
3. **Photos are stored in PostgreSQL**, not an object store. This follows SDD §5.1 ("PostgreSQL
   stores all persistent application data").
4. **Providers sit behind interfaces**, the same pattern used three times:
   - `MapService`: MapLibre / Google / Sketch;
   - `Geocoder`: OSM / Google;
   - `PushSender`: FCM / Null.
5. **The backend proxies the external APIs** (geocoding, routing), so the keys stay on the server
   and the results can be cached and rate-limited.

## 4.5 Scope changes

- **Gained scope:**
  - Module 3 gained push notifications.
  - Module 2 gained campaigns.
  - Module 8 gained automatic flagging, account moderation, blocking and the audit log.
  - Module 1 gained privacy consent and account deletion.
- **Moved to 100%:** Modules 7 and 10.
- **Explicitly out of scope:** ordering, payments, delivery, booking (CO-10), and iOS push (CO-11).

## 4.6 Small changes that could come up in a defense

| You might be asked | The honest answer |
|---|---|
| "Your SRS says Google Maps. Where is it?" | The default map is MapLibre with OpenStreetMap, because Google Maps needs a billing account. Google is still supported behind the same `MapService` interface (`MAP_PROVIDER=google`). The SRS text needs updating. |
| "Your SRS says passwords are encrypted." | They're **hashed** with bcrypt, which is one-way and better than encryption for passwords. The SRS wording is inaccurate. |
| "Where is document upload for verification?" | Replaced by an in-app storefront photo plus three automatic checks. Admins review only the referred cases. |
| "Can anyone review? Did they visit?" | Any signed-in user except the owner, once per business. We can't prove a visit; the burst rule and reports catch abuse. |
| "Your use case diagram shows a Firebase actor at Login." | Corrected in v1.1. Login uses our own accounts and Google Sign-In. Firebase is used **only** for push (FCM). |
| "Why 5 tabs when the SDD shows 4?" | The design bundle (`docs/design/Khojlo App.dc.html`) is the source of truth for navigation. |
| "The SDD says UUIDs." | The implementation uses auto-increment integer keys. Noted in the documentation review (D5). |
| "What is the Trust Score on SDD Screen 3?" | Not implemented. No algorithm or owner was defined (open decision 7); it's planned with Module 8 at 100%. |
| "Module numbering: is Maps 5 or 6?" | Maps is **Module 6** and Reviews is **Module 5**. The Feasibility Report's table of contents has them swapped, but its body is correct. |
| "Are verified businesses the only ones shown?" | No. Since v1.2, all published, non-suspended businesses are shown, and verified ones carry a badge. |
| "Is the chatbot working?" | It's a prototype with canned answers. The RAG chatbot is planned for the final iteration. |

---

# Part 5: Complete System Architecture

## 5.1 The big picture

**Simple version.** Khojlo has three main pieces:

1. **The app** (Flutter). It runs on Android phones and in web browsers. It shows screens and sends
   requests.
2. **The API server** (FastAPI, written in Python). It receives requests, checks who you are and
   whether the request is allowed, applies the business rules, and reads and writes the database.
3. **The database** (PostgreSQL). It stores everything permanently: users, businesses, reviews,
   messages, and even photos. The team's shared copy is **hosted by Supabase**.

Some outside services help:

- **Firebase Cloud Messaging** delivers push notifications.
- **Google** verifies Google sign-ins.
- **An email server** sends the one-time codes.
- **OpenStreetMap services** provide map tiles, address lookup and routes.

> **The most important sentence to remember:** the app never talks to the database directly. Every
> read and write goes **app → API → database**. Supabase is just where PostgreSQL is hosted;
> Firebase is used **only** for push notifications.

## 5.2 Main architecture diagram

```text
┌────────────────────────── FLUTTER APP (Android, Web) ──────────────────────────┐
│  Screens & widgets (lib/features/*/presentation)                               │
│        │ ref.watch / ref.read                                                  │
│        ▼                                                                       │
│  Riverpod providers & controllers (StateNotifier, FutureProvider)              │
│        │ calls                                                                 │
│        ▼                                                                       │
│  Repositories (lib/features/*/data/*_repository.dart)                          │
│        │                                                                       │
│        ▼                                                                       │
│  ApiClient = Dio + JWT interceptor ─────────┐     RealtimeService (WebSocket) ─┐ │
└─────────────────────────────────────────────│───────────────────────────────────│─┘
                     HTTP JSON /api/v1/...    │                 ws:// …/api/v1/ws │
                                              ▼                                   ▼
┌─────────────────────── FASTAPI (one uvicorn process, port 8000) ─────────────────┐
│ CORSMiddleware                                                                   │
│ Routers app/api/*.py  ──Depends──► get_db (DB session), get_current_user (JWT)   │
│        │ Pydantic schemas validate input/output (app/schemas)                    │
│        ▼                                                                         │
│ Services app/services/* (business rules: chat, reviews, search, moderation …)    │
│        │                                     BackgroundTasks: e-mail, push,      │
│        ▼                                     live events, view counting          │
│ SQLAlchemy ORM models app/models/*           ConnectionManager (open sockets)    │
└────────┬─────────────────────────────────────────────────────────────────────────┘
         │ SQL over TCP (psycopg2 driver) — DATABASE_URL
         ▼
┌──────────────────────────── POSTGRESQL ──────────────────────────────────────────┐
│ 28 tables, managed by Alembic migrations. Shared copy hosted on Supabase         │
│ (connection pooler, port 5432); developers can also run Postgres locally.        │
└──────────────────────────────────────────────────────────────────────────────────┘
```

## 5.3 External services diagram

This is the actual setup. It is *not* the "standard" Firebase setup.

```text
FLUTTER APP
   ├── Google Sign-In SDK ──────► Google accounts → returns an ID token (a signed JWT from Google)
   │                               └─ app sends it to FastAPI POST /auth/google
   ├── Firebase Messaging SDK ──► Firebase Cloud Messaging: gives the device a token,
   │                               delivers pushes to the phone/browser
   ├── MapLibre ────────────────► OpenFreeMap (tiles, sprites, fonts) — direct, no key
   └── url_launcher ────────────► Google Maps app/website (Directions), phone dialer (tel:)

FASTAPI BACKEND
   ├── google-auth ─────────────► Google: checks the ID token's signature and audience
   ├── google-auth + requests ──► FCM HTTP v1 API (send push) using the service account
   ├── smtplib ─────────────────► SMTP server (verification and reset codes, account notices)
   ├── requests ────────────────► Photon (address search) and Nominatim (address at a pin)
   ├── requests ────────────────► openrouteservice (route preview)
   └── requests (optional) ─────► Google Geocoding API (only if GEOCODING_PROVIDER=google)
```

What Khojlo does **not** use, because people often assume it does:

| Commonly assumed | Reality in Khojlo |
|---|---|
| Firebase Authentication | ❌ Not used. Accounts are Khojlo's own (`users` table + bcrypt + JWT). Google Sign-In tokens are checked by our backend. |
| Firebase Admin SDK (`firebase-admin`) | ❌ Not used. The backend calls the FCM HTTP v1 REST API itself (`backend/app/services/push.py`), because `firebase-admin` wheels lag behind new Python versions. |
| Firestore / Realtime Database | ❌ Not used. All data is in PostgreSQL. |
| Firebase Storage / Supabase Storage | ❌ Not used. Photos are stored in PostgreSQL (`media` table). |
| Supabase Auth / client SDK / Realtime | ❌ Not used. Supabase is only the PostgreSQL host; the backend connects with a normal `DATABASE_URL`. |
| Google Maps (by default) | ❌ No longer the default. MapLibre + OpenStreetMap is the default; Google is opt-in. |

## 5.4 The four ways data moves

| Channel | Direction | Used for | Code |
|---|---|---|---|
| **REST over HTTP** (JSON) | App asks, server answers | Everything that reads or changes data: login, feed, search, reviews, sending messages … | `lib/core/network/api_client.dart` ↔ `backend/app/api/*.py` |
| **WebSocket** | Both ways, stays open | *Announcing* live events: `message.new`, `conversation.read`, `typing` | `lib/core/realtime/realtime_service.dart` ↔ `realtime()` in `backend/app/api/chat.py` |
| **Push (FCM)** | Server → Google → device | Telling people about events while the app is closed or in the background | `backend/app/services/push.py` → FCM → `lib/core/push/push_platform.dart` |
| **Map tiles** | App → OpenFreeMap | Drawing the map | `lib/core/maps/maplibre_map_view.dart`, `assets/maps/khojlo_style.json` |

## 5.5 One request end to end (simple example)

A customer opens a business page:

```text
1. User taps a business card on Home
2. go_router opens /business/12  → BusinessDetailScreen
3. The screen watches businessDetailProvider(12)
4. The provider calls DiscoveryRepository.detail(12)
5. Dio sends GET http://localhost:8000/api/v1/businesses/12
   (the interceptor adds "Authorization: Bearer <access token>")
6. FastAPI routes it to business_detail() in backend/app/api/businesses.py
7. get_optional_user() decodes the JWT (it's optional: signed-out visitors can view too)
8. SQLAlchemy runs a SELECT with its photos, category, services, hours and offers
9. The response is built (BusinessDetail schema) and sent as JSON
10. After the response, a background task records the view (INSERT business_views,
    UPDATE businesses SET view_count = view_count + 1)
11. The provider gets the data → the screen rebuilds with photos, hours, reviews, map …
```

## 5.6 Design patterns you can name

| Pattern | Where | Why |
|---|---|---|
| **Layered architecture** | presentation → providers → repositories → API → services → ORM → DB | Each layer has one job; easy to test and change |
| **Strategy** (from the SDD) | `SearchStrategy` with `KeywordSearch`, `CategorySearch`, `LocationSearch`, `AreaSearch` and filter strategies (`backend/app/services/search/strategies.py`) | Each part of a search is a pluggable object; the engine combines them |
| **Adapter / interface + implementations** | `MapService` (MapLibre / Google / Sketch), `Geocoder` (OSM / Google), `Router` (openrouteservice), `PushSender` (FCM / Null) | Swap providers without touching screens or endpoints. This is exactly how Google Maps was replaced by MapLibre. |
| **Null Object** | `NullSender` (no Firebase key → push off), `SketchMapService` (no map available) | The app keeps working when an optional service isn't configured |
| **Repository** | `lib/features/*/data/*_repository.dart` | One place per feature that talks to the API |
| **Dependency injection** | FastAPI `Depends(...)` (DB session, current user); Riverpod providers | Easy to swap in tests (`app.dependency_overrides`, provider overrides) |
| **Observer / streams** | WebSocket events → `Stream` → controllers; `ref.listen` | Screens react to live events |
| **Background jobs** | FastAPI `BackgroundTasks`; command-line jobs in `backend/app/jobs/` | Slow work (email, push) never delays the response |
| **Denormalized counters** | `businesses.view_count`, `save_count`, `rating`, `review_count` | Fast feed and list reads; recalculated or incremented on each change |
| **Optimistic UI** | Chat sending, helpful votes | The app feels instant; it rolls back or shows "retry" on failure |

---

# Part 6: Folder Structure

## 6.1 The repository tree (important parts only)

Generated Flutter platform folders (`ios/`, `macos/`, `linux/`, `windows/`) and build output are
left out on purpose.

```text
khojlo/
├── README.md                       how to run backend + app, demo scripts for every module
├── .gitignore                      keeps .env, secrets/, dart_defines.json, builds out of git
├── .claude/launch.json             local preview launch config (web server on port 8090)
│
├── backend/                        ── THE API SERVER (Python 3.14, FastAPI) ──
│   ├── .env.example                template for backend/.env (placeholders only, committed)
│   ├── .env                        REAL settings & secrets (git-ignored)
│   ├── secrets/                    firebase-service-account.json (git-ignored)
│   ├── requirements.txt            Python dependencies (ranges, not pins)
│   ├── docker-compose.yml          optional local PostgreSQL 16 container
│   ├── alembic.ini                 Alembic config (DB URL comes from app settings)
│   ├── alembic/
│   │   ├── env.py                  connects Alembic to app.core.config + app.models metadata
│   │   └── versions/               10 migration files (schema history)
│   ├── app/
│   │   ├── main.py                 creates the FastAPI app, CORS, registers 14 routers
│   │   ├── core/                   config.py · database.py · security.py · privacy.py
│   │   ├── models/                 SQLAlchemy tables: user, business, review, chat,
│   │   │                           notification, media, moderation, campaign, engagement,
│   │   │                           search, otp
│   │   ├── schemas/                Pydantic request/response models + validation rules
│   │   ├── api/                    routers (HTTP endpoints) + deps.py (auth dependencies)
│   │   ├── services/               business logic; search/ = SearchEngine + strategies
│   │   ├── jobs/                   CLI jobs: trending_digest.py, promotions.py
│   │   └── db/                     seed.py (demo data), schema_check.py, demo_photos/
│   └── tests/                      pytest suite: 23 test files + conftest.py + factories.py
│
├── frontend/                       ── THE FLUTTER APP ──
│   ├── pubspec.yaml                Dart/Flutter dependencies + assets
│   ├── dart_defines.example.json   template for build-time settings (committed)
│   ├── dart_defines.json           REAL build-time settings (git-ignored)
│   ├── analysis_options.yaml       lint rules (flutter_lints)
│   ├── assets/maps/khojlo_style.json   MapLibre map style in Khojlo colours
│   ├── tool/build_map_style.py     script that generates that style from OpenFreeMap "Positron"
│   ├── lib/
│   │   ├── main.dart               entry point
│   │   ├── core/                   shared building blocks (see 6.3)
│   │   └── features/               one folder per feature (see 6.4)
│   ├── test/                       18 test files (flutter_test)
│   ├── web/                        index.html, manifest.json, firebase-messaging-sw.js
│   └── android/                    Gradle build, AndroidManifest, google-services.json
│
└── docs/
    ├── README.md                   index + "which document wins"
    ├── team_setup.md               which private files/values to share with a teammate
    ├── requirements/               SRS.pdf (v1.0), SRS.md (v1.2), SDD.pdf, Feasibility_Report.pdf,
    │                               document_review.md, diagrams/use_case.puml
    ├── development_roadmap/        implementation_plan.md + one record per module
    ├── design/                     Khojlo App.dc.html (design source of truth), mockup, notes
    └── brand/                      logo package (SVG)
```

## 6.2 Backend folders

| Folder | Purpose and responsibility | Layer | Talks to |
|---|---|---|---|
| `backend/app/core/` | App-wide settings (`config.py`), DB engine and sessions (`database.py`), password hashing and JWT (`security.py`), privacy policy version (`privacy.py`) | Infrastructure | Everything imports it |
| `backend/app/models/` | One Python class per table (SQLAlchemy ORM). Defines columns, keys, constraints and relationships | Data | `core/database.py` (Base); used by services, routers, Alembic |
| `backend/app/schemas/` | Pydantic models: what a request must look like (with validation) and what a response contains | API contract | Routers |
| `backend/app/api/` | Routers: functions that handle each URL. `deps.py` holds reusable dependencies (current user, admin, owner) | Presentation (HTTP) | schemas, services, models, core |
| `backend/app/services/` | Business logic that's too big or too shared for a router: chat, reviews, search, moderation, push, maps, media | Business logic | models, core, external APIs |
| `backend/app/services/search/` | The search engine: criteria, strategies, ranking, text folding, suggestions, history | Business logic | models |
| `backend/app/jobs/` | Scripts run from the command line (`python -m app.jobs.trending_digest`, `python -m app.jobs.promotions`) | Batch jobs | services, models |
| `backend/app/db/` | `seed.py` (demo data, safe on the shared DB), `schema_check.py` (warns if migrations are missing), `demo_photos/` | Tooling | models |
| `backend/alembic/` | Database migrations (the schema's version history) | Data tooling | models, DB |
| `backend/tests/` | Automated tests with an in-memory SQLite database | Testing | the whole app |

## 6.3 Frontend `core/` folders

| Folder | Purpose |
|---|---|
| `lib/core/network/` | `api_client.dart` (Dio + JWT interceptor), `api_config.dart` (API URL per platform), `google_auth_config.dart` (Google web client ID) |
| `lib/core/storage/` | `token_storage.dart`: saves the access and refresh tokens in secure storage |
| `lib/core/router/` | `app_router.dart` (all routes + redirect rules), `shell_scaffold.dart` (5-tab shell + Chat badge), `session_services.dart` (starts and stops chat socket, push and badges) |
| `lib/core/realtime/` | `realtime_service.dart`: the WebSocket client |
| `lib/core/push/` | `firebase_setup.dart` (starts Firebase), `push_platform.dart` (permission, token, taps), `sw_messages_web.dart` (clicks from the web service worker) |
| `lib/core/maps/` | `map_service.dart` (`MapService` + 3 implementations), `maplibre_map_view.dart`, `google_map_view.dart`, `sketch_map.dart`, `geo_repository.dart` (calls `/geo/*`), `pin_icons.dart`, `map_types.dart` |
| `lib/core/location/` | `location_service.dart` (geolocator wrapper with timeouts), `location_rationale.dart` (explains why before asking) |
| `lib/core/media/` | `media_repository.dart` (upload photos), `photo_source.dart` (camera or gallery) |
| `lib/core/models/` | Dart data classes with `fromJson` (user, business, review, chat, notification, campaign, moderation …) |
| `lib/core/theme/` | Colours (cream, gold, emerald, plum, ink, coral), typography (Fraunces, Plus Jakarta Sans, IBM Plex Mono), Material theme |
| `lib/core/widgets/` | Reusable widgets: glass surfaces, floating tab bar, business card, chips, buttons, skeletons, photo viewer, promotion badge |
| `lib/core/ui/` | `messenger.dart` (in-app banners), `splash_overlay.dart` (launch animation) |
| `lib/core/providers.dart` | Global providers: token storage, API client, Dio, "app resumed" counter |

## 6.4 Frontend `features/` folders

Each feature follows the same shape: `data/` (repository) + `*_providers.dart` (state) +
`presentation/` (screens and widgets).

| Feature | What it contains |
|---|---|
| `auth/` | Onboarding, sign-in/up (role picker), forgot password, email verification sheet, interests, `AuthController` |
| `account/` | Profile, edit profile, saved lists, Community Guidelines, delete-account sheet |
| `legal/` | Privacy policy text + version, policy screen, consent screen |
| `discovery/` | Home feed, business detail page, report-business sheet, feed providers |
| `search/` | Explore tab, filter sheet, compare screen, compare selection controller |
| `business/` | Business tab, owner dashboard, registration stepper, edit screens, verification screen |
| `promotions/` | Offers & promotions screen, offer and campaign editors, campaign details |
| `reviews/` | Reviews section, full reviews screen, write/edit sheets, my reviews, confetti |
| `maps/` | Map tab, location picker, route screen, List \| Map toggle |
| `chat/` | Chat tab (conversation list), conversation screen, composer, bubbles, report sheet |
| `notifications/` | Notifications screen, settings, push prompt card, `PushController` |
| `admin/` | Admin panel (overview, queues), business, report and user screens |
| `prototype/` | `kai_screen.dart` (Module 7 prototype), `surprise_screen.dart` (real API), `mock_data.dart` |

## 6.5 Important files, one by one

### Backend

**File:** `backend/app/main.py`

- **Purpose:** creates the FastAPI application.
- **Why it exists:** something has to assemble the app: middleware, routers and startup hooks.
- **Who uses it:** uvicorn (`uvicorn app.main:app`) and the tests (`TestClient(app)`).
- **What happens inside:**
  - On startup, `lifespan()` runs `warn_if_outdated()`.
  - `CORSMiddleware` is added (allowed origins from `BACKEND_CORS_ORIGINS`, plus any
    `http://localhost:<port>`).
  - 14 routers are included under `/api/v1`.
  - `/health` and `/` are defined.
- **If removed:** nothing runs.

**File:** `backend/app/core/config.py`

- **Purpose:** all settings in one typed `Settings` class (pydantic-settings), read from
  environment variables and `backend/.env`.
- **Inside:** defaults for every key (Part 18), and helper properties `email_enabled`,
  `firebase_enabled` and `geocoding_enabled` that switch features off cleanly.
- **If removed:** no database URL, no JWT secret; the app can't start.

**File:** `backend/app/core/database.py`

- **Purpose:** the SQLAlchemy `engine` (connection pool, `pool_pre_ping=True`), `SessionLocal`, the
  `Base` class for models, `get_db()` (one session per request), and `session_scope()` (sessions
  for WebSocket events and background jobs).
- **If removed:** no database access at all.

**File:** `backend/app/core/security.py`

- **Purpose:**
  - `hash_password()` / `verify_password()` (bcrypt);
  - `create_access_token()`, `create_refresh_token()` and `create_password_reset_token()`;
  - `decode_token()` (python-jose, HS256);
  - `verify_google_id_token()`.
- **Who uses it:** `api/auth.py`, `api/deps.py`, `api/users.py` and the WebSocket auth.
- **If removed:** no login, no protected endpoints.

**File:** `backend/app/api/deps.py`

- **Purpose:** reusable FastAPI dependencies:
  - `get_current_user()` (reads the Bearer token and returns the `User`, or 401/403);
  - `get_current_admin()`, `get_current_owner()` and `get_optional_user()`;
  - `require_current_privacy_policy()` and `get_now()`.
- **Why:** every protected endpoint just writes `user: User = Depends(get_current_user)`.
- **If removed:** every protected route breaks.

**File:** `backend/app/api/chat.py`

- **Purpose:** the chat REST endpoints and the `/ws` WebSocket.
- **Inside:**
  - `open_conversation()`, `list_conversations()`, `list_messages()`;
  - `send_message()`, which follows SDD Algorithm 8;
  - `mark_read()`, `report_conversation()`, `block_conversation()`;
  - `realtime()`, the socket loop.
- **If removed:** no chat. Push for other events would still work.

**File:** `backend/app/services/realtime.py`

- **Purpose:** `ConnectionManager`, an in-memory dictionary `{user_id: set of open sockets}`, with
  `add`, `remove`, `is_online`, `send`, `publish` and `disconnect`.
- **Why:** the server needs to know who is "online" (has the app open) and how to reach them.
- **Important consequence:** it lives in one process's memory, so the API must run as **one
  worker**.

**File:** `backend/app/services/push.py`

- **Purpose:** sends push notifications.
  - `PushSender` is the interface.
  - `FcmSender` calls the FCM HTTP v1 API with the service account.
  - `NullSender` sends nothing when Firebase isn't configured.
  - `get_sender()` picks one.
- **If removed:** no push; everything else still works.

**File:** `backend/app/services/notification_service.py`

- **Purpose:** `notify()` decides who gets what. It checks each user's settings, stores
  Notifications-list rows, and returns a `PushJob`. It also has the recipient helpers
  `users_who_saved()` and `users_interested_in()`.

**File:** `backend/app/services/search/engine.py` (with `strategies.py` and `ranking.py`)

- **Purpose:** the SDD's `SearchEngine`. `search()` builds the strategies for the criteria, runs
  them (SQL first, then the Python check), ranks, pages and summarizes the results.

**File:** `backend/app/services/review_service.py`

- **Purpose:** `refresh_rating()` (SDD Algorithm 7), `ranking_score()` (the Bayesian rating),
  `summary()` (the star distribution), `order_by()` (sort orders) and `display_name()`
  ("Hassan R.").

**File:** `backend/app/services/moderation_rules.py`

- **Purpose:** the automatic flag rules (regular expressions in English and Roman Urdu, review
  bursts, duplicates, mass messaging). Every check is wrapped in `@never_fail`, so a bug in a rule
  can never block publishing.

**File:** `backend/app/services/verification_service.py`

- **Purpose:** `checks()` (the 4 checks), `refresh()` (auto-verify or refer to an admin),
  `identity_changed()` (removes the badge), `set_storefront()`, `request_review()` and the admin's
  `decide()`.

**File:** `backend/app/services/media_service.py`

- **Purpose:** `process_image()` (Pillow: validate, turn upright, strip metadata, resize, focal
  point), `store_upload()`, `resolve_keys()` (you can only attach your own uploads) and
  `delete_orphans()` / `delete_if_unused()`.

**File:** `backend/app/db/seed.py`

- **Purpose:** demo data. It's safe on the shared database: it only adds and refreshes, unless you
  pass `--reset`.
- **Demo accounts:** `owner@khojlo.app`, `customer@khojlo.app`, `admin@khojlo.app` and 12 reviewer
  accounts, all with password `password123`.

**File:** `backend/app/db/schema_check.py`

- **Purpose:** at startup, compares the database's `alembic_version` with the migration files and
  logs a warning naming `alembic upgrade head` if the database is behind.
- **Why:** a teammate on an old schema used to see only "Couldn't load your feed".

**File:** `backend/alembic/env.py`

- **Purpose:** connects Alembic to the app. It reads `settings.DATABASE_URL`, imports all models
  (`import app.models`) and uses `Base.metadata` as the target, so `alembic revision
  --autogenerate` and `alembic check` can compare models with the database.

**File:** `backend/tests/conftest.py`

- **Purpose:** the test setup:
  - in-memory SQLite with foreign keys enforced;
  - fresh tables per test;
  - `get_db` overridden;
  - emails captured instead of sent;
  - pushes recorded by a fake `RecordingSender` instead of Firebase.

**File:** `backend/docker-compose.yml`

- **Purpose:** optional local PostgreSQL 16 container. See Part 21.

**File:** `backend/.env.example`

- **Purpose:** the template that teammates copy to `.env`. It holds placeholders and safe defaults
  only.

### Frontend

**File:** `frontend/lib/main.dart`

- **Purpose:** the app's entry point.
- **Inside:**
  1. `main()` calls `initFirebase()` while the splash animation plays.
  2. `KhojloRoot` builds a Riverpod `ProviderContainer` once Firebase has started (or failed), and
     overrides `firebaseReadyProvider`.
  3. `KhojloApp` creates `MaterialApp.router` with the router, the theme, the scroll behaviour and
     `rootMessengerKey` (in-app banners).
  4. It wraps everything in `SessionServices`.
- **If removed:** no app.

**File:** `frontend/lib/core/network/api_client.dart`

- **Purpose:** the HTTP client.
- **Inside:**
  - Dio with 12-second timeouts.
  - An interceptor that adds `Authorization: Bearer <token>` to every request.
  - On a 401 it calls `/auth/refresh` **once**, saves the new tokens and retries the original
    request.
  - `describeApiError()` turns server errors into friendly text.
- **Who uses it:** every repository, via `dioProvider`.

**File:** `frontend/lib/core/network/api_config.dart`

- **Purpose:** decides the API address.
  - `KHOJLO_API` from `dart_defines.json` wins.
  - Otherwise the Android emulator uses `http://10.0.2.2:8000/api/v1` and everything else uses
    `http://localhost:8000/api/v1`.
  - `realtimeUri` builds the WebSocket URL (`ws://` or `wss://` + `/ws`).

**File:** `frontend/lib/core/storage/token_storage.dart`

- **Purpose:** saves and reads `khojlo_access` and `khojlo_refresh` with `flutter_secure_storage`
  (the Android Keystore-backed encrypted storage on phones).

**File:** `frontend/lib/core/router/app_router.dart`

- **Purpose:** every route, and the **redirect rules**:
  - unknown session → `/splash`;
  - signed out → onboarding or auth;
  - signed in but no consent → `/privacy-consent`;
  - `/admin` only for admins.
- **Tabs:** the 5-tab shell (`StatefulShellRoute.indexedStack`): `/home`, `/explore`, `/map`,
  `/chat`, `/business`.

**File:** `frontend/lib/core/router/session_services.dart`

- **Purpose:** when the user signs in, it starts the WebSocket, loads the chat badge and the
  notification count, and sets up push. On sign-out it stops everything. When the app goes to the
  background it closes the socket, so the server knows to push instead.

**File:** `frontend/lib/core/realtime/realtime_service.dart`

- **Purpose:** the WebSocket client.
  - Sends the auth message first.
  - Pings every 25 seconds.
  - Reconnects with backoff (1, 2, 4 … 30 s).
  - After a 4401 close, it refreshes the session once and retries.

**File:** `frontend/lib/features/chat/chat_providers.dart`

- **Purpose:**
  - `ConversationsController` keeps the chat list and the badge.
  - `ConversationController` handles one open chat: loading, paging, optimistic send, retry,
    "Seen", typing, and polling when offline.

**File:** `frontend/lib/features/notifications/push_controller.dart`

- **Purpose:** notification permission, device registration with the backend, opening the right
  screen when a notification is tapped, and in-app banners for pushes that arrive while the app is
  open.

**File:** `frontend/lib/core/maps/map_service.dart`

- **Purpose:** the SDD's `MapService` interface and the three implementations. `mapServiceProvider`
  chooses MapLibre (default), Google (if `MAP_PROVIDER=google` with a key) or the drawn Sketch map
  (fallback).

**File:** `frontend/web/firebase-messaging-sw.js`

- **Purpose:** the web **service worker**, a small script the browser runs in the background. It
  shows push notifications while the tab is hidden or closed, and handles clicks.

**File:** `frontend/android/app/google-services.json`

- **Purpose:** Android's Firebase and Google OAuth settings (project `khojlo-c5ba0`, package
  `com.khojlo.khojlo`). It's committed on purpose because it isn't secret. See Part 17.

**File:** `frontend/android/app/build.gradle.kts`

- **Purpose:** Android build settings:
  - applies the `com.google.gms.google-services` plugin, which reads `google-services.json`;
  - reads `MAPS_API_KEY_ANDROID` from `dart_defines.json` into the manifest;
  - signs release builds with **debug keys** for now (a TODO).

**File:** `frontend/pubspec.yaml`

- **Purpose:** the Flutter dependencies (Part 30), the map style asset, and the launcher-icon
  settings.

---

# Part 7: Frontend Deep Dive

## 7.1 Technology

| Piece | What Khojlo uses | Evidence |
|---|---|---|
| UI framework | **Flutter 3.41** (stable), one codebase for Android + web (iOS builds, but push and Google Maps aren't wired there) | `flutter --version` → 3.41.4; README "Requires Flutter 3.41+" |
| Language | **Dart 3.11+** | `pubspec.yaml`: `sdk: ^3.11.1` |
| State management | **Riverpod 2** (`flutter_riverpod`): `Provider`, `StateProvider`, `FutureProvider`, `StateNotifierProvider`, `.family`, `.autoDispose` | `lib/core/providers.dart` and every `*_providers.dart` |
| Navigation | **go_router 14** with redirects and a `StatefulShellRoute` for the 5 tabs | `lib/core/router/app_router.dart` |
| HTTP client | **Dio 5** with an interceptor for JWT + automatic refresh | `lib/core/network/api_client.dart` |
| WebSocket | **web_socket_channel 3** | `lib/core/realtime/realtime_service.dart` |
| Firebase | **firebase_core** + **firebase_messaging** (push only) | `lib/core/push/` |
| Maps | **maplibre_gl** (default), **google_maps_flutter** (opt-in) | `lib/core/maps/` |
| Auth helpers | **google_sign_in** (+ `google_sign_in_web`), **pinput** (OTP boxes) | `lib/features/auth/` |
| Local storage | **flutter_secure_storage** (tokens only); no local database or offline cache | `lib/core/storage/token_storage.dart` |
| Location | **geolocator** | `lib/core/location/location_service.dart` |
| Images | **image_picker** (camera or gallery), **cached_network_image** (download + cache) | `lib/core/media/`, `lib/core/widgets/image_tile.dart` |
| Look and feel | **google_fonts**, **shimmer** (loading skeletons), **flutter_animate** (animations) | `lib/core/theme/`, `lib/core/widgets/skeletons.dart` |
| Other | **url_launcher** (Call, Directions), **share_plus** (Share), **pointer_interceptor** + **web** (Google Maps on web), **flutter_launcher_icons** (dev) | `pubspec.yaml` |

## 7.2 The important libraries, one by one

**Library: flutter_riverpod** (^2.6.1)

- **Purpose:** state management and dependency injection.
- **Where used:** everywhere. Examples: `authControllerProvider`, `feedProvider`,
  `conversationControllerProvider`, `searchControllerProvider`.
- **Why needed:** screens need shared, reactive data (who's signed in, unread counts, search
  results), and the logic must be testable without the UI.
- **Alternatives:** Provider, BLoC, GetX, setState.
- **Why this project uses it:** compile-safe, no `BuildContext` needed to read state, easy
  overrides in tests (`ProviderScope(overrides: …)`), and `.family` / `.autoDispose` suit
  per-business or per-conversation state.

**Library: go_router** (^14.6.2)

- **Purpose:** URL-based navigation (`/business/12`, `/conversations/5`).
- **Where used:** `lib/core/router/app_router.dart`.
- **Why needed:**
  - deep links: a push notification carries a `route` such as `/conversations/12`, and the router
    opens it;
  - web URLs;
  - redirect rules for auth, consent and admin.
- **Alternatives:** Navigator 2.0 by hand, auto_route, beamer.
- **Why this project uses it:** it's the Flutter team's recommended router. Its `redirect` and
  `StatefulShellRoute` cover exactly the auth gates and the 5-tab dock.

**Library: dio** (^5.7.0)

- **Purpose:** HTTP requests.
- **Where used:** `ApiClient` and every repository.
- **Why needed:** interceptors let one place add the token and refresh it on a 401. It also gives
  timeouts and multipart upload for photos.
- **Alternatives:** `http` package, chopper, retrofit.
- **Why this project uses it:** the interceptor makes the "refresh the token and retry" logic one
  piece of code instead of one per call.

**Library: flutter_secure_storage** (^9.2.4)

- **Purpose:** stores the JWTs securely (Android Keystore-backed encryption; on the web, browser
  storage).
- **Alternatives:** shared_preferences, which is **not** encrypted.
- **Why this project uses it:** tokens are credentials, so they shouldn't sit in plain storage.

**Library: web_socket_channel** (^3.0.3)

- **Purpose:** the chat WebSocket.
- **Why this project uses it:** it's the standard Dart WebSocket package and works on mobile and
  web.

**Library: firebase_core + firebase_messaging** (^4.15.0 / ^16.7.0)

- **Purpose:** get an FCM device token, ask for notification permission, and receive pushes and
  taps.
- **Why this project uses it:** FCM is free and works on Android and web (SRS OE-10, CO-11).

**Library: maplibre_gl** (^0.27.1)

- **Purpose:** draws vector maps from any tile source (Khojlo uses OpenFreeMap).
- **Alternatives:** google_maps_flutter (needs billing), flutter_map (raster tiles).
- **Why this project uses it:** free, no key, smooth vector zooming, and the style can be customized
  to Khojlo's colours.

**Library: google_sign_in** (^7.2.0) + **google_sign_in_web**

- **Purpose:** Google account sign-in that returns an **ID token** for the backend.
- **Note:** on the web, `authenticate()` isn't supported, so the app renders Google's own button
  (`google_web_button_web.dart`).

**Library: geolocator** (^14.0.2)

- **Purpose:** the device location for "near me", distances, the map dot and pinning a business.
- **Where used:** `LocationService`, which adds 15 s / 60 s timeouts because the web plugin can
  stall.

**Library: image_picker**, **cached_network_image**, **shimmer**, **flutter_animate**,
**google_fonts**, **url_launcher**, **share_plus**, **pinput**

These are standard UI and utility packages. The design system needs smooth images, skeleton
loading, motion and the Fraunces / Plus Jakarta Sans / IBM Plex Mono fonts.

---

# Part 8: Flutter Architecture

## 8.1 The layers

```text
┌───────────────────────────────────────────────────────────────┐
│ PRESENTATION   lib/features/<feature>/presentation/*.dart       │  Widgets & screens
│                (ConsumerWidget / ConsumerStatefulWidget)        │  ref.watch(...) to show data
├───────────────────────────────────────────────────────────────┤  ref.read(...).method() on taps
│ STATE          lib/features/<feature>/<feature>_providers.dart  │  Riverpod providers:
│                FutureProvider (load once), StateNotifier        │  hold & change state
│                (interactive state), StateProvider (small values)│
├───────────────────────────────────────────────────────────────┤
│ DATA           lib/features/<feature>/data/*_repository.dart    │  One method per API call,
│                                                                 │  JSON → Dart models
├───────────────────────────────────────────────────────────────┤
│ CORE           lib/core/network (Dio), storage, realtime, push, │  Shared infrastructure
│                maps, location, models, theme, widgets, router   │
└───────────────────────────────────────────────────────────────┘
```

- **Screens and widgets:** for example `home_screen.dart`, `business_detail_screen.dart` and
  `conversation_screen.dart`.
- **Reusable components:** `lib/core/widgets/` (`business_card.dart`, `glass.dart`,
  `floating_tab_bar.dart`, `skeletons.dart` …).
- **Models:** `lib/core/models/*.dart`. Each has a `fromJson` factory that turns the API's JSON
  into typed Dart objects.
- **Services:** `RealtimeService`, `LocationService`, `PushPlatform` and `MapService`.
- **Controllers:** `AuthController`, `SearchNotifier`, `ConversationController`,
  `ConversationsController`, `ReviewsController`, `MapResultsNotifier`, `PushController`,
  `CompareController`, `NotificationsController`.
- **Repositories:** `AuthRepository`, `DiscoveryRepository`, `BusinessRepository`,
  `SearchRepository`, `ReviewsRepository`, `ChatRepository`, `NotificationsRepository`,
  `PromotionsRepository`, `AdminRepository`, `AccountRepository`, `MediaRepository` and
  `GeoRepository`.

## 8.2 State management patterns in Khojlo

| Pattern | Example | When it's used |
|---|---|---|
| `FutureProvider.autoDispose` | `feedProvider`, `myReviewsProvider`, `campaignProvider` | Load data once for a screen; dispose when the screen closes |
| `FutureProvider.family` | `businessDetailProvider(id)` (kept alive for 1 minute), `adminBusinessProvider(id)` | Load data for one id |
| `StateNotifierProvider` | `authControllerProvider`, `searchControllerProvider`, `conversationsControllerProvider`, `pushControllerProvider` | Interactive state with methods (`login()`, `submit()`, `send()`) |
| `StateNotifierProvider.autoDispose.family` | `conversationControllerProvider(conversationId)` | One controller per open chat |
| `StateProvider` "change counters" | `reviewChangesProvider`, `promotionChangesProvider`, `appResumedProvider`, `feedSeedProvider` | Bump a number to tell other providers to reload (after a review edit, when the app returns to the foreground, on pull-to-refresh) |
| Provider overrides | `firebaseReadyProvider.overrideWithValue(ready)` in `main.dart` | Pass in startup facts; tests use the same mechanism |

## 8.3 Navigation

- `initialLocation: '/splash'`. While the session is being restored, the router remembers the URL
  you asked for (`pendingLocation`) and takes you there afterwards. This fixed "refreshing /admin
  goes to Home".
- **Redirect rules:**
  1. unknown → `/splash`;
  2. signed out → `/onboarding`, `/auth` or `/forgot-password`;
  3. signed in but `needsPrivacyConsent` → `/privacy-consent`;
  4. `/admin*` and not an admin → `/home`.
- **The 5-tab dock** is a `StatefulShellRoute.indexedStack` (`/home`, `/explore`, `/map`, `/chat`,
  `/business`). It keeps each tab's state when you switch, and the Chat tab shows an unread badge
  from `unreadMessagesProvider`.
- **Full-screen routes** sit on top: `/business/:id`, `/business/:id/reviews`,
  `/conversations/:id`, `/campaign/:id`, `/compare`, `/register-business`, `/edit-business/:id`,
  `/offers/:id`, `/profile`, `/saved`, `/notifications`, `/admin/...` and others (**36 routes** in all, including the 5 tabs).
- On the web, URLs use the hash style (`/#/conversations/12`). The service worker relies on this
  when it opens a tab.

## 8.4 Local storage and configuration

- **Stored on the device:** only the two JWTs (`flutter_secure_storage`). There is **no local
  database** and **no offline cache** of businesses or messages. That matches SRS CO-9 (no offline
  operation).
- **Images:** `cached_network_image` caches downloaded photos, and the server marks photo URLs as
  cacheable for a year.
- **Configuration** is compiled in at build time with `--dart-define-from-file=dart_defines.json`
  and read with `String.fromEnvironment(...)`:
  - `KHOJLO_API`
  - `GOOGLE_WEB_CLIENT_ID`
  - `MAP_PROVIDER`, `MAPS_API_KEY_*`
  - `FIREBASE_*`

## 8.5 How data moves through the app

Example: the user saves a business.

```text
User taps "Save" on the business page
      ↓
BusinessDetailScreen (_toggleSave) → DiscoveryRepository.save(businessId)
      ↓
Dio POST /api/v1/businesses/12/save  {"list_id": null}   (+ Bearer token)
      ↓
FastAPI save_business() → finds or creates the "Saved" list → INSERT saved_businesses,
                          businesses.save_count + 1 → COMMIT
      ↓
200 OK: the updated BusinessDetail JSON (is_saved: true, save_count: …)
      ↓
The screen updates the button and shows a snackbar ("Saved" → View)
```

Example: Home loads.

```text
HomeScreen build → ref.watch(feedProvider)
      ↓
feedProvider watches locationControllerProvider (device location, if allowed) and feedSeedProvider
      ↓
DiscoveryRepository.feed(lat, lng, seed) → GET /api/v1/feed?lat=…&lng=…&seed=…
      ↓
get_feed() → SELECT published businesses → builds rows (featured, because-you-like,
             trending, nearby) + campaign banners + greeting
      ↓
FeedResponse JSON → Feed.fromJson → AsyncValue.data(feed)
      ↓
UI rebuilds. While loading: skeletons. On error: _FeedError with a Retry button.
Pull-to-refresh → refreshFeed() sets a new seed → feedProvider reloads with different rows.
```

---

# Part 9: Backend Deep Dive

## 9.1 FastAPI

**In simple terms.** FastAPI is a Python framework for building web APIs. You write a normal
Python function, put a decorator such as `@router.post("/auth/login")` on it, and FastAPI turns it
into a URL the app can call.

**More precisely.** FastAPI is built on Starlette (an ASGI web toolkit) and Pydantic (data
validation). It reads the type hints on your function's parameters to:

- validate the request and return **422** automatically when the data is wrong;
- convert JSON into Python objects and back;
- inject dependencies (`Depends(...)`);
- generate interactive documentation at **`/docs`** (Swagger UI).

It supports both normal functions and `async` functions. Khojlo's WebSocket handler is `async`;
most REST handlers are normal functions, which FastAPI runs in a thread pool.

**In Khojlo.** `backend/app/main.py` creates `app = FastAPI(...)` and includes 14 routers. You run
it with `uvicorn app.main:app --reload` (port 8000).

## 9.2 The request lifecycle

Here is a real example: **`POST /api/v1/businesses/12/reviews`** with body
`{"rating": 5, "comment": "Best chai in F-7", "photos": []}`.

```text
HTTP request arrives at uvicorn (ASGI server, port 8000)
   ↓
CORSMiddleware: is the browser origin allowed? (BACKEND_CORS_ORIGINS + any http://localhost:port)
   ↓
Router match: reviews.router → create_review(business_id=12, ...)        (app/api/reviews.py)
   ↓
Validation (Pydantic, automatic): body must match ReviewCreate
   rating: int 1..5 · comment ≤ 1000 chars · photos ≤ 3      → else 422 with field errors
   ↓
Dependencies run (FastAPI Depends):
   get_db()            → opens a SQLAlchemy Session for this request
   get_current_user()  → reads "Authorization: Bearer <JWT>", decodes it with SECRET_KEY,
                         checks type == "access", loads the User, refuses suspended/banned (403)
                         → 401 if the token is missing/invalid/expired
   ↓
Business logic in the route + services:
   _business(): business exists and is published?          → else 404
   owner reviewing own business?                           → 403
   already reviewed?                                       → 409
   INSERT review → refresh_rating() (Algorithm 7) → rules.check_review() (Module 8 flags)
   notification_service.notify(owner, "review", …)         → returns a PushJob
   ↓
Database: one transaction → db.commit()
   ↓
Response: ReviewOut serialized to JSON, status 201
   ↓
Background task (after the response is sent): PushJob → FCM push to the owner's devices
```

## 9.3 Routers (the endpoint files)

| File | Prefix | What it handles |
|---|---|---|
| `backend/app/api/auth.py` | `/auth` | Register, login, Google, refresh, email verification, forgot/reset password |
| `backend/app/api/users.py` | `/users` | My profile, delete account, consent, interests, saved lists |
| `backend/app/api/businesses.py` | `/businesses` | Owner CRUD, photos, hours, analytics, detail, save/unsave, report, verification |
| `backend/app/api/categories.py` | `/categories` | The category catalogue with counts |
| `backend/app/api/feed.py` | `/feed` | Home feed, surprise stack |
| `backend/app/api/search.py` | `/search` | Search, suggestions, popular, history |
| `backend/app/api/compare.py` | `/compare` | Compare 2–3 businesses |
| `backend/app/api/media.py` | `/media` | Upload photo, serve large photo or thumbnail |
| `backend/app/api/geo.py` | `/geo` | Reverse geocode, place search, route preview |
| `backend/app/api/reviews.py` | (none) | `/businesses/{id}/reviews`, `/reviews/{id}/…`, `/users/me/reviews` |
| `backend/app/api/chat.py` | (none) | `/conversations…` and the `/ws` WebSocket |
| `backend/app/api/notifications.py` | `/notifications` | Devices, the list, unread count, mark read, settings |
| `backend/app/api/promotions.py` | (none) | `/businesses/{id}/offers…`, `/businesses/{id}/campaigns…`, `/campaigns/{id}` |
| `backend/app/api/admin.py` | `/admin` | The admin panel. The **whole router** requires an admin (`dependencies=[Depends(get_current_admin)]`). |
| `backend/app/api/deps.py` | — | Shared dependencies (current user, admin, owner, optional user, consent check, clock) |

## 9.4 Services (business logic)

| Service | Main functions |
|---|---|
| `otp_service.py` | `create_and_send()`, `verify_code()` |
| `email_service.py` | `send_email()` (smtplib + STARTTLS), HTML templates for codes and account notices |
| `account_service.py` | `delete_account()` (FR-32) |
| `business_service.py` | `to_card()`, `build_analytics()`, `record_view_later()`, `distance_km()`, `is_new_business()` |
| `media_service.py` | `process_image()`, `store_upload()`, `resolve_keys()`, `delete_orphans()` |
| `hours.py` | `is_open_now()`, `today_hours_label()` (timezone-aware, overnight hours) |
| `search/engine.py`, `strategies.py`, `ranking.py`, `criteria.py`, `text.py`, `suggestions.py`, `history.py` | The search engine |
| `compare_service.py` | `build_comparison()`, `compute_highlights()` (2–3 businesses) |
| `review_service.py` | `refresh_rating()`, `ranking_score()`, `summary()`, `order_by()`, `display_name()` |
| `promotion_service.py` | `offer_state()`, `campaign_state()`, `live_offers()`, `deal_label()`, `publish_problem()`, `due_notices()` |
| `chat_service.py` | `side_of()`, `unread_by_conversation()`, `send_problem()`, `detail_out()`, `business_message_counts()` |
| `realtime.py` | `ConnectionManager` (open sockets) |
| `push.py` | `PushSender`, `FcmSender`, `NullSender`, `get_sender()` |
| `notification_service.py` | `notify()`, `PushJob`, `users_who_saved()`, `users_interested_in()` |
| `verification_service.py` | `checks()`, `refresh()`, `identity_changed()`, `decide()` |
| `moderation_service.py` | `account_block()`, `hide_review()`, `close_conversation()`, `suspend_business()`, `act_on_user()`, `log_action()` |
| `moderation_rules.py` | `scan_text()`, `check_review()`, `check_business()`, `check_offer()`, `check_campaign()`, `check_mass_messaging()` |
| `geocoding.py` | `Geocoder`, `OsmGeocoder` (Photon + Nominatim), `GoogleGeocoder`, `_TtlCache` |
| `routing.py` | `Router`, `OrsRouter` (openrouteservice) |

## 9.5 Schemas (DTOs) and validation

**In simple terms.** A schema describes what a request must look like and what a response will
contain. In Khojlo, schemas are **Pydantic** classes in `backend/app/schemas/`.

Validation happens at three levels:

1. **Field rules** (automatic 422 when broken):
   - `RegisterRequest.password: Field(min_length=8, max_length=128)`;
   - `email: EmailStr` (must be a valid email);
   - `ReviewCreate.rating: Field(ge=1, le=5)`;
   - `MessageIn.body: Field(max_length=2000)`;
   - `HoursIn.day_of_week: Field(ge=0, le=6)`;
   - `latitude: Field(ge=-90, le=90)`.
2. **Custom validators:**
   - `RegisterRequest._no_self_service_admin` refuses `role=admin`;
   - `HoursIn._hhmm` requires "HH:MM";
   - `normalize_phone` requires 7–15 digits;
   - `BusinessBase._consistent` checks that the minimum price ≤ maximum price and that latitude and
     longitude come as a pair;
   - `BusinessCreate._unique_days` allows each weekday once.
3. **Rules that need the database** live in the route or service and raise `HTTPException`:
   - the category must exist, and "Other" needs a description;
   - the photo key must be your own upload;
   - you can't review your own business;
   - one active review per user per business.

**Response schemas also protect data.** `UserOut` lists exactly which user fields go out. It never
includes `hashed_password`, even though the `User` model has it.

## 9.6 Error handling (backend)

| Situation | What the backend does |
|---|---|
| Wrong input shape | FastAPI returns **422** automatically with a list of field errors |
| Business rule broken | `raise HTTPException(status_code=…, detail="Human sentence")`, e.g. 409 "You've already reviewed Brew & Bloom. Edit your review instead." |
| Race conditions (two requests at once) | Catch `IntegrityError` from a unique constraint, `rollback()`, return the existing row or a 409 (e.g. `open_conversation`, `send_message`, `create_review`) |
| External provider fails (geocoding, routing) | Logged with `log.warning(...)`, returned as **502** with a friendly message; never shows provider details to users |
| External provider not configured | **503** ("Address lookup isn't set up on this server") |
| Firebase or SMTP not configured | Feature switches off quietly (`NullSender`; `send_email()` logs a warning and skips) |
| A moderation rule crashes | `@never_fail` logs it and returns no flags, so publishing still succeeds |
| Unexpected exception | No custom global handler. FastAPI/Starlette return a generic **500**. |

## 9.7 WebSockets, Firebase and background tasks (summary)

- **WebSocket:** one endpoint, `@router.websocket("/ws")` in `backend/app/api/chat.py`. See
  Part 15.
- **Firebase:** *no Firebase Admin SDK*. `FcmSender` (in `backend/app/services/push.py`) uses
  `google.oauth2.service_account.Credentials` to get a short-lived OAuth access token, then POSTs
  JSON to the FCM HTTP v1 endpoint with `requests`. See Part 16.
- **Background tasks:** FastAPI `BackgroundTasks` run *after* the response is sent, in the same
  process. Khojlo uses them for:
  - OTP and account emails;
  - push jobs;
  - WebSocket `publish` events;
  - counting profile views (`record_view_later()`);
  - closing a deleted user's sockets;
  - verification and moderation notices.
- **Command-line jobs:** `python -m app.jobs.trending_digest [--dry-run]` and
  `python -m app.jobs.promotions` (scheduled-offer notices). Nothing runs them automatically, so
  they're run by hand or from cron. Home visits also send any notices that are due.

## 9.8 Configuration, logging and startup

- **Configuration:** `Settings` in `backend/app/core/config.py` (pydantic-settings). It reads
  `backend/.env`; real environment variables override it. See Part 18.
- **Logging:**
  - Messages go through Python's `logging`, mostly the `uvicorn.error` logger. Examples:
    "Push notifications are off …", "Geocoding failed …", "SMTP not configured — skipping email".
  - Tokens are never logged; the WebSocket token is sent in a message, not in the URL.
  - There's no structured logging or monitoring (no Sentry or Prometheus): **not confirmed from
    codebase / not present**.
- **Startup:** `lifespan()` → `warn_if_outdated(engine)` (`backend/app/db/schema_check.py`). If the
  database is missing migrations, it logs which revision is missing and tells you to run
  `alembic upgrade head`.
- **API docs:** `/docs` (Swagger) and `/redoc` are generated by FastAPI. `POST /auth/login/form`
  exists only so Swagger's **Authorize** button works.

---

# Part 10: Database Deep Dive

## 10.1 Which database, and why

- **What:** **PostgreSQL**, a free, open-source relational database (tables, rows, SQL,
  transactions).
- **Why** (SRS CO-3, SDD §5.1):
  - The data is highly relational: users own businesses, businesses have reviews, conversations
    link customers and businesses.
  - It needs constraints (unique, foreign keys, checks) and transactions for integrity (REL-1).
  - SQL makes it easy to aggregate (ratings, unread counts, analytics).

## 10.2 Where it's hosted

| Environment | Database | Evidence |
|---|---|---|
| **Team / shared** | PostgreSQL hosted on **Supabase**, reached through Supabase's connection pooler (host `*.pooler.supabase.com`, port 5432) | Local `backend/.env` `DATABASE_URL` (value not shown); `docs/team_setup.md` |
| **Local option A** | PostgreSQL 16 in Docker (`docker compose up -d`) | `backend/docker-compose.yml` |
| **Local option B** | A local PostgreSQL install (e.g. Homebrew `postgresql@14`), role and db `khojlo` | `README.md`; default `DATABASE_URL` in `config.py` |
| **Tests** | In-memory **SQLite** | `backend/tests/conftest.py` |

> **Supabase is not the backend.** Khojlo uses Supabase only as a managed PostgreSQL server: no
> Supabase Auth, Storage, Realtime or client SDK. If Supabase disappeared, you could point
> `DATABASE_URL` at any PostgreSQL server and run `alembic upgrade head`.

## 10.3 How the backend connects

```text
DATABASE_URL = postgresql+psycopg2://<user>:<password>@<host>:5432/<db>
                │          │
                │          └─ psycopg2: the driver that speaks PostgreSQL's network protocol
                └─ SQLAlchemy dialect
```

1. `create_engine(settings.DATABASE_URL, pool_pre_ping=True)` creates a **connection pool**. It
   reuses open connections, and `pool_pre_ping` checks a connection is alive before using it.
2. `SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)`.
3. Each request gets its own `Session` from `get_db()`, which is closed in a `finally` block.
4. WebSocket events and background jobs use `session_scope()`, because the request's session is
   already closed when they run.

## 10.4 ORM and migrations

**ORM, in simple terms.** An ORM (Object–Relational Mapper) lets you work with database rows as
Python objects. Instead of writing `INSERT INTO users …`, you write `db.add(User(email=…))`.
SQLAlchemy writes the SQL for you, with safe parameter binding.

- **Library:** SQLAlchemy **2.0**, typed style (`Mapped[int] = mapped_column(primary_key=True)`).
- **Migrations:** **Alembic**. Each change to the tables is a versioned Python script in
  `backend/alembic/versions/`. `alembic upgrade head` applies the missing ones. The chain:

| # | Revision | What it added |
|---|---|---|
| 1 | `4a15738bc9dc` | Initial schema (users, categories, businesses, services, hours, offers, saved lists, views, reviews stub) |
| 2 | `17614acc377c` | Google Sign-In (`users.google_id`, nullable password) |
| 3 | `4ff96035ae0a` | Email verification and password reset (`otp_codes`) |
| 4 | `71c2ae544c86` | Module 4: price range, service prices, `search_queries`, indexes |
| 5 | `b7d3f1a9c2e4` | Photos (`media`, `business_photos`), category columns, phone numbers |
| 6 | `c5e8a2d4f610` | Module 5: reviews reshaped + `review_photos`, `review_votes`, `review_reports` |
| 7 | `d9a4e1c7b3f5` | Module 9: `conversations`, `messages`, `conversation_reports`, `device_tokens`, `notifications`, `users.notification_prefs` |
| 8 | `e7c2a9f4b1d8` | Offers reworked + `campaigns`, `campaign_offers`, `campaign_services` |
| 9 | `f4c1a8e2b9d3` | Module 8: verification/suspension columns, `business_reports`, `moderation_flags`, `moderation_actions` |
| 10 | `e3b7c9a1f2d4` | Privacy consent columns; `business_views.viewer_id` → `ON DELETE SET NULL` |

## 10.5 The tables (28)

| Group | Table | Key columns (simplified) |
|---|---|---|
| Accounts | `users` | `id`, `email` (unique), `hashed_password` (null for Google-only), `google_id` (unique), `full_name`, `role`, `avatar_tone`, `phone`, `avatar_media_id`, `interests` (JSON), `notification_prefs` (JSON), `is_verified`, `privacy_policy_version`, `privacy_consent_at`, `is_banned`, `suspended_until`, `suspension_reason`, `created_at` |
| | `otp_codes` | `user_id`, `purpose` (verify_email / reset_password), `code_hash`, `attempts`, `expires_at`, `consumed_at` |
| Businesses | `categories` | `slug` (unique), `name`, `tone`, `emoji`, `group_name`, `sort_order`, `keywords` |
| | `businesses` | `owner_id`, `category_id`, `name`, `custom_category`, `tagline`, `description`, `tone`, `address`, `phone`, `latitude`, `longitude`, `price_level`, `price_min`, `price_max`, `is_verified`, `is_published`, `verification_status`, `verification_note`, `verified_at`, `verified_by_id`, `storefront_media_id`, `storefront_at`, `suspended_at`, `suspension_reason`, counters `view_count` / `save_count` / `rating` / `review_count`, `created_at` (plus a legacy unused `images` JSON) |
| | `services` | `business_id`, `name`, `price` (text), `price_amount` (PKR) |
| | `opening_hours` | `business_id`, `day_of_week` (0 = Monday), `opens`, `closes`, `is_closed` |
| Promotions | `offers` | `business_id`, `title`, `description`, `deal_type`, `deal_value`, `deal_text`, `start_date`, `end_date`, `terms`, `is_active`, `views`, `redemptions`, `deleted_at`, `notified_at` |
| | `campaigns` | `business_id`, `name`, `description`, `message`, `banner_media_id`, `start_date`, `end_date`, `terms`, `is_published`, `notify_savers`, `notified_at`, `deleted_at` |
| | `campaign_offers`, `campaign_services` | Link tables (campaign ↔ offer, campaign ↔ service) with `position` |
| Engagement | `saved_lists` | `user_id`, `name`, `tone` |
| | `saved_businesses` | `list_id`, `business_id` (unique together) |
| | `business_views` | `business_id`, `viewer_id` (set to NULL if the viewer deletes their account), `created_at` |
| | `search_queries` | `user_id` (null for anonymous), `query`, `normalized`, `filters` (JSON), `result_count` |
| Reviews | `reviews` | `business_id`, `user_id`, `rating` (CHECK 1–5), `comment`, `is_approved`, `helpful_count`, `owner_reply`, `owner_reply_at`, `created_at`, `updated_at`, `deleted_at` |
| | `review_photos` | `review_id`, `media_id`, `position` |
| | `review_votes` | `review_id`, `user_id` (unique together) |
| | `review_reports` | `review_id`, `reporter_id` (unique together), `reason`, `note`, `status`, `resolved_at`, `resolved_by_id` |
| Chat | `conversations` | `customer_id`, `business_id` (unique together), `last_message_at`, `customer_last_read_id`, `business_last_read_id`, `blocked_by`, `blocked_at`, `closed_at` |
| | `messages` | `conversation_id`, `sender_id`, `from_business`, `body`, `media_id`, `client_id` (unique per conversation), `created_at` |
| | `conversation_reports` | `conversation_id`, `reporter_id` (unique together), `reason`, `note`, `status` … |
| Push | `device_tokens` | `user_id`, `token` (unique), `platform` (android / web / ios), `created_at`, `last_seen_at` |
| | `notifications` | `user_id`, `kind`, `title`, `body`, `route`, `read_at`, `created_at` |
| Media | `media` | `key` (unique, 32 hex), `owner_id`, `content_type`, `width`, `height`, `focal_x`, `focal_y`, `size_bytes`, **`data`** and **`thumb`** (binary, *deferred*: only loaded when served) |
| | `business_photos` | `business_id`, `media_id`, `position` (0 = cover) |
| Moderation | `business_reports` | `business_id`, `reporter_id` (unique together), `reason`, `note`, `status` … |
| | `moderation_flags` | `target_type`, `target_id`, `business_id`, `user_id`, `rule`, `label`, `detail`, `excerpt`, `status` … |
| | `moderation_actions` | The audit log: `admin_id` (NULL = automatic), `action`, `target_type`, `target_id`, `subject_user_id`, `reason`, `note`, `created_at` |

## 10.6 Relationship overview (the actual relationships)

```text
users ─┬─< businesses (owner_id) ─┬─< services ──────────< campaign_services >─┐
       │                          ├─< opening_hours                            │
       │                          ├─< business_photos >── media                │
       │                          ├─< offers ─────────────< campaign_offers >──┼── campaigns
       │                          ├─< campaigns ─────────────────────────────────┘
       │                          ├─< reviews ──┬─< review_photos >── media
       │                          │             ├─< review_votes >── users
       │                          │             └─< review_reports >── users (reporter)
       │                          ├─< conversations ─┬─< messages (sender = users, photo = media)
       │                          │                  └─< conversation_reports
       │                          ├─< business_views (viewer = users, nullable)
       │                          ├─< business_reports
       │                          └── category ── categories
       ├─< reviews (author)
       ├─< conversations (customer_id)
       ├─< saved_lists ─< saved_businesses >── businesses
       ├─< device_tokens
       ├─< notifications
       ├─< otp_codes
       ├─< search_queries
       ├─< media (uploads; owner_id)
       └─< moderation_flags / moderation_actions (subject)

Legend: A ─< B  = one A has many B (B has a foreign key to A)
        >──     = many-to-one link
```

The main **cardinalities** to know:

- One user has many businesses (an owner can register several).
- One business has many reviews, but each user has **at most one active review** per business.
- One conversation per (customer, business) pair. A conversation has many messages.
- A campaign links to many offers, and an offer can be in many campaigns (many-to-many through
  `campaign_offers`).
- A saved list contains many businesses, and a business can be in many lists (many-to-many through
  `saved_businesses`).

## 10.7 Keys, constraints and indexes

| Kind | Examples in Khojlo |
|---|---|
| **Primary keys** | Every table has `id` INTEGER, auto-increment. The SDD said UUIDs; the implementation uses integers. |
| **Foreign keys** | `businesses.owner_id → users.id`, `reviews.business_id → businesses.id`, `messages.conversation_id → conversations.id` … |
| **ON DELETE CASCADE** | Most child tables: deleting a user deletes their businesses, reviews, conversations, devices …; deleting a business deletes its services, hours, offers, photos, reviews, conversations … |
| **ON DELETE SET NULL** | `business_views.viewer_id` (views stay, without the viewer), `businesses.verified_by_id`, `businesses.storefront_media_id`, `messages.media_id`, `users.avatar_media_id`, the `resolved_by_id` columns, `moderation_actions.admin_id` |
| **Unique** | `users.email`, `users.google_id`, `categories.slug`, `media.key`, `device_tokens.token`, `(customer_id, business_id)` on conversations, `(conversation_id, client_id)` on messages, `(list_id, business_id)`, `(review_id, user_id)` votes, one report per reporter per item, `(campaign_id, offer_id)`, `(campaign_id, service_id)`, `(business_id, media_id)` |
| **Partial unique index** | `uq_reviews_user_business_active` on `(user_id, business_id)` **WHERE `deleted_at IS NULL`**. One active review per user per business (BR-4); deleting your review frees the slot. |
| **Check constraint** | `ck_reviews_rating_range`: `rating BETWEEN 1 AND 5` |
| **Indexes** | On almost every foreign key, plus `businesses.created_at`, `is_published`, `verification_status`, `category_id`; `reviews.created_at`; `messages.created_at`; `conversations.last_message_at`; `notifications.created_at`; `search_queries.normalized`; `moderation_flags (target_type, target_id)`; `moderation_actions.action` |

## 10.8 Timestamps, soft delete, transactions and other details

- **Timestamps:**
  - `DateTime(timezone=True)` columns, filled with `datetime.now(timezone.utc)`. Everything is
    stored in **UTC**.
  - Business-local logic converts to `Asia/Karachi` (`to_local()` in
    `backend/app/services/hours.py`).
- **Soft delete** (the row stays, with `deleted_at` set): `reviews`, `offers` and `campaigns`.
  Everything else is deleted for real (hard delete).
- **Transactions:**
  - Each request does its work and calls `db.commit()` once, so everything succeeds or nothing
    does (REL-1).
  - `db.flush()` sends SQL early (for example, to get a new id or trigger a unique-constraint
    error) without ending the transaction.
  - `db.rollback()` undoes it after an `IntegrityError`.
- **Enums** (role, report reason, notification kind …) are stored as **short strings**
  (`native_enum=False`), so adding a value doesn't need a PostgreSQL `ALTER TYPE`.
- **JSON columns:** `users.interests`, `users.notification_prefs`, `search_queries.filters`.
- **Denormalized counters** on `businesses` (`rating`, `review_count`, `view_count`,
  `save_count`) make feed and list queries fast:
  - `rating` and `review_count` are **recalculated** from `reviews` on every change.
  - `view_count` is incremented atomically.
  - `save_count` is incremented and decremented with saves.
- **Photos in the database:** the `media.data` and `media.thumb` columns are binary (`BYTEA` in
  PostgreSQL), marked `deferred` so they're only loaded when a photo is actually served.

---

# Part 11: Database Query Defense

> **"Where did you use database queries in your project?"**
>
> **Answer you can give:** "Every API endpoint reads or writes PostgreSQL through SQLAlchemy, our
> ORM. We write queries in Python, for example `select(User).where(User.email == email)`, and
> SQLAlchemy turns them into parameterized SQL. The interesting ones are:
>
> - **login:** a SELECT by email;
> - **registration:** an INSERT;
> - **read receipts:** an UPDATE;
> - **deleting a business:** a DELETE with cascades;
> - **chat unread counts:** a JOIN with GROUP BY and COUNT;
> - **the business rating:** AVG and COUNT;
> - **chat history:** keyset pagination;
> - **search:** ILIKE, EXISTS and a bounding-box filter;
> - **creating a review:** a transaction that stays consistent even when two requests race.
>
> I can show you each one in the code."

## 11.1 How the ORM generates SQL

1. You build a query object in Python: `stmt = select(User).where(User.email == email)`.
2. `db.execute(stmt)` compiles it for the PostgreSQL dialect into SQL with **bound parameters**,
   such as `SELECT … FROM users WHERE users.email = %(email_1)s`. psycopg2 sends the SQL and the
   values **separately**, which is why user input can't inject SQL.
3. The rows come back as Python objects (`User` instances).
4. Changes to objects (`user.is_verified = True`) or new objects (`db.add(x)`) are tracked by the
   **Session** (the "unit of work"). `db.flush()` / `db.commit()` sends the matching
   `INSERT` / `UPDATE` / `DELETE`.

*Tip:* to see the real SQL, you could create the engine with `echo=True`. It's off in Khojlo.

The SQL shown below is **roughly** what SQLAlchemy sends (simplified column lists).

## 11.2 SELECT: logging in

| Step | What happens |
|---|---|
| User action | Taps **Sign in** |
| API endpoint | `POST /api/v1/auth/login` |
| Code | `login()` in `backend/app/api/auth.py` |
| Database operation | `db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()` |
| SQL | `SELECT users.* FROM users WHERE users.email = $1` |
| Result | One `User` or `None`. Then `verify_password()` checks the bcrypt hash in Python. |
| API response | `200 {"access_token": "...", "refresh_token": "...", "token_type": "bearer"}` or `401 "Incorrect email or password"` |
| Flutter UI | `AuthController.login()` saves the tokens, calls `/users/me`, and the router sends you to Home |

## 11.3 INSERT: registering

- **Endpoint:** `POST /auth/register` → `register()`.
- **Code:**

  ```python
  user = User(email=..., full_name=..., hashed_password=hash_password(...), role=..., interests=...)
  user.record_privacy_consent()
  db.add(user)
  db.commit()
  db.refresh(user)
  ```

- **SQL:**

  ```sql
  INSERT INTO users (email, hashed_password, full_name, role, interests, privacy_policy_version, ...)
  VALUES ($1, $2, ...) RETURNING users.id
  ```

  It's followed by `INSERT INTO otp_codes (...)` for the verification code.
- **Response:** `201` with the user (`UserOut`, no password hash). The app then logs in
  automatically.

## 11.4 UPDATE: "Seen" receipts and an atomic counter

**Read receipt.** `mark_read()` in `backend/app/api/chat.py`:

```python
setattr(conversation, "customer_last_read_id", latest)   # or business_last_read_id
db.commit()
```

```sql
UPDATE conversations SET customer_last_read_id = $1 WHERE conversations.id = $2
```

**Atomic increment.** `record_view_later()` in `backend/app/services/business_service.py`:

```python
db.execute(update(BusinessProfile).where(BusinessProfile.id == business_id)
           .values(view_count=BusinessProfile.view_count + 1))
```

```sql
UPDATE businesses SET view_count = (businesses.view_count + 1) WHERE businesses.id = $1
```

Why this is good: the database does the "+1", so two viewers at the same time can't overwrite each
other's count (no lost update).

**Bulk update.** "Mark all read" (`mark_read()` in `backend/app/api/notifications.py`):

```sql
UPDATE notifications SET read_at = now WHERE user_id = $1 AND read_at IS NULL
```

## 11.5 DELETE: deleting a business, and cleaning up dead push tokens

- `delete_business()` → `db.delete(b)` → `DELETE FROM businesses WHERE id = $1`.
  - The ORM's `cascade="all, delete-orphan"` deletes loaded children (services, hours, offers,
    campaigns, photos).
  - The database's `ON DELETE CASCADE` removes the rest (reviews, conversations and their
    messages, reports, views).
  - Then `delete_if_unused()` removes photo rows nobody uses any more.
- `PushJob` (in `notification_service.py`): when Firebase says tokens are dead,
  `DELETE FROM device_tokens WHERE token IN ($1, $2, …)`.
- **Soft delete** is an UPDATE, not a DELETE. Deleting a review sets `deleted_at`.

## 11.6 JOIN + GROUP BY + COUNT: chat unread counts

`unread_by_conversation()` in `backend/app/services/chat_service.py`, the customer half:

```python
select(Message.conversation_id, func.count(Message.id))
  .join(Conversation, Conversation.id == Message.conversation_id)
  .where(Conversation.customer_id == user_id,
         Message.from_business.is_(True),
         Message.id > func.coalesce(Conversation.customer_last_read_id, 0))
  .group_by(Message.conversation_id)
```

```sql
SELECT messages.conversation_id, count(messages.id)
FROM messages JOIN conversations ON conversations.id = messages.conversation_id
WHERE conversations.customer_id = $1
  AND messages.from_business IS true
  AND messages.id > coalesce(conversations.customer_last_read_id, 0)
GROUP BY messages.conversation_id
```

In words: "for each of my conversations, count the business's messages newer than the last one I
read". The owner half joins `businesses` too, to find conversations for businesses the user owns.

Another JOIN example, `users_who_saved()` (recipients of an offer notification):

```sql
SELECT DISTINCT users.* FROM users
JOIN saved_lists ON saved_lists.user_id = users.id
JOIN saved_businesses ON saved_businesses.list_id = saved_lists.id
WHERE saved_businesses.business_id = $1 AND users.id != $2   -- not the owner
```

## 11.7 Aggregation: the business rating (SDD Algorithm 7)

`refresh_rating()` in `backend/app/services/review_service.py`:

```sql
SELECT avg(reviews.rating), count(reviews.id) FROM reviews
WHERE reviews.business_id = $1 AND reviews.deleted_at IS NULL AND reviews.is_approved IS true
```

The result is written to `businesses.rating` (rounded to 2 decimals) and
`businesses.review_count`, **in the same transaction** as the review change.

Other aggregations:

- **Star distribution:** `summary()` runs `SELECT rating, count(id) … GROUP BY rating`.
- **Trending digest:** `SELECT business_id, count(id) FROM business_views WHERE created_at >= now-7d
  GROUP BY business_id`.
- **Admin overview:** 17 numbers in **one** SQL query, using scalar subqueries
  (`overview()` in `backend/app/api/admin.py`). Each number is a `SELECT count(...)` subquery
  inside one outer `SELECT`. This saves round trips to the remote database.

## 11.8 Filtering, sorting and pagination

**Offset pagination.** The conversations list:

```python
.where(Conversation.last_message_at.is_not(None))
.order_by(Conversation.last_message_at.desc(), Conversation.id.desc())
.limit(limit).offset(offset)
```

**Keyset ("cursor") pagination.** Chat history (`list_messages()`):

```python
query.where(Message.id < before_id).order_by(Message.id.desc()).limit(limit + 1)
```

It asks for one extra row to know if there's `has_more`, then reverses the list so it's oldest
first. Catching up uses `Message.id > after_id`. Keyset paging stays fast and doesn't skip or
repeat rows while new messages arrive.

**Count + page.** The notifications list runs a `count()` over a subquery for `total`, then
`ORDER BY created_at DESC, id DESC LIMIT … OFFSET …`.

## 11.9 Search queries

The keyword part of `KeywordSearch.apply()` in `backend/app/services/search/strategies.py`, for
each word typed:

```sql
SELECT businesses.* FROM businesses
LEFT OUTER JOIN categories ON businesses.category_id = categories.id
WHERE businesses.is_published IS true
  AND (businesses.name ILIKE '%d_rz_%' ESCAPE '\'
       OR businesses.tagline ILIKE … OR businesses.description ILIKE …
       OR businesses.address ILIKE … OR categories.name ILIKE …
       OR categories.keywords ILIKE … OR businesses.custom_category ILIKE …
       OR EXISTS (SELECT 1 FROM services
                  WHERE services.business_id = businesses.id AND services.name ILIKE …))
```

- `ILIKE` is a case-insensitive match.
- `like_pattern()` (in `backend/app/services/search/text.py`) turns each **vowel into the `_`
  wildcard** ("darzi" → `%d_rz_%`), so accented spellings ("café") also match. Python then
  re-checks every candidate with `fold()` (lowercase, accents removed), so the extra matches cost
  only a few rows.
- `%`, `_` and `\` typed by the user are **escaped**, so they're treated as normal characters.
- `LocationSearch` adds a **bounding box**: `latitude BETWEEN lat ± dlat AND longitude BETWEEN
  lng ± dlng`. Python then checks the exact distance with the haversine formula.
- `AreaSearch` (the map) adds `latitude BETWEEN south AND north AND longitude BETWEEN west AND
  east`.
- `CategorySearch` adds `categories.slug IN (...)`.
- **Ranking and paging happen in Python** after the SQL pre-filter (Part 36 covers the scaling
  impact).

## 11.10 Transactions: creating a review safely

From `create_review()` in `backend/app/api/reviews.py`:

```python
review = Review(business_id=b.id, user_id=user.id, rating=..., comment=...)
db.add(review)
try:
    db.flush()                       # INSERT now → the unique index can fire
except IntegrityError:               # the same user submitted twice at the same moment
    db.rollback()
    raise HTTPException(409, "You've already reviewed … Edit your review instead.")
_set_photos(db, review, media)       # INSERT review_photos
rs.refresh_rating(db, b)             # SELECT avg/count → UPDATE businesses
rules.check_review(db, review)       # maybe INSERT moderation_flags
job = ns.notify(...)                 # INSERT notifications
db.commit()                          # all of the above, atomically
```

If anything fails before `commit()`, nothing is saved. The review, its photos, the new rating and
the notification are all-or-nothing.

## 11.11 Other good examples to show

- **Existence check:** `is_saved_by()` runs `SELECT saved_businesses.id … JOIN saved_lists …
  LIMIT 1`.
- **Race-safe "get or create":** `open_conversation()` tries the INSERT, catches
  `IntegrityError`, and selects the conversation the other request created.
- **Idempotent insert:** `send_message()` checks for an existing `(conversation_id, client_id)`
  row, and the unique constraint stops duplicates even under a race.

---

# Part 12: Authentication

## 12.1 Two words first

- **Authentication** answers "**who** are you?" Khojlo handles it with a password or Google
  sign-in, then a token.
- **Authorization** answers "**what** may you do?" Khojlo handles it with roles (customer, owner,
  admin), ownership checks ("is this your business?") and participant checks ("are you in this
  conversation?").

## 12.2 Registration (email and password)

```text
AuthScreen (sign-up mode) — name, email, password, role chip (Customer / Business owner),
                            consent checkbox (never pre-ticked)
   ↓ AuthController.register()
   ↓ AuthRepository.register() → POST /api/v1/auth/register
        {full_name, email, password, role, interests, privacy_policy_version}
   ↓ backend register() (app/api/auth.py)
        1. Pydantic: valid email, password 8–128 chars, role ≠ admin
        2. email already used?                                → 409 "Email already registered"
        3. privacy_policy_version == server version?          → else 409 "Our privacy policy has changed…"
        4. User(hashed_password = bcrypt(password)), record consent (version + time)
        5. INSERT users → COMMIT
        6. create a 6-digit email code, store its HMAC hash in otp_codes, email it in the background
   ↓ 201 {user without any password field}
   ↓ the app immediately calls POST /auth/login with the same credentials (AuthRepository.register)
   ↓ tokens saved → GET /users/me → AuthStatus.authenticated → router → Home
     (customers with no interests yet are sent to the interests screen)
```

## 12.3 Login

```text
POST /api/v1/auth/login {email, password}
  → SELECT user by email
  → verify_password(plain, stored_hash)  (bcrypt.checkpw)
  → wrong email OR wrong password → the SAME 401 "Incorrect email or password"
    (so an attacker can't tell which part was wrong)
  → ensure_active(user): suspended or banned → 403 with the reason
  → 200 {access_token, refresh_token, token_type: "bearer"}
```

## 12.4 How passwords are hashed

**Simple explanation.** We never keep your password. We keep a **fingerprint** of it, made by a
deliberately slow one-way function. At login we fingerprint what you typed and compare the two.
Even we can't turn the fingerprint back into your password.

**Technical explanation.** **bcrypt** is a password-hashing function. For each password it
generates a random **salt**, so two users with the same password get different hashes. It has a
**cost factor** that makes each guess slow, so brute-forcing stolen hashes is expensive. The stored
string contains the algorithm, the cost, the salt and the hash, for example
`$2b$12$<22-char salt><31-char hash>`.

**Khojlo's implementation** (`backend/app/core/security.py`):

```python
def hash_password(password: str) -> str:
    return bcrypt.hashpw(_to_bytes(password), bcrypt.gensalt()).decode("utf-8")

def verify_password(plain: str, hashed: str | None) -> bool:
    if not hashed:                       # Google-only accounts have no password
        return False
    return bcrypt.checkpw(_to_bytes(plain), hashed.encode("utf-8"))
```

- It uses the `bcrypt` library directly. `passlib` was dropped because it breaks with bcrypt 4/5 on
  Python 3.14.
- `bcrypt.gensalt()` is called with its default cost factor, which is 12 in the `bcrypt`
  library.
- bcrypt only reads the first **72 bytes** of a password, so `_to_bytes()` cuts it to 72 bytes
  explicitly. Newer bcrypt versions would otherwise raise an error.

**Why bcrypt?** It's an industry standard made for passwords: salted and slow on purpose. Fast
hashes like SHA-256 are bad for passwords because attackers can try billions per second.

### Where is password verification performed?

| Place | Code |
|---|---|
| Login | `login()` in `backend/app/api/auth.py` |
| Swagger's login form | `login_form()` in `backend/app/api/auth.py` |
| Confirming account deletion | `delete_me()` in `backend/app/api/users.py` (wrong password → **403**, not 401, so the app doesn't think the session expired) |

### Are passwords ever stored in plaintext?

**No.** The `users` table only has `hashed_password` (`String(255)`, NULL for Google-only
accounts). The plaintext password exists only:

- in the request body;
- in memory while the request is processed.

It's never logged or returned (`UserOut` has no password field).

> **Caveat:** in local development the request travels over **http**, so the password crosses the
> network unencrypted. Production needs HTTPS (SRS SEC-4).

## 12.5 Tokens: JWT

**Simple explanation.** After you log in, the server gives the app a **signed pass**. The app shows
the pass with every request, so the server doesn't need your password again. The pass expires.

**Technical explanation.** A **JWT (JSON Web Token)** has three Base64URL parts separated by dots:
`header.payload.signature`.

```text
Header:    {"alg": "HS256", "typ": "JWT"}
Payload:   {"sub": "42", "type": "access", "iat": 1759680000, "exp": 1759681800}
Signature: HMAC-SHA256( base64(header) + "." + base64(payload), SECRET_KEY )
```

- `sub` is the **user id** (as text), and `type` is Khojlo's own claim: `access`, `refresh` or
  `password_reset`.
- `iat` is the issue time and `exp` is the expiry (Unix seconds).
- **HS256** means HMAC with SHA-256: one shared secret both signs and verifies.

> **The payload is only encoded, not encrypted.** Anyone holding a token can read the user id and
> expiry. The signature only proves the server issued it and nobody changed it. That's why Khojlo
> puts nothing sensitive in the token.

**Khojlo's implementation** (`backend/app/core/security.py`, using the `python-jose` library):

| Token | Lifetime | Created by | Used for |
|---|---|---|---|
| Access token | **30 minutes** (`ACCESS_TOKEN_EXPIRE_MINUTES`) | `create_access_token()` | Every protected API call and the WebSocket |
| Refresh token | **14 days** (`REFRESH_TOKEN_EXPIRE_DAYS`) | `create_refresh_token()` | Only `POST /auth/refresh`, which returns a new pair |
| Password reset token | **10 minutes** (`PASSWORD_RESET_TOKEN_EXPIRE_MINUTES`) | `create_password_reset_token()` | Only `POST /auth/password/reset` |

`decode_token()` verifies the signature and the expiry. It returns `None` if the token was tampered
with or has expired.

**The `type` claim matters.** `get_current_user()` only accepts `type == "access"`, and
`/auth/refresh` only accepts `type == "refresh"`. So a stolen refresh token can't be used directly
as an access token, and a reset token can't call the API. The test
`test_a_refresh_token_is_not_enough` (`backend/tests/test_realtime.py`) checks this for the
WebSocket.

### What is the secret key for?

`SECRET_KEY` (in `backend/.env`) is used in two places:

1. **Signing and verifying JWTs** (HS256). Whoever knows it can mint a valid token for *any* user
   id.
2. **Hashing one-time codes:** `_hash_code()` in `otp_service.py` stores `HMAC-SHA256(SECRET_KEY,
   code)` instead of the code.

If it leaks: generate a new one. Every existing token becomes invalid, so everyone is signed out
once (`docs/team_setup.md`, "If something leaks"). A missing `.env` would fall back to the
placeholder `"change-me-to-a-long-random-string"`, which is a serious risk in production (Known
Inconsistencies & Risks).

### What happens if someone steals the JWT?

- **A stolen access token** works for **up to 30 minutes**, until `exp`.
- **A stolen refresh token** can mint new access tokens for **up to 14 days**.
- There is **no server-side revocation list** and **no refresh-token rotation or blacklist**.
  Logging out deletes the tokens on the device but doesn't invalidate copies. Changing the password
  doesn't kill existing tokens either.

Two things limit the damage:

- A **suspended or banned** account is refused on every request (`ensure_active()`), even with a
  valid token.
- A **deleted** account's tokens fail, because `db.get(User, id)` returns nothing, and its open
  WebSockets are closed with code 4401.

How we reduce the chance of theft: short access lifetime, tokens kept in secure storage, and the
WebSocket token sent in a message instead of the URL (URLs end up in logs). Future work: HTTPS
everywhere, refresh-token rotation with reuse detection, a server-side session table so logout and
password changes revoke tokens, and device binding.

## 12.6 How the backend knows who made a request

```text
App:  GET /api/v1/users/me
      Authorization: Bearer eyJhbGciOiJIUzI1NiIs...      ← added by ApiClient's interceptor

FastAPI: get_current_user(token = Depends(OAuth2PasswordBearer), db = Depends(get_db))
         1. decode_token(token) → signature OK? not expired?       else 401
         2. payload["type"] == "access"?                             else 401
         3. user_id = int(payload["sub"]); user = db.get(User, user_id)   missing → 401
         4. ensure_active(user): banned or suspended → 403 + reason + header X-Account-Status: blocked
         5. return user  → the endpoint receives `user: User`
```

`get_optional_user()` is the same, but it returns `None` instead of failing. Endpoints such as the
feed, search and business details use it, so signed-out visitors and suspended accounts browse as
anonymous users.

## 12.7 Authorization (who may do what)

| Rule | Where |
|---|---|
| Only business owners (or admins) can create or manage businesses | `get_current_owner()` (`backend/app/api/deps.py`) |
| Only the **owner of this business** can edit it, even admins can't (SEC-2) | `_get_owned()` (`backend/app/api/businesses.py`) → 403 "Not your business" |
| Only admins reach `/admin/*` (SEC-3) | `APIRouter(prefix="/admin", dependencies=[Depends(get_current_admin)])` |
| Admin accounts can't be created through sign-up | `_no_self_service_admin` (`backend/app/schemas/auth.py`) |
| Only conversation participants can read or send | `_participant()` (`backend/app/api/chat.py`) → **404**, so outsiders can't even tell it exists (BR-15) |
| Only a review's author can edit or delete it; only the owner can reply | `_own_review()`, `reply()` (`backend/app/api/reviews.py`) |
| You can only attach photos you uploaded | `resolve_keys(..., allowed_owner=user.id)` (`backend/app/services/media_service.py`) |
| The app hides `/admin` from non-admins | `redirect` in `lib/core/router/app_router.dart`. This is **only for user experience**; the real protection is the API. |

## 12.8 Logout

`AuthController.logout()` in `lib/features/auth/auth_controller.dart`:

1. `PushController.unregister()` → `POST /notifications/devices/unregister`, then deletes the
   Firebase token on the device, so this phone stops getting your notifications.
2. `TokenStorage.clear()` deletes both JWTs from secure storage.
3. The state becomes `unauthenticated`. `SessionServices` closes the WebSocket and clears the chat
   list and badges. The router goes to `/onboarding`.

There is **no `/auth/logout` endpoint**. JWTs are stateless, so "logout" is client-side.

## 12.9 Token storage and frontend auth state

- **Storage:** `TokenStorage` (`lib/core/storage/token_storage.dart`) keeps `khojlo_access` and
  `khojlo_refresh` in **flutter_secure_storage** (encrypted storage backed by the Android
  Keystore; browser storage on the web).
- **State:** `AuthController` (a Riverpod `StateNotifier<AuthState>`) has a `status` of
  `unknown`, `authenticated` or `unauthenticated`, plus `user`, `loading` and `error`.
  - At startup, `bootstrap()` checks for a stored token, then calls `/users/me`. Failure → tokens
    cleared → `unauthenticated`.
  - The router listens to `status` and to `user.needsPrivacyConsent`, and redirects.
- **Automatic refresh:** `ApiClient` catches a **401**, calls `/auth/refresh` once, saves the new
  pair and retries the original request. If the refresh fails, it clears the tokens.

## 12.10 Google Sign-In

**Simple explanation.** Google proves to us that you own a Google account. It gives the app a
signed "ID card" (an **ID token**). The app hands it to our server, our server checks the card is
genuine and meant for Khojlo, and then we give you **our own** Khojlo tokens. Khojlo never sees
your Google password.

```text
Mobile: GoogleSignIn.instance.initialize(serverClientId: <Web client ID>)
        GoogleSignIn.instance.authenticate()  → Google account picker
Web:    GoogleSignIn.instance.initialize(clientId: <Web client ID>)
        Google's own rendered button (google_sign_in_web) → authenticationEvents stream
   ↓ account.authentication.idToken      (a JWT signed by Google, audience = our Web client ID)
   ↓ POST /api/v1/auth/google {id_token}
   ↓ backend google_login():
        verify_google_id_token(): google.oauth2.id_token.verify_oauth2_token(token, request,
            audience=GOOGLE_WEB_CLIENT_ID) → checks Google's signature (public certs), expiry,
            audience; then issuer must be accounts.google.com            else 401
        find user by google_id → else by email (link: set google_id, mark email verified)
                                → else create a new customer with NO password
   ↓ our TokenPair (access + refresh) → GET /users/me
   ↓ new Google users have no consent recorded → the router shows /privacy-consent first
```

Details worth knowing:

- **Why an ID token, not an access token?** An ID token is a signed statement of *who* the user is,
  addressed to our app (the audience). A Google access token is for calling Google APIs and doesn't
  prove identity to our backend.
- **The Web client ID** (OAuth client type 3 in `google-services.json`) is the audience the backend
  checks (`GOOGLE_WEB_CLIENT_ID` in `backend/.env`). It's **not secret**. The app has a default in
  `lib/core/network/google_auth_config.dart`.
- **Android** also has an OAuth client of type 1, tied to package `com.khojlo.khojlo` and the
  signing certificate's SHA-1. The `com.google.gms.google-services` Gradle plugin wires it in from
  `google-services.json`.
- **Is this Firebase Authentication?** **No.** It's the Google Sign-In SDK plus our own backend
  verification. Both OAuth clients happen to live in the same Google Cloud / Firebase project
  (`khojlo-c5ba0`).
- Google-only accounts have `hashed_password = NULL`. "Forgot password" silently does nothing for
  them, and deleting the account needs no password.

## 12.11 Email verification and password reset (one-time codes)

`backend/app/services/otp_service.py`, settings in `backend/app/core/config.py`:

| Rule | Value |
|---|---|
| Code | 6 digits from `secrets.randbelow(1_000_000)` (a cryptographically secure random number) |
| Stored as | `HMAC-SHA256(SECRET_KEY, code)`. The raw code is never stored. |
| Expires | 10 minutes |
| Resend cooldown | 45 seconds (429 "Please wait Ns…") |
| Daily cap | 5 codes per purpose per 24 h (429) |
| Wrong attempts | 5, then the code is dead |
| Comparison | `hmac.compare_digest`, a constant-time compare that doesn't leak timing |
| Single use | `consumed_at` is set on success |

**Password reset in 3 steps:**

1. `POST /auth/password/forgot {email}` always returns the **same** answer, whether or not the
   email exists or is Google-only. This means the endpoint can't be used to discover which emails
   are registered.
2. `POST /auth/password/forgot/verify {email, code}` → `{reset_token}` (a JWT of type
   `password_reset`, 10 minutes).
3. `POST /auth/password/reset {reset_token, new_password}` → a new bcrypt hash is saved.

Verifying an email also re-runs business verification for that user's businesses, because a
verified email is one of the Module 8 checks.

## 12.12 Direct answers

| Question | Answer |
|---|---|
| How did you hash passwords? | With **bcrypt** (salted, slow on purpose), using the `bcrypt` library directly in `hash_password()` (`backend/app/core/security.py`). |
| Where is password verification performed? | `verify_password()` → `bcrypt.checkpw`, called from `login()`, `login_form()` and `delete_me()`. |
| Are passwords ever stored as plaintext? | No. Only `users.hashed_password`. Google-only users have NULL. |
| What is the secret used for? | Signing and verifying JWTs (HS256), and hashing one-time codes (HMAC). |
| What happens if someone steals the JWT? | They act as that user until it expires (30 min for access, up to 14 days with a refresh token). There's no revocation list today; banning or deleting the account stops it. Fix: rotation + server-side revocation + HTTPS. |
| How does the backend know who made a request? | The `Authorization: Bearer` header → `get_current_user()` → decode → `sub` = user id → load the user. |
| How does Google Sign-In work? | The app gets a Google **ID token** → our backend verifies its signature, audience and issuer with `google-auth` → links or creates the user → returns **our** JWTs. |

---

# Part 13: Security

An honest audit at FYP level. "Have" means verified in code.

## 13.1 Area by area

| Area | What we have ✅ | What we don't have ❌ | Improvement |
|---|---|---|---|
| **Passwords** | bcrypt with salt; 8–128 characters; never returned or logged; generic login error | No strength check beyond length; no breached-password check | zxcvbn-style strength meter; Have I Been Pwned k-anonymity check |
| **Authentication** | JWT access (30 min) + refresh (14 days) with a `type` claim; Google ID tokens verified (signature, audience, issuer); OTP codes hashed, rate-limited, single-use, constant-time compare; anti-enumeration on "forgot password" | **No rate limit or lockout on `/auth/login`** (brute force possible); registration reveals whether an email exists (409) | Rate-limit login per IP and account (e.g. `slowapi` + Redis); progressive delays; CAPTCHA after failures |
| **JWT and sessions** | Short-lived access tokens; signature + expiry checked; tokens in secure storage; token not in the WebSocket URL | No revocation; no refresh rotation; logout and password change don't invalidate tokens; the reset token is reusable within its 10 minutes | Refresh-token rotation with a server-side session table; a token version per user (bumped on password change or logout-all) |
| **Authorization** | Role dependencies; `_get_owned` ownership (even admins can't edit businesses directly, SEC-2); participant checks with 404; admin-only router; admin can't be self-registered; suspended/banned → 403 on every request and no WebSocket | Client-side `/admin` guard is UX only (fine, because the API enforces it) | Automated permission tests per route (many already exist in tests) |
| **Secrets** | `.env`, `secrets/` and `dart_defines.json` are git-ignored; `.env.example` holds placeholders; service account read from a file path; `docs/team_setup.md` explains private sharing and leak response | Fallback default `SECRET_KEY` in code; secrets live in plain files on developer machines | Fail at startup if `SECRET_KEY` is the default; a secrets manager in production (Part 37) |
| **API keys** | The geocoding and routing keys stay **on the server** (the backend proxies the calls); Google Maps keys are restricted by referrer, package + SHA-1 or API (setup steps) | The Firebase web `apiKey` and the Android key in `google-services.json` are public by design | Restrict the auto-created Firebase browser key to the deployed domain (Module 9 manual step 6) |
| **Firebase credentials** | The service account file is git-ignored; push degrades to `NullSender` without it; dead tokens are removed | Anyone with the file can send pushes as Khojlo | Separate service accounts per developer; least-privilege role (FCM sender only) |
| **Input validation** | Pydantic on every body (types, lengths, ranges, email format, HH:MM, phone digits, enums); cross-field checks; BR-7 coordinates; (0, 0) rejected; dates validated (end ≥ start) | — | Fuzz and property tests |
| **SQL injection** | All queries go through SQLAlchemy with **bound parameters**; LIKE wildcards in user input are escaped | — | (Already strong) |
| **CORS** | An explicit origin list + `http://localhost:<any port>` for development | The localhost regex with `allow_credentials=True` is development-only | Production: exact HTTPS origins only |
| **Rate limiting** | Per-user in-memory limits on geocoding (60 / 10 min) and routes (30 / 10 min); OTP cooldowns and daily caps | **No global rate limiting** (login, search, upload, chat sending) | Reverse-proxy or Redis-based limits per IP and user |
| **File uploads** | Size ≤ 10 MB (read capped at 10 MB + 1 byte), formats JPEG/PNG/WebP/MPO, ≥ 200 px, ≤ 50 MP (decompression-bomb guard), **re-encoded** to JPEG (strips any hidden payload), EXIF/GPS metadata removed, random 128-bit keys, orphans deleted after 6 h, attach only your own uploads | `GET /media/{key}` is **public**: anyone with the key can view a photo, including "private" storefront photos | Signed, expiring URLs, or an auth check for storefront media; object storage + CDN |
| **User-generated content** | Flutter renders text, not HTML (no XSS in the app); account notice emails `html.escape` user text; moderation rules flag spam, scams, adult and abusive content; reporting; blocking | No profanity *blocking* (flags only, by design: BR-18); chat text never scanned (privacy decision) | Optional AI classifier at 100% (Part 33) |
| **Review abuse** | One review per user per business (index + check), no self-reviews, burst rule, reports, admin hide, Bayesian ranking | No visit or purchase verification; cheap email sign-ups (email verification not required to review) | Part 14 |
| **Sensitive information exposure** | `UserOut` hides the hash; reviewers shown as "Hassan R."; provider errors hidden (502 + log); non-participants get 404 for chats; tokens kept out of URLs and logs | Register reveals existing emails (409); `/docs` Swagger is open | Generic register response + email-based flow; disable `/docs` in production |
| **Privacy** | Consent recorded with a version (FR-31); hard account deletion with cascades (FR-32); device location never stored (SEC-7); photo GPS stripped; location explained before the permission prompt | — | A data-retention job for old search history and notifications |
| **Transport** | `ws`/`wss` follows `http`/`https` automatically | **Local development is plain HTTP/WS** (SEC-4 deferred) | HTTPS + WSS behind a reverse proxy |
| **.gitignore** | Ignores `.env`, `secrets/`, `**/*-service-account*.json`, `frontend/dart_defines.json`, `key.properties`, keystores, venvs, builds | `.claude/launch.json` is tracked although ignored (harmless config) | Untrack it if the team agrees |
| **Production configuration** | — | Android release signed with **debug keys**; `/docs` open; development CORS; single worker; no HTTPS | A release signing config, a production settings profile (Part 37) |

## 13.2 Summary

**What security we have:**

- bcrypt passwords;
- signed, short-lived, typed JWTs with automatic refresh;
- verified Google ID tokens;
- hashed, rate-limited one-time codes;
- role, ownership and participant checks on the server;
- account suspension enforcement;
- Pydantic validation and parameterized SQL;
- careful image processing;
- secrets kept out of git;
- privacy consent and account deletion;
- moderation (rules, reports, audit log).

**What we don't have:**

- login rate limiting;
- token revocation and rotation;
- HTTPS in development;
- global rate limits;
- private media URLs;
- production hardening (signing, CORS, `/docs`, secret checks);
- security tests (penetration or dependency scanning).

**Never say "the system is secure."** Say: "We applied standard protections for our scope. These
are the known gaps, and this is how we'd close them."

---

# Part 14: Reviews and Fake Content

## 14.1 The rules, one by one

| Question | Answer | Code |
|---|---|---|
| Who can submit a review? | Any **signed-in** user, customer *or* business owner, **except the business's own owner**. The business must be published. | `create_review()` in `backend/app/api/reviews.py` (403 for the owner, 404 if not published) |
| Can anonymous users review? | **No.** `get_current_user` is required (401). Reading reviews is public. | `list_reviews()` uses `get_optional_user` |
| Can the same user review multiple times? | **No**: one *active* review per business per user (BR-4). A second attempt → **409** "You've already reviewed X. Edit your review instead." | `_my_active_review()` check + `IntegrityError` guard |
| Is there a unique constraint? | **Yes**, a **partial unique index** `uq_reviews_user_business_active` on `(user_id, business_id) WHERE deleted_at IS NULL`. The database itself refuses duplicates, even if two requests race. | `backend/app/models/review.py` |
| Is ownership, purchase or a visit verified? | **No.** The app can't prove a visit (SRS UC-7 *assumes* the customer visited). A "Verified" badge on a review means the reviewer's **email** is verified. | Module 5 decision 2 |
| Can users edit reviews? | **Yes**, at any time. `updated_at` is set (shown as "edited") and the rating is recalculated. | `update_review()` (`PATCH /reviews/{id}`) |
| Can users delete reviews? | **Yes**: a **soft delete** (`deleted_at`). The rating is recalculated, and the user may write a new review. | `delete_review()` |
| Is moderation implemented? | **Yes.** Reviews publish immediately. Rules may **flag** them (never hide them). Admins can **hide** a review (`is_approved = false`), which removes it from lists and ratings, optionally with an account action. | `moderation_rules.check_review()`, `moderation_service.hide_review()` |
| Is reporting implemented? | **Yes**: spam / fake / offensive / other, **once per user per review** (unique constraint). You can't report your own review. Reports go to the admin "Reports" queue. | `report_review()`, `review_reports` |
| Ratings shown | The **plain average** of active reviews (2 decimals) and the count; the distribution bars; "No reviews" instead of 0.0 | `refresh_rating()`, `summary()` |
| Ranking by rating | **Bayesian (count-weighted)**: `(3 × 3.5 + avg × n) / (3 + n)`. One 5★ review = 3.875; 200 reviews at 4.8 ≈ 4.78. Unrated = last. | `ranking_score()` |
| Review order | "Most relevant": verified-email reviewers first → reviews with text or photos → most helpful → newest | `order_by()` in `review_service.py` |
| Helpful votes | One per user per review (unique), not on your own review | `review_votes` |
| Owner replies | One public reply per review. Only the **first** reply notifies the reviewer. | `reply()` |

## 14.2 How fake reviews could still happen

1. **Several accounts (sock puppets).** Sign-up needs only an email, and email verification isn't
   required to review. One person can create several accounts and review a business from each.
2. **The owner's friends and family** leaving 5★ reviews. They're real accounts, so no rule can
   tell.
3. **Competitors review-bombing** with 1★ reviews.
4. **Bought reviews** from people who never visited.
5. **Slow fake reviews** spread over days, from accounts older than a week, which avoid the burst
   rule.

## 14.3 What prevents or reduces them today

| Defence | How it helps | Code |
|---|---|---|
| One review per account per business (app check + database index) | Each fake needs a new account | `reviews.py`, `review.py` |
| No self-reviews | The owner can't review their own business from their own account | `create_review()` |
| **Review-burst rule** | **3+ five-star reviews from accounts under 7 days old within 24 hours** → a `fake_reviews` flag on the business, for an admin | `_check_review_burst()` (`BURST_*` constants) in `moderation_rules.py` |
| Text rules on reviews | Links, Pakistani mobile numbers and "WhatsApp me" in a review → spam flag; scam, adult and vulgar wording → flags | `scan_text(..., review=True)` |
| Community reporting | Users report fake reviews; each user counts once | `report_review()` |
| Admin hide + account action | Hide the review; warn, suspend or **ban** (optionally hiding *all* of that user's reviews) | `resolve_report()` / `act_on_user()` (`hide_reviews` option) |
| Verification is blocked by flags | An open flag on the listing, its offers or campaigns, or the owner's account (the review-burst flag targets the business), or an open or upheld report about the business, stops automatic verification. The business is referred to an admin instead. | `has_record_problem()` and `refresh()` in `backend/app/services/verification_service.py` |
| Bayesian ranking | A handful of fake 5★ reviews barely moves a business up the "best rated" list | `ranking_score()` |
| Verified-email reviewers listed first | Throwaway unverified accounts sink in "Most relevant" | `order_by()` |
| Audit log | Every decision is traceable | `moderation_actions` |

## 14.4 What does not prevent them

- There's no proof of a visit or purchase.
- There's no device, IP or phone verification, so multiple accounts are easy.
- The burst rule misses slow attacks and attacks from older accounts.
- There's no text-similarity check (the same review pasted on many businesses).
- There's no AI classifier yet.
- Flags **never hide** content automatically, by design (BR-18). An admin must act.

## 14.5 How to improve fake review detection (future)

1. **Verified-visit reviews:** a QR code at the shop counter, an in-app check-in near the
   business's coordinates, or a reviewer who already **chatted** with the business. Show a "Visited"
   badge and weight these reviews more.
2. **Account trust signals:** account age, verified email or phone, review history, reports
   upheld against the user, device fingerprint and IP clustering (many accounts from one device).
3. **Behavioural rules:**
   - rating deviation (always 5★ or always 1★);
   - reviews posted right after an account was created;
   - many reviews for one owner's businesses.
4. **Text similarity:** compare new reviews with recent ones using embeddings (cosine similarity);
   flag near-duplicates.
5. **An AI classifier (planned for 100%):** Claude through the `anthropic` SDK, with structured
   output, behind the same interface as the rules. It would be measured against admins' past
   decisions (precision and recall) and would never remove anything on its own
   (`docs/development_roadmap/module8_admin_moderation_plan.md`).
6. **The Trust Score** (SDD Screen 3, open decision 7): combine verification, account age, upheld
   reports, review signals and chat response rate.

---

# Part 15: Chat and Messaging

Module 9 covers SRS FR-23–FR-25, UC-13 and UC-14. It was built by Nouman (PR #15).

- Reference documents: `docs/development_roadmap/module9_chat_and_push_plan.md` and
  `module9_how_it_works.md`.
- Backend: `backend/app/api/chat.py`, `backend/app/services/chat_service.py` and
  `backend/app/services/realtime.py`.
- App: `lib/features/chat/` and `lib/core/realtime/realtime_service.dart`.

## 15.1 What the chat does

- A **customer** opens a business page and taps **Message**. A one-to-one conversation with that
  business opens.
- The **business owner** sees it in the Chat tab and replies on the business's behalf.
- The other side sees the message **instantly** if they have the app open. Otherwise they get a
  **push notification**.
- Extras:
  - **"Seen"** read receipts and **"typing…"**;
  - **photo messages**;
  - suggested replies;
  - the business's live offers inside the chat (tap one to ask about it);
  - quick actions (Call, Directions, View business);
  - **report** and **block**;
  - an unread **badge** on the Chat tab.

## 15.2 What is a WebSocket?

### The simple explanation

A WebSocket is a long-lived connection between the app and the server. With normal REST, the app
asks the server for something and gets an answer, and then the conversation is over. With a
WebSocket, the line stays open, so **either side can send data whenever it needs to**. In Khojlo,
this lets the server immediately tell the recipient "you have a new message" without the app
asking every few seconds.

### The technical explanation

The WebSocket protocol (RFC 6455) starts as an HTTP request with an `Upgrade: websocket` header.
The server answers `101 Switching Protocols`, and the same TCP connection then carries
**full-duplex** message frames in both directions until either side closes it with a close code.
`ws://` is plain; `wss://` is encrypted with TLS, like HTTPS.

### REST vs WebSocket

| | REST (HTTP) | WebSocket |
|---|---|---|
| Who starts a message | Only the client | Both sides |
| Connection | New request each time | One connection that stays open |
| Good for | Reading and **changing** data, with clear status codes (201, 403, 422 …) and easy testing | **Announcing** events instantly (new message, read, typing) |
| In Khojlo | Opening a conversation, **sending** messages, history, marking read, reporting, blocking | `message.new`, `conversation.read`, `typing`, `ping`/`pong` |

### Why Khojlo uses it, and why it *also* uses REST

- Without a socket, the app would have to **poll** ("anything new?") every few seconds. That's
  slower, wastes battery and data, and loads the server. SRS PER-6 asks for delivery under
  2 seconds; the measured time on a local server was about 20 ms.
- **Messages are still sent over REST**, not over the socket. That gives:
  - validation with clear errors;
  - a database write before any delivery;
  - safe retries using `client_id`;
  - a design where the socket is only an "announcer". If it's down, nothing is lost, and the app
    falls back to polling.

## 15.3 The data model

```text
conversations                                   messages
├─ id                                           ├─ id
├─ customer_id      → users.id                  ├─ conversation_id → conversations.id
├─ business_id      → businesses.id             ├─ sender_id       → users.id
├─ UNIQUE (customer_id, business_id)            ├─ from_business   (True = the owner sent it)
├─ created_at                                   ├─ body            (≤ 2,000 chars; may be "" with a photo)
├─ last_message_at  (NULL until first message)  ├─ media_id        → media.id (optional photo)
├─ customer_last_read_id   ← "read markers"     ├─ client_id       (app's id for this send)
├─ business_last_read_id                        ├─ UNIQUE (conversation_id, client_id)
├─ blocked_by ("customer"/"business"), blocked_at └─ created_at
└─ closed_at   (closed by a moderator)
conversation_reports: conversation_id, reporter_id (UNIQUE pair), reason, note, status …
```

**Why read markers instead of an `is_read` flag per message?** Each conversation stores two
numbers: the newest message id the customer has read, and the newest the business has read.

- **Unread for me** = messages from the other side with `id > my_last_read_id`.
- **"Seen"** = my messages with `id ≤ their_last_read_id`.

Marking a conversation read is **one UPDATE** instead of updating many message rows. Sending a
message also moves your own marker, because you've obviously seen the conversation.

## 15.4 How conversations are created, and who can start one

- **Only customers start conversations** (a design decision). Owners reply in conversations
  customers opened, which stops owners cold-messaging people.
- `POST /api/v1/conversations {"business_id": 7}` → `open_conversation()`:
  - the business must exist and be published (else 404);
  - you can't message **your own** business (403 "This is your business…", BR-16);
  - it returns the existing conversation, or creates one. **One per customer and business.**
    Tapping Message again reopens the same conversation.
  - If two "open" requests race, the unique constraint fires (`IntegrityError`) and the code reuses
    the conversation the other request created.
- A new, empty conversation **isn't listed** until its first message (`last_message_at IS NOT
  NULL`).

## 15.5 How users are identified

- **REST calls:** the JWT access token → `get_current_user()` → the `User`.
- **In a conversation**, `side_of(conversation, user)` (`chat_service.py`) decides the role:
  - `"customer"` if `conversation.customer_id == user.id`;
  - `"business"` if the user owns the conversation's business;
  - otherwise `None` → **404 "Conversation not found"**. Outsiders can't even tell whether the
    conversation exists (BR-15, SEC-5).
- **WebSocket:** the first message carries the access token (15.9).

## 15.6 The message schema (what the API returns)

`MessageOut` (built by `message_out()` in `chat_service.py`):

```json
{
  "id": 1532,
  "conversation_id": 12,
  "body": "Do you deliver to G-9?",
  "photo": null,
  "from_business": false,
  "is_mine": true,
  "created_at": "2026-10-05T14:03:11.204Z",
  "client_id": "9f2c41aa07be13d5"
}
```

- **Sender:** `sender_id` is stored. The API exposes `from_business` and `is_mine` (computed for
  the viewer's side).
- **Receiver:** implicit. It's the other participant of the conversation (`other_user_id()`).
- **Status in the app:** `SendStatus { sending, sent, failed }` (`lib/core/models/chat.dart`),
  shown as "Sending…", nothing (sent), "Seen" or "Not sent · Tap to retry".
- **Timestamps:** `created_at` in UTC. The app shows "Yesterday", "Mon 22 Sep" and so on.

## 15.7 Sending a message: the core flow

**On the sender's device** (`ConversationController.send()` in
`lib/features/chat/chat_providers.dart`):

1. The text is trimmed, and empty text is ignored.
2. A **pending** message is added to the screen immediately ("Sending…"). It has a **negative**
   temporary id and a random 16-hex `client_id`. This is *optimistic UI*.
3. `ChatRepository.send()` → `POST /api/v1/conversations/12/messages {"body": "...",
   "client_id": "..."}` (a photo is first uploaded with `POST /media`, and its key is sent as
   `photo`).
4. After the first message ever, the app offers to turn on notifications
   (`maybeAskAfterFirstMessage()`).

**On the server** (`send_message()` in `backend/app/api/chat.py`, SDD Algorithm 8):

1. **Participant?** `_participant()` → else 404.
2. **Can you send?** `send_problem()` → 403 if the conversation is **blocked** or **closed by a
   moderator**.
3. **Seen this send before?** If a message with the same `client_id` exists in this conversation,
   it's returned as is. **Retries never duplicate.**
4. **Validate:**
   - body ≤ 2,000 characters (Pydantic);
   - an empty body is allowed only with a photo ("Write a message first." → 422);
   - the photo must be the sender's own upload.
5. **Store:** INSERT the message, flushing to catch a concurrent duplicate `client_id`. Set
   `conversation.last_message_at`, and move the **sender's** read marker to this message.
6. **Module 8:** `check_mass_messaging()` flags a customer who sends the same text to 5+
   businesses within an hour. Only the pattern is checked; private text isn't scanned for content.
7. **Push or not?** If `manager.is_online(recipient_id)` is **false**, prepare a push with
   `notify(kind="message", store=False)`. It's titled with the sender's name ("Ali R.") or the
   business name.
8. **COMMIT**, then answer **201** with the saved message.
9. **Background tasks, after the response:**
   - `manager.publish(...)` sends `message.new` to **both** participants, each with their own view
     (`is_mine`, their unread total).
   - The push job is handed to Firebase, if one was prepared.

**Back on the sender's device:** the saved message replaces the pending one (matched by
`client_id`). If the WebSocket echo arrived first, `_add()` removes the duplicate. The
conversation moves to the top of the Chat tab (`ConversationsController.sent()`).

## 15.8 Receiving a message

- **The recipient has the app open** (socket connected):
  - `RealtimeService` emits `message.new`.
  - `ConversationsController` updates the list and the **badge**.
  - If that conversation is on screen, `ConversationController` adds the message, clears
    "typing…", and calls **mark read** immediately. That sends "Seen" back.
- **The recipient's app is in the background or closed:** the socket was closed by
  `SessionServices` (lifecycle `paused` / `hidden` / `detached`), so the server sees them offline
  and sends a **push**. Opening the app reloads everything from the database.

## 15.9 The WebSocket's life

`realtime()` in `backend/app/api/chat.py` and `RealtimeService` in
`lib/core/realtime/realtime_service.dart`:

```text
App (signed in, foreground)                         Server  /api/v1/ws
  connect ws://localhost:8000/api/v1/ws ─────────►  accept()
  {"type":"auth","token":"<access JWT>"} ────────►  must arrive within 10 s (AUTH_TIMEOUT)
                                                    _authenticate(): decode, type=="access",
                                                    user exists, not suspended/banned
                                     ◄────────────  close(4401)  if anything is wrong
                                     ◄────────────  {"type":"ready"}   manager.add(user_id, socket)
  every 25 s: {"type":"ping"} ───────────────────►
                                     ◄────────────  {"type":"pong"}
  while typing (≤ 1 per 3 s):
  {"type":"typing","conversation_id":12} ────────►  participant check → forward to the other side
                                     ◄────────────  events: message.new / conversation.read / typing
  app goes to background → close ───────────────►  finally: manager.remove(user_id, socket)
```

- **Why is the token not in the URL?** Servers and proxies write URLs into access logs, so a token
  in `?token=…` would leak into logs. The Module 9 live test confirmed no token appears in the
  server log.
- **Reconnects:** after an unexpected drop, the app retries after 1, 2, 4, 8, 16, then 30 seconds
  (exponential backoff, capped).
- **4401** (usually an expired 30-minute access token): the app refreshes the session once
  (`GET /users/me` through `ApiClient`, which refreshes on a 401) and reconnects. If that fails,
  it stops.
- **Several devices:** `ConnectionManager` keeps a **set** of sockets per user, so a phone and a
  browser both get events.
- **The server's view of "online"** is simply "has at least one open socket"
  (`manager.is_online()`).

## 15.10 Event reference

```json
{"type": "message.new", "conversation_id": 12,
 "message": { …MessageOut, with is_mine for THIS user… },
 "conversation": { …ConversationSummary: business, customer, last_message, unread_count… },
 "unread_total": 3}

{"type": "conversation.read", "conversation_id": 12, "side": "business",
 "last_read_id": 1532}                       // the other side read up to 1532 → show "Seen"

{"type": "typing", "conversation_id": 12, "side": "customer"}   // show "typing…" for 4 s
{"type": "ready"}   {"type": "pong"}
```

## 15.11 Read, unread and "Seen"

- **Opening a conversation**, or receiving a message in an open one, calls
  `POST /conversations/{id}/read`. `mark_read()` moves my marker to the newest message id. If it
  changed, it publishes `conversation.read`:
  - to the **other side**, which shows "Seen";
  - to **my other devices**, whose badges clear.
- **The unread total** for the Chat tab badge comes from `GET /conversations/unread`, and is kept
  live by the `unread_total` in each event.

## 15.12 Retrieval and pagination

`GET /conversations/{id}/messages`:

| Mode | Query | SQL idea | Used when |
|---|---|---|---|
| Latest page | `limit=30` | newest 31 by id DESC, keep 30, reverse | Opening the chat |
| Older | `before_id=…` | `id < before_id` | Scrolling up (`loadOlder()`) |
| Catch-up | `after_id=…` (limit up to 100) | `id > after_id` ASC | After reconnecting, while polling, or on resume (`catchUp()`) |

This is **keyset pagination** (by id). It doesn't skip or repeat messages when new ones arrive
during paging. The conversation list is paged with `limit` / `offset` (default 50), newest first.

## 15.13 Offline behaviour (REL-5)

| Situation | What happens |
|---|---|
| **Recipient offline** | The message is already **saved in PostgreSQL**. They get a push (if Firebase is configured and they allowed notifications). The next time they open the app, the list and history load from the database. |
| **Sender has no internet** | The REST call fails → the bubble shows **"Not sent · Tap to retry"**. Retrying reuses the same `client_id`, so a send that actually reached the server isn't duplicated. |
| **Socket down but REST works** (Wi-Fi blip, server restart) | The open conversation **polls every 8 seconds** (`catchUp()`), and the socket keeps reconnecting with backoff. When it's back online, polling stops and a final catch-up runs. |
| **App returns to the foreground** | `SessionServices` reconnects, refreshes the notification count and bumps `appResumedProvider`, so screens catch up. |
| **The app is never fully offline-capable** | There's no local message cache (SRS CO-9: no offline operation). |

## 15.14 Blocking, closing and reporting (Module 8 hooks)

- **Block** (`POST /conversations/{id}/block`):
  - either participant can block;
  - **nobody can send** until the blocker unblocks (`DELETE …/block`, blocker only, FR-28);
  - the composer is replaced by a notice;
  - typing indicators stop.
- **Closed by a moderator** (`closed_at`): still readable, but no new messages.
- **Report** (`POST /conversations/{id}/report`: spam, harassment, scam or other, plus an
  optional note):
  - once per user (409 on a repeat);
  - it **shares the conversation with Khojlo's moderators**, the one exception to "only
    participants can read" (v1.2, BR-15, SEC-5);
  - the other person isn't told who reported it.

## 15.15 The message flow diagram

```text
User A (customer, phone)
  │ types "Do you deliver to G-9?" → ConversationController.send()  [pending bubble]
  ▼
Flutter  ── REST POST /api/v1/conversations/12/messages {body, client_id} ──►
  ▼
FastAPI send_message()
  ├─ participant? not blocked? not a duplicate? valid?
  ├─ INSERT messages · UPDATE conversations (last_message_at, A's read marker)
  ├─ is User B online?  (ConnectionManager in memory)
  │     no  → notify(kind=message, store=False) → PushJob prepared
  ├─ COMMIT  → PostgreSQL  (message is now durable)
  ├─ 201 + MessageOut ───────────────────────────────────────► User A: bubble becomes "sent"
  └─ background tasks:
        ├─ WebSocket "message.new" ─► User A's other devices
        ├─ WebSocket "message.new" ─► User B (if online) → bubble appears + badge → B's app
        │                                calls POST …/read → "conversation.read" ─► User A: "Seen"
        └─ PushJob → FCM HTTP v1 → Firebase ─► User B's phone/browser (if offline)
                                                └─ tap → app opens /conversations/12
```

## 15.16 Chat limitations

- **Single server process:** the online-socket registry is in memory. With several workers or
  servers, a socket on worker A wouldn't receive events published on worker B. Fix: a shared
  pub/sub channel (Redis, or PostgreSQL `LISTEN/NOTIFY`, which the code's docstring suggests).
- **No per-message "delivered" ticks**, only "Seen". You can't edit or delete messages, and there
  are no group chats.
- **Not end-to-end encrypted:** messages are readable by whoever administers the database.
  Moderators can read a conversation only after a report.
- **iOS:** no push (CO-11). The socket works while the app is open.

---

# Part 16: Push Notifications

## 16.1 What is FCM?

**Simple explanation.** Firebase Cloud Messaging (FCM) is Google's free "post office" for
notifications. Our server can't knock on your phone directly: phones change networks, sleep, and
block incoming connections. So our server gives the message to FCM with the phone's **address**
(the device token), and FCM delivers it through the connection the phone already keeps open to
Google.

**Technical explanation.** FCM is a cross-platform push service. On Android it delivers through
Google Play services' persistent connection. On the web it uses the browser's **Web Push** protocol
(a service worker + a VAPID key). Servers send to FCM's **HTTP v1 API**
(`https://fcm.googleapis.com/v1/projects/<project-id>/messages:send`), authenticated with a
short-lived **OAuth 2.0 access token** obtained from a **service account**.

**Why Khojlo uses it:** free, Android and web from one API, and it's the standard (SRS OE-10,
CO-11). Push works even when the app is closed, which a WebSocket can't do.

## 16.2 The device token

| Question | Answer in Khojlo |
|---|---|
| What is it? | A long random string that identifies **this app on this device** (or this browser profile) for FCM. Think of it as the device's postal address. |
| Where is it generated? | **On the device**, by the Firebase SDK: `FirebaseMessaging.instance.getToken(vapidKey: …)` in `FirebasePushPlatform.token()` (`lib/core/push/push_platform.dart`). The web also needs `FIREBASE_WEB_VAPID_KEY`. |
| When does the app get it? | After permission is **granted**: from the "Turn on notifications" card (`PushController.enable()`), once after your first chat message, or on sign-in if permission was already granted (`onSignedIn()`). |
| Where is it stored? | On our server in **`device_tokens`** (`user_id`, `token` UNIQUE, `platform` android/web, `created_at`, `last_seen_at`), via `PUT /api/v1/notifications/devices`. |
| When does it change? | When Firebase rotates it, the app is reinstalled or its data is cleared, or the browser's site data is cleared. The app listens to `onTokenRefresh` and re-registers automatically. |
| Shared devices | If a token already belongs to another user, `register_device()` **moves** it to the current user, so the previous person stops getting notifications on that device. |
| On logout | `PushController.unregister()` → `POST /notifications/devices/unregister`, then `deleteToken()` on the device. |
| Dead tokens | If FCM answers 404 / `UNREGISTERED`, 403 `SENDER_ID_MISMATCH`, or 400 "invalid registration token", `PushJob` **deletes** that token from `device_tokens`. |

## 16.3 How the backend sends a push

```text
An event happens (e.g. a customer writes a review)
   ↓ the endpoint calls notification_service.notify(db, recipients, kind, title, body, route)
       1. wants(): drop recipients who switched this kind OFF (users.notification_prefs)
          (account & verification notices can't be switched off)
       2. INSERT a row per recipient into notifications (the bell list) — except kind "message"
       3. SELECT their device tokens
       4. return PushJob(tokens, PushMessage(title, body, data={route, kind}, tag))
   ↓ the endpoint COMMITs, then BackgroundTasks.add_task(job)   (the response doesn't wait)
   ↓ PushJob() → push.get_sender()
        FcmSender  (if GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_* are set and load correctly)
        NullSender (otherwise: logs "Push notifications are off…" once, sends nothing)
   ↓ FcmSender.send(tokens, message)
        • credentials.refresh() → OAuth access token (scope firebase.messaging), cached until expiry
        • for each token: POST https://fcm.googleapis.com/v1/projects/khojlo-c5ba0/messages:send
        • 200 → counted as sent; invalid-token errors → returned as `invalid`
   ↓ PushJob deletes the invalid tokens in its own DB session
```

The payload Khojlo sends (`FcmSender.payload()`):

```json
{
  "message": {
    "token": "<device token>",
    "notification": {"title": "Brew & Bloom", "body": "Yes, we deliver to G-9 🙂"},
    "data": {"route": "/conversations/12", "kind": "message"},
    "android": {"priority": "HIGH",
                "notification": {"color": "#1D6D5A", "tag": "conversation-12"}},
    "webpush": {"headers": {"Urgency": "high"}}
  }
}
```

- **`route`** tells the app which screen to open when the notification is tapped.
- **`tag`** makes a newer notification for the same conversation **replace** the older one.

## 16.4 What triggers a push

| Event | Code | Who is told | In the bell list? | Setting |
|---|---|---|---|---|
| New chat message | `send_message()` (`api/chat.py`) | The other participant, **only if they have no open socket** | No (the Chat tab is their list) | `messages` |
| New review | `create_review()` (`api/reviews.py`) | The business owner | Yes | `reviews` |
| Owner replies to a review | `reply()` (**first** reply only) | The reviewer | Yes | `reviews` |
| An offer goes live | `promotion_service.offer_notice()` | People who **saved** the business | Yes | `offers` |
| A campaign goes live (owner opted in) | `campaign_notice()` | People who saved the business | Yes | `offers` |
| New published business | `create_business()` (`api/businesses.py`) | Users whose **interests** include its category | Yes | `new_places` |
| Trending digest | `python -m app.jobs.trending_digest` | Each user with interests: the most-viewed business in their categories over 7 days, at most once per 20 hours | Yes | `trending` |
| Admin decisions (Module 8) | `moderation_service`, `verification_service` | Owners (verification), authors (removals, warnings, suspensions), reporters (outcomes) | Yes | **Always on** (`account`, `verification`) |

Scheduled offers and campaigns are announced when they start, either by `python -m
app.jobs.promotions` (cron) or **the next time anyone opens Home** (`due_notices()` in
`get_feed()`). There's no built-in scheduler.

## 16.5 What happens on the device

| State | Android | Web (Chrome) |
|---|---|---|
| **App open** (foreground) | Android doesn't show it in the status bar. `FirebaseMessaging.onMessage` → `PushController._onForeground()` → an **in-app banner** with an **Open** button (`showInAppBanner()` in `lib/core/ui/messenger.dart`), and the bell count refreshes. | The service worker (`web/firebase-messaging-sw.js`) shows a **system notification** even while the tab is open (it handles every push itself). |
| **Background** | Android shows it in the status bar with the white Khojlo star icon (`frontend/android/app/src/main/res/drawable/ic_stat_khojlo.xml`) in emerald (`notification_accent`). | The browser wakes the service worker, which calls `showNotification(title, {body, icon, tag: route, data: {route}})`. |
| **Closed / terminated** | Same as background (Google Play services delivers it). | Works if the **browser** is running (the tab may be closed). Needs `localhost` or HTTPS, and not incognito. |

## 16.6 What happens when a notification is tapped

- **Android, app in the background:** `FirebaseMessaging.onMessageOpenedApp` emits the message →
  `PushPlatform.openedRoutes` → `PushController._open(route)` → `routerProvider.push(route)`, for
  example `/conversations/12` or `/business/5/reviews`.
- **Android, app was closed:** on start, `getInitialMessage()` gives the launch route →
  `PushController.onSignedIn()` → `launchRoute()` → opens it after sign-in is restored.
- **Web:** the service worker's `notificationclick`:
  - If a Khojlo tab is open, it **focuses** it and `postMessage({type: "khojlo-open", route})`
    → `lib/core/push/sw_messages_web.dart` → the app navigates.
  - Otherwise it **opens a new tab** at `/#<route>` (the app uses hash URLs).

## 16.7 Settings (BR-14)

`GET` / `PUT /notifications/preferences` with five switches: `messages`, `reviews`, `offers`,
`new_places`, `trending`. They're stored as JSON in `users.notification_prefs`; **missing keys mean
"on"**. The screen is `notification_settings_screen.dart`, also reachable from Profile. The server
checks them in `wants()` before every notification.

## 16.8 Without Firebase keys

- **Backend:** without `backend/secrets/firebase-service-account.json` (or the three `FIREBASE_*`
  values), `get_sender()` returns `NullSender`. Push is off; chat and everything else still work.
- **App:** `initFirebase()` returns `false` when it isn't configured or fails within 8 seconds.
  - On the web, the `FIREBASE_*` defines must be real values (placeholders that start with
    `your-` are ignored).
  - Then `firebaseReadyProvider = false`, the push UI hides, and nothing else changes.
- **iOS:** `initFirebase()` returns `false` on purpose (CO-11).

## 16.9 The full flow

```text
Message sent / review written / offer goes live …
   ↓
Backend endpoint → notification_service.notify() → (settings filter, bell-list rows, tokens)
   ↓  COMMIT, then background task
FcmSender (service account → OAuth token)
   ↓  HTTPS POST per device token
Firebase Cloud Messaging (Google)
   ↓  Android: Google Play services connection · Web: Web Push → service worker
User's device
   ↓
Notification shown (status bar / system pop-up)  — or an in-app banner if the Android app is open
   ↓ tap
App opens data.route (e.g. /conversations/12)
```

## 16.10 Limitations

- iOS push is out of scope.
- The web needs HTTPS or localhost, and doesn't work in incognito.
- The trending digest isn't scheduled.
- Pushes are sent **one HTTP request per token**, sequentially. That's fine for a demo, but slow for
  thousands of users (Part 36).
- There's no delivery analytics.
- Real FCM delivery isn't covered by automated tests: the tests replace Firebase with a recording
  fake (`RecordingSender`), and FCM's own payload and error handling are unit-tested with a fake
  HTTP session (`backend/tests/test_push_sender.py`).

---

# Part 17: Firebase Files

## 17.1 The files at a glance

| File | Used by | Purpose | Contains | Secret? | Commit? |
|---|---|---|---|---|---|
| `backend/secrets/firebase-service-account.json` | **Backend** (`FcmSender`) | Lets the server **send** pushes as the Firebase project | `type: service_account`, `project_id` (khojlo-c5ba0), `client_email`, **`private_key`**, `private_key_id`, token URIs | **YES, the most sensitive file** | **No** (git-ignored: `secrets/`, `**/*-service-account*.json`) |
| `frontend/android/app/google-services.json` | **Android build** (the `com.google.gms.google-services` Gradle plugin) | The Android app's Firebase identity, and the Google Sign-In OAuth clients | `project_info` (project number, project id, storage bucket), the client for package `com.khojlo.khojlo`, OAuth clients (type 1 Android, type 3 Web), an Android API key | **No.** It ships inside every APK by design | **Yes** (committed on purpose) |
| `backend/.env` | **Backend** (pydantic-settings) | All server settings | `DATABASE_URL` (with the DB password), `SECRET_KEY`, SMTP password, `OPENROUTESERVICE_API_KEY`, `GOOGLE_APPLICATION_CREDENTIALS` (a **path** to the service account file), … | **YES** | **No** |
| `backend/.env.example` | Developers | Template for `.env` | Keys with placeholders and safe defaults | No | **Yes** |
| `frontend/dart_defines.json` | **Flutter build** (`--dart-define-from-file`) and the Android Gradle build (Maps key) | Build-time settings | `KHOJLO_API`, `GOOGLE_WEB_CLIENT_ID`, `MAP_PROVIDER`, `MAPS_API_KEY_WEB/ANDROID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_WEB_VAPID_KEY` | **Not really**: browsers receive these values anyway. Kept out of git so keys are handled one way. | **No** (git-ignored) |
| `frontend/dart_defines.example.json` | Developers | Template for `dart_defines.json` | Placeholders (`your-web-api-key` …), `MAP_PROVIDER: maplibre`, the public Google web client ID | No | **Yes** |
| `frontend/web/firebase-messaging-sw.js` | **Browser** | Shows web pushes and handles clicks | JavaScript only. **No Firebase config inside.** | No | Yes |

The brief calls the template `dart_defines.example`; the real file name is
`dart_defines.example.json`.

## 17.2 Which file belongs where

- **Backend:** `firebase-service-account.json`, `.env`, `.env.example`.
- **Android:** `google-services.json`. Android does **not** read `dart_defines.json` for Firebase,
  only for the optional Google Maps key.
- **Flutter build configuration:** `dart_defines.json` and `dart_defines.example.json`. The
  `FIREBASE_*` values are used **only on the web**.
- **Credentials:** the service account file (a private key) and `.env` (DB password,
  `SECRET_KEY`, SMTP password, the ORS key).
- **API configuration:** `.env` (backend URLs and keys), and `dart_defines.json` (`KHOJLO_API`, map
  provider and keys).
- **Ignored by git:** `.env`, `secrets/`, `dart_defines.json`.
- **Safely represented by example files:** `.env.example` and `dart_defines.example.json`.

## 17.3 Things that are *not* in this project

- **No `firebase_options.dart`.** The FlutterFire CLI wasn't used. Web options are built from
  `dart_defines.json` in `FirebaseWebConfig` (`lib/core/push/firebase_setup.dart`).
- **No `GoogleService-Info.plist`** (iOS isn't configured for Firebase).
- **No `firebase.json`** and no Firebase Hosting.
- **No `firebase-admin`** package in `requirements.txt`.

## 17.4 A common confusion

> "Is `google-services.json` the Firebase service account?"
> **No.** `google-services.json` is a **public client configuration** that identifies the *app*
> to Firebase and Google, and it can't send anything. The **service account** JSON contains a
> **private key** that lets a *server* act as the project, for example to send pushes to all
> users. The first is committed; the second must never be.

---

# Part 18: Environment Variables

## 18.1 What they are

**In simple terms.** An environment variable is a named setting that lives *outside* the code, such
as `DATABASE_URL=...`. The same code can then run on a laptop, on a teammate's machine or on a
server, each with its own database and keys, and **secrets never go into git**.

**In Khojlo:**

- **Backend:** `backend/app/core/config.py` defines a `Settings` class (pydantic-settings). Each
  field is read from a real environment variable or from **`backend/.env`**. If neither has it, the
  default in the code is used.
- **App:** settings are compiled in at **build time** with
  `flutter run --dart-define-from-file=dart_defines.json`, and read with
  `String.fromEnvironment('NAME')`.

The brief mentions names like `JWT_SECRET`, `GOOGLE_MAPS_API_KEY` and `API_URL`. **Those exact
names don't exist in Khojlo.** The real equivalents are `SECRET_KEY`, `MAPS_API_KEY_WEB` /
`MAPS_API_KEY_ANDROID` / `GOOGLE_MAPS_SERVER_KEY`, and `KHOJLO_API`.

## 18.2 Backend variables (`backend/.env`)

| Variable | Used by | Purpose | Secret? | Required? | Default in code |
|---|---|---|---|---|---|
| `DATABASE_URL` | `core/database.py`, `alembic/env.py` | PostgreSQL connection string (driver, user, password, host, port, db) | **Yes** (password) | Yes in practice | `postgresql+psycopg2://khojlo:khojlo@localhost:5432/khojlo` |
| `SCHEMA_CHECK_ON_STARTUP` | `main.py` lifespan | Warn at startup if migrations are missing | No | No | `True` |
| `SECRET_KEY` | `core/security.py`, `services/otp_service.py` | Signs and verifies JWTs; HMAC for OTP codes | **Yes** | **Yes** | `change-me-to-a-long-random-string` (unsafe) |
| `ALGORITHM` | `core/security.py` | JWT algorithm | No | No | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `core/security.py` | Access token lifetime | No | No | `30` |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `core/security.py` | Refresh token lifetime | No | No | `14` |
| `BACKEND_CORS_ORIGINS` | `main.py` | Browser origins allowed to call the API (comma-separated) | No | No | `http://localhost:3000,…:8080,…:5000` |
| `GOOGLE_WEB_CLIENT_ID` | `verify_google_id_token()` | The audience Google ID tokens must have | No (public id) | For Google login | `None` → Google login always fails with 401 |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_EMAIL`, `SMTP_FROM_NAME`, `SMTP_USE_TLS` | `services/email_service.py` | Send codes and account emails (the team uses a Gmail app password, per `docs/team_setup.md`) | **`SMTP_PASSWORD` yes** | For real emails | Empty host → no emails (a warning is logged) |
| `OTP_EXPIRE_MINUTES`, `OTP_RESEND_COOLDOWN_SECONDS`, `OTP_MAX_PER_DAY`, `OTP_MAX_ATTEMPTS` | `otp_service.py` | One-time code rules | No | No | 10, 45, 5, 5 |
| `PASSWORD_RESET_TOKEN_EXPIRE_MINUTES` | `core/security.py` | Reset token lifetime | No | No | 10 |
| `BUSINESS_TIMEZONE` | `services/hours.py`, feed greeting | "Open now" and local dates | No | No | `Asia/Karachi` |
| `NEW_BUSINESS_DAYS` | `business_service.is_new_business()` | How long the "New" badge and ranking boost last | No | No | 30 |
| `SEARCH_MAX_RADIUS_KM` | search criteria | Maximum distance filter | No | No | 50 |
| `GEOCODING_PROVIDER` | `services/geocoding.py` | `osm` (Photon + Nominatim) or `google` | No | No | `osm` |
| `GEOCODING_USER_AGENT` | `OsmGeocoder` | The identifying User-Agent that OSM services require | No | No | `Khojlo/1.0 (local business discovery app)` |
| `PHOTON_URL`, `NOMINATIM_URL` | `OsmGeocoder` | Point at self-hosted instances if needed | No | No | public servers |
| `GOOGLE_MAPS_SERVER_KEY` | `GoogleGeocoder` | Google Geocoding API (only with `GEOCODING_PROVIDER=google`) | **Yes** | Only in Google mode | `None` → `/geo/*` returns 503 in Google mode |
| `GEOCODING_REGION`, `GEOCODING_LANGUAGE` | geocoders | Keep results in Pakistan; English text | No | No | `pk`, `en` |
| `OPENROUTESERVICE_API_KEY` | `services/routing.py` | Route previews | **Yes** | For route lines | `None` → `/geo/route` returns 503 and the app shows the straight-line distance |
| `OPENROUTESERVICE_URL` | `OrsRouter` | ORS base URL | No | No | `https://api.openrouteservice.org` |
| `GOOGLE_APPLICATION_CREDENTIALS` | `services/push.py` | **Path** to the Firebase service account JSON | The path isn't secret; the file is | For push | `None` |
| `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` | `services/push.py` | Alternative to the file: the three fields inline | **`FIREBASE_PRIVATE_KEY` yes** | Alternative for push | `None` |

`PROJECT_NAME` and `API_V1_PREFIX` are also settings, but they're normally left at their defaults.

## 18.3 Frontend build-time variables (`frontend/dart_defines.json`)

| Variable | Read in | Purpose | Secret? | Required? | If missing |
|---|---|---|---|---|---|
| `KHOJLO_API` | `lib/core/network/api_config.dart` | Backend base URL, e.g. `http://127.0.0.1:8000/api/v1` | No | No | Per-platform default (`10.0.2.2:8000` on the Android emulator, `localhost:8000` elsewhere) |
| `GOOGLE_WEB_CLIENT_ID` | `lib/core/network/google_auth_config.dart` | Google Sign-In web client ID | No | No | A built-in default (the project's web client ID) |
| `MAP_PROVIDER` | `lib/core/maps/maps_config.dart` | `maplibre` or `google` | No | No | `maplibre` |
| `MAPS_API_KEY_WEB` | `maps_config.dart`, `maps_loader_web.dart` | Google Maps JavaScript API key (Google mode, web) | Restricted public key | Only for Google mode | Google mode shows the sketch map |
| `MAPS_API_KEY_ANDROID` | `android/app/build.gradle.kts` → `AndroidManifest.xml` | Google Maps SDK for Android key | Restricted public key | Only for Google mode | Same |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET` | `lib/core/push/firebase_setup.dart` | Firebase **web** app config | Not really (sent to every browser) | For web push | Web push is off (`initFirebase()` returns `false`) |
| `FIREBASE_WEB_VAPID_KEY` | `lib/core/push/push_platform.dart` | Public "Web Push certificate" key, needed for a web FCM token | No (public key) | For web push | No web token, so no web push |

## 18.4 What happens if an important variable is missing

| Missing | Effect |
|---|---|
| `DATABASE_URL` | Falls back to a local `khojlo` database on `localhost:5432`. If that doesn't exist, every DB request fails (500) and the startup schema check logs a warning. |
| `SECRET_KEY` | Falls back to the **public placeholder**. Logins still work, but anyone who reads the code could forge tokens. **Never deploy like this.** |
| `GOOGLE_WEB_CLIENT_ID` (backend) | Every Google sign-in returns 401 "Invalid Google ID token". |
| `SMTP_*` | No emails. Users can't receive verification or reset codes (the code is created but never delivered). |
| `GOOGLE_APPLICATION_CREDENTIALS` / the key file | `NullSender`: no pushes. Chat still works live. |
| `OPENROUTESERVICE_API_KEY` | No route line. The route screen shows the straight-line distance, and "Start" opens Google Maps. |
| `FIREBASE_*` / VAPID (app, web) | Web push is off; the "Turn on notifications" card doesn't appear on the web. |
| `KHOJLO_API` on a physical phone | The app tries `10.0.2.2`, which only exists on the emulator. Use `adb reverse` + `KHOJLO_API=http://127.0.0.1:8000/api/v1`. |

## 18.5 `.env` vs `.env.example`

- **`.env.example`** (committed) is the template. It holds placeholders and safe defaults, and has
  comments explaining every section. Teammates copy it: `cp .env.example .env`.
- **`.env`** (git-ignored) holds the real values. Locally it points at the team's **Supabase**
  database and has SMTP and the openrouteservice key filled in.

Inconsistencies found, comparing key names only:

1. The local `.env` **doesn't have** `GEOCODING_PROVIDER`, `GEOCODING_USER_AGENT`, `PHOTON_URL`
   and `NOMINATIM_URL`. That's harmless (the code defaults apply), but it breaks the team rule
   that `.env` and `.env.example` share the same layout.
2. `.env.example` doesn't list `SCHEMA_CHECK_ON_STARTUP` or `ALGORITHM`. They use code defaults.
3. In `.env.example`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY`
   are commented out ("Option B"). That's intentional.
4. The local `frontend/dart_defines.json` has no `MAP_PROVIDER` key (it defaults to `maplibre`)
   and leaves `KHOJLO_API` and the Google Maps keys empty. That's intentional: MapLibre is the
   default.

---

# Part 19: Maps (Google Maps and What Is Actually Used)

## 19.1 The honest headline

> **Khojlo's default map is not Google Maps.** It's **MapLibre GL** drawing **OpenStreetMap**
> vector tiles from **OpenFreeMap**, with a custom Khojlo style. Address lookup uses
> OpenStreetMap's **Photon** and **Nominatim** through our backend. Route previews use
> **openrouteservice**. Google Maps is still supported as an **option** (`MAP_PROVIDER=google`),
> and "Start in Google Maps" opens Google's navigation through a plain link that needs no key.

Why it changed (`docs/development_roadmap/module6_maps_location_plan.md`, "Map provider", October
2026): Google Maps Platform requires a **billing account**, even for free usage, and it couldn't be
set up for this iteration. The SDD's `MapService` interface meant the provider could change without
touching any screen.

## 19.2 The pieces

| Piece | Technology | Where |
|---|---|---|
| Interface (SDD §4.1) | `MapService` with `buildMap()`, `displayLocation()` (SDD Algorithm 12), `openDirections()` | `lib/core/maps/map_service.dart` |
| Default map | `MapLibreService` → `MapLibreMapView` (`maplibre_gl`) | `lib/core/maps/maplibre_map_view.dart` |
| Tiles, sprites, fonts | **OpenFreeMap** (`https://tiles.openfreemap.org/planet`); free, no key, no sign-up. The attribution "OpenFreeMap © OpenMapTiles Data from OpenStreetMap" must stay visible. | `frontend/assets/maps/khojlo_style.json` |
| Style | OpenFreeMap's "Positron" style recoloured in Khojlo's palette (no points of interest, so our pins stand out), generated by a script | `frontend/tool/build_map_style.py` |
| Optional Google map | `GoogleMapsService` → `GoogleMapView` (`google_maps_flutter`; on the web the Maps JavaScript API is loaded at runtime with the key) | `google_map_view.dart`, `maps_loader_web.dart` |
| Fallback | `SketchMapService`: a drawn map, used on desktop, without a Google key in Google mode, if MapLibre's style hasn't loaded within **20 s** (offline, no WebGL), and in tests | `sketch_map.dart` |
| Choosing one | `mapServiceProvider` | `map_service.dart` |

## 19.3 Keys and configuration

| Mode | Key needed? | Where it comes from |
|---|---|---|
| MapLibre (default) | **None** | — |
| Google, web | `MAPS_API_KEY_WEB` | `dart_defines.json` → `MapsConfig.webKey` → a `<script>` for the Maps JavaScript API |
| Google, Android | `MAPS_API_KEY_ANDROID` | `dart_defines.json` → read by `build.gradle.kts` (`JsonSlurper`) → `manifestPlaceholders["mapsApiKey"]` → `AndroidManifest.xml` `<meta-data android:name="com.google.android.geo.API_KEY">` |
| Geocoding with Google | `GOOGLE_MAPS_SERVER_KEY` (backend only) | `backend/.env` (empty locally) |
| Routes | `OPENROUTESERVICE_API_KEY` (backend only) | `backend/.env` |

- **How Flutter receives keys:** at build time, through `--dart-define-from-file`.
- **How Android receives them:** through the Gradle manifest placeholder above.
- **Restrictions** (documented in the Module 6 setup steps, for Google mode):
  - the web key is restricted to **HTTP referrers** and the Maps JavaScript API;
  - the Android key is restricted to package **`com.khojlo.khojlo` + the debug SHA-1** and the Maps
    SDK for Android;
  - the server key is restricted to the **Geocoding API**.
- Whether these Google keys currently exist in Google Cloud is **not confirmed from the codebase**:
  the local values are empty.

## 19.4 Features Khojlo uses

| Feature | How | Files |
|---|---|---|
| **Map tab** | A map card with a floating preview card for the tapped pin, a nearby carousel synced with the pins, a filter button that reuses the Explore filters, a locate-me button, and a List \| Map switch | `lib/features/maps/presentation/map_screen.dart`, `view_toggle.dart` |
| **Markers** | Pins are a **GeoJSON source** drawn by one **symbol layer**, with icons painted in code: gold, emerald when selected, plum while pinning, and a blue "you" dot | `maplibre_map_view.dart`, `pin_icons.dart` |
| **Coordinates** | `businesses.latitude` / `longitude` (floats). **BR-7**: in range, both or neither, and never (0, 0) | `backend/app/schemas/business.py`, `update_business()` |
| **Map-area search** | When the map stops moving (300 ms debounce), `GET /search?north=&south=&east=&west=&limit=100` plus the same keyword and filters as Explore. It shows "Showing 100 of N · zoom in" when capped. If nothing matches in view, it searches everywhere and **moves to the nearest matches**. Rotation and tilt are off, because area search assumes a north-up rectangle. | `map_providers.dart` (`MapResultsNotifier`), `AreaSearch` in `strategies.py` |
| **Location selection** | The pin picker: drag the map under a fixed pin, or "Use my current location", or search a typed address. The address fills from the pin. | `location_picker_screen.dart` |
| **Geocoding** | **Reverse** (address at a pin; the Home "Near F-7 Markaz, Islamabad") via `GET /geo/reverse` → Nominatim. **Forward** (typed address) via `GET /geo/search` → Photon, limited to Pakistan and ranked near the map centre. | `lib/core/maps/geo_repository.dart`, `backend/app/services/geocoding.py` |
| **Places API** | **Not used** (no Google Places). Business data is Khojlo's own. | — |
| **Business page map** | `displayLocation()`: a small, still map with the pin. Tapping it opens the Map tab centred on the business. "Location unavailable" if there's no pin (the UC-9 exception). | `business_detail_screen.dart` |
| **Route preview** | `showRoute()` → `RouteScreen`: an emerald route line, a Car / Walk switch, "~11 min · 4.3 km", **Start in Google Maps** | `route_screen.dart`, `GET /geo/route` |
| **Directions** | `openDirections()` opens `https://www.google.com/maps/dir/?api=1&destination=lat,lng&travelmode=…` in the Google Maps app or website. **No key needed.** | `map_service.dart` |
| **User location** | `geolocator`, with an explanation sheet before the permission prompt. **Never sent for storage**; it's only used per request (SEC-7). | `lib/core/location/location_service.dart`, `location_rationale.dart` |

## 19.5 The complete flows

**Map tab:**

```text
Open Map tab → MapLibreMapView loads khojlo_style.json (tiles from OpenFreeMap)
  → camera idle → MapResultsNotifier (300 ms debounce)
  → SearchRepository.search(filters, bounds, limit: 100) → GET /api/v1/search?north=…&south=…
  → backend SearchEngine with AreaSearch (+ keyword/filters) → BusinessCard list with lat/lng
  → pins GeoJSON updated → tap a pin → preview card → "View" opens /business/:id
```

**Pin picker (registration):**

```text
Drag map → pin stays centred → camera idle → GeoRepository.reverse(point)
  → GET /api/v1/geo/reverse?lat&lng  (signed in, 60 lookups / 10 min / user)
  → backend: cache hit? (24 h, ~11 m grid) → else Nominatim (≥ 1 s between calls, User-Agent)
  → PlaceOut {address, area, city, label, latitude, longitude} → fills the Address field
```

**Route:**

```text
Directions → location fix (asks with explanation if needed) → GET /api/v1/geo/route
  ?from_lat&from_lng&to_lat&to_lng&mode=car|walk (30 routes / 10 min / user)
  → backend cache (6 h, start on ~110 m grid) → else openrouteservice driving-car / foot-walking
  → RouteOut {distance_m, duration_s, points[]} → emerald line on the map
  → 503 without key / 404 no road / 502 provider error → straight-line fallback in the app
```

## 19.6 What to say if asked "Why not Google Maps?"

"The SRS planned Google Maps, and we built the SDD's `MapService` abstraction for it. Google Maps
Platform requires a billing account even within the free tier, which we couldn't set up, so we
switched the default to MapLibre with OpenStreetMap data. It's free, needs no key, and runs on
Android, iOS and web. Google Maps is still one setting away (`MAP_PROVIDER=google`). The SRS
wording needs updating to match."

---

# Part 20: Other External APIs and Services

**Service: PostgreSQL on Supabase**

- **Purpose:** the shared team database.
- **Used by:** the backend only.
- **How integrated:** a normal PostgreSQL connection (psycopg2 via SQLAlchemy) to Supabase's
  connection pooler.
- **Authentication:** the DB username and password inside `DATABASE_URL`.
- **Env var:** `DATABASE_URL`.
- **Data sent:** all SQL reads and writes.
- **Data received:** rows.

**Service: Firebase Cloud Messaging**

- **Purpose:** push notifications.
- **Used by:** the backend (sending) and the app (receiving, tokens).
- **How integrated:**
  - Backend: the HTTP v1 REST API via `requests`, with a `google-auth` OAuth token.
  - App: the `firebase_messaging` SDK, plus a service worker on the web.
- **Authentication:** the service account private key (backend); `google-services.json` and the
  web config + VAPID key (app).
- **Env vars:** `GOOGLE_APPLICATION_CREDENTIALS` (or `FIREBASE_*`); the app's `FIREBASE_*` defines.
- **Data sent:** the device token, title, body, `{route, kind}`.
- **Data received:** success, or an error code (dead tokens).

**Service: Google Sign-In / Google OAuth**

- **Purpose:** log in with Google.
- **Used by:** the app (gets an ID token) and the backend (verifies it).
- **How integrated:**
  - App: `google_sign_in` / `google_sign_in_web`.
  - Backend: `google.oauth2.id_token.verify_oauth2_token`, which downloads Google's public
    certificates.
- **Authentication:** the OAuth client IDs (public).
- **Env var:** `GOOGLE_WEB_CLIENT_ID` (backend; optional in the app).
- **Data sent:** the ID token.
- **Data received:** the claims (`sub`, `email`, `name`, `iss`, `aud`, `exp`).

**Service: SMTP email** (Gmail, per `docs/team_setup.md`; *the provider is not confirmed from code,
which only sees `SMTP_HOST`*)

- **Purpose:** verification and reset codes; suspension, ban and lift notices.
- **Used by:** the backend (`smtplib` with STARTTLS, port 587).
- **Authentication:** username + app password.
- **Env vars:** `SMTP_*`.
- **Data sent:** the recipient's email address and an HTML email with the code or notice.
- **Data received:** SMTP accept or reject.

**Service: OpenFreeMap**

- **Purpose:** vector map tiles, sprites and fonts.
- **Used by:** the app, directly.
- **How integrated:** the MapLibre style JSON references `tiles.openfreemap.org`.
- **Authentication:** none. **Env var:** none.
- **Data sent:** tile requests (they reveal roughly which area is being viewed).
- **Data received:** vector tiles.

**Service: Photon** (photon.komoot.io)

- **Purpose:** typed address search.
- **Used by:** the backend (`OsmGeocoder.search()`).
- **Authentication:** none, but an identifying **User-Agent** is required.
- **Env vars:** `PHOTON_URL`, `GEOCODING_USER_AGENT`, `GEOCODING_REGION`.
- **Data sent:** the query text and the map centre.
- **Data received:** places (GeoJSON features).

**Service: Nominatim** (nominatim.openstreetmap.org)

- **Purpose:** the address at a map point.
- **Used by:** the backend (`OsmGeocoder.reverse()`).
- **Authentication:** none, but the usage policy allows **≤ 1 request per second**, which the code
  enforces, and needs a User-Agent.
- **Env var:** `NOMINATIM_URL`.
- **Data sent:** a lat/lng (snapped to an ~11 m grid for caching).
- **Data received:** the address parts.

**Service: openrouteservice** (HeiGIT)

- **Purpose:** the route line, distance and duration.
- **Used by:** the backend (`OrsRouter`).
- **Authentication:** an API key in the `Authorization` header (free "Standard" plan: 2,000
  requests a day, 40 a minute).
- **Env vars:** `OPENROUTESERVICE_API_KEY`, `OPENROUTESERVICE_URL`.
- **Data sent:** the start and end coordinates and the mode.
- **Data received:** the route geometry, distance and duration.

**Service: Google Maps Platform** (optional)

- **Purpose:** the alternative map (Maps JavaScript API, Maps SDK for Android) and the Geocoding
  API.
- **Used by:** the app (map) and the backend (geocoding), only in Google mode.
- **Authentication:** restricted API keys.
- **Env vars:** `MAPS_API_KEY_WEB`, `MAPS_API_KEY_ANDROID`, `GOOGLE_MAPS_SERVER_KEY`.

**Service: Google Maps URL** (directions)

- **Purpose:** turn-by-turn navigation.
- **Used by:** the app (`url_launcher`).
- **Authentication:** none.
- **Data sent:** the destination coordinates.

**Service: Google Fonts**

- **Purpose:** the Fraunces, Plus Jakarta Sans and IBM Plex Mono fonts.
- **Used by:** the app (`google_fonts` package).
- **Inference:** no font files are bundled in `pubspec.yaml`, so the package downloads the fonts at
  runtime from Google's font servers and caches them.

**Device services** (OS share sheet via `share_plus`, the phone dialer via `tel:`, the camera and
gallery via `image_picker`, GPS via `geolocator`). These aren't network APIs.

**AI or analytics services: none.** No OpenAI, Anthropic, Gemini, Firebase Analytics or Crashlytics
code exists in the repository. A code search for these names finds nothing.

---

# Part 21: Docker

## 21.1 Simple definitions

- **Docker** runs software in **containers**: small isolated environments that contain an app and
  everything it needs, so it runs the same on every machine.
- **Docker Compose** describes one or more containers in a YAML file (`docker-compose.yml`), so a
  single command (`docker compose up`) starts them all.

## 21.2 Why the backend has a compose file

**To give every teammate the same local PostgreSQL in one command, without installing Postgres.**
That's all it does.

`backend/docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:16                  # official PostgreSQL 16 image
    container_name: khojlo-postgres
    restart: unless-stopped
    environment:                        # creates user/password/database "khojlo"
      POSTGRES_USER: khojlo
      POSTGRES_PASSWORD: khojlo
      POSTGRES_DB: khojlo
    ports:
      - "5432:5432"                     # host port 5432 → container port 5432
    volumes:
      - khojlo_pgdata:/var/lib/postgresql/data   # data survives container restarts
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U khojlo"]  # "is Postgres accepting connections?"
volumes:
  khojlo_pgdata:
```

| Question | Answer |
|---|---|
| Containers | **One:** `db` (PostgreSQL 16) |
| Ports | 5432 → 5432 |
| Volumes | `khojlo_pgdata` (a named volume, so data is kept when the container is recreated) |
| Environment | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (all `khojlo`). These match the default `DATABASE_URL` in `config.py` and `.env.example`. |
| Networking | The default Compose network; the API (running on the host, *not* in Docker) reaches it at `localhost:5432` |
| Is the API in Docker? | **No.** There is **no Dockerfile** in the repository. The API runs with `uvicorn` on your machine. |
| Required for local development? | **No.** It's "Option A" in the README. Option B is a local PostgreSQL install (e.g. Homebrew `postgresql@14`; the module records mention testing on PostgreSQL 14 and 16). Most of the team uses the **shared Supabase** database instead. |
| Required for deployment? | **No.** Nothing in the repo deploys with Docker (Part 37). |

## 21.3 What happens when you run `docker compose up -d`

1. Docker downloads `postgres:16` (the first time only).
2. It creates the `khojlo_pgdata` volume and the `khojlo-postgres` container.
3. Postgres initializes an empty `khojlo` database with user `khojlo`.
4. Port 5432 on your machine is forwarded into the container.
5. The healthcheck runs `pg_isready` every 5 seconds until it's healthy.
6. You then run `alembic upgrade head` (to create the tables) and `python -m app.db.seed` (demo
   data) from `backend/`.

> **Trick question:** "Does Docker deploy your application?" **No.** In Khojlo, Docker only runs
> a local database. Deploying would need a Dockerfile for the API, a host and HTTPS (Part 37).

---

# Part 22: Ports

| Service | Port | Where it's set |
|---|---|---|
| **Backend API** (uvicorn) | **8000** | uvicorn's default (`uvicorn app.main:app --reload`); the app's default URLs use `:8000` |
| **PostgreSQL** (local Docker or a local install) | **5432** | `docker-compose.yml`, the default `DATABASE_URL` |
| **PostgreSQL** (Supabase pooler) | **5432** (session pooler, from the local `.env`) | `DATABASE_URL` |
| **Flutter web dev server** (preview config) | **8090** | `.claude/launch.json` (`flutter run -d web-server --web-port 8090`) |
| **Static web build server** (preview config) | **8091** | `.claude/launch.json` (`python3 -m http.server 8091`) |
| **`flutter run -d chrome`** | **Random** each run | Flutter picks it. That's why CORS allows any `http://localhost:<port>`. |
| **Android emulator → host** | `10.0.2.2:8000` | `ApiConfig.baseUrl` |
| **Physical Android phone** | `127.0.0.1:8000` via `adb reverse tcp:8000 tcp:8000`, or the PC's Wi-Fi IP with `--host 0.0.0.0` | README |
| **SMTP** | 587 (STARTTLS) | `SMTP_PORT` |

**Why does each service need a port?** One computer runs many network programs. The IP address
finds the **computer**; the port number finds the **program** on it. The API listens on 8000 and
PostgreSQL on 5432, so requests reach the right program.

**How Flutter talks to the backend locally:**

```text
Chrome tab (http://localhost:<random>) ── HTTP ──► http://localhost:8000/api/v1/...
                                         └─ CORS: allowed by the localhost regex
Android emulator ── HTTP ──► http://10.0.2.2:8000/api/v1/...   (10.0.2.2 = the host machine)
Physical phone + adb reverse ── HTTP ──► http://127.0.0.1:8000/... → tunnelled to the PC's 8000
WebSocket: the same host/port with ws:// …/api/v1/ws
```

**What changes in production:** the API sits behind a reverse proxy on **443 (HTTPS/WSS)**. The app
is built with `KHOJLO_API=https://api.<domain>/api/v1`, so the socket automatically becomes `wss://`.
CORS lists the real web origin only, and the database isn't exposed publicly. **This isn't
implemented yet** (Part 37).

---

# Part 23: API Inventory

Everything is under the `/api/v1` prefix.

- **Count:** **98 HTTP endpoints + 1 WebSocket**, plus 2 meta routes outside the prefix (`GET
  /health` → `{"status": "ok"}` and `GET /` → name + docs link).
- **Auth levels** (verified by reading each route's dependencies):

| Level | Meaning | Count |
|---|---|---|
| **Public** | No token | 15 |
| **Optional** | Works signed in or out (`get_optional_user`) | 7 |
| **User** | Any signed-in, active account | 45 |
| **Owner** | `business_owner` or admin role; the routes also check ownership of the specific business | 16 |
| **Admin** | Admin role only | 15 |

Swagger shows them all at `http://localhost:8000/docs`.

## 23.1 Authentication: `backend/app/api/auth.py`

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| POST | `/auth/register` | Create an account (FR-1, FR-31) | Public | `{full_name, email, password (8–128), role, interests[], privacy_policy_version}` | 201 `UserOut` · 409 duplicate email or old policy · 422 |
| POST | `/auth/login` | Log in (FR-2) | Public | `{email, password}` | `{access_token, refresh_token, token_type}` · 401 · 403 suspended |
| POST | `/auth/login/form` | Swagger "Authorize" (hidden) | Public | form `username, password` | `TokenPair` |
| POST | `/auth/google` | Google Sign-In | Public | `{id_token}` | `TokenPair` · 401 |
| POST | `/auth/refresh` | New tokens | Public | `{refresh_token}` | `TokenPair` · 401 |
| POST | `/auth/email/verify/send` | Email a verification code | User | — | `{expires_in_minutes, resend_cooldown_seconds}` · 400 already verified · 429 |
| POST | `/auth/email/verify` | Confirm the code | User | `{code: 6 digits}` | `UserOut` · 400 |
| POST | `/auth/password/forgot` | Email a reset code | Public | `{email}` | The same `OtpSentResponse` whether or not the email exists |
| POST | `/auth/password/forgot/verify` | Exchange the code for a reset token | Public | `{email, code}` | `{reset_token, expires_in_minutes}` · 400 |
| POST | `/auth/password/reset` | Set a new password | Public | `{reset_token, new_password}` | `{message}` · 401 |

## 23.2 Users and profile: `backend/app/api/users.py`

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| GET | `/users/me` | My profile | User | — | `UserOut` |
| PATCH | `/users/me` | Edit name, colour, phone, photo (FR-16) | User | `{full_name?, avatar_tone?, phone?, avatar? (media key or null)}` | `UserOut` |
| DELETE | `/users/me` | Delete the account (FR-32) | User | `{password}` (not needed for Google-only) | 204 · 403 wrong password |
| POST | `/users/me/privacy-consent` | Agree to the current policy | User | `{policy_version}` | `UserOut` · 409 |
| PUT | `/users/me/interests` | Set interests | User | `{interests: [slugs]}` | `UserOut` |
| GET | `/users/me/saved` | My saved lists | User | — | `[{id, name, tone, count, businesses[]}]` |
| POST | `/users/me/saved` | New list | User | `{name, tone}` | 201 `SavedListOut` |
| DELETE | `/users/me/saved/{list_id}` | Delete a list | User | — | 204 · 404 |

## 23.3 Businesses: `backend/app/api/businesses.py`

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| GET | `/businesses/mine` | My businesses | Owner | — | `[BusinessCard]` |
| POST | `/businesses` | Register a business (FR-8) | Owner | `BusinessCreate` (name, category_id, custom_category, tagline, description, tone, address, phone, lat/lng, price_level, price_min/max, services[], hours[], photos[]) | 201 `BusinessDetail` · 422 |
| PATCH | `/businesses/{id}` | Edit (FR-9) | Owner (own business) | `BusinessUpdate` (partial) | `BusinessDetail` · 403 · 422 |
| PUT | `/businesses/{id}/photos` | Replace the gallery (≤ 10; the first is the cover) | Owner | `{photos: [keys]}` | `BusinessDetail` |
| PUT | `/businesses/{id}/hours` | Replace the weekly hours | Owner | `{hours: [{day_of_week, opens, closes, is_closed}]}` | `BusinessDetail` |
| DELETE | `/businesses/{id}` | Delete a business | Owner | — | 204 |
| GET | `/businesses/{id}/analytics` | Dashboard numbers (FR-20) | Owner | — | `BusinessAnalytics` (views, weekly chart, saves, messages, unread) |
| GET | `/businesses/{id}` | Business page (FR-5) | Optional | `?track=true\|false` | `BusinessDetail` (+ `is_saved`, `is_owner`) · 404 |
| POST | `/businesses/{id}/save` | Save (FR-7) | User | `{list_id?}` | `BusinessDetail` |
| DELETE | `/businesses/{id}/save` | Unsave | User | — | `BusinessDetail` |
| POST | `/businesses/{id}/report` | Report a listing | User (not the owner) | `{reason, note}` | 201 · 409 repeat |
| GET | `/businesses/{id}/verification` | Verification checklist | Owner | — | `VerificationOut` (status, checks[], storefront …) |
| PUT | `/businesses/{id}/verification/storefront` | Add the storefront photo | Owner | `{photo: key}` | `VerificationOut` |
| POST | `/businesses/{id}/verification/review` | Ask for another look | Owner | `{note}` | `VerificationOut` · 409 |

## 23.4 Discovery, categories, search and compare

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| GET | `/categories` | Category catalogue | Public | — | `[{id, slug, name, emoji, group_name, sort_order, is_other, business_count …}]` |
| GET | `/feed` | Home feed (FR-11) | Optional | `?lat&lng&seed` | `{greeting, headline, categories, sections[], campaigns[]}` |
| GET | `/feed/surprise` | Surprise stack | Public | — | `[BusinessCard]` (shuffled) |
| GET | `/search` | Search + filters (FR-3, FR-4) | Optional | `q, category[], price[], min_price, max_price, min_rating, open_now, has_offer, verified_only, lat, lng, radius_km, north, south, east, west, sort, limit, offset, record` | `{items[], total, relaxed, summary …}` · 422 (e.g. distance without a location) |
| GET | `/search/suggestions` | Typeahead | Public | `?q` | `[{type: business\|category\|service, label, sublabel, business_id, category_slug}]` |
| GET | `/search/popular` | Popular searches (30 days) | Public | — | `[string]` |
| GET | `/search/history` | My recent searches | User | — | `[SearchHistoryItem]` |
| DELETE | `/search/history` | Clear history | User | — | 204 |
| GET | `/compare` | Compare 2–3 (FR-18, BR-12) | Public | `?ids=1&ids=2[&ids=3][&lat&lng]` | `CompareResponse` (items + highlighted winners) · 422 · 404 |

## 23.5 Media and maps

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| POST | `/media` | Upload a photo | User | multipart `file` (JPG/PNG/WebP ≤ 10 MB) | 201 `{key, url, thumb_url, width, height, focal_x, focal_y}` · 413 · 422 |
| GET | `/media/{key}` | Large photo (≤ 1600 px) | Public | 32-hex key | JPEG, cached for 1 year |
| GET | `/media/{key}/thumb` | Thumbnail (≤ 480 px) | Public | — | JPEG |
| GET | `/geo/reverse` | Address at a point | User | `?lat&lng` | `{address, area, city, label, latitude, longitude}` · 404 · 429 · 502 · 503 |
| GET | `/geo/search` | Find a typed address | User | `?q (2–120)&lat&lng` | `[PlaceOut]` |
| GET | `/geo/route` | Route preview | User | `?from_lat&from_lng&to_lat&to_lng&mode=car\|walk` | `{mode, distance_m, duration_s, points[[lat,lng]]}` · 404 · 429 · 502 · 503 |

## 23.6 Reviews: `backend/app/api/reviews.py`

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| GET | `/businesses/{id}/reviews` | Reviews + summary | Optional | `?sort=relevant\|recent\|highest\|lowest\|helpful&stars=&photos=&limit&offset` | `{summary{average, count, distribution, with_photos, unreplied}, items[], total, mine, can_review, is_owner}` |
| GET | `/users/me/reviews` | My reviews | User | — | `[MyReview]` |
| POST | `/businesses/{id}/reviews` | Write a review (FR-6) | User (not the owner) | `{rating 1–5, comment ≤ 1000, photos ≤ 3}` | 201 `ReviewOut` · 403 · 409 |
| PATCH | `/reviews/{id}` | Edit my review | User (author) | `{rating?, comment?, photos?}` | `ReviewOut` |
| DELETE | `/reviews/{id}` | Delete my review (soft) | User (author) | — | 204 |
| PUT | `/reviews/{id}/reply` | Owner's public reply | User (the business owner) | `{text 1–1000}` | `ReviewOut` |
| DELETE | `/reviews/{id}/reply` | Remove the reply | Owner of the business | — | `ReviewOut` |
| PUT | `/reviews/{id}/helpful` | Mark helpful | User (not the author) | — | `{helpful_count, voted_helpful}` |
| DELETE | `/reviews/{id}/helpful` | Remove the vote | User | — | `HelpfulOut` |
| POST | `/reviews/{id}/report` | Report (FR-19) | User (not the author) | `{reason: spam\|fake\|offensive\|other, note}` | 201 · 409 |

## 23.7 Chat: `backend/app/api/chat.py`

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| POST | `/conversations` | Open or start a chat with a business (UC-13) | User (not the owner) | `{business_id}` | `ConversationDetail` · 403 · 404 |
| GET | `/conversations` | My conversations, newest first (FR-25) | User | `?limit=50&offset` | `[ConversationSummary]` |
| GET | `/conversations/unread` | Badge count | User | — | `{total}` |
| GET | `/conversations/{id}` | Header (business or customer, read markers, blocked/closed, `can_send`) | Participant | — | `ConversationDetail` · 404 |
| GET | `/conversations/{id}/messages` | History | Participant | `?before_id \| after_id &limit=30` | `{items[MessageOut], has_more}` |
| POST | `/conversations/{id}/messages` | Send (FR-23, FR-24) | Participant | `{body ≤ 2000, client_id ≤ 36, photo?}` | 201 `MessageOut` · 403 blocked/closed · 422 |
| POST | `/conversations/{id}/read` | Mark read ("Seen") | Participant | — | `{last_read_id, unread_total}` |
| POST | `/conversations/{id}/report` | Report a conversation | Participant | `{reason: spam\|harassment\|scam\|other, note}` | 201 · 409 |
| POST | `/conversations/{id}/block` | Block | Participant | — | `ConversationDetail` · 409 |
| DELETE | `/conversations/{id}/block` | Unblock (blocker only) | Participant | — | `ConversationDetail` · 403 |
| WS | `/ws` | Live events | Token in the first message | `{"type":"auth","token":…}`, then `ping` / `typing` | `ready`, `message.new`, `conversation.read`, `typing`, `pong`; close 4401 |

## 23.8 Notifications: `backend/app/api/notifications.py`

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| PUT | `/notifications/devices` | Register this device's FCM token | User | `{token (10–512), platform: android\|web\|ios}` | 204 |
| POST | `/notifications/devices/unregister` | Stop push to this device (logout) | User | `{token}` | 204 |
| GET | `/notifications` | The bell list | User | `?limit=30&offset` | `{items[], total, unread}` |
| GET | `/notifications/unread-count` | Bell dot | User | — | `{total}` |
| POST | `/notifications/read` | Mark read (some or all) | User | `{ids?}` | `{total}` |
| GET | `/notifications/preferences` | Settings | User | — | `{messages, reviews, offers, new_places, trending}` |
| PUT | `/notifications/preferences` | Change settings | User | the same five booleans | the same |

## 23.9 Offers and campaigns: `backend/app/api/promotions.py`

| Method | Endpoint | Purpose | Auth | Request | Response |
|---|---|---|---|---|---|
| GET | `/businesses/{id}/offers` | Offers (owner: all; others: live only) | Optional | — | `[OfferOut]` (with the derived status and the deal label) |
| POST | `/businesses/{id}/offers` | Create an offer (FR-10, UC-11) | Owner | `{title, description, deal_type, deal_value, deal_text, start_date, end_date?, terms, is_active, tone}` | 201 `OfferOut` · 403 (activating needs a verified business) · 422 invalid dates |
| PATCH | `/businesses/{id}/offers/{offer_id}` | Edit, activate or deactivate | Owner | partial `OfferUpdate` | `OfferOut` |
| DELETE | `/businesses/{id}/offers/{offer_id}` | Delete (soft) | Owner | — | 204 |
| GET | `/businesses/{id}/campaigns` | Campaigns (owner: all; others: visible only) | Optional | — | `[CampaignOut]` |
| POST | `/businesses/{id}/campaigns` | Create a campaign | Owner | `{name, description, message, banner?, start_date, end_date, terms, offer_ids[≤10], service_ids[≤10], is_published, notify_savers}` | 201 `CampaignOut` · 403 · 409 (one published at a time) |
| PATCH | `/businesses/{id}/campaigns/{campaign_id}` | Edit, publish or unpublish | Owner | partial | `CampaignOut` |
| DELETE | `/businesses/{id}/campaigns/{campaign_id}` | Delete (soft) | Owner | — | 204 |
| GET | `/campaigns/{id}` | Campaign details | Optional | — | `CampaignOut` · 404 |

## 23.10 Admin: `backend/app/api/admin.py` (admin only)

| Method | Endpoint | Purpose | Request | Response |
|---|---|---|---|---|
| GET | `/admin/overview` | Queues, today's numbers, 14-day chart, recent activity | — | `OverviewOut` |
| GET | `/admin/businesses` | Businesses by status (`pending_review`, `recently_verified`, `needs_info`, `rejected`, `verified`, `unverified`, `suspended`, `all`) | `?status&q&limit&offset` | `BusinessPage` |
| GET | `/admin/businesses/{id}` | Checks, storefront photo, reports, flags, history | — | `AdminBusinessDetail` |
| POST | `/admin/businesses/{id}/verification` | Decide | `{decision: approve\|reject\|request_info\|revoke, note}` (a note is required except for approve) | `AdminBusinessDetail` |
| POST | `/admin/businesses/{id}/suspend` | Take a listing down | `{reason, note}` | `AdminBusinessDetail` |
| POST | `/admin/businesses/{id}/reinstate` | Put it back | `{note}` | `AdminBusinessDetail` |
| GET | `/admin/reports` | Grouped reports | `?kind=review\|conversation\|business&status` | `ReportPage` |
| GET | `/admin/reports/{kind}/{target_id}` | One reported item (a reported conversation's messages are included) | — | `ReportDetail` |
| POST | `/admin/reports/{kind}/{target_id}/resolve` | Uphold or dismiss, with an optional account action | `{decision: uphold\|dismiss, reason, note, account_action: none\|warn\|suspend\|ban, hide_reviews}` | `ReportDetail` |
| GET | `/admin/flags` | Automatic flags | `?status` | `FlagPage` |
| POST | `/admin/flags/{id}/resolve` | Uphold or dismiss a flag | the same resolution shape | `FlagOut` |
| GET | `/admin/users` | Find accounts | `?q&status` | `UserPage` |
| GET | `/admin/users/{id}` | An account's history | — | `AdminUserDetail` |
| POST | `/admin/users/{id}/action` | Warn, suspend, ban or lift | `{action, reason, note, days 1–365, hide_reviews}` | `AdminUserDetail` |
| GET | `/admin/actions` | The audit log | `?automatic&limit&offset` | `ActionPage` |

## 23.11 Important APIs as full request and response flows

**1. Login**

```http
POST /api/v1/auth/login
Content-Type: application/json

{"email": "customer@khojlo.app", "password": "password123"}
```

```json
200 OK
{"access_token": "eyJhbGciOiJIUzI1NiIs…", "refresh_token": "eyJhbGciOiJIUzI1NiIs…", "token_type": "bearer"}
```

**2. Create a business**

```http
POST /api/v1/businesses
Authorization: Bearer <owner access token>

{"name": "Qalam Calligraphy Studio", "category_id": 26, "custom_category": "Calligraphy studio",
 "address": "F-7 Markaz, Islamabad", "latitude": 33.72, "longitude": 73.05, "phone": "0510000123",
 "price_level": "$$", "price_min": 800, "price_max": 2500,
 "hours": [{"day_of_week": 0, "opens": "10:00", "closes": "20:00"}],
 "services": [{"name": "Name plate", "price": "Rs 1,500", "price_amount": 1500}], "photos": []}
```

The response is `201 BusinessDetail`. In the background: moderation rules run, the verification
checks refresh, and users interested in the category get a "New on Khojlo" push. (The
`category_id` value here is illustrative.)

**3. Search**

```http
GET /api/v1/search?q=darzi&open_now=true&sort=distance&lat=33.72&lng=73.06&radius_km=5&record=true
```

The response is `200 {"items": [BusinessCard…], "total": 4, "relaxed": false, "summary": "4 places
· 3 open now · avg ★ 4.5 · nearest 0.8 km", …}`. With `record=true`, the search is saved in
`search_queries`: in your history if you're signed in, or anonymously (`user_id` NULL) otherwise.
Both kinds count towards Popular searches.

**4. Send a message**

```http
POST /api/v1/conversations/12/messages
Authorization: Bearer <customer token>

{"body": "Do you deliver to G-9?", "client_id": "9f2c41aa07be13d5"}
```

The response is `201 MessageOut`. Then: `message.new` goes over the WebSocket to both sides, and a
push goes to the owner if they're offline.

**5. Register a device for push**

```http
PUT /api/v1/notifications/devices
Authorization: Bearer <token>

{"token": "<FCM token>", "platform": "android"}
```

The response is `204 No Content`.

**6. Write a review**

```http
POST /api/v1/businesses/7/reviews
Authorization: Bearer <token>

{"rating": 5, "comment": "Best chai in F-7", "photos": []}
```

The response is `201 ReviewOut`. The business rating is recalculated in the same transaction, and
the owner is notified. A second try returns `409`.

---

# Part 24: Control Flow

Every flow below uses real files and functions. `lib/` means `frontend/lib/`, and `app/` means
`backend/app/`.

## 24.1 User registration

```text
User fills Sign up (name, email, password, role chip, consent checkbox) and taps "Create account"
 ↓ Flutter screen: lib/features/auth/presentation/auth_screen.dart (inline errors if consent unticked)
 ↓ Controller: AuthController.register(fullName, email, password, role, interests)  [loading = true]
 ↓ Repository: AuthRepository.register() → POST /api/v1/auth/register (+ privacy_policy_version)
 ↓ Backend route: register() in app/api/auth.py
 ↓ Validation: RegisterRequest (EmailStr, password 8–128, role ≠ admin)
 ↓ Business logic: duplicate email → 409; policy version check → 409; bcrypt hash; record consent
 ↓ Database/external: INSERT users; INSERT otp_codes; email the code in a BackgroundTask (SMTP)
 ↓ Response: 201 UserOut
 ↓ Repository then logs in: POST /auth/login → saves tokens (TokenStorage) → GET /users/me
 ↓ Flutter state: AuthState(status: authenticated, user)
 ↓ UI: router redirect → customers with no interests go to /interests, others to /home;
       SessionServices starts the WebSocket, badge counts and push setup
```

## 24.2 Login

```text
"Sign in" → AuthScreen → AuthController.login() → AuthRepository.login()
 → POST /api/v1/auth/login (skipAuth) → login(): SELECT user by email, bcrypt.checkpw,
   ensure_active → TokenPair → TokenStorage.save() → GET /users/me (Bearer access token)
 → AuthState authenticated → router: needsPrivacyConsent? → /privacy-consent : /home
 → errors: 401 shown as "Incorrect email or password" via describeApiError()
```

## 24.3 Google login

```text
Tap "Continue with Google" (mobile) / Google's rendered button (web)
 → AuthController.loginWithGoogle() / loginWithGoogleAccount(account)
 → AuthRepository.ensureGoogleSignInReady() → GoogleSignIn.instance.authenticate()
 → account.authentication.idToken → POST /api/v1/auth/google {id_token}
 → google_login(): verify_google_id_token() (signature, audience = GOOGLE_WEB_CLIENT_ID, issuer)
   → find by google_id → else link by email (is_verified = True) → else INSERT new customer
 → TokenPair → saved → GET /users/me → authenticated
 → router: a new Google user has no consent → /privacy-consent → "I agree"
   → POST /users/me/privacy-consent → /home
 → cancelled picker: no error shown; other failures: "Google sign-in failed. Please try again."
```

## 24.4 Create a business (listing)

```text
Business tab → BusinessTabScreen: myBusinessesProvider (GET /businesses/mine)
   empty list (or 403 for a customer account) → "Register your business" CTA → /register-business
 → RegistrationStepper: 8 steps fill a BusinessDraft (photos uploaded as you go: POST /media)
 → last step "Publish business" → _publish() → BusinessRepository.create(draft)
 → POST /api/v1/businesses (owner token) → create_business() in app/api/businesses.py
 → Validation: BusinessCreate (lengths, HH:MM, unique days, prices, lat/lng pair, phone digits)
 → Logic: photos must be yours; category exists, "Other" needs a description; services + hours;
          moderation rules (check_business) + verification refresh; notify interested users
 → DB: INSERT businesses, services, opening_hours, business_photos (+ flags, notifications) → COMMIT
 → Background: push "New on Khojlo: <name>" to users interested in the category
 → 201 BusinessDetail → ref.invalidate(myBusinessesProvider) → Business tab shows the dashboard
```

**A customer account can't do this.** The API answers **403 "Business owner account required"**
(`get_current_owner()`), and there's no way to upgrade an account's role (Known Inconsistencies &
Risks).

## 24.5 Update or delete a listing, and create an offer

```text
Update: Dashboard → "Edit business profile" → edit_business_screen.dart
   → BusinessRepository.update(id, changes) → PATCH /businesses/{id} → update_business():
     _get_owned (403 if not yours) → apply changes → price/lat-lng/(0,0) checks → category check
     → name/address/pin changed? → identity_changed() removes the Verified badge
     → moderation rules + verification refresh → COMMIT → BusinessDetail
Hours/photos: PUT /businesses/{id}/hours  ·  PUT /businesses/{id}/photos (first photo = cover)
Delete: DELETE /businesses/{id} → db.delete(b) → cascades → delete_if_unused(photos) → 204
Offer: Dashboard → "Offers & promotions" → offer_editor_screen.dart → PromotionsRepository.saveOffer()
   → POST /businesses/{id}/offers → active offer on an unverified business → 403 with explanation;
     end before start → 422; savers notified once when it goes live
```

## 24.6 Search for a business

```text
Home search pill → /explore with keyboard → SearchScreen
 → typing: SearchNotifier.onInputChanged (350 ms debounce) → SearchRepository.search()
   + suggestionsProvider → GET /search/suggestions?q=
 → submit: SearchNotifier.submit() → GET /api/v1/search?q=…&record=true (+ filters, lat/lng)
 → search_businesses() in app/api/search.py → SearchCriteria (validation → 422 messages)
 → SearchEngine.search(): strategies_for(criteria) → SQL pre-filter → Python matches()
   → no results with 2+ words → retry "any word" (relaxed) → rank() → page → summarize()
 → record_search() (app/services/search/history.py) if record=true: INSERT search_queries
   (user_id is NULL for anonymous searches, which still count towards Popular)
 → SearchResponse → SearchState → result rows, "N places match", the summary card
 → stale responses (from older keystrokes) are dropped
```

## 24.7 View a business

```text
Tap a card → context.push('/business/12') → BusinessDetailScreen
 → businessDetailProvider(12) → DiscoveryRepository.detail(12) → GET /businesses/12
 → business_detail(): SELECT with detail_load_options (photos, category, services, hours, offers…)
   → 404 if missing or suspended (unless you're the owner) → BusinessDetail (live offers only,
   is_saved, is_owner) → background: record_view_later() (INSERT business_views; view_count + 1)
 → UI: gallery, open now, prices, offers strip, reviews section (its own provider:
   GET /businesses/12/reviews?limit=…), mini map (MapService.displayLocation), buttons
   (Message, Save, Call, Directions, Share, Compare, Report)
```

## 24.8 Add a review

```text
Business page → "Write a review" → openWriteReview() (lib/features/reviews/presentation/review_flows.dart)
 → showWriteReviewSheet: star picker ("Pick a star rating first." if missing), comment, ≤ 3 photos
   (each uploaded with POST /media)
 → ReviewsRepository.create(businessId, rating, comment, photoKeys)
 → POST /businesses/{id}/reviews → create_review(): published? owner? already reviewed? → INSERT
   → photos → refresh_rating() → check_review() → notify owner → COMMIT
 → 201 ReviewOut → reviewChangesProvider bumped → business page, reviews screen, My reviews and
   the dashboard reload → confetti + "Thanks! Your review of <name> is live."
 → background: push "New 5★ review for <business>" to the owner
```

## 24.9 Send a message

```text
Business page → "Message" → _message() → openConversationWith(ref, id) → POST /conversations
 → context.push('/conversations/{id}') → ConversationScreen → ConversationController.load()
   (GET /conversations/{id}, GET …/messages?limit=30, then POST …/read)
 → type + send → ConversationController.send() → pending bubble → ChatRepository.send()
 → POST /conversations/{id}/messages → send_message() (Part 15.7) → 201 MessageOut
 → _add(saved) replaces the pending bubble; ConversationsController.sent() reorders the list
```

## 24.10 Receive a message

```text
App open: WebSocket event {"type":"message.new"} → RealtimeService._onData → events stream
 → ConversationsController updates the row + badge (ShellScaffold → FloatingTabBar badge)
 → ConversationController (if that chat is open) → _add() → _markRead() → POST …/read
   → server sends "conversation.read" → sender's screen shows "Seen"
App closed/background: no socket → server prepared a push → Part 24.11
```

## 24.11 Receive and open a notification

```text
Backend notify() → PushJob → FcmSender → FCM → device
 Android background/closed: system notification → tap → onMessageOpenedApp / getInitialMessage
   → PushPlatform.openedRoutes / launchRoute → PushController._open(route) → router.push(route)
 Android foreground: FirebaseMessaging.onMessage → PushController._onForeground()
   → showInAppBanner(title, body, onOpen) + unreadNotificationsProvider.refresh()
 Web: service worker shows it → click → postMessage {type: "khojlo-open", route} → app navigates
 Bell list: NotificationsScreen → GET /notifications → tap → POST /notifications/read {ids} → route
```

## 24.12 Open the map

```text
Tab "Map" → MapScreen → mapServiceProvider → MapLibreService.buildMap(...)
 → style asset loads (OpenFreeMap tiles) → onCameraIdle → MapResultsNotifier (300 ms debounce)
 → SearchRepository.search(filters, bounds, limit: 100) → GET /search?north&south&east&west…
 → AreaSearch + filters → BusinessCards with lat/lng → pins (GeoJSON) + nearby carousel
 → tap pin → preview card → Directions → showRoute() → GET /geo/route → route line
 → nothing in view for a new search → search everywhere → camera moves to the nearest matches
```

---

# Part 25: Data Flow

## 25.1 Authentication data

```text
User types email + password
 → Flutter (memory only) → HTTP JSON (plain HTTP locally; HTTPS needed in production)
 → FastAPI (Pydantic validation) → bcrypt hash → PostgreSQL users.hashed_password
 → JWTs (signed with SECRET_KEY) → back to the app → flutter_secure_storage
 → every request: "Authorization: Bearer <access>" → get_current_user → users row
```

The password plaintext is never stored. The JWTs are stored only on the device. One-time codes
are stored only as HMAC hashes (`otp_codes`).

## 25.2 Business listing data

```text
Owner input (stepper) + photos (camera/gallery) + device location (pin)
 → photos: POST /media → Pillow processing → media table (bytes in PostgreSQL)
 → listing: POST /businesses → businesses, services, opening_hours, business_photos
 → moderation_flags (if rules match), moderation_actions (auto-verify/refer), notifications
 → read paths: feed / search / map / compare / detail → BusinessCard / BusinessDetail JSON → app
 → views: GET detail → business_views + view_count → owner analytics (GET /analytics)
```

## 25.3 Review data

```text
Customer rating + comment + photos → POST review → reviews (+ review_photos)
 → refresh_rating → businesses.rating / review_count (denormalized)
 → read by: business page summary, reviews screen, search rating filter/sort, feed "Trending",
   compare, map pins, owner dashboard
 → reports → review_reports → admin queue → moderation_actions (+ is_approved = false if removed)
```

## 25.4 Chat data

```text
Text/photo → REST → messages (+ media) → conversations (last_message_at, read markers)
 → live: WebSocket event to both participants (memory only, not stored again)
 → offline: FCM push (title + snippet ≤ 90 chars) → Google → device
 → reports → conversation_reports → admins can read that conversation (only after a report)
```

## 25.5 Notification data

```text
Event → notify() → notifications rows (except chat) + device_tokens lookup
 → FCM HTTP v1 request per token {title, body, data{route, kind}} → Google → device
 → device token origin: Firebase SDK on the device → PUT /notifications/devices → device_tokens
 → settings: PUT /notifications/preferences → users.notification_prefs (JSON)
```

## 25.6 Map data

```text
Device GPS (geolocator) → app memory → sent only as query params (lat/lng) for distance,
   Nearby, the route start and geocoding → never stored server-side (SEC-7)
Tiles: OpenFreeMap → app (direct)
Addresses: app → /geo/* → backend cache → Photon/Nominatim → backend → app
Routes:    app → /geo/route → backend cache → openrouteservice → backend → app
Business coordinates: owner's pin → businesses.latitude/longitude → every card → pins
```

## 25.7 What leaves Khojlo's own servers

| Data | Goes to | Why |
|---|---|---|
| Device token, notification title, body, route | Google (FCM) | Delivering pushes |
| Google ID token | Verified locally with Google's public certificates (fetched from Google) | Google sign-in |
| Email address + code | The SMTP provider | Verification and reset emails |
| Typed address text, coordinates | Photon, Nominatim (OpenStreetMap community servers) | Address lookup |
| Route start and end | openrouteservice | Route previews |
| Viewed map area (tile requests) | OpenFreeMap | Map tiles |
| Destination coordinates | Google Maps (only when the user taps "Start in Google Maps") | Navigation |

The privacy policy (`lib/features/legal/privacy_policy.dart`) explains these to users.

---

# Part 26: Error Handling

## 26.1 In the Flutter app

| Mechanism | Where | What it does |
|---|---|---|
| `describeApiError(error)` | `lib/core/network/api_client.dart` | Turns any error into one friendly sentence. It uses FastAPI's `detail` string if there is one, else the first validation `msg`, else "Can't reach the server. Is the backend running?" for timeouts and connection errors, else "Something went wrong." |
| `AsyncValue` (`loading` / `error` / `data`) | Every `FutureProvider` (`feedProvider`, `businessDetailProvider` …) | Screens show **skeletons** while loading, an **error card with Retry** on failure (e.g. `_FeedError` on Home), and the data otherwise |
| Empty states | Chat tab ("explains how to start a conversation"), Notifications ("an empty list says so"), My reviews, search ("No places match yet…") | Covered by widget tests |
| Inline form validation | Sign-up (consent checkbox), the review sheet ("Pick a star rating first."), the offer editor, phone validators that mirror the backend | The UI blocks bad input before calling the API |
| Optimistic actions with rollback | Helpful votes ("rolls back when the server refuses"), chat sending ("Not sent · Tap to retry") | The app feels instant, and failures are visible |
| Snackbars and banners | `showReviewSnack()`, `showInAppBanner()` (`lib/core/ui/messenger.dart`) | Short success or error messages |
| Timeouts | Dio: 12 s connect/receive. Location: 15 s (60 s for a permission prompt). Firebase start: 8 s. Map style: 20 s → sketch map. | Nothing hangs forever |
| Fallbacks | `SketchMapService`, `NullSender`, push UI hidden when `firebaseReadyProvider` is false, route screen shows the straight-line distance | Optional services fail softly |

## 26.2 API errors (status codes Khojlo uses)

| Code | Meaning | Examples |
|---|---|---|
| 400 | Bad request (logic) | Wrong or expired one-time code; email already verified; reporting your own business |
| 401 | Not authenticated | Missing, invalid or expired token; wrong login; invalid Google token; invalid refresh or reset token |
| 403 | Not allowed | Not your business; customer creating a business; reviewing your own business; blocked or closed chat; suspended or banned account (with the reason); wrong password when deleting an account; activating an offer while unverified |
| 404 | Not found (or hidden) | Unknown business, review or conversation; **non-participants** asking for a conversation; suspended listing for non-owners |
| 409 | Conflict | Duplicate email; already reviewed; already reported; old privacy policy version; second published campaign; already-blocked chat |
| 413 | Too large | Photo > 10 MB |
| 422 | Validation | Pydantic field errors (automatic); "Write a message first."; invalid dates; bad search combination; compare needs 2–3 distinct ids |
| 429 | Too many requests | One-time code cooldown or daily cap; geocoding (60 per 10 min) or routes (30 per 10 min) per user |
| 500 | Unexpected | Any unhandled exception (no custom global handler) |
| 502 | Upstream failed | Geocoding or routing provider error (details only in the server log) |
| 503 | Not configured | Geocoding in Google mode without a key; routing without an ORS key |

## 26.3 Database errors

- **Constraint violations** (`IntegrityError`) are caught where races are expected (duplicate
  review, conversation, message `client_id`, report, vote), and turned into a 409 or "return the
  existing row".
- **Connection problems:** `pool_pre_ping=True` replaces dead pooled connections. If the database is
  completely down, requests raise and return **500**, and the app shows "Something went wrong" or
  the screen's error card. The schema check at startup logs a clear warning if the database is
  missing migrations.
- **Transactions:** a failure before `commit()` saves nothing (all-or-nothing).

## 26.4 Authentication errors

- **401:** `ApiClient` tries **one** `/auth/refresh` and retries the request.
- **If the refresh also fails**, the tokens are cleared. **Inference:** `ApiClient` doesn't notify
  `AuthController`, so the UI keeps its signed-in state until the next launch or logout. Calls
  meanwhile show errors.
- **403 for a suspended account:** the server's reason ("Your account is suspended until …") is the
  `detail`, so it appears wherever an error message is shown. **Inference:** there's no dedicated
  "account suspended" screen; the `X-Account-Status` header isn't read by the app.
- **Launch with a stored token:** `bootstrap()` calls `/users/me`. On **any** error, including "no
  internet" or "server down", it **clears the tokens** and shows sign-in. Opening the app while the
  backend is unreachable therefore signs you out (Known Inconsistencies & Risks).

## 26.5 WebSocket and Firebase errors

- **WebSocket:**
  - Drops → reconnect with backoff (1 → 30 s).
  - 4401 → refresh once, then stop.
  - The open chat polls every 8 s while offline.
  - `send()` silently drops events like typing while offline.
- **Firebase (app):** `initFirebase()` failing → push is off and nothing else breaks. Token
  registration errors are swallowed (`catch (_) {}`) so they never block the user.
- **Firebase (server):**
  - Bad or missing credentials → `NullSender` and a single log line.
  - An authorisation failure → "Could not authorise with Firebase", logged, nothing sent.
  - A network error per token → logged, continue.
  - Dead tokens → deleted.

## 26.6 What happens when …

| Situation | Result |
|---|---|
| **Internet disconnects** | REST calls time out (12 s) → "Can't reach the server…" with Retry. Chat sends show "Not sent · Tap to retry". The socket reconnects with backoff. Images already cached still show. *If the app is launched offline, the user is signed out.* |
| **Backend is down** | The same as above, from the app's point of view. Pushes can't be sent (the backend sends them). |
| **Database unavailable** | The API process runs, but requests fail with 500. Startup logs a schema-check warning. Nothing is half-saved, thanks to transactions. |
| **Token expires** (30 min) | The next call gets 401 → automatic refresh → retried transparently. The WebSocket gets 4401 → refresh → reconnect. After 14 days the refresh token expires too → sign in again. |
| **Firebase fails** | No push. Chat still delivers live to open apps. The bell list still fills (rows are stored before pushing). |
| **WebSocket disconnects** | Backoff reconnect; an open chat polls every 8 s; on reconnect, `catchUp()` fetches missed messages. Nothing is lost, because messages are stored before delivery. |
| **Invalid data submitted** | Client-side validators catch most of it. The server rejects the rest with 422 (field errors) or 409/403/400 with a human sentence, which the app shows via `describeApiError()`. |

---

# Part 27: Testing

## 27.1 Frameworks and where the tests are

| Side | Framework | Location | Runs with |
|---|---|---|---|
| Backend | **pytest** + FastAPI **`TestClient`** (uses `httpx`) | `backend/tests/` (23 test files, `conftest.py`, `factories.py`, `moderation_support.py`) | `cd backend && .venv/bin/pytest` |
| Frontend | **flutter_test** (unit tests + widget tests) | `frontend/test/` (18 files) | `cd frontend && flutter test` |
| Static analysis | `flutter analyze` with `flutter_lints` | `frontend/analysis_options.yaml` | `flutter analyze` (the module records say "No issues") |

## 27.2 Results (run while writing this handbook, 5 Oct 2026)

| Suite | Result |
|---|---|
| Backend `pytest` | **316 passed**, 5 warnings (Alembic deprecation notices), **240 s** |
| Flutter `flutter test` (Flutter 3.41.4) | **134 passed** ("All tests passed!") |

The backend has 254 `def test_…` functions. Parametrized tests (15 `@pytest.mark.parametrize`
uses) expand them into 316 test cases.

## 27.3 How the backend tests are built

- **Test database:** in-memory **SQLite** (`sqlite://` + `StaticPool`). `PRAGMA
  foreign_keys=ON` makes cascades behave like PostgreSQL. Tables are created and dropped **per
  test**, so every test starts clean. No PostgreSQL is needed.
- **Dependency overrides:** `app.dependency_overrides[get_db]` points the app at the test
  database. `session_factory` is patched so WebSocket and background sessions use it too.
- **Mocking and fakes:**
  - **`RecordingSender`** replaces Firebase and records every push.
  - Emails are captured into a list (`sent_emails`), so tests can read the one-time code.
  - The geocoder and router are replaced through `get_geocoder` / `get_router` overrides with fake
    providers.
  - `get_now` is overridden to freeze the clock (to test "open now" at a known hour).
  - `FcmSender` and `GoogleGeocoder` are tested with **fake HTTP sessions**.
  - Seed demo photos are off by default (`INCLUDE_PHOTOS = False`).
- **Helpers:** `register()`, `login()` and `auth()` in `conftest.py`; `factories.py` builds
  businesses and other objects.

## 27.4 What each backend test file covers

| File | Tests (functions) | What is tested |
|---|---|---|
| `test_flows.py` | 12 | Register → login → me; short passwords rejected; **can't register as admin**; customer can't create a business; business lifecycle + feed; views recorded; refresh token; surprise; feed seed rotation; greeting; analytics per day |
| `test_email_and_password_flows.py` | 6 | Verification codes, reset flow, limits |
| `test_privacy.py` | 8 | Consent on sign-up; old version rejected; Google users must agree; new version asks again; delete needs the password; Google-only delete; full cascade checks for a customer and an owner |
| `test_search.py` | 26 | Keyword fields, accents, stopwords, all-words / any-word fallback, relevance order, every filter alone and combined, radius and distance, validation, paging, the summary, a **500-business timing check** |
| `test_search_history.py` | 8 | Recent searches are private; clearing; popular searches |
| `test_compare.py` | 6 | Comparison rows, winners and ties, invalid requests |
| `test_hours.py` | 7 | Open now, including **after-midnight** and 24-hour days |
| `test_business_price_hours.py` | 6 | Price range and hours validation, hours replacement permissions |
| `test_categories_contact_profile.py` | 9 | Categories order and counts, "Other" rules, phone validation, profile photo and phone |
| `test_photos.py` | 14 | Upload sizes and variants, EXIF rotation and metadata stripping, bad, tiny and huge files, focal point, galleries, orphan cleanup |
| `test_reviews.py` | 17 | UC-7 + Algorithm 7, **BR-4**, invalid reviews, the owner rule, edit and soft delete, verified-first ordering, filters, hidden reviews, replies, helpful votes, reports, photos, **weighted ranking** |
| `test_maps.py` | 21 | Map area, filters, validation, BR-7, the geocoding API with a fake provider, the Google client with a fake HTTP session |
| `test_routes.py` | 8 | The route API: caching, 503 / 404 / 502 behaviour |
| `test_chat.py` | 19 | Open, reopen, no self-messaging, unpublished business, needs an account, **read receipts**, mark read twice, owner sees all their businesses' chats, empty or too-long messages, **retried send stored once**, **outsiders can't see or use a conversation**, paging + catch-up, photos (only your own), reports, dashboard counts, **push to an offline recipient**, message notifications can be turned off |
| `test_realtime.py` | 7 | **Sockets must authenticate first**; a refresh token isn't enough; ping/pong + presence; the owner receives live with **no push while online**; the sender's other devices; "Seen" reaches the customer; typing is forwarded only between participants |
| `test_notifications.py` | 12 | Devices (moving between users), every trigger, dead tokens, settings, the list, the trending digest |
| `test_push_sender.py` | 7 | The FCM payload, invalid-token handling, credentials that can't authorise, push off without credentials |
| `test_promotions.py` | 15 | Deal labels, derived statuses, the verified-only rule, live-only visibility, campaign rules, one at a time, banner cleanup, notifications (opt-in, once, scheduled) |
| `test_verification.py` | 8 | Automatic verification checks, referral, identity change |
| `test_moderation_rules.py` | 10 | Each rule (English + Roman Urdu), bursts, duplicates, mass messaging |
| `test_admin.py` | 18 | Admin-only access, queues, resolving reports, account actions, the audit log |
| `test_schema_check.py` | 3 | Missing or behind migrations are reported; an up-to-date database passes |
| `test_seed.py` | 7 | Seed totals equal real reviews; BR-4 holds; re-running changes nothing |

## 27.5 Important tests, explained

**`test_br4_one_review_per_business_per_user`** (`backend/tests/test_reviews.py`)

- **What:** a second review of the same business by the same user is refused.
- **Why:** SRS BR-4.
- **Input:** two `POST /businesses/{id}/reviews` calls by one user.
- **Expected:** 201, then **409** "Edit your review instead."
- **Actual:** passes.

**`test_a_retried_send_is_stored_once`** (`backend/tests/test_chat.py`)

- **What:** the same `client_id` sent twice creates one message.
- **Why:** retries after a network failure mustn't duplicate messages.
- **Expected:** both calls return the same message id.
- **Actual:** passes.

**`test_other_people_cant_see_or_use_a_conversation`** (`backend/tests/test_chat.py`)

- **What:** a third user gets **404** for the conversation, its messages and sending.
- **Why:** BR-15 / SEC-5 privacy.
- **Actual:** passes.

**`test_owner_receives_a_new_message_live_and_gets_no_push`** (`backend/tests/test_realtime.py`)

- **What:** with the owner's socket open, a customer's REST send produces a `message.new` event
  and **no** recorded push.
- **Why:** the "online → live, offline → push" rule.
- **Actual:** passes.

**`test_cannot_register_as_admin`** (`backend/tests/test_flows.py`)

- **Input:** `role: "admin"` on register.
- **Expected:** 422.
- **Why:** SEC-3.

**`test_deleting_a_customer_removes_their_data_and_fixes_counters`** (`backend/tests/test_privacy.py`)

- **What:** after deletion, every table is checked for leftovers, and the rating, save and helpful
  counts are recalculated.
- **Why:** FR-32 / SEC-8.

**Flutter: `'sending shows the message at once, then confirms it'`** and **`'the socket echo
arriving first doesn't…'`** (`frontend/test/chat_test.dart`)

- **What:** optimistic sending and de-duplication, using a fake `Realtime` and repository.

**Flutter: `'a stalled position request ends in an error instead of hanging'`**
(`frontend/test/location_service_test.dart`)

- **What:** the 15-second location timeout.

## 27.6 Manual testing recorded in the module records

- Migrations upgraded, downgraded and upgraded again on real PostgreSQL 14/16 (Modules 4, 5, 8, 9,
  privacy).
- Seeding run twice to prove it's idempotent.
- Browser runs at phone size against a seeded database.
- A live WebSocket latency check: **20 ms** from a REST send to `message.new`.
- `flutter build web --release` and `flutter build apk --debug` both succeeded.

## 27.7 Weak or missing coverage (be honest)

- **No CI pipeline.** Tests only run when someone runs them.
- **Tests use SQLite, not PostgreSQL.** Most behaviour matches; differences such as time zones are
  handled in code (`_aware()`). Migrations are only checked by hand.
- **No end-to-end tests on real devices or emulators** (no `integration_test`), and no tests of the
  real Firebase, Google Sign-In, SMTP, Photon/Nominatim or openrouteservice. All of them are faked.
- **No Flutter tests for the login flow or the business registration stepper.** The auth tests
  cover the password eye, the consent checkbox and deletion.
- **No load or performance tests** for PER-1–PER-6, except one 500-business search timing test.
- **No security tests** (penetration testing, dependency vulnerability scans).
- **Multi-worker WebSocket behaviour** isn't tested (it isn't supported).

---

# Part 28: Documentation

## 28.1 What exists

| Document | Path | What it is |
|---|---|---|
| README | `README.md` | How to run backend and app, the module status table, demo scripts for each module, phone setup |
| Docs index | `docs/README.md` | The folder map and **which document wins** when sources disagree |
| SRS v1.0 | `docs/requirements/SRS.pdf` | As submitted |
| SRS v1.2 | `docs/requirements/SRS.md` | Editable working copy with all v1.1 and v1.2 changes marked; Appendix A module traceability |
| SDD | `docs/requirements/SDD.pdf` | Architecture, class, sequence and state diagrams, data dictionary, algorithms, screens |
| Feasibility Report | `docs/requirements/Feasibility_Report.pdf` | Problem, modules, tools, work division, Gantt chart |
| Documentation review | `docs/requirements/document_review.md` | Every issue in the three documents, its fix, and the open decisions |
| Use case diagram source | `docs/requirements/diagrams/use_case.puml` | The corrected Figure 3.1 (PlantUML) |
| Implementation plan | `docs/development_roadmap/implementation_plan.md` | The 30% / 60% / 100% plan and status |
| Module records | `module4_…`, `module5_…`, `module6_…`, `module8_…`, `module9_chat_and_push_plan.md`, `offers_campaigns_plan.md`, `polish_photos_categories_profile.md`, `privacy_consent_and_account_deletion.md` | Decisions → plan → implementation record → tests → rollout, per module |
| Chat and push guide | `docs/development_roadmap/module9_how_it_works.md` | A plain-English guide to Module 9 |
| Team setup | `docs/team_setup.md` | Which private files and values to share, a new-teammate checklist, what to do after a leak |
| Design | `docs/design/Khojlo App.dc.html` (source of truth for screens and navigation), `docs/design/khojlo-mockup/`, `theme.md`, `ui_design_direction.md`, `modules_layout.md` | Visual design |
| Brand | `docs/brand/khojlo-logo-package/` | Logos (SVG) |
| API docs | Generated by FastAPI at `/docs` and `/redoc` | There's no separate written API document |
| Code comments | Docstrings at the top of most modules cite SRS and SDD IDs (e.g. `"""Module 9 — chat … (SRS FR-23–FR-25…)"""`) | Traceability inside the code |
| Frontend README | `frontend/README.md` | The default Flutter template text (not project-specific) |

## 28.2 Outdated or inconsistent documentation

1. **SRS** OE-8, CO-5 and UC-9 ("Load Google Maps"), the SRS references, the Feasibility tools
   list, and `implementation_plan.md` ("Interactive Google map", "Directions to Google Maps
   navigation") are behind the MapLibre/OpenStreetMap switch.
2. **SEC-1** and `implementation_plan.md` say "encrypted passwords"; they're hashed.
3. **`docs/team_setup.md`** says "Last updated: 28 Sep 2026", although later work (maps and routing
   keys) changed its tables. The content mentions `OPENROUTESERVICE_API_KEY` and `MAP_PROVIDER`,
   so the text was updated but the date wasn't.
4. **`polish_photos_categories_profile.md`** says "Directions and Share … still do nothing". Both
   work now (route preview and `share_plus`).
5. **SDD and Feasibility corrections** (the 📝 items in `document_review.md`) are listed but not yet
   applied to the Word and PDF files: UUIDs, ER subtypes, the traceability matrix, the 4-tab
   screenshots, the Gantt chart, the work division.
6. **`frontend/README.md`** is still the Flutter template.
7. The privacy commit message says "FR-26, FR-27", while the SRS numbers are **FR-31, FR-32**.

---

# Part 29: Tech Stack Master Table

| Layer | Technology | Purpose | Why used |
|---|---|---|---|
| Frontend | **Flutter 3.41** | One codebase for the Android app and the web app | Cross-platform, fast UI, matches SRS OE-3 |
| Language | **Dart 3.11** | Flutter's language | Required by Flutter; null safety; async/await |
| State management | **Riverpod 2** | Shared reactive state + dependency injection | Testable, compile-safe, overridable in tests |
| Navigation | **go_router 14** | URL routes, redirects, 5-tab shell | Deep links from notifications; auth and consent gates |
| HTTP client | **Dio 5** | REST calls | An interceptor for the JWT + refresh |
| Realtime client | **web_socket_channel** | The chat WebSocket | The standard Dart WebSocket for mobile + web |
| Backend | **FastAPI** (≥ 0.115) on **uvicorn** | REST API + WebSocket | Fast to build, automatic validation and docs, async WebSockets |
| Language | **Python 3.14** | Backend language | The team's skills; a rich library ecosystem |
| Validation | **Pydantic 2** + pydantic-settings | Request and response schemas, settings | Built into FastAPI |
| ORM | **SQLAlchemy 2.0** | Python ↔ SQL | Safe parameterized SQL, relationships, unit of work |
| Migrations | **Alembic** | Versioned schema changes | A shared database needs controlled changes |
| Database | **PostgreSQL** (14+; Supabase-hosted shared instance) | All persistent data, including photos | Relational integrity, transactions, SQL (SRS CO-3) |
| DB hosting | **Supabase** (managed PostgreSQL only) | One shared database for the team | Free tier, no server to manage |
| Auth | **bcrypt** + **JWT (python-jose, HS256)** + **Google Sign-In** (google-auth) | Passwords, sessions, social login | Standard, stateless, no paid identity service |
| Email | **SMTP** (`smtplib`) | One-time codes, account notices | Simple, works with Gmail app passwords |
| Notifications | **Firebase Cloud Messaging** (HTTP v1; `firebase_messaging` in the app) | Push to Android and web | Free, standard (SRS OE-10) |
| Realtime | **WebSocket** (FastAPI/Starlette) | Live chat events | Instant delivery (PER-6) |
| Maps | **MapLibre GL + OpenStreetMap (OpenFreeMap tiles)**; Google Maps optional | The map tab, pins, the pin picker | Free, no billing account, customizable style |
| Geocoding | **Photon + Nominatim** (OSM) via the backend; Google optional | Address search and reverse | Free; the keys and policy are handled on the server |
| Routing | **openrouteservice** | Route preview | Free key, car + walking |
| Images | **Pillow** | Validate, resize, strip metadata, focal point | The standard Python imaging library |
| Containerization | **Docker Compose** (Postgres only) | Optional local database | One-command database setup |
| Testing | **pytest**, **flutter_test** | Automated tests | The standard tools for each language |

---

# Part 30: Library and Dependency Master Table

## 30.1 Backend (`backend/requirements.txt`)

Version *ranges* (`>=`) are used instead of pins, so packages resolve on Python 3.14.

| Library | Version | Purpose | Where used |
|---|---|---|---|
| `fastapi` | ≥ 0.115 | Web framework | `app/main.py`, `app/api/*` |
| `uvicorn[standard]` | ≥ 0.34 | ASGI server (+ websockets support) | `uvicorn app.main:app` |
| `sqlalchemy` | ≥ 2.0.36 | ORM | `app/models/*`, services |
| `alembic` | ≥ 1.14 | Migrations | `backend/alembic/`, `app/db/schema_check.py` |
| `psycopg2-binary` | ≥ 2.9.10 | PostgreSQL driver | `DATABASE_URL` (`postgresql+psycopg2://`) |
| `pydantic` | ≥ 2.11 | Validation | `app/schemas/*` |
| `pydantic-settings` | ≥ 2.7 | Settings from `.env` | `app/core/config.py` |
| `python-jose[cryptography]` | ≥ 3.3 | JWT encode/decode | `app/core/security.py` |
| `bcrypt` | ≥ 4.2 | Password hashing | `app/core/security.py` |
| `python-multipart` | ≥ 0.0.20 | Multipart uploads (photos) and form login | `POST /media`, `/auth/login/form` |
| `email-validator` | ≥ 2.2 | `EmailStr` validation | `app/schemas/auth.py` |
| `google-auth` | ≥ 2.35 | Verify Google ID tokens; service-account OAuth tokens for FCM | `security.py`, `push.py` |
| `requests` | ≥ 2.32 | HTTP to FCM, Photon, Nominatim, ORS, Google | `push.py`, `geocoding.py`, `routing.py` |
| `tzdata` | ≥ 2024.1 | Time zone data (Windows has none) | `services/hours.py` |
| `pillow` | ≥ 11.0 | Image processing | `services/media_service.py` |
| `pytest` | ≥ 8.3 | Tests (dev) | `backend/tests/` |
| `httpx` | ≥ 0.28 | HTTP client used by `TestClient` (dev) | tests |

## 30.2 Frontend (`frontend/pubspec.yaml`, Dart SDK `^3.11.1`)

| Library | Version | Purpose | Where used |
|---|---|---|---|
| `flutter_riverpod` | ^2.6.1 | State management | everywhere |
| `go_router` | ^14.6.2 | Routing | `lib/core/router/app_router.dart` |
| `dio` | ^5.7.0 | HTTP | `lib/core/network/api_client.dart`, repositories |
| `flutter_secure_storage` | ^9.2.4 | Token storage | `lib/core/storage/token_storage.dart` |
| `google_fonts` | ^6.2.1 | Fraunces, Plus Jakarta Sans, IBM Plex Mono | `lib/core/theme/app_typography.dart` |
| `cached_network_image` | ^3.4.1 | Photo download + cache | `lib/core/widgets/image_tile.dart` |
| `shimmer` | ^3.0.0 | Loading skeletons | `lib/core/widgets/skeletons.dart` |
| `flutter_animate` | ^4.5.2 | Animations | screens and widgets |
| `maplibre_gl` | ^0.27.1 | Default map | `lib/core/maps/maplibre_map_view.dart` |
| `google_maps_flutter` | ^2.10.0 | Optional Google map | `lib/core/maps/google_map_view.dart` |
| `google_sign_in` / `google_sign_in_web` | ^7.2.0 / ^1.1.3 | Google login | `lib/features/auth/` |
| `pinput` | ^6.0.2 | 6-digit code input | `email_verification_sheet.dart`, `forgot_password_screen.dart` |
| `geolocator` | ^14.0.2 | Device location | `lib/core/location/location_service.dart` |
| `image_picker` | ^1.2.3 | Camera or gallery | `lib/core/media/photo_source.dart` |
| `url_launcher` | ^6.3.2 | Call (`tel:`), Directions (Google Maps link) | `business_detail_screen.dart`, `map_service.dart` |
| `pointer_interceptor` | ^0.10.1+3 | Taps over a Google map on the web | Google mode |
| `web` | ^1.1.1 | Load the Maps JavaScript API; service-worker messages | `maps_loader_web.dart`, `sw_messages_web.dart` |
| `web_socket_channel` | ^3.0.3 | Chat WebSocket | `lib/core/realtime/realtime_service.dart` |
| `firebase_core` | ^4.15.0 | Start Firebase | `lib/core/push/firebase_setup.dart` |
| `firebase_messaging` | ^16.7.0 | Push tokens and messages | `lib/core/push/push_platform.dart` |
| `share_plus` | ^12.0.2 | Share a business | `business_detail_screen.dart` (`_share`) |
| `cupertino_icons` | ^1.0.8 | iOS-style icons | — |
| `flutter_lints` (dev) | ^6.0.0 | Lint rules | `analysis_options.yaml` |
| `flutter_launcher_icons` (dev) | ^0.14.4 | Generate the app icons | `dart run flutter_launcher_icons` |

Android build plugins (`frontend/android/app/build.gradle.kts`): `com.android.application`,
`kotlin-android`, `dev.flutter.flutter-gradle-plugin`, and `com.google.gms.google-services` (reads
`google-services.json`).

---

# Part 31: Why These Technologies

Each answer has a **short viva answer** (say it in one breath) and a **deeper explanation** (if they
push).

## Why Flutter?

**Short viva answer:** "One codebase gives us both the Android app and the web app that the SRS
requires (OE-1, OE-2, OE-3). It has a fast, fully custom UI, which our glassy design needed."

**Deeper explanation:**

- Flutter draws its own widgets, so the cream/gold/emerald design with frosted glass and a
  floating dock looks identical on Android and web (SRS USE-2: a consistent UI).
- Hot reload sped up development, and there's a mature package ecosystem (Firebase, maps,
  WebSockets, secure storage).
- Alternatives:
  - React Native would mean JavaScript plus separate web work.
  - Native Kotlin + a separate web app would be two codebases.
- Trade-offs: larger web bundles, and some plugins behave differently on the web. Examples:
  `geolocator` timeouts needed a workaround, and Google Sign-In needs a rendered button on the
  web.

## Why FastAPI?

**Short viva answer:** "FastAPI lets us write typed Python functions that become validated REST
endpoints with automatic documentation, and it supports WebSockets for chat in the same app."

**Deeper explanation:**

- Pydantic validation from type hints gives automatic 422 errors with field messages.
- Dependency injection (`Depends(get_current_user)`) keeps authentication in one place.
- Swagger UI at `/docs` helped the team and testing.
- It runs on ASGI, so the `async` WebSocket endpoint lives next to normal REST routes.
- Alternatives: Django REST Framework (heavier, more boilerplate), Flask (needs many add-ons, and
  WebSockets aren't built in), Node/Express (a different language from the team's Python).

## Why PostgreSQL?

**Short viva answer:** "Our data is relational, with users, businesses, reviews and conversations
linked by keys, and we need constraints and transactions for integrity. PostgreSQL is the best free
relational database for that (SRS CO-3)."

**Deeper explanation:**

- Integrity:
  - unique constraints (one review per user per business, enforced by a **partial unique index**);
  - a CHECK constraint (rating 1–5);
  - foreign keys with `ON DELETE CASCADE` (account deletion);
  - transactions (the rating recalculated atomically with the review).
- Aggregations in SQL (averages, counts, group-by).
- It can grow into full-text search (`pg_trgm`, `tsvector`) and geospatial search (PostGIS).
- Why not MongoDB or Firestore: joins and constraints matter here, and NoSQL would push integrity
  rules into application code.

## Why Supabase?

**Short viva answer:** "Supabase gives us a free, managed PostgreSQL that the whole team shares, so
we didn't have to run a database server. We use it only as a Postgres host."

**Deeper explanation:**

- The backend connects with a normal `DATABASE_URL` through Supabase's connection pooler. No
  Supabase SDK, Auth or Storage is used, so we're not locked in. Any PostgreSQL works (local Docker
  and a local install are documented too).
- **Trade-off:** a shared database means teammates must coordinate migrations. The records warn to
  run `alembic upgrade head` in agreement, so nobody generates a migration from an older branch.

## Why Firebase?

**Short viva answer:** "Only for push notifications. Firebase Cloud Messaging is the free, standard
way to deliver pushes to Android and web browsers (SRS OE-10)."

**Deeper explanation:**

- Our server can't reach phones directly. FCM delivers through Google Play services on Android and
  Web Push in browsers.
- We call FCM's HTTP v1 API with a service account. We skipped `firebase-admin`, whose wheels lag
  new Python versions.
- **We deliberately didn't use** Firebase Auth or Firestore. Keeping accounts and data in our own
  backend and PostgreSQL keeps one source of truth, and lets us implement our own rules: roles,
  suspension, consent, deletion.

## Why WebSockets?

**Short viva answer:** "Chat must feel instant (SRS PER-6, under 2 s). A WebSocket lets the server
push a new message to the open app immediately, instead of the app asking every few seconds."

**Deeper explanation:**

- The socket only **announces** events (`message.new`, `conversation.read`, `typing`). Sending
  stays on REST for validation, clear errors and safe retries.
- "Has an open socket" doubles as presence, which decides between live delivery and push.
- Alternatives:
  - **Polling** is simple but slow and wasteful. We keep it only as a fallback.
  - **Server-Sent Events** are one-way only; typing goes app → server.
  - **Firebase Realtime Database or Firestore** would move chat data out of PostgreSQL.

## Why REST APIs?

**Short viva answer:** "REST is simple, stateless and standard. Each resource has a URL and each
action an HTTP method, and the SRS requires RESTful communication (CO-4)."

**Deeper explanation:**

- Clear status codes, easy testing with `TestClient`, cacheable GETs (photos are cached for a
  year), and Swagger docs.
- GraphQL would add complexity without a need. Our screens map well to resources.

## Why Docker?

**Short viva answer:** "Only to give developers a one-command local PostgreSQL. Our compose file
runs a single Postgres 16 container. The API itself isn't containerized yet."

**Deeper explanation:** this avoids "works on my machine" database differences. It's optional,
because most of the team uses the shared Supabase database. Containerizing the API (a Dockerfile) is
production work (Part 37).

## Why Google Maps, and why MapLibre now?

**Short viva answer:** "The SRS chose Google Maps for its familiarity and data. We built the SDD's
`MapService` interface around it. Google Maps needs a billing account, so the default is now MapLibre
with OpenStreetMap: free, no key, same features. Google is still one setting away."

**Deeper explanation:**

- The provider-agnostic design (`MapService` → MapLibre / Google / Sketch) proved its value when
  we switched without touching any screen.
- Address lookup and routes go through our backend (OSM Photon and Nominatim, openrouteservice),
  so keys stay server-side and results are cached and rate-limited.
- "Start in Google Maps" still gives users Google's turn-by-turn navigation through a free link.

## Why JWT?

**Short viva answer:** "JWTs are signed tokens the server can verify without a database lookup or a
session store, which suits a mobile and web client. A short-lived access token plus a long-lived
refresh token balances security and convenience."

**Deeper explanation:**

- They're stateless (any server instance with the secret can verify them), and work the same for
  REST and the WebSocket.
- The `type` claim prevents a refresh token being used as an access token.
- Trade-off: revocation is hard. A stolen token is valid until it expires, so we keep access tokens
  at 30 minutes. A future server-side session table would add rotation and revocation.

## Why SQLAlchemy and Alembic?

**Short viva answer:** "SQLAlchemy is the standard Python ORM. It writes safe, parameterized SQL
from Python, maps rows to objects, and lets us use the same models with PostgreSQL in production and
SQLite in tests. Alembic versions the schema, which a shared database needs."

**Deeper explanation:**

- SQLAlchemy 2.0's typed `Mapped[...]` models document the schema in code.
- The unit-of-work Session gives transactions.
- Relationships make joins readable.
- Alembic's `--autogenerate` and `alembic check` catch drift between models and the database.
- The 10-revision chain is the schema's history.
- Alternatives: raw SQL (more injection risk and boilerplate), Django ORM (tied to Django),
  Tortoise or SQLModel (less mature).

## Why Riverpod?

**Short viva answer:** "Riverpod gives us testable, compile-safe state management and dependency
injection. Providers can be overridden in tests, and `.family` / `.autoDispose` fit per-business and
per-conversation state."

**Deeper explanation:** it needs no `BuildContext` to read state, so controllers can use each
other. `ProviderContainer` overrides pass startup facts (Firebase ready). Compared with BLoC there's
less boilerplate; compared with Provider it's safer and easier to test.

## Bonus questions

- **Why bcrypt?** It's built for passwords: salted, slow and adjustable (Part 12).
- **Why Dio instead of `http`?** Interceptors for the JWT refresh, timeouts, multipart uploads.
- **Why store photos in PostgreSQL?**
  - SDD §5.1 says PostgreSQL stores all persistent data.
  - No extra service or credentials, and it works for the whole team on the shared database.
  - Photos are re-encoded to roughly 150–300 KB each, so about 1,500 photos fit in Supabase's free
    500 MB. Production would move them to object storage + a CDN (Part 36).
- **Why Python 3.14?** It's what the team's machines run. The SRS says "3.12 or later".

---

# Part 32: Product USPs

## 32.1 Feature by feature

| Area | In Khojlo | Unique, or standard? |
|---|---|---|
| **Business discovery** | A feed with a **new-first "Featured find"**, a "Because you like…" row, Trending, Nearby, campaign banners, rotation on refresh, "Surprise me" | **Partly unique:** new businesses deliberately get the spotlight (BR-6), unlike rating-first platforms |
| **Local discovery** | Pakistani sectors, rupee prices, `Asia/Karachi` "open now", **local-language keywords** (*darzi, dhaba, kiryana, dhobi*), Roman Urdu moderation, address search limited to Pakistan | **Unique in focus**: tuned for local Pakistani small businesses |
| **Business profiles** | Photos with automatic smart cropping (focal point), services with rupee prices, hours (including overnight), price range, offers, map, Call, Share | Mostly standard; the photo pipeline is polished |
| **Reviews** | One review per user, photos, owner replies, helpful votes, reports, **Bayesian ranking** so new businesses aren't buried | Standard features; the **fairness of the ranking** is the differentiator |
| **Chat** | Direct customer ↔ business chat **inside the discovery app**, with offers in the chat, "Seen", typing, push | **Differentiator:** Google Maps and Yelp send you to a phone call or WhatsApp |
| **Maps** | Map-area search linked to the same filters, a list/map toggle, route preview | Standard capability, nicely integrated |
| **Verification** | **Automatic** Verified badge from an email check + complete listing + **in-app storefront photo** + a clean record | **Unique approach:** a free, fast trust badge without paperwork or waiting for an admin |
| **Promotion** | Offers (deal types, scheduling) + **campaigns** with Home banners and an "Active promotion" badge, notifying savers. Free for owners | A differentiator for small businesses (no ad budget) |
| **Search and filter** | Typo-tolerant-ish (accent folding), any-word fallback, filters, 2–3 way **comparison** with winners highlighted | **Comparison** is uncommon in local apps |
| **Personalization** | Interest-based row and interest-based new-business alerts | Basic and standard |
| **AI features** | None implemented (Kai is a prototype) | Not a USP **today**. Don't claim it. |
| **Business microsites** | **Not implemented.** There's no public web page per business. Share sends text with a Google Maps link ("Found on Khojlo"). | — |

## 32.2 Why would someone use Khojlo instead of the alternatives?

- **Customers:**
  - "Show me what's **new and nearby**, at **my budget**, open **now**, and let me **compare** and
    **message** them before I go."
  - Google Maps answers "where is X?" Khojlo answers "what's new and worth trying around me?"
- **Owners:**
  - A **free** listing that's seen even with zero reviews, a **Verified** badge in minutes,
    offers and campaigns that reach people who saved the business, direct customer chat, and
    simple analytics.

## 32.3 Genuinely unique vs simply standard

- **Genuinely distinctive (the combination):**
  - new-first fairness (featuring + ranking ties + Bayesian ratings);
  - automatic storefront-photo verification;
  - chat + offers inside discovery;
  - local-language search;
  - free promotion tools for small businesses.
- **Standard (every competitor has them):** reviews, maps, search, filters, push notifications,
  saved lists, profiles.

---

# Part 33: AI Opportunities

## 33.1 AI features we already have

**None.** No machine-learning model and no LLM is called anywhere in the code. A search for
OpenAI, Anthropic, Gemini, TensorFlow, scikit-learn or LangChain in `backend/app` and
`frontend/lib` finds nothing.

What *looks* smart but is rule-based or classical:

| Feature | What it really is |
|---|---|
| Search "summary" ("3 places · mostly $ · 2 open now…") | Python rules (`summarize()` in `backend/app/services/search/engine.py`) |
| Relevance ranking | Weighted keyword scoring (`backend/app/services/search/ranking.py`) |
| Bayesian rating | A statistical formula (`ranking_score()`) |
| Spam, scam and fake-review flags | Regular expressions + thresholds (`backend/app/services/moderation_rules.py`) |
| Photo focal point | Classical image processing (an edge map with Pillow), not AI (`focal_point()` in `media_service.py`) |
| Kai chatbot | A **prototype with canned answers** (`lib/features/prototype/kai_screen.dart`) |

## 33.2 AI features planned (from the documents)

| Planned item | Source |
|---|---|
| **Kai, a RAG chatbot** answering only from platform data (FR-13, CO-6, UC-8, USE-5, PER-4 < 5 s) | Module 7, 100% phase. The use case diagram names "Claude API" (`document_review.md`, decision 6: provider still to confirm) |
| **AI moderation classifier** for listings, reviews, offers and photos | Module 8 Tier 3: "Claude through the official `anthropic` SDK, with structured outputs, behind the same interface as the rules, and off without a key", measured against admins' decisions |
| **Trust Score** | Open decision 7 (proposed: Module 8 at 100%) |
| **Personalized recommendations** from saves, views and searches (FR-22) | Module 10, 100% phase |
| **AI review summary** | Deferred to Module 7 (Module 5 record) |

## 33.3 AI features that could be added

Each card follows the brief's format.

**1. RAG chatbot (Kai)**

- **Problem solved:** "Which tailor near G-9 is open now and does bridal work under Rs 5,000?" in
  one question.
- **Technique:** Retrieval-Augmented Generation. Search the business data first (the existing
  `SearchEngine`, or embeddings), then let an LLM answer **using only** the retrieved facts, with
  citations.
- **Data required:** business listings, services, prices, hours, offers, review snippets.
- **Training dataset?** No. It uses a pre-trained LLM plus retrieval.
- **Could an LLM be used?** Yes, it's the core.
- **Architecture:**
  `POST /assistant/ask` → retrieve (`SearchEngine` / pgvector) → prompt with the retrieved rows →
  LLM → answer + business cards.
  Keep the key server-side, rate-limit it, and log the questions.
- **Difficulty:** medium.

**2. Semantic search**

- **Problem:** "romantic dinner" or "cheap desi breakfast" don't match keywords.
- **Technique:** text embeddings for businesses and queries, with vector similarity (pgvector in
  PostgreSQL), combined with the current keyword score.
- **Data:** listing text.
- **Training?** No (a pre-trained embedding model).
- **LLM?** An embedding model, not a chat LLM.
- **Architecture:** a `SemanticSearch` strategy plugged into `SearchEngine`. The Strategy pattern
  makes this a clean addition.
- **Difficulty:** medium.

**3. Personalized recommendations (FR-22)**

- **Problem:** show each user what they're likely to enjoy.
- **Technique:** start with content-based scoring (interests + categories of saved and viewed
  places). Later, collaborative filtering (matrix factorization) or two-tower models.
- **Data:** `business_views`, `saved_businesses`, `search_queries`, reviews, `users.interests`.
  Khojlo already collects most of these.
- **Training?** Yes for collaborative filtering (interaction logs); no for content-based.
- **LLM?** Optional (to explain "why").
- **Architecture:** a nightly job computes recommendations into a table; the feed reads it.
- **Difficulty:** medium to high.

**4. Fake review detection**

- **Problem:** sock-puppet and bought reviews (Part 14).
- **Technique:** supervised classification on behaviour (account age, burst timing, rating
  deviation, device or IP clusters) and text (LLM or embeddings). Start with the existing rules
  plus an LLM judge.
- **Data:** reviews + **admin decisions as labels**. Module 8 stores every uphold or dismiss, which
  is exactly a labelled dataset.
- **Training?** For an ML model, yes (the labels exist). For an LLM classifier, no, but evaluate it
  against the labels.
- **Architecture:** a classifier behind the same `ModerationFlag` interface. It flags only; an
  admin decides.
- **Difficulty:** medium.

**5. Review summarization**

- **Problem:** nobody reads 200 reviews.
- **Technique:** LLM summarization ("Customers love the chai; service is slow at night").
- **Data:** the reviews.
- **Training?** No.
- **LLM?** Yes.
- **Architecture:** cache one summary per business; refresh on new reviews.
- **Difficulty:** low to medium.

**6. AI-generated business profiles**

- **Problem:** owners write poor descriptions.
- **Technique:** an LLM drafts a tagline, description and service list from a few answers or
  photos; the owner edits it.
- **Training?** No.
- **Architecture:** a "Help me write" button in the stepper → a backend endpoint → the LLM.
- **Difficulty:** low.

**7. Business categorization**

- **Problem:** "Other" listings and wrong categories.
- **Technique:** zero-shot classification with an LLM, or embeddings + nearest category.
- **Data:** the category catalogue + the listing text.
- **Training?** No for zero-shot.
- **Difficulty:** low.

**8. Intelligent chatbot / lead qualification for owners**

- **Problem:** owners miss or repeat answers.
- **Technique:**
  - LLM-suggested replies grounded in the owner's own listing (the chat already has static
    suggested replies);
  - intent classification ("price question", "booking", "complaint").
- **Data:** conversations. **Privacy:** only with consent and a policy update; private chat text
  is currently never scanned, by design.
- **Difficulty:** medium.

**9. Voice agent**

- **Problem:** voice search in Urdu.
- **Technique:** speech-to-text (an ASR model supporting Urdu) → the same search or RAG pipeline →
  optional text-to-speech.
- **Training?** No (pre-trained ASR).
- **Difficulty:** medium to high (Urdu and Roman Urdu quality).

**10. Business analytics insights**

- **Problem:** owners don't know why views drop.
- **Technique:** trend detection on `business_views`, saves and messages, plus an LLM narrative ("Views
  dropped 30% since your hours changed").
- **Data:** the analytics tables.
- **Difficulty:** medium.

**11. Fraud detection** (scam listings, payment scams)

- **Technique:** extend the rules with ML on account and listing signals, and image checks (does the
  storefront sign match the name? This is the planned Module 8 100% feature).
- **LLM?** A vision-capable LLM for the storefront check.
- **Difficulty:** medium.

**12. Location intelligence**

- **Problem:** where demand outstrips supply; "areas trending for cafés".
- **Technique:** aggregate searches with no results (`search_queries.result_count = 0`) by area, and
  heatmaps of views.
- **Training?** No.
- **Difficulty:** low to medium.

**Architecture principle for all of these** (already used for maps and push): put each AI provider
behind an interface with a "null" fallback, keep keys server-side, cache results, rate-limit, never
let the AI act alone on moderation, and update the privacy policy before using new data.

---

# Part 34: Datasets and Research

## 34.1 Datasets used today

**No external or training dataset is used, and no model was trained.** Say so plainly if asked.

What the project does have:

- **Demo (seed) data** in `backend/app/db/seed.py`. It's a hand-written catalogue:
  - demo businesses across Islamabad sectors and Abbottabad (including the four tailors from the
    SDD's "unstitched fabric" mockup);
  - rupee prices, hours, services, offers and three campaigns;
  - 12 demo reviewer accounts writing 3–8 reviews per catalogue business (the Module 5 record
    reported 167 reviews at the time);
  - demo conversations and moderation examples.
- **Demo photos** in `backend/app/db/demo_photos/`: openly licensed photos found through
  **Openverse** (CC BY, CC BY-SA, CC0), credited in `backend/app/db/demo_photos/CREDITS.md`.
- **Category catalogue:** 25 categories in 5 groups, plus local keyword lists, written by the team
  (migration `b7d3f1a9c2e4`).

## 34.2 Data we would need for AI features

| Data | Where it comes from in Khojlo | Used for |
|---|---|---|
| Business data (name, category, services, prices, hours, location) | `businesses`, `services`, `opening_hours`, `categories` | RAG, semantic search, categorization |
| Reviews and ratings | `reviews`, `review_votes` | Summaries, fake-review detection, trust |
| Moderation labels | `moderation_actions`, `moderation_flags`, `*_reports` (status upheld or dismissed) | **Supervised labels** for fake and spam detection |
| User behaviour: views, saves, searches | `business_views`, `saved_businesses`, `search_queries` (with filters and result counts) | Recommendations, trends, demand gaps |
| Interests | `users.interests` | Cold-start personalization |
| Location | Business coordinates, **not** user locations (they're never stored, SEC-7) | Location intelligence (aggregated) |
| Conversations | `messages`, **only with explicit consent and a policy change** | Reply suggestions, lead intent |
| Clicks, follows | **Not collected today** (no click tracking, no follow feature) | Would need new tracking + consent |

## 34.3 Possible public datasets and APIs (future research; none used yet)

| Source | What it offers | Caveat |
|---|---|---|
| OpenStreetMap / Overpass API | Points of interest (shops, restaurants) in Pakistan | Free (ODbL licence). Coverage of small shops varies. |
| Yelp Open Dataset | Businesses + reviews (US/Canada), widely used in recommendation research | Licence restricts use; not Pakistan |
| Deceptive Opinion Spam corpus (Ott et al.) | Labelled truthful vs fake hotel reviews | English, a small domain |
| Public review datasets (Amazon, Google Local reviews) | Large review corpora for training or evaluation | Licensing; domain mismatch |
| Roman Urdu text datasets (e.g. sentiment corpora on Kaggle or UCI) | Roman Urdu language data | Check licences and quality |
| Google Places API | Rich business data | Paid; terms restrict storage |

**Honest research position** (matching the Module 8 plan's reasoning): there's no labelled Khojlo
data yet. Content mixes English, Urdu and Roman Urdu, where English-only public datasets transfer
poorly. So rules come first, admin decisions become the labelled dataset, and any AI model is
evaluated on precision and recall against those decisions.

---

# Part 35: Limitations

| Category | Limitation | How to improve |
|---|---|---|
| **Technical** | In-memory socket registry, caches and rate limiters → one API process only; a restart drops them | Redis pub/sub (or PostgreSQL `LISTEN/NOTIFY`) + Redis caches and limits |
| | No scheduler (trending digest, promotion notices) | Cron, APScheduler or a worker queue |
| | Photos stored in the database | Object storage (S3, Supabase Storage) + a CDN |
| **Security** | No login rate limit; no token revocation; HTTP in development; public media URLs; debug-signed release builds; a default `SECRET_KEY` fallback | Part 13 fixes |
| **Scalability** | Search and feed load **all** candidates into Python, then rank and page; the duplicate check scans every business; pushes are sent one at a time | PostgreSQL full-text search / `pg_trgm` / PostGIS with SQL ranking and paging; batch FCM sends via a worker |
| **UX** | Customers can't upgrade to owners; the owner dashboard opens only the first business; launching offline signs you out; no offline caching; no "Save draft" in registration; iOS push missing | A role upgrade endpoint; a business switcher; only clear tokens on 401; a local cache; drafts; APNs setup |
| **AI** | None implemented; Kai is a prototype | Part 33 |
| **Data** | Demo data only; no click tracking; no Pakistan-specific labelled datasets | Pilot with real businesses; collect admin labels |
| **Testing** | No CI; SQLite instead of Postgres in tests; no end-to-end, load or security tests; external services faked | GitHub Actions running pytest + flutter test + a Postgres service container; integration tests; Locust/k6 load tests |
| **Deployment** | Not deployed: no Dockerfile, no hosting, no HTTPS, no monitoring | Part 37 |
| **Fake reviews** | No visit verification; cheap accounts; the burst rule misses slow attacks | Part 14.5 |
| **Recommendations** | Interest row only; no activity signals | Part 33 (3) |
| **Chat** | Single worker; no message edit or delete; no per-message delivery ticks; no group chat; not end-to-end encrypted; text-only + photos | Pub/sub, delivery receipts, edit and delete with an audit trail |
| **Notifications** | Android + web only; web needs HTTPS or localhost; sequential sends; the digest is manual; no analytics | APNs, batching, scheduling, delivery metrics |
| **Maps** | Depends on donation-funded OpenFreeMap and public Nominatim (rate-limited); travel times without live traffic | Self-host a Pakistan tile extract (PMTiles) and Nominatim/Photon; paid routing if needed |

---

# Part 36: Scalability

## 36.1 What the current FYP implementation does

- **One** FastAPI process (`uvicorn`, no `--workers`), because live chat events and caches live in
  memory.
- **One** shared PostgreSQL (Supabase), through the pooler, with indexes on foreign keys and the
  common filters.
- Feed and search: **fetch every candidate** that passes the SQL pre-filter, then rank and page in
  Python. Module 4 tested 500 businesses within the time limit.
- Denormalized counters (`rating`, `review_count`, `view_count`, `save_count`) keep list reads
  cheap. The admin overview computes its numbers in **one** query.
- Pushes go one request per token in a background task. Geocoding and routing are cached for
  24 h / 6 h in memory, with per-user limits.
- Photos are stored in PostgreSQL and served with year-long cache headers.

## 36.2 Growing the system

| Users | What breaks first | What production Khojlo would need |
|---|---|---|
| **100** (FYP demo) | Nothing. The current design is fine. | — |
| **10,000** | Feed and search loading all businesses per request; sequential pushes to many tokens; database size from photos; one process's CPU | **Search:** do ranking and paging in SQL (full-text search with `tsvector` + GIN, `pg_trgm` for fuzzy matching, PostGIS for distance). **Feed:** cache feed rows for a few minutes. **Photos:** move to object storage + a CDN. **Workers:** a worker queue (Celery/RQ/Arq) for push and email. Add monitoring (logs, error tracking). |
| **100,000** | One API process; in-memory WebSocket registry; in-memory rate limits and caches; database connections | **Several API instances** behind a **load balancer** (sticky or not). **Redis** for WebSocket pub/sub (fan-out across instances), rate limits and caches. Separate WebSocket servers from REST if needed. PgBouncer pooling, read replicas for heavy reads. FCM batch sending. A proper scheduler (digests, promotions). Alerts and SLO monitoring (PER-1–PER-6). |
| **1,000,000** | Database write load (messages, views); search relevance and latency; notification fan-out | Partition or archive big tables (`messages`, `business_views`, `search_queries`). A dedicated search engine (OpenSearch/Elasticsearch, or vector search for semantic queries). Event streaming (Kafka) for analytics. CDN everywhere. Multi-region if needed. Autoscaling containers (Kubernetes / a managed container service). A cost-aware push strategy (topics or segments). |

## 36.3 Topic by topic

- **Database:** good indexes now. Next: SQL-side ranking, PostGIS, partitioning, replicas, pooling.
- **API:** stateless REST already (JWT), so it scales horizontally once the in-memory state moves to
  Redis.
- **WebSockets:** the main blocker. The in-memory `ConnectionManager` needs a pub/sub backbone
  (the code's own docstring suggests PostgreSQL `LISTEN/NOTIFY`).
- **Notifications:** move `PushJob`s to a worker queue; batch; drop dead tokens (already done).
- **Caching:** the current in-memory TTL caches → Redis. Cache the feed per area and seed.
- **File storage:** photos out of PostgreSQL → object storage + CDN, with signed URLs for private
  storefront photos.
- **Search:** SQL full-text + trigram + PostGIS, then a search engine at large scale.
- **Background jobs:** a queue + scheduler instead of `BackgroundTasks` and manual commands.
- **Load balancing:** a reverse proxy (Nginx/Caddy) or a cloud load balancer with TLS and
  WebSocket support.
- **Monitoring:** structured logs, metrics (Prometheus/Grafana), error tracking (Sentry), uptime
  checks. **None exist today.**
- **Rate limiting:** global per-IP and per-user limits (Redis), especially on auth and uploads.
- **Horizontal scaling:** possible after removing in-process state (sockets, caches, limiters).

---

# Part 37: Deployment

## 37.1 How the project runs today

**Khojlo is not deployed to production.** There is no Dockerfile for the API, no CI/CD, no hosting
configuration, no domain and no HTTPS setup in the repository.

| Part | How it runs now |
|---|---|
| **Backend** | On a developer's machine: `cd backend && uvicorn app.main:app --reload` on port 8000, as **one process** |
| **Database** | The team's **shared Supabase PostgreSQL** (via `DATABASE_URL`), or a local Postgres (Docker or a local install). The schema comes from `alembic upgrade head`; demo data from `python -m app.db.seed` |
| **Frontend** | `flutter run --dart-define-from-file=dart_defines.json` on the Android emulator, a physical phone (with `adb reverse`) or Chrome. `flutter build web --release` and `flutter build apk --debug` work (Module 9 record). |
| **Firebase** | A real Firebase project (`khojlo-c5ba0`) for FCM and the Google OAuth clients. The service account key is on the developer's machine. |
| **Environment variables** | `backend/.env` + `backend/secrets/` (shared privately per `docs/team_setup.md`); `frontend/dart_defines.json` |
| **Docker** | Optional local Postgres only |
| **Android release** | Signed with the **debug** key (a TODO in `build.gradle.kts`), so it's not ready for the Play Store |

## 37.2 What a production deployment would need

1. **API container:** a Dockerfile (Python 3.14 image, `pip install -r requirements.txt`,
   `uvicorn app.main:app --host 0.0.0.0`). Run it on a host (a VPS, Render, Railway, Fly.io, or a
   cloud container service).
2. **HTTPS and WSS:** a reverse proxy (Caddy or Nginx) with TLS certificates. Build the app with
   `KHOJLO_API=https://api.<domain>/api/v1`; the WebSocket becomes `wss://` automatically (SEC-4).
3. **Production settings:**
   - a strong `SECRET_KEY` (and fail on the default);
   - real CORS origins only;
   - disable `/docs` if desired;
   - `SCHEMA_CHECK_ON_STARTUP` on;
   - secrets in the host's secret manager, not files.
4. **Database:** Supabase (paid tier or backups) with `alembic upgrade head` in the deployment
   pipeline.
5. **Single worker, or Redis:** keep one worker for chat until pub/sub exists (Part 36).
6. **Scheduler:** cron for `python -m app.jobs.trending_digest` and `python -m app.jobs.promotions`.
7. **Web app:** `flutter build web` → static hosting (Firebase Hosting, Netlify or a CDN). Add the
   web domain to CORS, to the Firebase browser-key referrers, and to the Google OAuth origins.
8. **Android:** a release keystore + signing config (keep `key.properties` out of git; it's already
   ignored). Register the release SHA-1 for Google Sign-In (and Google Maps if used). Publish via
   Play Console (the in-app account deletion required by Play already exists).
9. **Maps and geocoding:** set a contactable `GEOCODING_USER_AGENT`. Consider self-hosting tiles and
   geocoding for production load.
10. **Monitoring and CI:** run the test suites on every push (GitHub Actions); add error tracking and
    uptime checks.

## 37.3 Local development vs production

| | Local development (today) | Production (needed) |
|---|---|---|
| URL | `http://localhost:8000`, `10.0.2.2:8000` | `https://api.<domain>` |
| Transport | HTTP / WS | HTTPS / WSS |
| Process | `uvicorn --reload`, one process | Container, one worker (or more with Redis), auto-restart |
| CORS | Any localhost port | Exact origins |
| Secrets | `.env` and files on laptops | Secret manager |
| Android signing | Debug key | Release keystore |
| Monitoring | Console logs | Logs + metrics + alerts |

---

# Part 38: Git and Project Management

## 38.1 Branches and workflow (from `git branch -a` and `git log`)

- **`main`:** the GitHub default branch (`origin/HEAD → origin/main`). It's **29 commits behind
  `dev`**, so it shows only the earlier build.
- **`dev`:** the integration branch. Every feature branch has been merged into it.
- **Feature branches** (all merged into `dev`): `feat/notification` (PR #15, chat + push), `temp`
  (PR #17, offers + Module 8), `feat/privacy-consent` (PR #18), `brand-visuals` (PR #19),
  `maps-maplibre` (PR #20); locally also `feat/consent-form`.
- **Workflow:** branch from `dev` → build the module with its record in
  `docs/development_roadmap/` → open a pull request into `dev` → merge. Teammates sometimes merged
  `dev` into their branch first to resolve conflicts (e.g. "Merge origin/dev (offers, campaigns,
  Module 8) into feat/privacy-consent").
- **Commit style:** mostly conventional prefixes (`feat:`, `feat(auth):`, `feat(doc):`,
  `fix(refactor):`), plus some plain messages ("Fix some buggs", "add Module 8: …").

## 38.2 The `.gitignore` (root) and what it protects

| Ignored | Why |
|---|---|
| `backend/.env`, `.env` | Real settings and secrets |
| `secrets/`, `**/firebase-service-account*.json`, `**/*-service-account*.json` | The Firebase private key |
| `frontend/dart_defines.json` | Build-time keys and config |
| `backend/.venv/`, `backend/venv/`, `__pycache__/`, `.pytest_cache/` | Local Python environments and caches |
| `frontend/build/`, `.dart_tool/`, `GeneratedPluginRegistrant.*`, `ios/Pods/` | Build outputs |
| `frontend/android/local.properties`, `key.properties` (+ `*.keystore`, `*.jks` in `android/.gitignore`) | Machine paths and signing keys |
| `*.sqlite3`, `*.db` | Local databases |
| `.idea/`, `.vscode/`, `.claude/` | Editor settings (but `.claude/launch.json` and `frontend/.claude/launch.json` are tracked anyway, document review item G9) |

## 38.3 What should and shouldn't be committed

| Commit ✅ | Never commit ❌ |
|---|---|
| Source code, tests, migrations | `backend/.env` |
| `backend/.env.example`, `frontend/dart_defines.example.json` (placeholders only) | `backend/secrets/firebase-service-account.json` |
| `frontend/android/app/google-services.json` (public client config) | `frontend/dart_defines.json` (team choice; not strictly secret) |
| `pubspec.lock` (reproducible Flutter builds) | Keystores / `key.properties` |
| Docs, design files, brand assets | Database dumps, `*.db`, build outputs, virtual environments |

Leak response is documented in `docs/team_setup.md` → "If something leaks" (rotate the Supabase
password, revoke the Firebase key, regenerate `SECRET_KEY`, revoke the Gmail app password, rotate
Maps keys).

## 38.4 Project management practices you can mention

- **Requirements traceability:** every module record starts with its SRS/SDD sources and "What the
  documents ask for", then the decisions (with dates), the plan, the implementation record, the
  tests and the rollout notes.
- **Documentation review:** `docs/requirements/document_review.md` tracks every inconsistency and
  open decision.
- **The shared-database discipline:** migrations run on the shared Supabase database must be
  coordinated. The records warn not to generate a migration from an older branch, because Alembic
  would see the revision history diverge.
- **The definition of done** for each module (from the records): backend + frontend tests pass,
  `flutter analyze` is clean, the migration is tested up/down/up on PostgreSQL, the seed is
  idempotent, and a browser run is done.
- **Process:** the SRS states Agile/Scrum (CO-8). The iterations are the 30% / 60% / 100%
  evaluations. *Sprint artefacts (boards, burndown charts) are not in the repository: not
  confirmed from codebase.*

---

# Part 39: Viva and Defense Question Bank

Format: **Q** → *Short answer* (what to say first) → *Deeper* (if they push) → *In Khojlo* (the
evidence).

## Product questions

**Q1. What is Khojlo, in one sentence?**

- *Short:* A Flutter mobile and web app with a FastAPI backend that helps people discover new and
  underrated local businesses, and helps those businesses get visible: discovery feed, search,
  comparison, reviews, maps, chat and push notifications.
- *Deeper:* It targets the "cold start" problem of new businesses on rating-first platforms.
- *In Khojlo:* `README.md`, SRS §1.2–2.1.

**Q2. Who are your users?**

- *Short:* Customers, business owners and admins.
- *In Khojlo:* `UserRole` in `backend/app/models/user.py`. Admins can't sign up
  (`_no_self_service_admin`).

**Q3. How are you different from Google Maps or Yelp?**

- *Short:* We deliberately give new businesses visibility (the newest are featured, and ties in
  search favour new ones), rank ratings with a Bayesian formula so a few reviews don't dominate,
  allow side-by-side comparison, and let customers chat with the business inside the app.
- *In Khojlo:* `_featured()` in `api/feed.py`; `rank()` in `services/search/ranking.py`;
  `ranking_score()`; `api/compare.py`; `api/chat.py`.

**Q4. How exactly do you "prioritize new businesses"?**

- *Short:* Three ways: the Featured find is a weighted random pick from the 8 newest; when search
  relevance ties, newer wins; and businesses carry a "New" badge for 30 days.
- *Deeper:* We don't let newness beat a better keyword match. That would make search useless.
- *In Khojlo:* `FEATURED_POOL = 8`, `NEW_BUSINESS_DAYS = 30`, the relevance sort key in `rank()`.

**Q5. What is out of scope?**

- *Short:* Ordering, payments, delivery and booking (SRS CO-10); iOS push (CO-11, needs a paid Apple
  account).

**Q6. How does a business get the Verified badge?**

- *Short:* Automatically, when four checks pass: email verified, listing complete, a storefront
  photo taken in the app, and no open report or flag. If only the last check fails, an admin
  reviews it.
- *In Khojlo:* `checks()` and `refresh()` in `backend/app/services/verification_service.py`.

## Architecture questions

**Q7. Explain your architecture.**

- *Short:* A three-tier client–server system. The Flutter app talks to a FastAPI backend over REST
  (plus one WebSocket for live chat events). The backend applies the business rules and stores
  everything in PostgreSQL through the SQLAlchemy ORM. External services: FCM for push, Google for
  sign-in tokens, SMTP for emails, and OpenStreetMap services for maps and addresses.
- *In Khojlo:* Part 5 diagram; `backend/app/main.py`.

**Q8. Does the Flutter app connect directly to PostgreSQL or Supabase?**

- *Short:* **No.** Only the backend connects to the database, using `DATABASE_URL`. The app only
  calls our API.
- *Deeper:* That keeps credentials off devices and puts all rules and permissions in one place.

**Q9. Monolith or microservices?**

- *Short:* A modular monolith: one FastAPI app with routers and services per module. That's right
  for our team size and scale; modules could be split out later.

**Q10. Which design patterns did you use?**

- *Short:*
  - **Strategy** for search (from the SDD);
  - **adapter/interface** for providers (`MapService`, `Geocoder`, `Router`, `PushSender`), with a
    **Null object** fallback (`NullSender`, `SketchMapService`);
  - **Repository** in Flutter;
  - **dependency injection** (FastAPI `Depends`, Riverpod);
  - **observer** (streams for live events);
  - **unit of work** (the SQLAlchemy Session).

**Q11. How did you replace Google Maps without rewriting screens?**

- *Short:* Screens only use the `MapService` interface. We added a `MapLibreService`
  implementation and changed which one `mapServiceProvider` returns.
- *In Khojlo:* `lib/core/maps/map_service.dart`.

## Flutter questions

**Q12. Which state management did you use, and why?**

- *Short:* Riverpod 2: compile-safe, testable with overrides, and `.family` / `.autoDispose` fit
  per-item state.
- *In Khojlo:* `authControllerProvider` (a StateNotifier), `feedProvider` (a FutureProvider),
  `conversationControllerProvider(id)` (autoDispose.family).

**Q13. How does navigation handle login, consent and admin?**

- *Short:* go_router's `redirect`:
  - unknown session → splash;
  - signed out → onboarding;
  - signed in without consent → the consent screen;
  - admin routes → admins only.

  The router refreshes when the auth state changes.
- *In Khojlo:* `lib/core/router/app_router.dart`.

**Q14. How are tokens attached to requests, and refreshed?**

- *Short:* A Dio interceptor adds `Authorization: Bearer`. On a 401 it calls `/auth/refresh` once,
  saves the new pair and retries the request.
- *In Khojlo:* `ApiClient` in `lib/core/network/api_client.dart`.

**Q15. Where are tokens stored?**

- *Short:* In `flutter_secure_storage`: Keystore-backed encrypted storage on Android, browser
  storage on the web. Never in plain SharedPreferences.

**Q16. How does the app know the backend URL?**

- *Short:* `ApiConfig.baseUrl`: the `KHOJLO_API` dart-define if it's set, else `10.0.2.2:8000` on
  the Android emulator and `localhost:8000` elsewhere.

**Q17. How do you show loading and errors?**

- *Short:* `AsyncValue` from Riverpod: skeletons while loading, an error card with Retry on
  failure. `describeApiError()` shows the server's message or "Can't reach the server…".

## Backend questions

**Q18. Why FastAPI?**

- *Short:* Typed endpoints with automatic validation and Swagger docs, dependency injection for
  auth, and WebSocket support. See Part 31.

**Q19. Walk me through a request.**

- *Short:* uvicorn → CORS middleware → the router function → Pydantic validates the body → the
  `Depends` functions give us the DB session and the current user → the service logic → the ORM
  queries → commit → the response model → JSON. Background tasks then run (emails, pushes).

**Q20. What is `Depends`?**

- *Short:* FastAPI's dependency injection. It runs a function before the endpoint and passes in
  its result, for example `user: User = Depends(get_current_user)`.

**Q21. How do you validate input?**

- *Short:* Three layers:
  1. Pydantic field rules (automatic 422);
  2. custom validators (no admin sign-up, HH:MM, phone digits, price order, the lat/lng pair);
  3. database-aware checks in the routes (ownership, duplicates).

**Q22. What do background tasks do?**

- *Short:* Work done after the response is sent: emails, push notifications, WebSocket broadcasts,
  counting views.
- *In Khojlo:* `BackgroundTasks.add_task(...)` in `auth.py`, `chat.py`, `businesses.py`,
  `reviews.py`.

## Database questions

**Q23. Which database, and where is it?**

- *Short:* PostgreSQL. The team shares a database hosted by Supabase. Developers can also run it
  locally with Docker or a normal install. Tests use in-memory SQLite.

**Q24. Which ORM, and how are queries generated?**

- *Short:* SQLAlchemy 2.0. We build queries in Python (`select(User).where(...)`), and SQLAlchemy
  compiles them to parameterized SQL for PostgreSQL.

**Q25. How many tables? Name the important relationships.**

- *Short:* 28 tables.
  - User → businesses (owner).
  - Business → services, hours, photos, offers, campaigns, reviews, conversations.
  - Conversation → messages.
  - User → reviews, saved lists, devices, notifications.

**Q26. How do you guarantee one review per user per business?**

- *Short:* Twice:
  1. The API checks for an active review (409).
  2. The database has a partial unique index on (user_id, business_id) WHERE `deleted_at IS NULL`,
     which also stops race conditions.

**Q27. What are migrations? How many do you have?**

- *Short:* Versioned scripts that change the schema step by step. We have 10 Alembic revisions,
  from the initial schema to privacy consent. `alembic upgrade head` applies them.

**Q28. Where are photos stored?**

- *Short:* In PostgreSQL, in the `media` table (as binary columns), after Pillow processing. The SDD
  says PostgreSQL stores all persistent data; production would move them to object storage.

**Q29. Show me a transaction.**

- *Short:* `create_review()`: insert the review, its photos, the recalculated rating, any
  moderation flags and the owner's notification, all with a single `commit()`. A duplicate raises
  `IntegrityError` → rollback → 409.

**Q30. Show me a JOIN and an aggregation.**

- *Short:* `unread_by_conversation()` joins messages with conversations and counts unread messages
  per conversation (GROUP BY). `refresh_rating()` computes `AVG(rating)` and `COUNT(*)`.

**Q31. Do you use soft deletes?**

- *Short:* Yes, for reviews, offers and campaigns (`deleted_at`). Everything else is hard-deleted
  with cascades (account deletion has to really delete).

## API questions

**Q32. How many endpoints?**

- *Short:* 98 HTTP endpoints and 1 WebSocket under `/api/v1`, in 14 routers, plus `/health` and
  `/`.

**Q33. Which HTTP status codes do you return, and when?**

- *Short:* 201 created, 204 no content, 400, 401 unauthenticated, 403 forbidden, 404 (including
  hiding private chats), 409 conflict (duplicates), 413 too large, 422 validation, 429 rate
  limit, 502 provider failed, 503 not configured.

**Q34. How is the API documented?**

- *Short:* FastAPI generates OpenAPI and Swagger UI at `/docs`. The module records list every
  endpoint.

**Q35. Which endpoints are public?**

- *Short:* 15 are fully public (auth entry points, categories, surprise, suggestions, popular
  searches, compare, photos). 7 work signed in or out (feed, search, business detail, reviews list,
  offers, campaigns). Everything else needs a token.

## Authentication questions

**Q36. How are passwords hashed?** bcrypt with a random salt (`hash_password()`). Never stored in
plaintext. (Part 12.)

**Q37. What is in your JWT?** `sub` (the user id), `type` (access, refresh or password_reset),
`iat` and `exp`, signed with HS256 and `SECRET_KEY`. It's not encrypted, so no secrets are inside.

**Q38. What are the token lifetimes?** Access 30 minutes, refresh 14 days, password reset 10
minutes.

**Q39. How does refresh work?** On a 401, the app calls `POST /auth/refresh` with the refresh token
and gets a new pair (`ApiClient._tryRefresh()`).

**Q40. How does logout work?** Client-side: the app unregisters the push device and deletes the
stored tokens. JWTs are stateless, so there's no server session to destroy. That's a known gap
(revocation).

**Q41. How does Google Sign-In work?** The app gets a Google ID token. The backend verifies its
signature, audience (our web client ID) and issuer with `google-auth`, then finds, links or creates
the user and returns **our** JWTs.

**Q42. How do email verification and password reset work?** 6-digit codes, stored as HMAC hashes,
with a 10-minute expiry, a 45-second resend cooldown, 5 per day and 5 attempts. Reset swaps the code
for a 10-minute reset JWT.

**Q43. How do you stop admins being created by sign-up?** The `RegisterRequest` validator rejects
`role=admin`. Admins come from the seed or the database.

**Q44. What happens when an account is suspended?** `ensure_active()` makes every request return
403 with the reason, no new tokens are issued, and the WebSocket refuses it.

## Security questions

**Q45. How do you prevent SQL injection?** Every query goes through SQLAlchemy with bound
parameters. LIKE wildcards in user input are escaped.

**Q46. What about XSS?** Flutter renders text, not HTML, so user content can't run scripts in the
app. Emails escape user text (`html.escape`).

**Q47. What is CORS, and how is it configured?** Browsers block calls to other origins unless the
server allows them. We allow the configured origins plus any `http://localhost:<port>` for
development. Production should list exact HTTPS origins.

**Q48. Do you rate-limit?** Partly: one-time codes (cooldown and daily cap), geocoding (60 per
10 min per user) and routes (30 per 10 min). Not login or global traffic: a known gap.

**Q49. How are secrets managed?** `.env` and the `secrets/` folder are git-ignored. Templates are
committed with placeholders. `docs/team_setup.md` lists what to share privately and how to rotate
after a leak.

**Q50. Is your system secure?** "We applied standard protections: bcrypt, signed short-lived JWTs,
server-side authorization, validation, parameterized SQL and secrets out of git. The known gaps are
login rate limiting, token revocation, HTTPS in deployment and private media URLs. Our plan for
each is …" (Part 13).

## Firebase questions

**Q51. What do you use Firebase for?** Only Firebase Cloud Messaging (push). Not auth, not a
database, not storage.

**Q52. Why not the Firebase Admin SDK?** Its wheels lag new Python versions. We call the FCM HTTP v1
REST API directly with a service-account OAuth token (`FcmSender`), which is the same API the SDK
uses.

**Q53. What's the difference between `google-services.json` and the service account file?** The
first is a public client configuration for the Android app (committed). The second holds a private
key that lets the server send pushes (secret, git-ignored).

**Q54. What if the Firebase keys are missing?** The backend uses `NullSender` (push off) and the app
skips push. Everything else works.

## Chat questions

**Q55. Who can start a conversation?** Only customers, from a business page. Owners reply. An owner
can't message their own business (403).

**Q56. How are messages stored?** In PostgreSQL: `conversations` (one per customer-business pair,
with read markers) and `messages` (sender, `from_business`, body, optional photo, `client_id`,
time).

**Q57. How do you compute unread counts?** Each conversation stores each side's last-read message id.
Unread = messages from the other side with a higher id (a JOIN + COUNT query).

**Q58. How do you prevent duplicate messages on retry?** The app sends a random `client_id`.
`(conversation_id, client_id)` is unique, and the server returns the existing message for a repeat.

**Q59. Can other users read a conversation?** No. Non-participants get 404. Admins can read a
conversation only after a participant reports it.

**Q60. What happens if the recipient is offline?** The message is saved first. They get an FCM push,
and the history loads from the database when they open the app.

## WebSocket questions

**Q61. What is a WebSocket?** A long-lived, two-way connection, so the server can push events
instantly. REST is request → response only.

**Q62. Why do you still send messages over REST?** For validation, clear status codes, a database
write before delivery, safe retries and easy testing. The socket only announces events.

**Q63. How is the WebSocket authenticated?** The first message must be `{type: "auth", token}`
within 10 seconds. The token is checked as an access token. Failure → close with code 4401. The
token isn't in the URL, because URLs get logged.

**Q64. What happens when the connection drops?** The app reconnects with backoff (1→30 s). An open
chat polls every 8 s meanwhile. On 4401 it refreshes the token once.

**Q65. How does the server know whom to send an event to?** `ConnectionManager` maps user ids to
their open sockets. It sends `message.new` to both participants' sockets.

**Q66. What's the scaling problem with your WebSocket design?** The socket registry is in memory, so
the API must run as one process. To scale out, add Redis pub/sub or PostgreSQL `LISTEN/NOTIFY`
between instances.

## Notification questions

**Q67. What is FCM?** Google's free push delivery service, for Android and web.

**Q68. What is a device token, and where is it stored?** An address for this app on this device,
created by the Firebase SDK on the device, registered with `PUT /notifications/devices` and stored in
`device_tokens`.

**Q69. When do you push, and when do you deliver live?** Live over the WebSocket if the recipient has
a socket open. For chat, a push is sent only when they don't.

**Q70. What happens when a notification is tapped?** It carries `data.route`. The app opens that
screen (`PushController._open()`); on the web, the service worker focuses or opens the tab.

**Q71. Can users turn notifications off?** Yes: five switches (messages, reviews, offers, new places,
trending). Account and verification notices can't be switched off.

**Q72. What happens to dead tokens?** FCM reports them (404 / UNREGISTERED …), and `PushJob` deletes
them.

## Google Maps questions

**Q73. Which map do you use?** MapLibre with OpenStreetMap tiles from OpenFreeMap by default; Google
Maps is optional (`MAP_PROVIDER=google`).

**Q74. Why not Google Maps?** It needs a billing account, which we couldn't set up. MapLibre is free,
has no key, and our `MapService` interface made switching easy.

**Q75. How do you get an address from a pin?** `GET /geo/reverse` → backend → Nominatim (cached
24 h, ≥ 1 s between calls, rate-limited per user).

**Q76. How do you validate coordinates?** In range, both or neither, and not (0, 0) (BR-7).

## Docker questions

**Q77. What does your docker-compose file do?** Starts a single PostgreSQL 16 container for local
development, with a named volume and a healthcheck.

**Q78. Is your API containerized? Is Docker used for deployment?** No and no. There's no Dockerfile,
and there's no deployment yet.

## Environment variable questions

**Q79. What is `.env`, and why isn't it in git?** It holds the real settings and secrets
(`DATABASE_URL`, `SECRET_KEY`, the SMTP password, API keys). Committing it would leak them.
`.env.example` is the committed template.

**Q80. What happens if `SECRET_KEY` leaks?** Anyone could forge tokens for any user. Rotate it;
everyone is signed out once.

**Q81. What is `dart_defines.json`?** Build-time settings for the Flutter app (API URL, map provider,
Firebase web config, VAPID key), passed with `--dart-define-from-file`.

## Testing questions

**Q82. How do you test?** Backend: pytest with FastAPI's TestClient on in-memory SQLite (316 tests
pass). Flutter: `flutter_test` unit and widget tests (134 pass).

**Q83. How do you test push without Firebase?** A `RecordingSender` replaces the real sender in
tests, and `FcmSender` itself is tested with a fake HTTP session.

**Q84. How do you test the WebSocket?** `TestClient.websocket_connect`: authenticate, then assert on
the events received, e.g. live delivery with no push while the user is online.

**Q85. What isn't tested?** No CI, no tests against real PostgreSQL in the suite, no end-to-end device
tests, no load or security tests, external services faked.

## AI questions

**Q86. Does Khojlo use AI?** Not yet. Kai is a prototype. Today's "smart" features are rule-based
(ranking, the summary, moderation rules).

**Q87. What is RAG, and how would Kai use it?** Retrieval-Augmented Generation: first retrieve the
relevant Khojlo businesses (our search engine or embeddings), then let an LLM answer **only** from
them. That satisfies CO-6 (platform data only) and reduces hallucination.

**Q88. Would you train a model for fake reviews?** Not from scratch. There's no labelled Khojlo data
yet. Rules first; admin decisions become labels; then evaluate an LLM classifier on precision and
recall. That's the documented Module 8 plan.

## SRS questions

**Q89. What changed from your SRS?** Maps provider, automatic verification, chat and push added as
FRs, campaigns, privacy and deletion, reports extended. See Part 4.

**Q90. Why does your SRS say "encrypted passwords"?** That wording is inaccurate. They're hashed with
bcrypt, which is the correct approach. The SRS should be corrected.

**Q91. Is the chatbot (FR-13) done?** No. It's a prototype, planned for the final iteration.

## Scalability questions

**Q92. What breaks first at 10,000 users?** Feed and search load all candidates into Python, and
photos sit in the database. Fix: SQL-side ranking and paging, caching, object storage.

**Q93. How would you scale chat?** Multiple instances + Redis pub/sub for events, a worker queue for
pushes.

**Q94. How would you scale search?** PostgreSQL full-text search + `pg_trgm` + PostGIS with ranking
in SQL; later a search engine.

## Design decision questions

**Q95. Why read markers instead of an `is_read` column per message?** One UPDATE per read instead of
many. Unread and "Seen" both come from two integers.

**Q96. Why automatic verification instead of admin approval?** An admin can't be on duty around the
clock. Automatic checks plus referrals give trust quickly and keep admins for the hard cases.

**Q97. Why do flags never hide content automatically?** False positives would silence honest users
(BR-18). A person decides.

**Q98. Why is private chat text never scanned?** Privacy (SEC-5). Only patterns, such as the same
message to 5+ businesses, are flagged.

## "Why X instead of Y?" questions

| Question | Answer |
|---|---|
| Flutter vs React Native? | One Dart codebase for Android + web, with a pixel-identical custom UI; we didn't need JavaScript or a separate web app |
| FastAPI vs Django? | Lighter and typed, with automatic validation and docs and built-in WebSockets; we didn't need Django's admin or templates |
| PostgreSQL vs MongoDB or Firebase? | Relational data with constraints and transactions (one review per user, cascades, atomic ratings) |
| JWT vs server sessions? | Stateless, works for mobile + web + WebSocket; trade-off: revocation (mitigated by short expiry) |
| WebSocket vs polling? | Instant (PER-6) and efficient; polling is kept only as a fallback |
| WebSocket vs Firebase for chat? | Chat stays in our PostgreSQL with our privacy rules; FCM is used only for offline delivery |
| Riverpod vs BLoC? | Less boilerplate, easy test overrides, `family` / `autoDispose` |
| MapLibre vs Google Maps? | No billing account or key, custom style; Google kept behind the same interface |
| FCM vs OneSignal or others? | Free, official, Android + web, no extra vendor |
| bcrypt vs SHA-256? | bcrypt is salted and deliberately slow; SHA-256 is fast, which helps attackers |
| Photos in PostgreSQL vs S3? | Simplicity and the SDD rule for now; S3 + CDN at scale |
| Integer IDs vs UUIDs? | Simpler and smaller; the SDD said UUIDs, and the team chose integers (noted in the review, D5) |

---

# Part 40: Trick Questions

| Trick question | The trap | Correct answer |
|---|---|---|
| "Is Firebase your database?" | "Yes" | **No.** PostgreSQL (hosted on Supabase) is the database. Firebase is used only for push notifications (FCM). |
| "Is Supabase the backend?" | "Yes" | **No.** The backend is our **FastAPI** app. Supabase only **hosts the PostgreSQL database**; we use none of its other features. |
| "Does the WebSocket store messages?" | "Yes" | **No.** Messages are stored in PostgreSQL by the REST `send_message()` endpoint **before** anything is sent. The WebSocket only announces events and keeps nothing. |
| "Is an API key the same as a secret key?" | "Yes" | **No.** An API key identifies the app to a service (often semi-public and restricted by domain, package or API, like the Firebase web key). A secret key (`SECRET_KEY`, the service-account private key) must never be shared; it **signs** or **authorizes** things. |
| "Is `google-services.json` the Firebase service account?" | "Yes" | **No.** It's the Android app's public client config (committed). The service account is a separate private-key file on the server (git-ignored). |
| "Does JWT encrypt the user's password?" | "Yes" | **No.** The JWT doesn't contain the password at all, and it isn't encrypted. It's **signed** (HS256) and contains only the user id, type and times. The password is **hashed** with bcrypt in the database. |
| "Are passwords encrypted?" | "Yes (the SRS says so)" | **Hashed**, not encrypted. Encryption can be reversed with a key; bcrypt hashing is one-way. |
| "Does Firebase automatically handle your chat?" | "Yes" | **No.** Chat is our own: FastAPI + PostgreSQL + our WebSocket. FCM only delivers a push when the recipient is offline. |
| "Does Docker deploy your application?" | "Yes" | **No.** Our compose file only runs a local PostgreSQL. The API isn't containerized, and the app isn't deployed. |
| "Does Flutter directly communicate with PostgreSQL?" | "Yes, through Supabase" | **No.** Flutter → FastAPI → PostgreSQL. No database credentials exist in the app. |
| "Does the WebSocket replace REST?" | "Yes" | **No.** REST does all reads and writes, sending messages included. The WebSocket only pushes live events (new message, read, typing). |
| "Do you use Firebase Authentication?" | "Yes, for Google login" | **No.** Google Sign-In gives the app an ID token; **our backend** verifies it with `google-auth` and issues our own JWTs. |
| "Is your map Google Maps?" | "Yes" | **Not by default.** MapLibre + OpenStreetMap (OpenFreeMap tiles). Google Maps is optional; "Directions" opens Google Maps via a link. |
| "Is your chatbot AI-powered?" | "Yes" | It's a **prototype** with canned answers. The RAG chatbot is planned for the final iteration. |
| "Do you use AI for moderation?" | "Yes" | **No**, rule-based (regex + thresholds). An AI classifier is planned for 100%. |
| "Does logging out invalidate the token on the server?" | "Yes" | **No.** Logout deletes the tokens on the device and unregisters push. The JWT stays valid until it expires (no revocation list). |
| "Is the JWT payload secret?" | "Yes" | **No.** Anyone can Base64-decode it. Only the signature is protected. |
| "Do only verified businesses appear?" | "Yes (the old SRS)" | **No.** All published, non-suspended businesses appear. Verified ones get a badge, and there's a "Verified only" filter (SRS v1.2). |
| "Can a business owner review their own business?" | "Yes" | **No.** 403. They can reply to reviews instead. |
| "Do you verify that reviewers visited the business?" | "Yes" | **No.** It's an SRS assumption that we can't prove. A "Verified" reviewer badge means a verified **email**. |
| "Is the location of users stored?" | "Yes" | **No.** It's sent only with a request (distance, nearby, route) and never stored (SEC-7). Photo GPS metadata is stripped too. |
| "Do you use the Firebase Admin SDK?" | "Yes" | **No.** We call the FCM HTTP v1 API directly with `google-auth` + `requests`. |
| "Is Docker required to run Khojlo?" | "Yes" | **No.** It's optional; local Postgres or the shared Supabase database also work. |
| "Do push notifications go through your WebSocket?" | "Yes" | **No.** Pushes go server → **FCM (Google)** → device. The WebSocket is only used while the app is open. |
| "Is `dart_defines.json` secret like `.env`?" | "Yes" | **Not really.** Its Firebase web values reach every browser anyway. It's git-ignored to keep key handling consistent. The truly secret files are `backend/.env` and the service-account JSON. |
| "Does the trending row use views?" | "Yes" | The feed's "Trending today" row ranks by **count-weighted rating**. The **trending digest** notification uses 7-day **views**. |
| "Can you scale your API to 10 workers right now?" | "Yes, it's stateless" | **Not yet.** Live chat events, caches and rate limits are in memory, so it must be one worker until Redis pub/sub is added. |

---

# Part 41: Real Code Examples

Each walkthrough follows the same chain: **file → function → what it does → who calls it → what it
calls → what it receives → what it returns.**

## 41.1 Password hashing

```text
File:        backend/app/core/security.py
Function:    hash_password(password) / verify_password(plain, hashed)
What:        bcrypt hash with a fresh salt / bcrypt.checkpw comparison (False if no hash)
Called by:   register(), reset_password()  (hash) · login(), login_form(), delete_me()  (verify)
Calls:       bcrypt.gensalt(), bcrypt.hashpw(), bcrypt.checkpw(); _to_bytes() (72-byte limit)
Receives:    plain password (str) [+ stored hash]
Returns:     "$2b$12$…" (str) / True or False
```

## 41.2 Creating and checking JWTs

```text
File:        backend/app/core/security.py
Function:    create_access_token(user_id) · create_refresh_token(user_id) · decode_token(token)
What:        jwt.encode({sub, type, iat, exp}, SECRET_KEY, HS256) / jwt.decode(...) → None if invalid
Called by:   _tokens_for() in api/auth.py (create) · get_current_user(), refresh(), reset_password(),
             _authenticate() in api/chat.py (decode)
Calls:       python-jose jwt.encode / jwt.decode
Receives:    user id / token string
Returns:     token string / payload dict or None
```

## 41.3 Finding the current user

```text
File:        backend/app/api/deps.py
Function:    get_current_user(token=Depends(oauth2_scheme), db=Depends(get_db))
What:        Bearer token → decode → type must be "access" → load User → ensure_active()
Called by:   FastAPI, for every endpoint that declares Depends(get_current_user) (and via
             get_current_owner / get_current_admin)
Calls:       decode_token(), db.get(User, id), account_block() (moderation_service)
Receives:    the Authorization header token, a DB session
Returns:     User  ·  raises 401 (bad token) or 403 (suspended/banned)
```

## 41.4 Login

```text
File:        backend/app/api/auth.py
Function:    login(payload: LoginRequest, db)
What:        find user by email, verify bcrypt hash, issue tokens
Called by:   POST /api/v1/auth/login ← AuthRepository.login() (lib/features/auth/data/auth_repository.dart)
Calls:       select(User).where(User.email == …), verify_password(), _tokens_for() → ensure_active(),
             create_access_token(), create_refresh_token()
Receives:    {"email", "password"}
Returns:     TokenPair {access_token, refresh_token, token_type}  ·  401 / 403
```

## 41.5 Google Sign-In

```text
File:        backend/app/api/auth.py + backend/app/core/security.py
Function:    google_login(payload) → verify_google_id_token(id_token)
What:        verify Google's ID token (signature, audience = GOOGLE_WEB_CLIENT_ID, issuer), then
             find by google_id / link by email / create a passwordless customer
Called by:   POST /auth/google ← AuthRepository.signInWithGoogleAccount()
Calls:       google.oauth2.id_token.verify_oauth2_token(), SQLAlchemy select/add/commit, _tokens_for()
Receives:    {"id_token"}
Returns:     TokenPair  ·  401 "Invalid Google ID token"
```

## 41.6 One-time codes

```text
File:        backend/app/services/otp_service.py
Function:    create_and_send(db, user, purpose, background_tasks) · verify_code(db, user, purpose, code)
What:        cooldown + daily cap → random 6 digits → store HMAC hash → email in background /
             latest code, not consumed, not expired, < 5 attempts, constant-time compare → consume
Called by:   register(), send_verification_email(), forgot_password() / verify_email(), verify_reset_otp()
Calls:       secrets.randbelow, hmac.new(SECRET_KEY…), hmac.compare_digest, send_*_otp (email_service)
Receives:    user + purpose (+ code)
Returns:     cooldown seconds / None  ·  raises 429 or 400 with a clear message
```

## 41.7 Sending a chat message

```text
File:        backend/app/api/chat.py
Function:    send_message(conversation_id, payload: MessageIn, background_tasks, user, db)
What:        SDD Algorithm 8: participant + blocked/closed checks → client_id dedupe → validate →
             INSERT → update last_message_at and read marker → mass-messaging rule → push if the
             recipient is offline → commit → live events in background
Called by:   POST /conversations/{id}/messages ← ChatRepository.send() ← ConversationController._deliver()
Calls:       _participant(), cs.send_problem(), resolve_keys(), rules.check_mass_messaging(),
             manager.is_online(), ns.notify(), manager.publish(), _message_events()
Receives:    {"body", "client_id", "photo"?}
Returns:     201 MessageOut  ·  403 / 404 / 422
```

## 41.8 The WebSocket endpoint and the connection manager

```text
File:        backend/app/api/chat.py (realtime) + backend/app/services/realtime.py (ConnectionManager)
Function:    async realtime(socket) · manager.add/remove/is_online/send/publish/disconnect
What:        accept → auth message within 10 s → 4401 or "ready" → loop (ping→pong, typing→forward)
             → remove on disconnect. The manager keeps {user_id: {sockets}} in memory.
Called by:   the app's RealtimeService (ws://…/api/v1/ws); publish() is called by send_message()
             and mark_read() as background tasks; disconnect() by delete_me()
Calls:       asyncio.wait_for, run_in_threadpool(_authenticate / _typing_target), socket.send_json
Receives:    JSON events from the app
Returns:     events to the app (ready, pong, message.new, conversation.read, typing)
```

## 41.9 Notifications and push

```text
File:        backend/app/services/notification_service.py + backend/app/services/push.py
Function:    notify(db, recipients, kind, title, body, route, tag=?, store=True) → PushJob.__call__()
             → get_sender() → FcmSender.send(tokens, message)
What:        filter by preferences → store Notification rows (not for chat) → collect device tokens
             → (after commit, in background) POST each token to FCM HTTP v1 → delete invalid tokens
Called by:   send_message(), create_review(), reply(), create_business(), promotion notices,
             trending digest, moderation/verification notices
Calls:       wants(), DeviceToken query, service_account.Credentials, requests.Session.post,
             _is_invalid_token(), delete(DeviceToken)
Receives:    users + message text + route
Returns:     PushJob or None / SendResult(sent, invalid)
```

## 41.10 Writing a review and recalculating the rating

```text
File:        backend/app/api/reviews.py + backend/app/services/review_service.py
Function:    create_review(business_id, payload, background_tasks, user, db) → refresh_rating(db, business)
What:        checks (published, not owner, not duplicate) → INSERT → photos → AVG/COUNT → update
             businesses.rating/review_count → moderation rules → notify owner → commit
Called by:   POST /businesses/{id}/reviews ← ReviewsRepository.create() ← showWriteReviewSheet()
Calls:       _business(), _my_active_review(), _resolve_photos(), _set_photos(), rs.refresh_rating(),
             rules.check_review(), ns.notify()
Receives:    {"rating": 1–5, "comment", "photos": [keys]}
Returns:     201 ReviewOut  ·  403 / 404 / 409 / 422
```

## 41.11 The search engine

```text
File:        backend/app/services/search/engine.py (+ strategies.py, ranking.py, text.py)
Function:    SearchEngine(db).search(criteria) → run(ctx) → rank(results, ctx) → summarize()
What:        build strategies (Keyword, Category, Location/Area, Price, Rating, Offer, Verified,
             OpenNow) → each .apply() adds SQL WHERE → one SELECT → each .matches() confirms in
             Python → retry with any-word if empty → rank → page → summary
Called by:   search_businesses() (GET /search) ← SearchRepository.search() ← SearchNotifier /
             MapResultsNotifier
Calls:       base_query(), strategies_for(), card_load_options(), rank(), summarize()
Receives:    SearchCriteria (query, filters, origin, bounds, sort, limit, offset)
Returns:     SearchOutcome(items, total, relaxed, summary, context)
```

## 41.12 The discovery feed

```text
File:        backend/app/api/feed.py
Function:    get_feed(background_tasks, lat, lng, seed, db, user)
What:        send due promotion notices → load published businesses → featured (newest pool),
             because-you-like (interests) / worth exploring, trending (Bayesian), nearby (if lat/lng)
             → greeting + headline → campaign banners
Called by:   GET /feed ← DiscoveryRepository.feed() ← feedProvider (Home)
Calls:       ps.due_notices(), card_load_options(), ranking_score(), to_card(), categories_with_counts(),
             feed_banners(), random.Random(seed)
Receives:    optional lat, lng, seed; optional user
Returns:     FeedResponse {greeting, headline, categories, sections, campaigns}
```

## 41.13 Registering a business and verifying it automatically

```text
File:        backend/app/api/businesses.py + backend/app/services/verification_service.py
Function:    create_business(payload, background_tasks, owner, db) → _moderate() → vs.refresh(db, b)
What:        create listing (+ services, hours, photos) → rules.check_business() → refresh():
             all 4 checks pass → Verified (logged as auto_verify); all but "clean record" →
             Pending Review (refer) → notify interested users → commit
Called by:   POST /businesses ← BusinessRepository.create() ← RegistrationStepper._publish()
Calls:       _resolve_photos(), _check_category(), set_business_photos(), checks(), log_action(),
             ns.users_interested_in(), ns.notify()
Receives:    BusinessCreate JSON
Returns:     201 BusinessDetail
```

## 41.14 Processing a photo upload

```text
File:        backend/app/services/media_service.py (+ backend/app/api/media.py)
Function:    upload_photo() → store_upload(db, owner, raw) → process_image(raw)
What:        size/format/pixel checks → exif_transpose (upright) → flatten transparency → resize to
             1600 px + 480 px progressive JPEG (metadata dropped) → focal point → INSERT media with
             key = secrets.token_hex(16)
Called by:   POST /media ← MediaRepository.upload()
Calls:       PIL.Image.open, ImageOps.exif_transpose, thumbnail(LANCZOS), _encode(), focal_point()
Receives:    file bytes (≤ 10 MB)
Returns:     PhotoOut {key, url, thumb_url, width, height, focal_x, focal_y}  ·  413 / 422
```

## 41.15 Deleting an account

```text
File:        backend/app/services/account_service.py (+ delete_me in backend/app/api/users.py)
Function:    delete_account(db, user)
What:        remember which businesses/reviews/saves the user affected → delete user (DB cascades)
             → recalculate ratings, helpful counts, save counts → commit; then close their sockets
Called by:   DELETE /users/me ← AuthController.deleteAccount() ← delete_account_sheet.dart
Calls:       refresh_rating(), func.count(ReviewVote), db.delete(user), manager.disconnect(…, 4401)
Receives:    the User (password checked in delete_me first)
Returns:     None (endpoint returns 204)
```

## 41.16 The app's API client

```text
File:        frontend/lib/core/network/api_client.dart
Class:       ApiClient (_authInterceptor, _tryRefresh) + describeApiError()
What:        add Bearer token to every request; on 401 refresh once and retry; on refresh failure
             clear tokens; turn errors into friendly text
Used by:     dioProvider → every repository
Calls:       TokenStorage.accessToken/refreshToken/save/clear, POST /auth/refresh
Receives:    any Dio request / error
Returns:     the response, or a DioException the UI shows via describeApiError()
```

## 41.17 The app's session bootstrap and login

```text
File:        frontend/lib/features/auth/auth_controller.dart
Class:       AuthController (StateNotifier<AuthState>)
What:        bootstrap() restores the session (GET /users/me); login/register/Google sign-in;
             logout() unregisters push then clears tokens
Used by:     authControllerProvider → AuthScreen, router redirect, SessionServices
Calls:       AuthRepository (Dio), PushController.unregister() (beforeLogout)
State:       status unknown/authenticated/unauthenticated, user, loading, error
```

## 41.18 The app's WebSocket client

```text
File:        frontend/lib/core/realtime/realtime_service.dart
Class:       RealtimeService (start, stop, send, _open, _onData, _onClosed, _scheduleRetry)
What:        connect → send auth → on "ready" ping every 25 s → forward events to a stream →
             reconnect with backoff → on 4401 refresh once
Used by:     realtimeProvider → SessionServices (start/stop), ConversationsController,
             ConversationController (events, status)
Calls:       WebSocketChannel.connect, GET /users/me (refreshSession)
```

## 41.19 The app's chat controller

```text
File:        frontend/lib/features/chat/chat_providers.dart
Class:       ConversationController (load, loadOlder, catchUp, send, sendPhoto, retry, typing,
             _deliver, _add, _markRead, _onEvent, _onStatus)
What:        one open conversation: optimistic send with client_id, de-duplicated live echo,
             "Seen", typing, polling every 8 s when the socket is down
Used by:     conversationControllerProvider(conversationId) → ConversationScreen, ChatComposer
Calls:       ChatRepository (REST), MediaRepository.upload (photos), Realtime.send (typing),
             PushController.maybeAskAfterFirstMessage()
```

## 41.20 The app's push controller

```text
File:        frontend/lib/features/notifications/push_controller.dart (+ lib/core/push/push_platform.dart)
Class:       PushController (onSignedIn, enable, maybeAskAfterFirstMessage, unregister, _register,
             _listen, _open, _onForeground)
What:        permission → FCM token → PUT /notifications/devices; token refresh; open tapped routes;
             in-app banner for foreground pushes; unregister on logout
Used by:     pushControllerProvider → SessionServices, PushPromptCard, AuthController (logout)
Calls:       FirebasePushPlatform (firebase_messaging), NotificationsRepository, routerProvider
```

## 41.21 Choosing the map

```text
File:        frontend/lib/core/maps/map_service.dart
Provider:    mapServiceProvider → GoogleMapsService | MapLibreService | SketchMapService
What:        one interface (buildMap, displayLocation, openDirections) with three implementations
Used by:     MapScreen, BusinessDetailScreen (mini map), LocationPickerScreen, RouteScreen
Decides by:  MapsConfig.provider (MAP_PROVIDER), MapsConfig.isConfigured (key), platform support
```

---

# Part 42: Trace This Feature Exercises

Open the files in order and find each function. Tick each step as you go.

**1. Register a user**

1. `lib/features/auth/presentation/auth_screen.dart`: the sign-up form and the role chips.
2. `lib/features/auth/auth_controller.dart` → `register()`
3. `lib/features/auth/data/auth_repository.dart` → `register()` (`POST /auth/register`), then
   `login()`
4. `backend/app/schemas/auth.py` → `RegisterRequest` (with its `_no_self_service_admin` validator)
5. `backend/app/api/auth.py` → `register()` → `hash_password()` (`backend/app/core/security.py`)
6. `backend/app/services/otp_service.py` → `create_and_send()` → `send_verify_email_otp()`
   (`backend/app/services/email_service.py`)
7. Back in the app: `lib/core/router/app_router.dart` → `redirect` → `/interests` or `/home`

**2. Login**

1. `auth_screen.dart` → `AuthController.login()` → `AuthRepository.login()`
2. `backend/app/api/auth.py` → `login()` → `verify_password()` → `_tokens_for()`
3. `lib/core/storage/token_storage.dart` → `save()`
4. `AuthRepository.me()` → `GET /users/me` → `read_me()` (`backend/app/api/users.py`)
5. `lib/core/router/session_services.dart` → `_onSignedIn()`

**3. Google Sign-In**

1. `lib/features/auth/presentation/google_web_button_web.dart` (web) / `AuthController.loginWithGoogle()`
   (mobile)
2. `AuthRepository.ensureGoogleSignInReady()` → `signInWithGoogleAccount()` → `POST /auth/google`
3. `backend/app/api/auth.py` → `google_login()` → `verify_google_id_token()`
4. The router → `/privacy-consent` (new Google users) →
   `lib/features/legal/presentation/privacy_consent_screen.dart` → `POST /users/me/privacy-consent`

**4. Create a business**

1. `lib/features/business/presentation/business_tab_screen.dart` → the "Register your business" CTA
2. `registration_stepper.dart` → the steps → `_publish()` → `BusinessRepository.create()`
   (`lib/features/business/data/business_repository.dart`)
3. `backend/app/schemas/business.py` → `BusinessCreate` (with its validators)
4. `backend/app/api/businesses.py` → `create_business()` → `_check_category()` →
   `set_business_photos()` → `_moderate()`
5. `backend/app/services/verification_service.py` → `refresh()` → `checks()`
6. `backend/app/services/notification_service.py` → `users_interested_in()` → `notify()`

**5. Search for a business**

1. `lib/features/search/presentation/search_screen.dart` (the Explore tab)
2. `lib/features/search/search_providers.dart` → `SearchNotifier.onInputChanged()` / `submit()`
3. `lib/features/search/data/search_repository.dart` → `search()` → `GET /search`
4. `backend/app/api/search.py` → `search_businesses()` → `record_search()`
5. `backend/app/services/search/engine.py` → `SearchEngine.search()` → `strategies.py` →
   `KeywordSearch.apply()` / `matches()` → `ranking.py` → `rank()`

**6. View a business**

1. `lib/features/discovery/discovery_providers.dart` → `businessDetailProvider`
2. `lib/features/discovery/data/discovery_repository.dart` → `detail()`
3. `backend/app/api/businesses.py` → `business_detail()` → `_detail()` → `record_view_later()`
   (`backend/app/services/business_service.py`)
4. `lib/features/discovery/presentation/business_detail_screen.dart` (the sections and buttons)

**7. Submit a review**

1. `lib/features/reviews/presentation/business_reviews_section.dart` (the CTA) →
   `review_flows.dart` → `openWriteReview()`
2. `review_sheets.dart` → `showWriteReviewSheet()` → `ReviewsRepository.create()`
3. `backend/app/api/reviews.py` → `create_review()`
4. `backend/app/services/review_service.py` → `refresh_rating()`;
   `backend/app/services/moderation_rules.py` → `check_review()`
5. `lib/features/reviews/presentation/widgets/confetti.dart` (the celebration)

**8. Send a message**

1. `business_detail_screen.dart` → `_message()` → `openConversationWith()`
   (`lib/features/chat/chat_providers.dart`)
2. `backend/app/api/chat.py` → `open_conversation()`
3. `lib/features/chat/presentation/conversation_screen.dart` →
   `lib/features/chat/presentation/widgets/chat_composer.dart` →
   `ConversationController.send()` → `_deliver()`
4. `lib/features/chat/data/chat_repository.dart` → `send()`
5. `backend/app/api/chat.py` → `send_message()` → `_message_events()` → `manager.publish()`

**9. Receive a message**

1. `backend/app/services/realtime.py` → `ConnectionManager.publish()` → `send()`
2. `lib/core/realtime/realtime_service.dart` → `_onData()` → the `events` stream
3. `lib/features/chat/chat_providers.dart` → `ConversationsController` (the list and badge) and
   `ConversationController._onEvent()` → `_add()` → `_markRead()`
4. `backend/app/api/chat.py` → `mark_read()` → `conversation.read` event → "Seen"

**10. Send a notification**

1. Any trigger, e.g. `create_review()` in `backend/app/api/reviews.py`
2. `backend/app/services/notification_service.py` → `notify()` → `wants()` → `PushJob`
3. `backend/app/services/push.py` → `get_sender()` → `FcmSender.send()` → `payload()`
4. Then `PushJob.__call__()` deletes the invalid tokens

**11. Open a notification**

1. `lib/core/push/push_platform.dart` → `FirebasePushPlatform` (`openedRoutes`, `launchRoute`,
   `foreground`)
2. `lib/features/notifications/push_controller.dart` → `_open()` / `_onForeground()`
3. Web: `frontend/web/firebase-messaging-sw.js` (`notificationclick`) →
   `lib/core/push/sw_messages_web.dart`
4. Bell list: `lib/features/notifications/presentation/notifications_screen.dart` →
   `NotificationsRepository.markRead()`

**12. Display a map**

1. `lib/features/maps/presentation/map_screen.dart`
2. `lib/core/maps/map_service.dart` → `mapServiceProvider` → `MapLibreService.buildMap()`
3. `lib/core/maps/maplibre_map_view.dart` (the style asset, the pins GeoJSON, the symbol layer, the
   20 s fallback)
4. `lib/features/maps/map_providers.dart` → `MapResultsNotifier` → `SearchRepository.search(bounds…)`
5. `backend/app/services/search/strategies.py` → `AreaSearch`
6. Directions: `lib/features/maps/presentation/route_screen.dart` → `showRoute()` →
   `GeoRepository.route()` → `backend/app/api/geo.py` → `route_between()` →
   `backend/app/services/routing.py` → `OrsRouter`

---

# Part 43: Final Mental Model

```text
KHOJLO  — discover new & underrated local businesses (Pakistan), compare, chat, review
│
├── Flutter app (Android + Web)            lib/
│   ├── core/            Dio+JWT client · secure token storage · go_router (5-tab shell,
│   │                    auth/consent/admin gates) · WebSocket client · FCM push · MapService
│   ├── Authentication   email+password · Google Sign-In · OTP verify/reset · consent · delete account
│   ├── Discovery        Home feed (featured new · because you like · trending · nearby · campaigns)
│   ├── Search           keyword + filters + sort · compare 2–3 · map/list toggle
│   ├── Business         8-step registration · edit · photos · hours · analytics · verification
│   ├── Promotions       offers (deal types, dates) · campaigns (banners, badge)
│   ├── Reviews          write/edit/delete · photos · replies · helpful · report
│   ├── Chat             conversations · live messages · Seen · typing · block/report
│   ├── Notifications    bell list · settings · push permission & taps
│   ├── Maps             MapLibre + OSM tiles · pins · pin picker · route preview
│   ├── Admin            overview · verification · reports · flags · users · audit log
│   └── Prototype        Kai chatbot (canned answers)
│
├── FastAPI backend (one process, :8000)   backend/app/
│   ├── api/             14 routers · 98 endpoints + 1 WebSocket · Depends(get_current_user/owner/admin)
│   ├── core/            settings (.env) · DB engine/sessions · bcrypt + JWT · privacy version
│   ├── Authentication   tokens (30 min / 14 days) · Google ID token check · OTP (HMAC, limits)
│   ├── Business logic   services/: business · media (Pillow) · promotion · verification · moderation
│   ├── Search           SearchEngine + Strategy pattern · SQL pre-filter → Python rank
│   ├── Reviews          one per user (index) · refresh_rating (Algorithm 7) · Bayesian ranking
│   ├── Chat             REST writes · ConnectionManager (in memory) · read markers · client_id
│   ├── Notifications    notify() → PushJob → FcmSender (FCM HTTP v1) / NullSender
│   ├── Maps proxy       /geo: Photon + Nominatim (cache, rate limit) · openrouteservice
│   └── Jobs             trending digest · promotion notices (manual/cron)
│
├── PostgreSQL (Supabase-hosted; local Docker or install optional; SQLite in tests)
│   ├── users · otp_codes
│   ├── businesses · categories · services · opening_hours · media · business_photos
│   ├── offers · campaigns (+ links) · saved_lists · saved_businesses · business_views
│   ├── reviews (+ photos, votes, reports)
│   ├── conversations · messages · conversation_reports · device_tokens · notifications
│   ├── business_reports · moderation_flags · moderation_actions (audit log)
│   └── search_queries                         — 28 tables, 10 Alembic migrations
│
└── External services
    ├── Firebase Cloud Messaging   push only (service account on server; google-services.json in app)
    ├── Google                     Sign-In ID tokens · Maps link for navigation · (optional Maps/Geocoding)
    ├── OpenStreetMap stack        OpenFreeMap tiles · Photon · Nominatim · openrouteservice
    └── SMTP (Gmail)               verification/reset codes · account notices
```

**Four sentences to remember:**

1. The app never touches the database. App → API → PostgreSQL.
2. REST changes data. The WebSocket only announces events. FCM covers people who aren't in the app.
3. Passwords are **hashed** (bcrypt). Sessions are **signed** JWTs (30 min / 14 days).
4. Maps are MapLibre + OpenStreetMap by default, and Firebase is only for push.

---

# Part 44: What I Should Be Able to Answer After Studying

- ☐ **What is Khojlo?** A Flutter + FastAPI + PostgreSQL platform to discover, compare and contact
  new and underrated local businesses.
- ☐ **What problem does it solve?** New businesses are invisible on rating-first platforms; customers
  can't easily find new, affordable places.
- ☐ **Who are its users?** Customers, business owners and admins.
- ☐ **What are its USPs?** New-first fairness, comparison, chat inside discovery, automatic
  storefront verification, local-language search, free promotions.
- ☐ **What are its modules?** 10: Auth, Business, Feed (+ push), Search/Compare, Reviews, Maps, AI
  Chatbot, Admin, Chat, Personalization.
- ☐ **How much is implemented?** 8/10 production, Module 10 basic, Module 7 prototype; all 8 items on
  the 60% slide.
- ☐ **What changed from the SRS?** Maps provider, automatic verification, chat and push FRs, campaigns,
  privacy/deletion, extended reporting, integer IDs, a 5-tab navigation (Part 4).
- ☐ **What technologies are used?** Flutter/Dart, Riverpod, go_router, Dio, FastAPI/Python,
  SQLAlchemy, Alembic, PostgreSQL/Supabase, FCM, MapLibre/OSM, Docker (DB only).
- ☐ **Why were they selected?** See Part 31.
- ☐ **How does Flutter communicate with FastAPI?** HTTP JSON via Dio (Bearer JWT) + one WebSocket
  `/api/v1/ws`.
- ☐ **How does FastAPI communicate with PostgreSQL?** SQLAlchemy ORM → psycopg2 → `DATABASE_URL`;
  a session per request.
- ☐ **Where are database queries?** In routers and services through SQLAlchemy (login, register,
  `mark_read`, `refresh_rating`, `unread_by_conversation`, search strategies …) (Part 11).
- ☐ **How does authentication work?** bcrypt password check or Google ID token → JWT access +
  refresh → `get_current_user()`.
- ☐ **How are passwords hashed?** bcrypt with a salt (`hash_password()`).
- ☐ **What is a JWT?** A signed token `{sub, type, iat, exp}` (HS256); readable, but tamper-proof.
- ☐ **What is the JWT secret?** `SECRET_KEY`: it signs and verifies tokens (and HMACs OTP codes).
- ☐ **How does Google Sign-In work?** The app gets an ID token → the backend verifies it with
  google-auth → our JWTs.
- ☐ **How does Firebase work here?** Only FCM: devices get tokens; the backend sends via the HTTP v1
  API with a service account.
- ☐ **What is FCM?** Google's free push delivery service (Android + web).
- ☐ **How do push notifications work?** `notify()` → `PushJob` → `FcmSender` → FCM → device → tap
  opens `data.route`.
- ☐ **How does chat work?** REST to send and store; WebSocket for live events; push when offline;
  read markers for unread and "Seen".
- ☐ **How does the WebSocket work?** Open socket → auth message → `ready` → events both ways →
  reconnect with backoff.
- ☐ **Where are messages stored?** The PostgreSQL `messages` table (plus `conversations`).
- ☐ **How does offline messaging work?** Stored first → push to the offline recipient → loaded on
  next open; the sender retries with the same `client_id`; polling while the socket is down.
- ☐ **How are reviews stored?** The `reviews` table (+ photos, votes, reports); the business rating
  is recalculated on each change.
- ☐ **How do we handle fake reviews?** One per user, no self-reviews, burst rule, reports, admin
  hide/ban, Bayesian ranking; no visit proof yet.
- ☐ **How do maps work?** MapLibre + OpenFreeMap tiles; area search via `/search`; geocoding and
  routes via the backend.
- ☐ **What are the APIs?** 98 REST + 1 WebSocket in 14 groups (Part 23).
- ☐ **What are environment variables?** Settings outside the code (`.env` / dart-defines), so
  secrets stay out of git.
- ☐ **What is `.env`?** The backend's real settings and secrets (git-ignored).
- ☐ **What is `.env.example`?** The committed template with placeholders.
- ☐ **What is `firebase-service-account.json`?** The server's private key for sending FCM pushes
  (secret).
- ☐ **What is `google-services.json`?** The Android app's public Firebase/OAuth config
  (committed).
- ☐ **What is `dart_defines.json`?** The Flutter build-time settings (API URL, map provider,
  Firebase web config).
- ☐ **What is `dart_defines.example.json`?** Its committed template.
- ☐ **Why do we have Docker?** A one-command local PostgreSQL 16; it isn't used for deployment.
- ☐ **What ports are used?** API 8000, Postgres 5432, web dev 8090 (or random), emulator
  `10.0.2.2:8000`.
- ☐ **How does testing work?** pytest + TestClient on SQLite (316 pass); flutter_test (134 pass);
  fakes for external services.
- ☐ **How is the app deployed?** It isn't yet. Local API + Supabase DB; production needs a
  container, HTTPS, signing (Part 37).
- ☐ **What are the security measures?** Part 13: hashing, JWT, authorization, validation,
  parameterized SQL, secrets out of git, moderation, privacy.
- ☐ **What are the limitations?** Part 35: single worker, no revocation, no rate limiting, no
  deployment, no AI yet, in-memory ranking.
- ☐ **How would we scale it?** SQL-side search, Redis pub/sub + caches, workers, object storage +
  CDN, load balancer, monitoring.
- ☐ **How would AI improve it?** RAG Kai, semantic search, recommendations, fake-review detection,
  summaries (Part 33).
- ☐ **What datasets would AI require?** Our own logs (views, saves, searches, reviews, admin
  decisions as labels) + possibly OSM POIs and public review corpora.
- ☐ **What would we change in a production version?** HTTPS/WSS, a strong secret, login rate limits,
  token revocation, Redis, object storage, release signing, CI, monitoring, a scheduler.

---

# Part 45: Study Plan

## Level 1: Product

- **Know:** what Khojlo is, the problem, the users, the journeys, what's in and out of scope, the
  honest status (8/10 modules).
- **Why it matters:** the first viva questions are always about the product, and confidence here
  sets the tone.
- **Study:** Part 1, Part 2, Part 32; `README.md`; `docs/requirements/SRS.md` §1–2.
- **Practise:** "Pitch Khojlo in 30 seconds." "Who is it for?" "Why would a shop owner use it?"

## Level 2: Architecture

- **Know:** app → API → database; REST vs WebSocket vs push; what Firebase and Supabase are (and
  aren't).
- **Why it matters:** most trick questions target this layer.
- **Study:** Parts 5, 40, 43; `backend/app/main.py`; `frontend/lib/main.dart`.
- **Practise:** draw the architecture from memory; answer every row of Part 40 without looking.

## Level 3: Modules

- **Know:** the 10 modules, their status, who built what, the SRS changes.
- **Why it matters:** "What did *you* build?" and "What changed from the SRS?" are guaranteed
  questions.
- **Study:** Parts 3 and 4; `docs/development_roadmap/implementation_plan.md`; the module records.
- **Practise:** for each module, one sentence on what it does + its key file + its status.

## Level 4: Code flow

- **Know:** the 12 traces.
- **Why it matters:** examiners often say "show me in the code where…".
- **Study:** Parts 24, 41 and 42, with the code open; Part 15 for chat (your module).
- **Practise:** open the files in Part 42 and narrate each trace aloud; find `send_message()`,
  `refresh_rating()` and `get_current_user()` in under 30 seconds each.

## Level 5: Infrastructure

- **Know:** environment variables, the Firebase files, Docker, ports, Supabase, maps services,
  how to run everything.
- **Why it matters:** "What is this file?" / "Why Docker?" / "What port?" are easy marks.
- **Study:** Parts 17–22, 37; `docs/team_setup.md`; `backend/.env.example`;
  `frontend/dart_defines.example.json`; `backend/docker-compose.yml`.
- **Practise:** explain every file in the Part 17 table; start the backend and the app yourself
  (`README.md`).

## Level 6: Security

- **Know:** bcrypt, JWT structure and lifetimes, the secret key, Google token verification,
  authorization checks, the security gaps.
- **Why it matters:** security questions are where students over-claim. Be precise and honest.
- **Study:** Parts 12, 13 and 14; `backend/app/core/security.py`; `backend/app/api/deps.py`;
  `backend/app/services/otp_service.py`.
- **Practise:** "What happens if someone steals the JWT?" "Encrypted or hashed?" "How do you stop
  SQL injection?" "Is your system secure?"

## Level 7: Advanced

- **Know:** WebSocket internals and scaling, push delivery states, the scalability path, AI plans
  (RAG), limitations.
- **Why it matters:** distinguishes a strong defense; it shows engineering judgement.
- **Study:** Parts 15, 16, 33, 35 and 36; `backend/app/services/realtime.py`;
  `backend/app/services/push.py`; `frontend/lib/core/realtime/realtime_service.dart`.
- **Practise:** "Scale to 100k users." "Design Kai with RAG." "Why REST for sending messages?" "What
  breaks with 2 uvicorn workers?"

---

# Known Inconsistencies & Risks

Each item lists the **evidence**, the **impact**, a **fix**, and **what to say** if an examiner
raises it.

## A. Documents vs code

**1. The documents still say Google Maps; the code uses MapLibre + OpenStreetMap.**

- **Evidence:** SRS OE-8, CO-5, UC-9 ("Load Google Maps"); the 60% slide ("Google Maps and location
  services"); `docs/development_roadmap/implementation_plan.md` (Module 6 bullets: "Interactive
  Google map", "Directions to Google Maps navigation"). Against that, `lib/core/maps/maps_config.dart`
  defaults to `maplibre`, and `backend/app/core/config.py` defaults to `GEOCODING_PROVIDER=osm`.
- **Fix:** update the SRS v1.2 wording ("Google Maps or an open-source equivalent behind
  `MapService`") and the implementation plan.
- **Say:** "Google Maps needs billing, so the provider changed behind the SDD's `MapService`
  interface. Google remains supported."

**2. "Encrypted" passwords.**

- **Evidence:** SRS SEC-1; `implementation_plan.md` ("encrypted passwords"). The code hashes with
  bcrypt.
- **Fix:** reword to "stored as salted one-way hashes (bcrypt)".
- **Say:** "Hashed, not encrypted, which is the correct practice."

**3. Outdated statements in other documents.**

- `polish_photos_categories_profile.md` says Directions and Share "still do nothing"; both work now.
- `frontend/README.md` is still the Flutter template.
- `docs/team_setup.md` still says "Last updated: 28 Sep 2026".
- The privacy commit message cites "FR-26, FR-27"; the SRS numbers are FR-31 and FR-32.

**4. Open SDD and Feasibility corrections** (`docs/requirements/document_review.md`, the 📝 items).

- UUIDs vs integer IDs.
- ER-diagram subtype tables vs one `users` table.
- Traceability matrix numbering.
- 4-tab screenshots vs 5 tabs.
- Gantt chart.
- **The work-division table** (it assigns Modules 7, 8 and 10 to Kazim Shauket; git shows Module 8
  built by Sayyam, and no commits from Kazim).

**Say:** "These are tracked in our documentation review, with fixes ready to apply."

**5. "AI-powered" wording.**

- **Evidence:** `README.md` and the SRS describe AI features. No AI code exists; Kai is canned
  (`kai_screen.dart`).
- **Risk:** over-claiming in the viva.
- **Say:** "AI is planned for the final iteration (RAG Kai, an AI moderation classifier,
  recommendations); the current build is rule-based."

## B. Repository and process

**6. `main` is 29 commits behind `dev`.**

- **Evidence:** `git rev-list --count main..dev` = 29, and GitHub's default branch is `main`
  (`origin/HEAD → origin/main`).
- **Impact:** anyone opening the repository on GitHub sees the old 30% build.
- **Fix (team decision):** merge `dev` into `main` via a pull request before the evaluation.

**7. `.claude/launch.json` files are tracked although `.gitignore` excludes `.claude/`.**

- **Evidence:** `git ls-files` (review item G9).
- **Impact:** harmless config.

**8. Shared database risks.**

- **Shared credentials:** everyone uses the same Supabase `DATABASE_URL`.
- **Migration coordination:** running a migration from an unmerged branch blocks others; the module
  records warn about this.
- **Known demo passwords:** the seed creates **known-password demo accounts, including
  `admin@khojlo.app` / `password123`**.
- **Impact:** if the API were ever deployed against this database, anyone could log in as admin.
- **Fix:** before any public deployment, use a separate production database without demo
  accounts, or change those passwords.

## C. Product and UX gaps

**9. Customers can't become business owners.**

- **Evidence:** `business_tab_screen.dart` shows "Register your business" to customers (a 403 from
  `/businesses/mine` falls back to the CTA), but `POST /businesses` requires
  `get_current_owner()`, and no endpoint changes a user's role.
- **Impact:** a customer who taps the CTA and fills the stepper gets "Business owner account
  required".
- **Fix:** a role upgrade endpoint (`POST /users/me/become-owner`), or hide the CTA for customers.
- **Say:** "Owners register with the owner role. A role upgrade is a known small gap."

**10. Only the first business appears in the Business tab** (`DashboardScreen(business:
businesses.first)`) although the API supports several. **Fix:** a business switcher.

**11. Launching the app while offline signs you out.**

- **Evidence:** `AuthController.bootstrap()` calls `_repo.logout()` on **any** error from
  `/users/me`, including a connection error.
- **Fix:** clear the tokens only on 401/403; otherwise show an offline state and retry.

**12. A refresh failure mid-session doesn't update the auth state.**

- **Inference:** `ApiClient._tryRefresh()` clears the tokens but doesn't notify `AuthController`, so
  the UI stays "signed in", and calls fail until the next launch.
- **Fix:** a callback or stream from `ApiClient` → `AuthController.logout()`.

**13. "Trending" means two different things.**

- **Evidence:** the feed's "Trending today" = top 8 by Bayesian **rating** (`get_feed()`); the
  trending digest = most **views** in 7 days (`trending_picks()`).
- **Fix:** rename the row ("Top rated") or base it on recent views.

**14. Unused or legacy data.**

- `businesses.images` is unused (kept for old builds).
- `offers.views` and `offers.redemptions` are set only by the seed: never incremented, never shown.
- The Google Maps packages (`google_maps_flutter`, `pointer_interceptor`, `web`'s Maps loader) are
  only needed in the optional Google mode.

**15. No "Save draft" in business registration** (UC-10 alternative flow), and no verification
document upload (UC-10 "Upload docs" was replaced by the storefront photo).

**16. Reviews:** no visit verification (the UC-7 assumption), and the "Verified" reviewer badge means
"verified email". **Say** it exactly that way.

**17. `GET /businesses/{id}` hides suspended listings but not unpublished ones.**

- **Evidence:** `business_detail()` checks only `suspended_at`.
- **Impact:** low (the app has no "unpublish" button), but a listing an owner unpublished via the API
  would still be viewable by id.

## D. Security and operations risks

**18. No login rate limit or lockout** (only the OTP flows are limited). Brute force is possible.

**19. Token lifecycle gaps.**

- No server-side logout or revocation.
- Refresh tokens aren't rotated.
- A password reset doesn't invalidate old tokens.
- A reset token can be reused within 10 minutes.

**20. A default `SECRET_KEY` fallback in code** (`change-me-to-a-long-random-string`). **Fix:**
refuse to start with the default outside development.

**21. Development-only settings.**

- CORS allows any `http://localhost:<port>` with credentials.
- HTTP/WS, not HTTPS/WSS (SEC-4).
- `/docs` is open.
- The Android release build is signed with **debug keys** (`build.gradle.kts`).

**22. Public media URLs.** `GET /media/{key}` needs no auth, so "private" storefront photos are
protected only by the unguessable 128-bit key.

**23. No deployment, CI or monitoring.** There's no Dockerfile for the API, no hosting
configuration, no automated test runs, and no error tracking.

## E. Scalability and reliability

**24. One process only.** The WebSocket registry, rate limiters and geocode/route caches live in
memory (`realtime.py`, `geo.py`, `geocoding.py`, `routing.py`). Running 2+ workers would break live
chat; restarts reset limits and caches.

**25. Search and feed load all matching businesses into Python**, then rank and page there. The
duplicate-listing check scans all businesses on every save. Pushes are sent one by one. All of this
is fine at demo scale, but not at large scale (Part 36).

**26. No scheduler.** The trending digest and the scheduled promotion notices depend on someone
running a command, or on a Home visit (`due_notices()` inside `get_feed()`).

**27. External free services.** OpenFreeMap (donation-funded) and the public Nominatim (≤ 1 request
per second) aren't meant for production load. iOS has no push or Google Maps wiring. Web push needs
HTTPS or localhost.

## F. Local configuration drift (your machine)

**28. Config files don't match their templates.**

- The local `backend/.env` doesn't have `GEOCODING_PROVIDER`, `GEOCODING_USER_AGENT`, `PHOTON_URL`
  and `NOMINATIM_URL` (the defaults apply), so it no longer matches `.env.example`'s layout.
- The local `frontend/dart_defines.json` has no `MAP_PROVIDER` (it defaults to `maplibre`).

Both are harmless, but they're worth aligning per the team rule in `docs/team_setup.md`.

---

*End of handbook. Built from the `dev` branch at commit `5b7ca3d` (5 Oct 2026). Test results: backend
316 passed, Flutter 134 passed, both run on 5 Oct 2026.*
