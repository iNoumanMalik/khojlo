# Module 5: Reviews and Ratings System — Plan

Status: **implemented** (27 Sep 2026). The decisions are below, the original plan follows, and the [Implementation record](#implementation-record) at the end describes what was built, how it was tested and how to roll it out.

## Decisions (confirmed 27 Sep 2026)

| # | Question | Decision |
|---|---|---|
| 1 | Demo data | **Seed real reviews.** Demo reviewer accounts write 3–8 genuine reviews per demo business. Ratings and counts are then recalculated from real reviews only, so the made-up totals ("214 reviews") are removed. |
| 2 | Who may review | **Any signed-in user**, verified email or not, except the business's own owner. There's no visit check. |
| 2a | "Priority" for verified users | Reviewers with a **verified email** get a **Verified** badge, and their reviews appear **first** in the default "Most relevant" order and in the business page preview. The average counts every review equally, so it matches the distribution bars and Algorithm 7. |
| 3 | Moderation | **Publish immediately, and users can report** a review (Spam / Fake / Offensive / Other). Reports are stored for Module 8's "Flagged reviews" queue. Hidden reviews (`is_approved = false`) are already left out of lists and ratings, so Module 8 only needs to flip the flag. |
| 4 | Design extras | **Owner replies** (one public reply per review), **helpful votes** (with a "Most helpful" sort) and **photo reviews** (up to 3 photos, with a "Photos" filter). Reactions, sentiment and highlights are not included. |
| 5 | Trust Score | **Not in this module.** It stays out until its owning module and algorithm are decided. |
| – | Smaller defaults | As listed under "Smaller defaults" below: optional comment of up to 1,000 characters, "Hassan R." names, edit any time with an "edited" mark, count-weighted sorting by rating, and the AI summary deferred to Module 7. |

## Sources

- `docs/requirements/SRS.pdf`:
  - UC-7 Submit Reviews and Ratings
  - FR-6 Submit Reviews (**BR-4:** one review per business per user)
  - UC-6 exception "Open map/reviews"
  - FR-15 Content Moderation, REL-4 (persistence), SCA-3 (growth)
  - Figure 3.1 use case diagram: "Review & Ratings" extends "View Business Details"
- `docs/requirements/SDD.pdf`:
  - §3.1.1 (the Reviews and Ratings Module stores and displays customer feedback; the Admin Module moderates reviews)
  - §4.1 class diagram: `Review` with `createReview()`, `updateReview()`, `deleteReview()`; `Customer.writeReview()`; `Admin.moderateContent(review)`
  - §4.3 state diagram: a "Reviewing" state reached from the business view
  - §5 data dictionary and Figure 5.1 ER diagram (`REVIEW`: customer_id, business_id, rating, comment, is_approved, created_at, updated_at, deleted_at)
  - Algorithm 7 `Customer.submitReview()`, Algorithm 10 `Admin.moderateContent()`
  - §8 text and Screen 3: Reviews Section, See All Button, Trust Score; Figure 8.3 mockup
- `docs/requirements/Feasibility_Report.pdf`:
  - Module 5 description (feedback on services, pricing and overall satisfaction; owners can view feedback)
  - Module 8 description (removing fake reviews)
- `docs/design/modules_layout.md`:
  - Module 5 "Reviews": overall rating, rating circle, distribution, AI summary, photo reviews, recent reviews, write review; review cards with photos, reactions and a verified badge
  - Business page, business dashboard and profile sections that list "Reviews"
- `docs/design/ui_design_direction.md`:
  - "Reviews": animated score circle, highlights, sentiment, helpful votes, photo reviews, reactions
  - Microinteraction: "Review submitted → confetti burst"
- `docs/design/Khojlo App.dc.html`:
  - Reviews screen: score and distribution, "Write a review", filter chips (All / Photos / Recent / Top rated), cards with photos and "Helpful (12)"
  - Admin "Flagged reviews" tab (Spam / Fake)
- Existing code:
  - a stub `reviews` table (author name only, no reviewer account) behind the unlinked prototype `/reviews` screen
  - `businesses.rating` and `review_count`, set by the seed script and used by search (rating filter and sort), the feed ("Trending"), Compare, the map and the owner dashboard

## What the documents ask for

| Source | Requirement |
|---|---|
| FR-6, UC-7 | A signed-in customer opens "Add Review", enters a rating and a comment, submits, and the review is saved |
| UC-7 | Alternative flow: **edit review**. Exception: **invalid review**. Business rule: **one review per business**. Assumption: **customer visited** |
| BR-4 | One review per business per user |
| SDD Algorithm 7 | Validate → store → **recalculate the average rating → update the business rating** |
| SDD class diagram | `Review(id, rating: Integer, comment, createdAt)` with create / update / delete |
| SDD ER diagram | Adds `is_approved`, `updated_at` and `deleted_at` (soft delete) |
| SDD Screen 3 | Business profile: **Reviews section** and a **See All** button that opens the complete list |
| SDD §8 | Review submission is confirmed with a success message; invalid input gets a clear validation message (also USE-3) |
| Feasibility | Business owners can **view customer feedback** |
| FR-15, SDD Algorithm 10 | The admin removes inappropriate content, starting from **reported content** (the admin side is Module 8) |
| REL-4 | Reviews and ratings persist across restarts |

## Proposed implementation (the parts the documents fix)

### Backend

1. **Reviews table rework.** Add the reviewer (`user_id`), `updated_at`, `deleted_at` and `is_approved`, following the ER diagram.
   * Rating is an integer from 1 to 5, enforced by a database check.
   * BR-4 is enforced by a unique index on (user, business) among non-deleted reviews.
   * The migration deals with the four stub reviews, which have no reviewer (see question 1).
2. **Endpoints.**
   * `GET /businesses/{id}/reviews` returns reviews with a summary: average, count, the 1–5★ distribution, and the caller's own review. Sort: recent, highest or lowest rated. Paged.
   * `POST /businesses/{id}/reviews` creates a review. A second review of the same business gets a clear "edit your review instead" error (409).
   * `PATCH /reviews/{id}` and `DELETE /reviews/{id}` are for the author only. Delete is a soft delete, per the ER diagram.
   * `GET /users/me/reviews` powers "My reviews".
3. **Rating recalculation (Algorithm 7).** Every create, edit and delete recalculates `businesses.rating` and `review_count` in the same transaction (REL-1). Search, the feed, Compare, the map and the dashboard then show real numbers with no changes to them.
4. **Validation (the "invalid review" exception).** The rating must be 1–5. Owners can't review their own business. Comment length is limited. Clear messages are returned for each case.
5. **Tests** for all of the above.

### Flutter

1. **Business page "Reviews" section** (SDD Screen 3):
   * average, count and a small distribution
   * the latest two or three reviews
   * **See all**, plus **Write a review** (or **Edit your review** if you already wrote one)
2. **Reviews screen** (replaces the prototype):
   * animated score circle and distribution bars
   * sort chips
   * a paged list, with your own review pinned first with Edit / Delete
3. **Write / edit review sheet**:
   * a 1–5 star picker with labels ("Loved it")
   * a comment box
   * inline validation
   * a success confirmation with the design's confetti
4. **Profile → My reviews** (the row exists today but does nothing).
5. **Owner dashboard → Reviews**: average, distribution and the latest reviews ("owners can view feedback").

## Decisions needed

1. **Demo data.** Seeded businesses show made-up totals, e.g. 4.8★ from "214 reviews", with no actual reviews behind them. Once ratings are recalculated from real reviews, those totals can't stay.
2. **Who may review, and "customer visited".** UC-7 names the Customer, and assumes they visited, which the app can't check.
3. **Moderation.** The ER diagram has `is_approved`, and Algorithm 10 starts from "reported content". But Algorithm 7 updates the rating immediately, and the admin side is Module 8.
4. **Design extras** that aren't in the SRS or SDD: owner replies, helpful votes, photo reviews, reactions, sentiment, review highlights and an AI summary.
5. **Trust Score** (SDD Screen 3, Figure 8.3): an "AI-generated trust indicator" meant to replace the flat star number. No algorithm or owning module is given.

Smaller defaults, unless you say otherwise:

* **Comment:** optional, up to 1,000 characters. A rating alone is a valid review.
* **Reviewer name:** shown as first name plus last initial ("Hassan R."), as in the mockup, with their avatar.
* **Edits:** allowed at any time, and the review is marked "edited". Deleting your review lets you write a new one.
* **Ranking:** listings still display the true average, but sorting by rating uses a count-weighted score, so one 5★ review doesn't outrank 4.8★ from 200 reviews. This keeps BR-6 (new businesses prioritized) fair without letting a single review dominate.
* **AI summary:** deferred to the chatbot module (Module 7), which brings the language model.

## Documentation issues found

1. ~~**SRS UC-7 table is misaligned.**~~ *Correction (28 Sep 2026):* the use-case tables in `SRS.pdf` are laid out correctly. The shifted rows came from the PDF's extracted text, not from the document itself.
2. **Actor naming.** UC-7 names the Customer, while Figure 3.1 links "Review & Ratings" to "User". Owners viewing feedback (Feasibility Report) has no use case or FR.
3. **Traceability numbering.** The SDD matrix numbers "Submit Reviews and Ratings" FR11, but it is SRS **FR-6**. This is the same numbering drift noted in Module 6.
4. **IDs.** The SDD gives `Review.id` as a UUID; the implementation uses integer IDs throughout, as in every earlier module.
5. **Approval flow.** The ER diagram's `is_approved` suggests reviews are approved before appearing, but Algorithm 7 updates the business rating immediately and no document describes an approval step.
6. **"Invalid review" is undefined.** FR-6 gives no rating scale or comment rules. The SDD's `rating: Integer` implies a 1–5 scale, but it's never stated.
7. **Reporting.** Algorithm 10 retrieves "reported content", but no FR or use case lets users report a review.
8. **Trust Score.** It's called "AI-generated", but nothing defines how it's computed or which module owns it.
9. **Design vs. SRS scope.** Photo reviews, reactions, helpful votes, sentiment and an AI summary appear only in the design notes.
10. **Module numbering.** The Feasibility Report's table of contents lists Reviews as Module 6. This is the known issue from Module 6.

## Implementation record

### Backend

| Piece | Where | Notes |
|---|---|---|
| Models | `app/models/review.py` | `Review` (reviewer, rating, comment, `is_approved`, `helpful_count`, owner reply, `updated_at`, `deleted_at`), `ReviewPhoto`, `ReviewVote`, `ReviewReport`. The database enforces the 1–5 rating (check constraint) and BR-4 (a unique index on reviewer + business over non-deleted reviews). |
| Migration | `alembic/versions/c5e8a2d4f610_module5_reviews_ratings.py` | Removes the four prototype reviews, which had no reviewer. Reshapes `reviews` to the ER diagram, adds the three new tables, and resets every business's rating and count to real (empty) values. Tested on PostgreSQL: upgrade, seeding twice, downgrade and upgrade again. |
| API | `app/api/reviews.py` | `GET/POST /businesses/{id}/reviews`, `PATCH/DELETE /reviews/{id}`, `PUT/DELETE /reviews/{id}/reply`, `PUT/DELETE /reviews/{id}/helpful`, `POST /reviews/{id}/report`, `GET /users/me/reviews`. |
| Rules | same | Signed-in users only, not the business's owner. One review per business (a clear 409 message). Rating 1–5, comment up to 1,000 characters, up to 3 photos, which must be your own uploads. Only the owner may reply. You can't vote on or report your own review, and each report is counted once. |
| Algorithm 7 | `app/services/review_service.py` | `refresh_rating()` recalculates the average and count in the same transaction as every create, edit and delete. Hidden and deleted reviews don't count. |
| Ordering | same | "Most relevant" lists verified reviewers first (decision 2a), then reviews with text or photos, then helpful and newest. Newest, highest, lowest and most-helpful sorts are also available. |
| Ranking | `ranking_score()`; `search/ranking.py`, `api/feed.py` | Search "Rating" sort, relevance tie-breaks and the feed's "Trending" row use a count-weighted score (prior 3.5 with a weight of 3 reviews). Businesses without reviews come last. All screens still show the plain average. |
| Photos | `media_service._referenced()` | Review photos count as "in use", so the abandoned-upload cleanup never deletes them. |
| Seed | `app/db/seed.py` | 12 demo reviewer accounts (8 with a verified email) write 3–8 reviews per catalogue business, aimed at each business's catalogue rating. The seed also adds owner replies (on every review of 3★ or less, and some others), helpful votes, and one review by the demo customer. Every business's totals are then recalculated from real reviews. Running it again changes nothing. |

### Flutter

| Piece | Where | Notes |
|---|---|---|
| Models, repository, state | `core/models/review.dart`, `features/reviews/data`, `reviews_providers.dart` | A shared "reviews changed" counter refreshes the business page, full list, dashboard and My reviews after any write, edit, delete or reply. Helpful votes are optimistic and roll back on error. |
| Business page (SDD Screen 3) | `business_reviews_section.dart` | Score circle and distribution, the top two reviews, **See all**, and the right call to action for the viewer: **Write a review**, **Edit your review**, or **Reply to reviews (N waiting)** for owners. The header's rating chips use the live summary, or say "No reviews yet". |
| Reviews screen ("See All") | `reviews_screen.dart` (`/business/:id/reviews`) | Animated score circle and bars (tap a bar to filter by stars), a "With photos" filter, five sort orders and paging. Your own review is pinned first with Edit / Delete. Each card has Helpful and Report, and owners get a Reply banner and per-review Reply / Edit / Remove. |
| Write / edit (UC-7) | `review_sheets.dart`, `review_flows.dart` | Star picker with labels, optional comment, up to 3 photos with upload progress, and inline validation ("Pick a star rating first."). A new review triggers the design's **confetti burst** and a success message. Report and reply sheets live here too. |
| My reviews | `my_reviews_screen.dart` (`/my-reviews`) | Linked from Profile, whose placeholder "Visited 0" stat became a real **Reviews** count. |
| Owner dashboard | `dashboard_screen.dart` | The rating card comes from real reviews and shows "N awaiting reply". A new **Reviews & replies** row opens the list. |
| "No reviews" instead of 0.0 | `BusinessCard.ratingLabel` | Cards, map pins and the map preview say "No reviews" rather than a fake ★ 0.0. |
| Removed | `prototype/reviews_screen.dart`, mock reviews | Replaced by the real screens. |

### Testing

* **Backend:** 156 tests pass. `tests/test_reviews.py` (22 tests) covers:
  * UC-7 and Algorithm 7, BR-4, invalid reviews, owner and unpublished-business rules
  * editing, soft delete and re-reviewing
  * verified-first ordering, star and photo filters, paging, hidden reviews, My reviews
  * owner replies, helpful votes and reports
  * photo attachment and the orphan cleanup
  * the weighted rating sort

  `tests/test_seed.py` checks that seeded totals equal real reviews and that BR-4 holds.
* **Flutter:** 60 tests pass. `test/reviews_test.dart` (13 tests) covers:
  * JSON parsing and relative dates
  * controller filters, sorting, optimistic helpful votes and replies
  * the reviews screen (helpful, report), the write flow (validation, submit, confetti message)
  * the owner reply flow, the business page section (with and without reviews), and My reviews

  `flutter analyze` is clean.
* **PostgreSQL:** the migration, seed and every endpoint were exercised against a local PostgreSQL. The seed wrote 167 reviews, every card total matched its reviews, and the database rejected duplicate reviews and out-of-range ratings.

### Rollout notes

* **Shared (Supabase) database.** Run `alembic upgrade head` and then `python -m app.db.seed`.
  * The migration deletes the four prototype reviews and resets every rating to real (empty) totals.
  * The seed then adds the demo reviewers and their reviews.
  * Teammates on older builds should pull first: the old seed's review code no longer matches the table.
* **Accounts.** The demo reviewer accounts (`ayesha.khan@khojlo.app` and others, password `password123`) are ordinary customer accounts. Use one to try helpful votes and reports on someone else's review.

### Out of scope, handed to other modules

* **Module 8 (Admin):** the "Flagged reviews" queue that reads `review_reports`, and the hide / keep action that sets `is_approved` and updates the report status.
* **Module 7 (Chatbot):** an AI summary of reviews.
* **Trust Score (SDD Screen 3):** still unassigned (decision 5).
* **Notifications:** telling owners about new reviews waits for push notifications (Module 3's pending item).
