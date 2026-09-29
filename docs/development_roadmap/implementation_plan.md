### Development and Implementation Plan

The development of Khojlo follows an incremental approach. Core modules are fully implemented first, and the remaining modules start as interactive prototypes that are converted into working features in later phases. This keeps the primary functionality stable and demonstrable at every evaluation (30%, 60% and 100%), while leaving room to grow.

This plan reflects the implementation as of September 2026 and is aligned with the SRS, SDD and Feasibility Report in `docs/requirements/`. Requirement IDs follow SRS v1.1 (`docs/requirements/SRS.md`), which adds FR-16 to FR-25 and UC-13 to UC-15. The 60% scope follows the second-iteration slide presented to the FYP committee.

> **Module numbering.** The Feasibility Report's body text and team work division list Module 5 as Reviews and Module 6 as Maps; its table of contents has them the other way round. This plan follows the body text. The table of contents should be updated to match before the next submission.

#### Status at a Glance

| # | Module | Requirements (SRS v1.1) | Status | Phase |
|---|---|---|---|---|
| 1 | User Authentication and Profile Management | FR-1, FR-2, FR-7, FR-16, FR-17, UC-1, UC-2 | ✅ Implemented | 30% |
| 2 | Business Registration and Management | FR-8, FR-9, FR-10, FR-20, UC-10, UC-11 | ✅ Implemented (offers need rework, see Phase 2) | 30% |
| 3 | Business Discovery Feed (New & Trending) | FR-5, FR-11, FR-21, UC-3, UC-6, UC-15 | ✅ Implemented, including push notifications (see `module9_chat_and_push_plan.md`) | 30% (push: 60%) |
| 4 | Search, Filtering, and Comparison System | FR-3, FR-4, FR-18, UC-4, UC-5 | ✅ Implemented (see `module4_search_filter_compare_plan.md`) | 30% |
| 5 | Reviews and Ratings System | FR-6, FR-19, UC-7, REL-4 | ✅ Implemented (see `module5_reviews_ratings_plan.md`) | 60% |
| 6 | Maps and Location Integration | FR-12, UC-9 | ✅ Implemented (see `module6_maps_location_plan.md`) | 60% |
| 7 | AI Chatbot Assistance (RAG) | FR-13, UC-8, USE-5, PER-4 | 🎨 Prototype | 100% |
| 8 | Admin and Moderation System | FR-14, FR-15, UC-12, SEC-2, SEC-3 | 🎨 Prototype | 60% |
| 9 | Chat and Messaging System | FR-23, FR-24, FR-25, UC-13, UC-14 | ✅ Implemented (see `module9_chat_and_push_plan.md`) | 60% |
| 10 | AI Personalization and Recommendation | FR-22 | 🟡 Basic version in the feed | 100% |

---

#### Phase 1 – 30% Evaluation (Minimum Viable Product)

Phase 1 implements the functionality that demonstrates Khojlo's primary objective: finding new and local businesses. It is built with Flutter (mobile and web), FastAPI and PostgreSQL. Search, filtering and comparison (Module 4) was originally planned as a prototype at this stage, but it was completed early.

**Fully Implemented Modules**

**Module 1: User Authentication and Profile Management**

* User registration and login with email and password, plus Google Sign-In
* Role-based access (Customer, Business Owner, Admin)
* Email verification and password reset with one-time codes
* Secure session management (encrypted passwords, access and refresh tokens)
* User profile with an edit profile screen: name, profile photo, phone number, avatar colour and interests
* Interest selection at sign-up, loaded from the category list
* Favorites: saved businesses organised into named collections

**Module 2: Business Registration and Management**

* Step-by-step business registration:
  * name and colour
  * category
  * location and contact (address, phone number, map pin from the device location)
  * photos
  * description and prices
  * opening hours
  * services
  * review and publish
* Business profile editing, including category, phone number and colour
* Photo management: a cover photo shown on every card plus a gallery of up to 10 photos, cropped automatically to fit each card
* Services with prices, opening hours (including overnight and 24-hour days) and a price range in rupees
* Offers and promotions management
* Basic analytics: profile views, saves and a weekly views chart

**Module 3: Business Discovery Feed (New & Trending Businesses)**

* Home feed with a featured new business, trending businesses and nearby businesses
* Category-based browsing through category chips
* Business cards with cover photo, rating, distance and price
* Basic personalization: a "because you like…" row based on the user's interests
* Business detail page with photos and gallery, services, hours, offers, a Call button and a compare action
* Save business functionality
* "Surprise me" discovery

> **Note:** Push notifications for new businesses and offers were not part of the 30% build. They are scheduled for Phase 2 (60%), as shown on the committee's second-iteration slide.

**Module 4: Search, Filtering, and Comparison System**

* Keyword search across names, categories, services, descriptions and addresses, including local terms such as "darzi" or "dhaba"
* Search suggestions as the user types, plus recent and popular searches
* Filters:
  * category
  * price level and rupee budget
  * rating
  * distance from the user's location
  * open now
  * offers
  * verified only
* Sorting by relevance, distance, rating, price, newest and popularity
* Side-by-side comparison of 2 to 3 businesses, with the best value in each row highlighted
* Search engine built with the SDD's Strategy pattern (keyword, category and location strategies)

**Cross-cutting Work Completed in Phase 1**

* 25 specific business categories in 5 groups, plus an "Other" category where the owner describes the business in their own words. Categories are stored in the database, so new ones need no code changes (SCA-1).
* Photos stored in PostgreSQL (SDD §5.1). Uploads are resized, turned upright, stripped of location metadata and cropped around their main subject.
* Safe demo data, and a startup check that warns when the database schema is out of date.

**Prototype Modules (30% Evaluation)**

The following modules are presented as high-fidelity interactive prototypes, showing the intended user experience with sample data.

* **Module 5: Reviews and Ratings System** — reviews screen and rating display with sample reviews
* **Module 6: Maps and Location Integration** — map screen with business pins and a nearby list
* **Module 7: AI Chatbot Assistance Module** — chatbot ("Kai") interface with sample responses
* **Module 8: Admin and Moderation System** — admin dashboard, verification queue and analytics prototype
* **Module 9: Chat and Messaging System** — conversation list and chat screen between customers and businesses
* **Module 10: AI Personalization and Recommendation System** — personalized rows in the feed (basic)

---

### Phase 2 – 60% Evaluation

The 60% scope is the second-iteration slide shown to the committee:

| Slide item | Module | Status |
|---|---|---|
| User reviews and ratings | 5 | ✅ Implemented |
| Business search and advanced filtering | 4 | ✅ Implemented (completed early, at 30%) |
| Business comparison feature | 4 | ✅ Implemented (completed early, at 30%) |
| Admin moderation panel | 8 | 🎨 Prototype, to build |
| Google Maps and location services | 6 | ✅ Implemented |
| Offers and promotional campaigns | 2 | ✅ Implemented (see `offers_campaigns_plan.md`) |
| Push notification system | 3 | ✅ Implemented (Firebase keys: manual setup) |
| Chat and messaging system | 9 | ✅ Implemented |

**Module 6: Maps and Location Integration** (FR-12, UC-9) ✅ Implemented

* Interactive Google map of businesses behind the SDD's `MapService` interface, styled in Khojlo's colours
* Business pins with a floating preview card and a nearby carousel, linked to the business page
* Map results that refresh as the map moves and follow the Module 4 keyword and filters, with a List | Map switch
* Map pin picker, with address lookup, for setting a business location during registration and editing
* The business page shows its location on a map, with Directions to Google Maps navigation (or "Location unavailable")
* Home location indicator ("Near F-7 Markaz, Islamabad") and a Nearby row in the feed
* Valid coordinates enforced (BR-7). API keys are kept out of git; see the module record for setup

**Module 5: Reviews and Ratings System** (FR-6, FR-19, UC-7, REL-4) ✅ Implemented

* Any signed-in user (except the business's owner) submits a 1–5★ rating with an optional comment and up to 3 photos, and can edit or delete it. One review per business per user (BR-4)
* Business ratings and review counts recalculated from real reviews on every change (SDD Algorithm 7). Verified reviewers get a badge and are listed first
* Reviews on the business page with "See all", a full reviews screen with sorting and filters, and "My reviews" in the profile
* Owner replies, helpful votes, and user reports stored for the Module 8 moderation queue
* Rating filters and sorting in search, and the feed's Trending row, use real review data (count-weighted for ranking)

**Module 8: Admin and Moderation System** (FR-14, FR-15, UC-12, SEC-2, SEC-3)

* Verifying business profiles (FR-14), including the verification documents from UC-10. Whether businesses wait for verification before they appear is an open decision (see `docs/requirements/document_review.md`, decision 1)
* Removing spam and inappropriate content (FR-15), starting with the review reports Module 5 already stores (FR-19)
* Limiting profile changes to verified owners (SEC-2) and admin functions to admins (SEC-3)

**Offers and Promotional Campaigns** (Module 2: FR-10, UC-11) ✅ Implemented

* Special offers with a deal type and value (the SDD's discount), description, real dates validated per UC-11, terms, and Draft / Scheduled / Active / Expired. Owners create, edit, activate, deactivate and delete them
* Promotional campaigns that link existing offers (and featured services) for a period, with a banner, message, terms and publish switch. One campaign at a time per business
* Customers see live campaigns as Home banners, an "Active promotion" badge on cards, an "On now" strip and coupon-style offers on the business page, and a campaign details screen
* Activating and publishing need a verified business (UC-11 precondition). Savers are notified once per offer, and once per campaign if the owner opts in

**Push Notification System** (Module 3: FR-21, UC-15) ✅ Implemented (see `module9_chat_and_push_plan.md`)

* Firebase Cloud Messaging on Android and web, sent from the backend through the FCM HTTP v1 API. Push switches off cleanly without the Firebase keys, which are a manual setup step
* Notifications for new chat messages (when the recipient isn't in the app), new reviews (to the owner), replies to reviews, new offers (to people who saved the business), new businesses (to users interested in the category), and a trending digest (`python -m app.jobs.trending_digest`)
* The real Notifications screen (grouped timeline, mark read, tap to open) and per-type notification settings
* Tapping a notification opens its screen; a push arriving while the app is open shows a banner

**Module 9: Chat and Messaging System** (FR-23, FR-24, FR-25, UC-13, UC-14) ✅ Implemented (see `module9_chat_and_push_plan.md`)

* Customers message a business from its page; the owner replies. One conversation per customer and business, visible only to the two of them
* Live delivery over a WebSocket (about 20 ms on a local server), with polling when the connection drops
* Conversation list with unread counts and a Chat tab badge, "Seen" receipts, a typing indicator, photos, suggested replies, the business's offers, and reporting a conversation for Module 8
* Customer message counts (this week and unread) in the owner's dashboard

**General**

* Backend optimization and API integration for the new modules

---

### Phase 3 – Final Evaluation (100%)

The final phase completes the remaining advanced features and prepares the application for a production-level demonstration.

> Modules 7 and 10 were planned for 60% in earlier versions of this plan but are not on the 60% slide, so they are listed here. Confirm with their owner (see `docs/requirements/document_review.md`, decision 4).

* **Module 7: AI Chatbot Assistance (FR-13):** a working chatbot that answers questions using business data from the platform (RAG), available from the main navigation (USE-5) and meeting the 5-second response target (PER-4)
* **Module 10: AI Personalization and Recommendation (FR-22):** recommendations based on interests, saves, views and searches, then advanced personalization
* Admin and moderation items not finished in the 60% panel
* Advanced business analytics
* Performance testing against the SRS targets (PER-1 to PER-6)
* Security improvements, including HTTPS and WSS for all client-server traffic in deployment (SEC-4)
* Comprehensive testing and bug fixing
* Final UI/UX refinements
* Deployment and documentation

---

### Documentation Items to Resolve

The full review of the SRS, SDD and Feasibility Report, with a fix for each issue, is in `docs/requirements/document_review.md`. SRS v1.1 (`docs/requirements/SRS.md`) already resolves the SRS items, including:

* the missing functional requirements for comparison, chat, push notifications, personalization and more (FR-16 to FR-25);
* the UC-3 / FR-11 conflict over which businesses the feed prioritizes;
* the product name on the cover ("KOJLO").

Still open, and listed as decisions in the review:

* The verification rule (BR-3, UC-6, SEC-2), which depends on how Module 8 implements verification.
* The team work division for Modules 7, 8 and 10.
* The SDD and Feasibility Report corrections, which need to be made in the Word files. They include the traceability matrix numbering, the ER diagram, the screenshots, the Gantt chart and the tables of contents.

---

### Overall Development Strategy

The project follows an **incremental development approach**. Essential modules are implemented first to establish a fully functional Minimum Viable Product, and advanced modules are demonstrated as interactive prototypes before being converted into working features in later phases. Each module is planned against the SRS and SDD before implementation, and verified with automated backend and Flutter tests plus a run of the app in the browser. This keeps progress steady across the 30%, 60% and 100% evaluations while maintaining a stable and scalable architecture.
