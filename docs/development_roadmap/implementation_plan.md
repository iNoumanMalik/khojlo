### Development and Implementation Plan

The development of Khojlo follows an incremental approach. Core modules are fully implemented first, and the remaining modules start as interactive prototypes that are converted into working features in later phases. This keeps the primary functionality stable and demonstrable at every evaluation (30%, 60% and 100%), while leaving room to grow.

This plan reflects the implementation as of September 2026 and is aligned with the SRS, SDD and Feasibility Report in `docs/requirements/`.

> **Module numbering.** The Feasibility Report's body text and team work division list Module 5 as Reviews and Module 6 as Maps; its table of contents has them the other way round. This plan follows the body text. The table of contents should be updated to match before the next submission.

#### Status at a Glance

| # | Module | Requirements (SRS) | Status | Phase |
|---|---|---|---|---|
| 1 | User Authentication and Profile Management | FR-1, FR-2, FR-7, UC-1, UC-2 | ✅ Implemented | 30% |
| 2 | Business Registration and Management | FR-8, FR-9, FR-10, UC-10, UC-11 | ✅ Implemented | 30% |
| 3 | Business Discovery Feed (New & Trending) | FR-5, FR-11, UC-3 | ✅ Implemented (push notifications pending) | 30% (push: 100%) |
| 4 | Search, Filtering, and Comparison System | FR-3, FR-4, UC-4, UC-5 | ✅ Implemented | 30% |
| 5 | Reviews and Ratings System | FR-6, REL-4 | ✅ Implemented (see `module5_reviews_ratings_plan.md`) | 60% |
| 6 | Maps and Location Integration | FR-12, UC-9 | ✅ Implemented (see `module6_maps_location_plan.md`) | 60% |
| 7 | AI Chatbot Assistance (RAG) | FR-13, USE-5, PER-4 | 🎨 Prototype | 60% (basic) / 100% (complete) |
| 8 | Admin and Moderation System | FR-14, FR-15, SEC-2, SEC-3 | 🎨 Prototype | 100% |
| 9 | Chat and Messaging System | none yet (see below) | 🎨 Prototype | 60% |
| 10 | AI Personalization and Recommendation | FR-11 (personalized feed) | 🟡 Basic version in the feed | 60% (enhanced) / 100% (advanced) |

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

> **Note:** Push notifications for new businesses and offers are deferred to Phase 3, as originally planned.

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

The second phase converts the prototype modules into working features, in this order.

**Module 6: Maps and Location Integration** (FR-12, UC-9) ✅ Implemented

* Interactive Google map of businesses behind the SDD's `MapService` interface, styled in Khojlo's colours
* Business pins with a floating preview card and a nearby carousel, linked to the business page
* Map results that refresh as the map moves and follow the Module 4 keyword and filters, with a List | Map switch
* Map pin picker, with address lookup, for setting a business location during registration and editing
* The business page shows its location on a map, with Directions to Google Maps navigation (or "Location unavailable")
* Home location indicator ("Near F-7 Markaz, Islamabad") and a Nearby row in the feed
* Valid coordinates enforced (BR-7). API keys are kept out of git; see the module record for setup

**Module 5: Reviews and Ratings System** (FR-6, UC-7, REL-4) ✅ Implemented

* Any signed-in user (except the business's owner) submits a 1–5★ rating with an optional comment and up to 3 photos, and can edit or delete it. One review per business per user (BR-4)
* Business ratings and review counts recalculated from real reviews on every change (SDD Algorithm 7). Verified reviewers get a badge and are listed first
* Reviews on the business page with "See all", a full reviews screen with sorting and filters, and "My reviews" in the profile
* Owner replies, helpful votes, and user reports stored for the Module 8 moderation queue
* Rating filters and sorting in search, and the feed's Trending row, use real review data (count-weighted for ranking)

**Module 9: Chat and Messaging System**

* Real-time messaging between customers and business owners
* Conversation list, unread counts, and "Message" from the business page
* Message counts added to business analytics

**Module 7: AI Chatbot Assistance Module** (FR-13)

* Working chatbot that answers questions using business data from the platform (RAG), available from the main navigation (USE-5)

**Module 10: AI Personalization and Recommendation System**

* Enhanced recommendations based on interests, saves, views and searches

**General**

* Backend optimization and API integration for the new modules

---

### Phase 3 – Final Evaluation (100%)

The final phase completes the remaining advanced features and prepares the application for a production-level demonstration.

* Push notification system (Firebase Cloud Messaging) for new businesses, trending listings and offers (Module 3)
* Admin and moderation workflow (Module 8):
  * verifying business profiles before publication (FR-14), including the verification documents from UC-10
  * removing spam and inappropriate content (FR-15)
  * limiting profile changes to verified owners (SEC-2) and admin functions to admins (SEC-3)
* Complete RAG-based chatbot, meeting the 5-second response target (PER-4)
* Advanced AI personalization
* Advanced business analytics
* Performance testing against the SRS targets (PER-1 to PER-5)
* Security improvements, including HTTPS for all client-server traffic in deployment (SEC-4)
* Comprehensive testing and bug fixing
* Final UI/UX refinements
* Deployment and documentation

---

### Documentation Items to Resolve

These inconsistencies in the requirement documents should be fixed before the next submission:

* Module 5 and 6 numbering differs between the Feasibility Report's table of contents and its body (see the note at the top).
* The SDD traceability matrix numbers requirements differently from the SRS (e.g. SDD "FR10 View Business Location" is SRS FR-12).
* The SRS has use cases for comparison (UC-5) but no functional requirement for it, and no functional requirement at all for chat and messaging (Module 9).
* BR-3 (under FR-5) says only verified businesses are displayed. The agreed implementation shows every published business, with a "Verified only" filter; the rule should be reworded, or tied to the admin verification workflow in Phase 3.
* UC-3 says verified businesses appear first in the feed, while FR-11 says newest businesses appear first.
* The tables of contents in the SRS and Feasibility Report show "Error! Bookmark not defined." Updating the fields in Word before exporting fixes this.

---

### Overall Development Strategy

The project follows an **incremental development approach**. Essential modules are implemented first to establish a fully functional Minimum Viable Product, and advanced modules are demonstrated as interactive prototypes before being converted into working features in later phases. Each module is planned against the SRS and SDD before implementation, and verified with automated backend and Flutter tests plus a run of the app in the browser. This keeps progress steady across the 30%, 60% and 100% evaluations while maintaining a stable and scalable architecture.
