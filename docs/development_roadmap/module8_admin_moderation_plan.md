# Module 8: Admin and Moderation — Plan and Implementation Record

Status: **implemented for the 60% evaluation** (30 Sep 2026): Tier 1 and Tier 2 below. The AI classifier and the Trust Score (Tier 3) are planned for 100%.

Module 8 covers SRS FR-14, FR-15, FR-19, UC-12, SEC-2 and SEC-3, and the SRS v1.2 additions FR-26 to FR-30 and UC-16 to UC-18. The 60% slide lists it as "Admin moderation panel". It answers `docs/requirements/document_review.md` decisions 1, 5 and 8; decision 7 (Trust Score) is still open.

## Sources

- **`docs/requirements/SRS.md`:** FR-14, FR-15, FR-19, BR-9, BR-10, BR-13, BR-15, UC-10 step 2, UC-12, SEC-2, SEC-3, SEC-5.
- **`docs/requirements/SDD.pdf`:** the Admin class (`verifyBusiness()`, `moderateContent()`); Algorithms 4, 5, 9 and 10; the business lifecycle (Draft, Pending, Verified, Rejected, Suspended, Archived) cited by the traceability matrix; the Screen 3 "Trust Score".
- **`docs/requirements/Feasibility_Report.pdf`, Module 8:** "verify business profiles, monitor user-generated content, and remove spam or fake information".
- **`docs/design/modules_layout.md`, Module 8:** "Should feel enterprise." Overview, Today's Stats, Business Verification Queue, Reports, Spam, Analytics, Users, Businesses, AI Insights; cards, charts, a timeline and an activity feed.

## Decisions (30 Sep 2026)

1. **Verification is automatic (decision 1).** A business is listed as soon as it's published. The system gives the Verified badge when it passes every check:
   - the owner's email is verified;
   - the listing is complete (category, a description of 30+ characters, address, map pin, phone, a photo, opening hours);
   - the owner took a **storefront photo in the app**;
   - there's no open report or automatic flag, and no report an admin upheld.

   Admins see only the businesses the checks refer to them (every check passes except the last), and can verify, reject, ask for more (UC-12's alternative flow), revoke or suspend any business. The team chose this over an admin approving every business by hand, which needs an admin on duty all the time. The SRS wording of FR-14, BR-9, UC-12, BR-3 and SEC-2 changed to match (v1.2).
2. **Admins can read a conversation once a participant reports it (decision 8).** It's the one exception to BR-15 and SEC-5. The report sheet says so. Admins still can't open any other conversation (the API returns 404).
3. **The 60% scope is Tier 1 and Tier 2.**
4. **AI flagging comes at 100%.** The rules and the admin decisions they produce come first. A Claude-based classifier is added later and measured against those decisions.
5. **Trust Score (decision 7): still open.** The recommendation stands: Module 8 owns it, at 100%.

## Should Khojlo use a trained AI model?

**Not one trained from scratch, and not before the moderation queues exist.** A model trained from scratch doesn't fit Khojlo:
- There's no labelled Khojlo data to train on or measure against.
- Content mixes English, Urdu and Roman Urdu, and public spam datasets are English-only.
- Self-hosted deep-learning models add gigabytes of dependencies to the backend.

Instead, the rules come first: they're free and explainable, and they work from day one. Every admin decision is stored, so by the 100% evaluation there's a labelled Khojlo dataset. It can measure an AI classifier's precision and recall, and can train a lightweight model to compare against it. The AI never removes anything itself; flags only reach an admin, which keeps BR-13 and Algorithm 10 intact.

## What was built

### Tier 1: the admin panel

1. **Admin-only access (SEC-3).**
   - Sign-up can't create admin accounts.
   - Every `/admin` endpoint needs an admin.
   - The app's `/admin` routes redirect everyone else, and **Profile → Admin panel** appears only for admins.
   - Admins no longer count as the owner of every business (SEC-2): they act through the audited panel.
2. **Automatic verification and the verification queue (FR-14, UC-12, Algorithm 9).**
   - The owner's **Verification** screen shows the checklist and takes the storefront photo.
   - The dashboard shows how far along it is.
   - Changing a verified business's name, address or map pin removes the badge until a new storefront photo is taken (Algorithm 5 "IF verification required").
   - Existing verified businesses keep their badges.
3. **Reports queue (FR-15, FR-19, Algorithm 10).**
   - Reviews, conversations and businesses, grouped per item, most-reported first.
   - Each item shows the content (a reported conversation's messages included), every report and note, the accounts involved, any automatic flags, and the history.
   - **Decide** removes the content (hides a review, closes a conversation, suspends a business) or dismisses the reports.
4. **Enforcement.**
   - Warn, suspend for 1–365 days, ban (optionally hiding every review they wrote) or lift.
   - Suspended and banned accounts get a 403 with the reason on every request and at sign-in, and no live chat connection.
   - Banning an owner suspends their businesses.
   - A suspended business disappears for everyone but its owner, who can't republish it.
   - Every action takes a reason from the Community Guidelines.
5. **Notifications (always on).**
   - The owner hears every verification outcome.
   - Authors hear about removals, warnings and suspensions (suspensions, bans and lifts also by email).
   - Reporters hear back whether their report was upheld.
   - Two new notification kinds, `account` and `verification`, can't be switched off.
6. **Audit log.** Every decision, by an admin or the automatic checks: who, what, why and when. It feeds the **Activity** timeline and the history on each business, report and account.
7. **Overview.** What needs an admin (referred businesses, open reports, open flags, suspensions), today's numbers, verification totals, a 14-day chart of reports, flags and new businesses, and the latest activity.

### Tier 2

8. **Reporting a business** from the bottom of its page: scam or fraud, adult content or prohibited items, not a real business, wrong information, offensive, other. One report per person per business (409 on a repeat).
   - *Accounts:* the app has no public profile pages, so there's nothing to put a "report account" button on. People are reported through their reviews, conversations and businesses. The admin panel acts on the account behind any of them, and on any account found under **Users**.
9. **Rule-based flags** (the **Spam & flags** section). A flag never hides anything, and editing the content so it no longer matches clears the flag. A flag an admin dismissed doesn't come back for the same text. Upholding a report settles the open flags on the same content, and upholding a flag settles its open reports and tells the reporters.

   | Rule | Where | Label |
   |---|---|---|
   | A link, a Pakistani mobile number, or "WhatsApp me" | reviews only | spam |
   | A payment wallet or bank transfer together with "advance", "pehle", "booking fee"… | listings, offers, campaigns, reviews | scam |
   | "You have won", "lucky draw", "inaam"… with "claim", "fee", "call"… | all | scam |
   | English and Roman Urdu vulgar words | all | offensive |
   | Escorts, "happy ending", nudes, porn… | all | adult |
   | Drugs, alcohol, fake documents, unlicensed weapons | all | prohibited |
   | 3+ five-star reviews from week-old accounts within 24 hours | the business | fake reviews |
   | The same phone number, or the same name within 200 m, under another owner | the business | duplicate |
   | 90% off or more | offers | scam |
   | The same message to 5+ businesses within an hour (the pattern only, never the text) | the sender's account | spam |

   Private chat text is never scanned (SEC-5).
10. **Blocking in chat.** Either participant can block. Nobody can send until the blocker unblocks, and the composer is replaced by a notice. A conversation a moderator closed can still be read.
11. **Community Guidelines** (BR-10) at **Profile → Community Guidelines**. The six reasons match the reasons every notice and admin decision uses.

## API

| Endpoint | Who | What |
|---|---|---|
| `POST /businesses/{id}/report` | signed in, not the owner | Report a listing |
| `GET /businesses/{id}/verification` | owner | The checklist |
| `PUT /businesses/{id}/verification/storefront` | owner | Add the storefront photo (a key from `POST /media`) |
| `POST /businesses/{id}/verification/review` | owner | Ask for another look after "needs info" or a rejection |
| `POST`, `DELETE /conversations/{id}/block` | participant | Block, unblock |
| `GET /admin/overview` | admin | The overview |
| `GET /admin/businesses?status=` | admin | `pending_review` (the queue), `recently_verified` (to spot-check), `needs_info`, `rejected`, `verified`, `unverified`, `suspended`, `all`; `q` searches names |
| `GET /admin/businesses/{id}` | admin | Checks, storefront photo, reports, flags, history |
| `POST /admin/businesses/{id}/verification` | admin | `approve`, `reject`, `request_info`, `revoke` (a note is required except to approve) |
| `POST /admin/businesses/{id}/suspend`, `/reinstate` | admin | Take a listing down, put it back |
| `GET /admin/reports?kind=&status=` | admin | Grouped reports |
| `GET /admin/reports/{kind}/{id}` | admin | One reported item |
| `POST /admin/reports/{kind}/{id}/resolve` | admin | `uphold` or `dismiss`, with a reason, a note and an optional account action |
| `GET /admin/flags`, `POST /admin/flags/{id}/resolve` | admin | The same for flags |
| `GET /admin/users?q=&status=`, `GET /admin/users/{id}`, `POST /admin/users/{id}/action` | admin | Find accounts; `warn`, `suspend`, `ban`, `lift` |
| `GET /admin/actions` | admin | The audit log |

## Data

Migration `backend/alembic/versions/f4c1a8e2b9d3_module8_admin_moderation.py`. It only adds tables and columns:
- **businesses:** `verification_status`, `verification_note`, `verified_at`, `verified_by_id`, `storefront_media_id`, `storefront_at`, `suspended_at`, `suspension_reason`. Businesses that already have the badge become `verified`.
- **users:** `is_banned`, `suspended_until`, `suspension_reason`.
- **conversations:** `blocked_by`, `blocked_at`, `closed_at`.
- **review_reports** and **conversation_reports:** `resolved_at`, `resolved_by_id`.
- **New tables:** `business_reports`, `moderation_flags`, `moderation_actions`.

`is_verified` stays the badge that search, cards and the offer rules read. It's kept in step with the new status.

## Main files

- **Backend:**
  - Models: `app/models/moderation.py`, plus new fields in `app/models/business.py`, `user.py`, `chat.py`, `review.py` and `notification.py`.
  - Services: `app/services/verification_service.py`, `moderation_service.py` and `moderation_rules.py`.
  - API: `app/api/admin.py`, plus hooks in `businesses.py`, `reviews.py`, `promotions.py`, `chat.py`, `auth.py` and `deps.py`.
  - The seed's demo moderation data is in `app/db/seed.py`.
- **App:**
  - `lib/core/models/moderation.dart`.
  - `lib/features/admin/`: the panel, business, report and account screens.
  - `lib/features/business/presentation/verification_screen.dart` and `lib/features/discovery/presentation/report_business_sheet.dart`.
  - `lib/features/account/presentation/guidelines_screen.dart`.
  - The retired prototype, `lib/features/prototype/admin_screen.dart`, is gone.

## Tests and checks

| Check | Result |
|---|---|
| Backend tests (`pytest`) | 287 passed, 57 of them new: `test_admin.py`, `test_verification.py`, `test_moderation_rules.py`, and a sign-up test in `test_flows.py` |
| Flutter tests (`flutter test`) | 109 passed, 10 of them new (`test/moderation_test.dart`) |
| `flutter analyze` | No issues |
| Migration on PostgreSQL 16.2 (a disposable local server) | Upgrade, `alembic check` (no drift), downgrade and upgrade again. Existing verified businesses kept their badges. |
| Seed on PostgreSQL | First run adds the three demo items; a second run adds nothing |
| The web app against that database (headless Edge) | Admin overview, reports, flags, a report, a business, the decision sheet and a real decision, the owner's dashboard and checklist, and the guidelines. No console errors. |

Running the real app found three problems, all fixed and covered by tests:
- Upholding a report left its flags open.
- A report page's bottom bar took the whole screen height.
- Opening or refreshing any page directly lost it and went to Home. This bug came from earlier modules; the router now returns to the requested page once the session is restored.

## Your manual steps

1. On the shared database, run `alembic upgrade head` in `backend/`. It only adds, and existing badges are kept.
2. Optionally run `python -m app.db.seed` for the demo moderation data. It's added once, and only while nothing has been reported or flagged yet.
3. No keys or settings are needed. Suspension emails use the existing SMTP settings, and are skipped without them.

## Limits and follow-ups

- **Storefront photos on the web:** browsers without a camera open a file picker, so the "taken in the app" guarantee holds on Android only.
- **At 60%, nobody checks the storefront photo automatically.** Admins can spot-check the week's verifications under **Verification → Recently verified**. At 100% the AI classifier checks that the sign matches the name.
- **Tier 3 at 100%:**
  - AI risk scoring for listings, reviews, offers and photos: Claude through the official `anthropic` SDK, with structured outputs, behind the same interface as the rules, and off without a key.
  - The Trust Score (decision 7).
  - Appeals and reporter credibility.

## SDD additions (ready to paste into the Word file)

**Data dictionary.**

| Entity | Attribute | Type | Description |
|---|---|---|---|
| Business | verificationStatus | VerificationStatus | unverified, pending_review, needs_info, verified, rejected |
| Business | storefrontPhoto | Media | Taken in the app; private to the owner and admins |
| Business | verifiedAt, verifiedBy | DateTime, User | verifiedBy is empty when the automatic checks verified it |
| Business | suspendedAt, suspensionReason | DateTime, String | Set while an admin has taken it down |
| User | isBanned, suspendedUntil, suspensionReason | Boolean, DateTime, String | Account standing |
| BusinessReport | business, reporter, reason, note, status | — | A user's report of a listing |
| ModerationFlag | target, rule, label, detail, excerpt, status | — | A match from the automatic rules |
| ModerationAction | admin, action, target, subject, reason, note, createdAt | — | One audit-log entry; admin is empty for automatic actions |

**Class diagram.**
- **Admin:** `verifyBusiness(businessId, decision, note)`, `moderateContent(targetType, targetId, decision, reason)`, `actOnAccount(userId, action, reason, days)`.
- **VerificationService:** `checks(business)`, `refresh(business)`.
- **ModerationRules:** `scanText(text)`, `checkBusiness()`, `checkReview()`, `checkOffer()`, `checkMassMessaging()`.
- **Associations:** Business 1–* BusinessReport; ModerationAction *–1 Admin.

**Algorithm 9 (revised): VerificationService.refresh() and Admin.verifyBusiness()**
```
BEGIN Refresh (after the owner changes the business, adds the storefront photo or verifies the email)
IF business is suspended OR status ≠ Unverified THEN stop
Run the checks: email, complete profile, storefront photo, clean record
IF all pass THEN Status = Verified; log "verified automatically"; notify the owner
ELSE IF all pass except the clean record THEN Status = Pending Review; log "referred"; notify the owner
END

BEGIN VerifyBusiness (admin, for a referred or any business)
Review the checks, storefront photo, reports and flags
Approve → Verified | Reject / Revoke → Rejected | Request more info → Needs Info
Record the decision and the note; notify the owner
END
```

**Algorithm 10 (revised): Admin.moderateContent()**
```
BEGIN ModerateContent
Retrieve reported or flagged content
Review the content, the reports and the flags
IF it violates the Community Guidelines THEN
   Remove it (hide the review / close the conversation / suspend the business / switch off the offer)
   Optionally warn, suspend or ban the account
   Resolve the remaining reports and flags on that content
ELSE
   Keep it; dismiss the reports or flag
ENDIF
Record the decision; notify the people affected and the reporters
END
```

**Business lifecycle state diagram** (the traceability matrix cites it). PlantUML:
```
@startuml Business_Lifecycle
[*] --> Listed : registered and published
state Listed {
  [*] --> Unverified
  Unverified --> Verified : every check passes
  Unverified --> PendingReview : checks pass but there is a report or flag
  PendingReview --> Verified : admin approves
  PendingReview --> NeedsInfo : admin asks for more
  PendingReview --> Rejected : admin rejects
  NeedsInfo --> PendingReview : owner answers
  Rejected --> PendingReview : owner asks again
  Verified --> Unverified : name or location changed
  Verified --> Rejected : admin revokes the badge
}
Listed --> Suspended : admin suspends (hidden)
Suspended --> Listed[H] : admin reinstates (verification status kept)
Listed --> [*] : owner deletes it
@enduml
```
