# Offers and Promotional Campaigns — Plan

Status: **implemented** (29 Sep 2026). The decisions and the original plan are below; the [Implementation record](#implementation-record) at the end describes what was built, how it was tested and how to roll it out.

Module 2 (Business Registration and Management): SRS FR-10 "Manage Promotions" and UC-11 "Manage Offers". The 60% slide lists it as "Offers and promotional campaigns". This plan answers `docs/requirements/document_review.md` decision 3 (what "campaigns" means) and issue D8 (the offer fields).

## Sources

- **Feature brief (Sayyam, 29 Sep 2026)**, "Khojlo — Offers and Promotional Campaigns". It is the main source for what a campaign is.
- **`docs/requirements/SRS.md` v1.1:**
  - UC-11: open offers → add/edit → save; alternative flow "Deactivate offer"; exception "Invalid dates"; business rule "Offer dates valid"; precondition "Business verified"
  - FR-10 "Business owners shall create promotional offers"
  - FR-21: push notifications about promotional offers
- **`docs/requirements/SDD.pdf`:**
  - class diagram `Offer(id, title, description, discount: Double, expiryDate, status: Boolean)` with create / update / delete
  - data dictionary (discount Decimal, start and end dates)
  - ER diagram (`title`, `description`, `discount`, `start_date`, `end_date`, `terms_conditions`, `usage_count`, `is_active`, `deleted_at`)
  - Algorithm 6 `createOffer()`: validate dates → save → associate with the business → confirm
  - Screen 3 "Offer Banner: displays active promotional offers"
- **Design notes:**
  - `design/ui_design_direction.md`: "Offer cards should shimmer", an "Offer badge" on cards, "Offer claimed" microinteraction
  - `design/modules_layout.md`: "Offers → animated coupon-style tiles"; offers on the dashboard, business page and feed
- **Existing code:**
  - `offers` table: title, **free-text** `starts_on` / `ends_on` ("Jul 1"), status Active / Scheduled / Ended, tone, views, redemptions
  - owner Offers screen: create with a title only; no edit, delete or deactivate
  - offers strip on the business page
  - "Has offer" search filter; offers in Compare and in the chat business card
  - new-offer notification to people who saved the business (Module 9)

## What to build

### Special Offers (the deal)

1. **Fields:**
   - title
   - description
   - **deal** information (see question 1)
   - start and end **dates**, as real dates, validated per UC-11 "Invalid dates" (end on or after start)
   - terms and conditions
2. **Status:**
   - the owner sets **Draft** or **Active** (activate / deactivate, UC-11 alternative flow)
   - **Expired** follows automatically from the end date (see question 2 for future start dates)
3. **Owner actions:** create, edit, delete (soft delete, as in the SDD ER `deleted_at`), activate / deactivate, list.
4. **Customers only ever see live offers.** That covers the business page, the "Has offer" filter, the "Offer" badge on cards, Compare and chat.
5. **Migration.** Existing offers keep their titles.
   - The old text dates ("Jul 1") are converted where they parse.
   - Active → Active, Scheduled → Active with a future start date, Ended → Expired.

### Promotional Campaigns (how the offers are promoted)

1. **Fields:**
   - name
   - description
   - **banner image**, using the existing photo upload
   - start and end dates
   - promotional message
   - featured services, linked from the business's existing services
   - **linked offers**, which reference existing offers and are never copied
   - terms and conditions
2. **Status** works the same way: the owner **publishes / unpublishes** (Draft ↔ Published). Live and Expired follow from the dates.
3. **Customer-facing (only for campaigns that are published and within their dates):**
   - **Campaign banners** at the top of Home's discovery feed, as a swipeable carousel: banner image, title, message, business name, dates, **View offers**
   - **Campaign details screen:** banner, business, description, message, dates, the linked offers that are live, featured services, terms, **View business**
   - An **"Active promotion" badge** on business cards (feed, search, map preview, saved). Tapping it opens the campaign.
   - An **"On now" strip** on the business page linking to its live campaign
   - **No new search filter.** The existing "Has offer" filter stays as it is (brief §8).
4. **Notification.** An optional "Notify people who saved my business" switch when publishing, using the Module 9 notification system and the existing "Offers" notification setting (see question 4).

### Owner dashboard

The "Offers & promotions" row becomes a screen with two clearly separated lists:
- **Offers**: "Create and manage individual deals", **+ Create offer**
- **Promotional campaigns**: "Create a promotion that highlights one or more existing offers", **+ Create campaign**

Each item shows its status chip (Draft / Scheduled / Active / Expired) and opens a full editor.

### Out of scope (brief §13)

Paid ads, budgets, bidding, targeting, audience segments, marketing analytics, payments and external ad networks. The existing view and redemption counters stay as they are; nothing new is added.

## Decisions (confirmed 29 Sep 2026)

| # | Question | Decision |
|---|---|---|
| 1 | Deal information | **Deal type + value.** The type is % off, Rs off, Buy 1 Get 1, Free item or Other. A value is entered where needed (20 → "20% OFF", 500 → "Rs 500 OFF"), and a free item or Other gets a short text. The app builds the badge label. The numeric value is the SDD's `discount`. |
| 2 | Dates and statuses | **Draft / Scheduled / Active / Expired.** An activated item with a future start date is "Scheduled" and goes live on its own. Offers may be open-ended (no end date). Campaigns need both dates. End before start is rejected (UC-11 "Invalid dates"). |
| 3 | Campaign rules | **One published campaign at a time** per business, meaning published and not yet expired. A campaign needs at least one linked offer that is activated and not expired before it can be published. Customers see only the linked offers that are live, and a campaign with none left is hidden. |
| 4 | Notifications | **People who saved the business, if the owner opts in** ("Notify people who saved my business"). One notification per campaign, sent when it goes live (at once if it's already live). It respects the user's existing "Offers" setting. |
| 5 | Verification (UC-11 precondition) | **Verified businesses only.** Unverified businesses can create and edit drafts, but can't activate offers or publish campaigns until an admin verifies them (Module 8). The app explains why. |

## Documentation notes (to change later)

1. **Campaigns aren't in any requirements document.** The SRS, SDD and Feasibility Report only mention "promotional offers". Campaigns come from the 60% slide and this brief. Suggest adding a Campaign entity to the SDD class and ER diagrams, a "Manage Campaigns" use case (or an extension of UC-11), and a line in FR-10.
2. **Offer status.** The SDD class diagram has `status: Boolean`, the ER diagram `is_active`, and the brief Draft / Active / Expired. The implementation will store the owner's choice (a boolean, matching the SDD) and derive Expired from the dates. The SDD text should say so.
3. **Discount type (D8).** The data dictionary says Decimal and the ER diagram says string. Settle this once question 1 is answered.
4. **UC-11 precondition "Business verified".** This depends on decision 1 in `document_review.md` (see question 5).

## Implementation record

### Backend

| Piece | Where | Notes |
|---|---|---|
| Offer model | `app/models/business.py` (`Offer`, `DealType`) | Title, description, deal type + value (the SDD `discount`) + text, real `start_date` / optional `end_date`, terms, `is_active`, soft delete, and a `notified_at` so savers are told once. No stored status. |
| Campaign model | `app/models/campaign.py` | `Campaign` (name, description, message, banner photo, dates, terms, `is_published`, `notify_savers`, soft delete). `CampaignOffer` and `CampaignService` link existing offers and services and never copy them. `sync_links()` reuses link rows so an edit never trips the unique constraints. |
| Status and visibility | `app/services/promotion_service.py` | Draft / Scheduled / Active / Expired come from the switch and the dates, in the businesses' timezone. A campaign is visible when it's published, within its dates, its business is published, and it still has a live offer. Deal labels ("20% OFF", "BUY 1 GET 1", "FREE DESSERT"). Validation messages for UC-11 "invalid dates" and the deal rules. |
| API | `app/api/promotions.py` | `GET/POST /businesses/{id}/offers`, `PATCH/DELETE …/offers/{offer_id}`, the same for `…/campaigns`, and `GET /campaigns/{id}`. Owners see everything; everyone else sees only live items. |
| Rules | same | Activating an offer or publishing a campaign needs a **verified business** (403 with an explanation). Only one published, unexpired campaign per business (409). Publishing needs at least one active or scheduled linked offer. Only your own offers and services can be linked. |
| Customer surfaces | `app/api/feed.py`, `business_service.to_card` | The feed returns `campaigns` (banners, new businesses first per BR-6, then soonest ending). Every business card carries `active_campaign` for the badge. The business page, "Has offer" filter, Compare and chat use live offers only. |
| Notifications | `promotion_service.offer_notice / campaign_notice / due_notices`, `app/jobs/promotions.py` | Savers hear about an offer once, when it first goes live (this replaces "on creation"), and about a campaign once, if the owner opted in. Scheduled items are announced on their start date, either by `python -m app.jobs.promotions` (cron) or the next time anyone opens Home, since there's no scheduler. |
| Photos | `media_service._referenced()` | Campaign banners count as "in use", so the abandoned-upload cleanup keeps them. A replaced or removed banner is deleted. |
| Migration | `alembic/versions/e7c2a9f4b1d8_offers_and_campaigns.py` | Converts existing offers: text dates → real dates (in the year they were created, wrapping "Dec 20 – Jan 5"); Active and Scheduled → on; Ended → expired; "25% off" in a title → a percent deal; all marked as already announced. Tested on PostgreSQL, including downgrade and upgrade. |
| Seed | `app/db/seed.py` | 12 offers covering every deal type (one open-ended, one expired, one draft at an unverified business) and three campaigns from the brief: **Weekend Food Festival** (Forno Italiano), **Grand Opening** (Brew & Bloom) and **Winter Special** (Glow Studio). Dates are refreshed relative to today on every run, so the demo always has live deals. |

### Flutter

| Piece | Where | Notes |
|---|---|---|
| Models | `core/models/business.dart` (`Offer`, `DealType`, `PromoStatus`, `CampaignRef`, `dateRangeLabel`), `core/models/campaign.dart`, `core/models/feed.dart` | "Until 20 Oct", "Ends tomorrow", "From 3 Oct", "Ongoing". |
| Owner: Offers & promotions | `features/promotions/presentation/promotions_screen.dart` (dashboard row, `/offers/:id`) | Two clearly separate lists with the brief's wording, status chips, and a menu to edit, activate / deactivate or publish / unpublish, preview and delete. Unverified businesses see a note explaining that drafts are fine and publishing unlocks after verification. |
| Offer editor | `offer_editor_screen.dart` | Deal type chips with a live badge preview, value or text as needed, start date, an optional end date, terms, and an Active switch that explains Scheduled vs live. The switch is disabled while unverified. Client-side checks mirror the server's. |
| Campaign editor | `campaign_editor_screen.dart` | Banner photo, name, message, description, dates, the offers to promote (expired ones can't be picked), featured services, terms, Publish, and "Notify people who saved my business". |
| Customer: Home banners | `home_screen.dart` (`_CampaignCarousel`), `promo_widgets.dart` (`CampaignBannerCard`) | A swipeable carousel under the search bar: image, name, message, business, dates, the top deal and **View offers**. |
| Customer: campaign details | `campaign_screen.dart` (`/campaign/:id`) | Banner, business (tappable), message, description, the live offers as coupons (tap for the offer's own terms), featured services, terms, **View business**. An ended promotion says so. Owners can preview drafts. |
| Promotion badge | `core/widgets/promotion_badge.dart` | "Active promotion" on feed cards (mini, hero, list) and search results. Tapping it opens the campaign. No new search filter (brief §8). |
| Business page | `business_detail_screen.dart` | An "On now" strip for its live campaign, and offers as shimmering coupon tiles that open the full offer with its terms. |

### Testing

* **Backend:** 229 tests pass. `tests/test_promotions.py` (24 tests) covers:
  * deal labels and validation
  * derived statuses; edit, activate, deactivate and delete
  * the verified-only rule; live-only visibility on the page, the filter and search
  * campaign linking, publishing rules and one-at-a-time
  * cross-business links, hiding when no live offers remain, private drafts and scheduled items
  * banner cleanup, and notifications (opt-in, once, scheduled)
* **Flutter:** 99 tests pass. `test/promotions_test.dart` (12 tests) covers:
  * models and date labels; the editor's label preview matching the server
  * the owner screen and the unverified note
  * both editors (validation, the verification lock, saved drafts)
  * campaign details, the ended state, the Home banner and the card badge

  `flutter analyze` is clean.
* **PostgreSQL:** the migration converted old-format offers correctly, seeding twice changed nothing the second time, and the feed, badges, campaign details and "Has offer" search all worked against the seeded data.

### Rollout notes

* **Shared database.** Run `alembic upgrade head` and then `python -m app.db.seed`. The migration keeps every existing offer (converted as above) and adds the campaign tables. The seed then refreshes the demo offers and adds the three demo campaigns.
* **Scheduled announcements.** Optionally schedule `python -m app.jobs.promotions` daily. Without it, Home visits trigger the same announcements.
* **Verification.** New businesses can only prepare drafts until Module 8 lets an admin verify them. Most demo businesses are verified; Smash & Stack isn't, to show the rule.

### Not included (brief §13)

Paid ads, budgets, bidding, targeting, audience segments, marketing analytics, payments and ad networks. There is also no "Deals & promotions" search filter (brief §8).
