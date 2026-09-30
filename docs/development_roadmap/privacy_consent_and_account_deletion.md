# Privacy Consent and Account Deletion (Module 1) — Implementation Record

Status: **implemented** (30 Sep 2026, for the 60% evaluation on 6 Oct 2026). Requirements: SRS v1.1 **FR-26** (Privacy Consent), **FR-27** (Delete Account), BR-17, BR-18, SEC-6, SEC-7.

Khojlo stores names, emails, phone numbers, photos, private messages and push device tokens, and it uses the device location. Before this change, the sign-in screen had a line of text about a privacy policy that didn't exist, consent was never recorded, and there was no way to delete an account.

## Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Where the policy text lives | In the app (`frontend/lib/features/legal/privacy_policy.dart`), so it can be read before signing up. The server records only the **version** each user agreed to (`backend/app/core/privacy.py`). |
| 2 | How consent is collected | Email sign-up: a checkbox that is **never pre-ticked**, and the server rejects a sign-up without the current version (409). Google sign-up, older accounts, and everyone after a policy change: a **consent screen** the router shows before anything else. |
| 3 | Changing the policy | Bump the version (the date the wording changed) in **both** files. Everyone sees the consent screen again on their next launch. |
| 4 | What deletion removes | Everything, immediately (hard delete via the existing `ON DELETE CASCADE`s): profile, photos, businesses (with their photos, offers, reviews and conversations), reviews, votes, reports, saved lists, conversations and messages (**both sides' copy**), devices, notifications, one-time codes and search history. |
| 5 | What deletion keeps | Business **view counts**: `business_views.viewer_id` becomes null, so owners' analytics don't drop. Anonymous "popular searches" rows were never linked to a user. |
| 6 | Confirming deletion | Re-enter the password. Google-only accounts have no password, so they just confirm. The wrong password returns 403, not 401, so the app doesn't treat it as an expired session. |
| 7 | Location | Before the device's permission prompt, a sheet explains why Khojlo wants the location. "Not now" skips the system prompt entirely. On iOS that prompt only appears once, so skipping it keeps the option to ask later. The location is never stored (SEC-6). Push already asks only from a "Turn on" button with an explanation. |

## What was built

**Backend**
- `users.privacy_policy_version` and `users.privacy_consent_at` columns; `UserOut` gains `needs_privacy_consent` and `has_password`.
- `POST /auth/register` requires `privacy_policy_version` and records consent.
- `POST /users/me/privacy-consent` `{policy_version}` records consent (the consent screen).
- `DELETE /users/me` `{password}` deletes the account (`app/services/account_service.py`). It then recalculates the counters the cascade can't: ratings of businesses the user reviewed, helpful counts of reviews they voted on, and save counts. It also closes the user's open WebSockets.
- Migration `e3b7c9a1f2d4`: the two columns, plus `ON DELETE SET NULL` on `business_views.viewer_id` (before this, deleting any user who had viewed a business would fail).

**App**
- Privacy policy screen (`/privacy`), reachable signed in or out: from the sign-in footer, the sign-up checkbox, the consent screen and Account › Privacy policy.
- Consent screen (`/privacy-consent`) with a four-point summary, "I agree" and "Not now — sign out".
- Sign-up consent checkbox, with an inline error if it's not ticked.
- Account › **Delete account**: a confirmation sheet listing what will be removed, with a password field for password accounts.
- The location explanation sheet (`core/location/location_rationale.dart`), built into `LocationService`, so all seven places that ask for the location get it.

## Tests

- Backend `tests/test_privacy.py` (8 tests): consent recorded on sign-up; old or missing version rejected; Google sign-ups must agree; a new version asks everyone again; wrong or missing password refused; Google-only delete. Two end-to-end deletes check every table (for a customer and for an owner), plus the recalculated rating, save and helpful counts.
- The test database now enforces foreign keys (`PRAGMA foreign_keys=ON` in `conftest.py`), so the cascades are tested the way PostgreSQL runs them. The whole suite passed unchanged with this on.
- The migration was run up, down and up again on a real PostgreSQL 14 database. Every account in the seed data was then deleted through the service, leaving no rows behind except anonymous searches. An owner with a profile photo and business photos was also deleted cleanly.
- App `test/privacy_test.dart` (5 tests) covers the sign-up checkbox, the consent screen and both delete-sheet variants. `test/location_service_test.dart` checks that the system prompt appears only after the explanation is accepted, and never on silent checks.

## Your manual steps

1. Run `alembic upgrade head` in `backend/` (every teammate and the shared database).
2. Replace the placeholder contact address `privacy@khojlo.app` in `privacy_policy.dart` (`kPrivacyContactEmail`) with a real inbox.
3. The seeded demo accounts have no consent recorded, so each one shows the consent screen once after signing in. That's a good way to demo FR-26.
4. Have the policy text read by the team or supervisor. It describes what the code does as of this date. Update it whenever a feature starts collecting something new (e.g. Module 7's chatbot or Module 10's personalisation).
