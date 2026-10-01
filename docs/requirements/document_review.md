# Documentation Review

**Reviewed:** 28 Sep 2026, against the code on `dev`.
**Documents:** `SRS.pdf`, `SDD.pdf` and `Feasibility_Report.pdf` (version 1.0), the development roadmap, and the repository's folder structure.

The documents describe the intended system, not necessarily what's built. Where they disagree with the code, this review says which one should change.

**Legend**

- ✅ Fixed in the repository.
- 📝 Change it in the Word file before exporting the next PDF.
- ❓ Needs a decision from the team or the module's owner.
- 🔜 Will be fixed by the Module 9 and push notification plan (now done: see D3 and D4).

---

## Decisions needed

These can't be settled by editing text alone.

1. ✅ **Answered (30 Sep 2026): verification rule.** Businesses are listed as soon as they're published, and the **system** gives the Verified badge automatically when a business passes every check: the owner's email is verified, the listing is complete, the owner took a storefront photo in the app, and there's no open report or flag. Admins review only the businesses the checks refer to them, and can revoke a badge or suspend a listing. This is option (b), without making an admin approve every business by hand. SRS v1.2 rewords FR-14, BR-3, BR-9, UC-12 and SEC-2 to match; the UC-11 precondition "Business verified" stays, because owners can now meet it without waiting. Still to do in the Word files: the same SRS changes, and the SDD's Algorithm 9 and business lifecycle diagram (ready-to-paste text in `development_roadmap/module8_admin_moderation_plan.md` → "SDD additions").
2. ❓ **Work division (Feasibility Report, Table 4).** The table gives Module 8 to Kazim Shauket, along with Modules 7 and 10. The Module 4–6 records name Sayyam Tahir, and the team now plans for Sayyam to build Module 8 as well. Update the table to show who owns Modules 7, 8 and 10.
3. ✅ **Answered (29 Sep 2026)** — campaigns are defined and built as described in `docs/development_roadmap/offers_campaigns_plan.md` (a campaign promotes one or more existing offers for a period). Still to do in the Word files: add Campaign to the SDD class and ER diagrams and extend FR-10 / UC-11. Original note: **"Offers and promotional campaigns" (60% slide).** No one is assigned to it. Offers exist from the 30% build, but they are thinner than the SDD describes. The `offers` table has a title, free-text start and end values, and a status. The SDD's description, discount and real start/end dates are missing, so UC-11's "invalid dates" exception and Algorithm 6's date validation can't be enforced. Decide who owns this item and what "campaigns" means. If it means telling users about new offers, it overlaps with push notifications (FR-21) and fits with that work.
4. ❓ **Modules 7 and 10 at 60%.** The roadmap planned a basic chatbot and enhanced recommendations for 60%, but neither is on the 60% slide. The roadmap now lists them under 100%. Confirm this with their owner.
5. ✅ **Partly answered (30 Sep 2026): use cases without tables.** Module 8 added tables for **Manage Content, Manage Users and Monitor System** (UC-16 to UC-18, SRS v1.2), and a **Report Content** use case to the diagram. Manage Preferences, Manage Favorites and View Analytics (Modules 1 and 2) still have no table: their owners add one, or they come off the diagram.
6. ❓ **Chatbot provider.** The use case diagram names "Claude API" for the chatbot, but the Feasibility Report's tools table lists no language model. The Module 7 owner should confirm the provider, and the tools table should include it.
7. ❓ **Trust Score (SDD Screen 3).** It's described as an "AI-generated trust indicator", but no algorithm or owning module is defined (also noted in the Module 5 record). Either assign it to a module or remove it from the Screen 3 table. Module 8's proposal: it owns the Trust Score at 100%, built from verification, account age, upheld reports, review signals and chat response rate.
8. ✅ **Answered (30 Sep 2026): admin access to reported conversations.** Reporting a conversation shares it with Khojlo's moderators, and the report sheet says so. BR-15 and SEC-5 have the exception in SRS v1.2. Admins can't open any conversation nobody reported.

---

## SRS

The corrected text is in [SRS.md](SRS.md) (version 1.1, plus Module 8's version 1.2 changes, marked **(v1.2)**: see decisions 1, 5 and 8). Every item below is ✅ there and 📝 still needs applying to the Word file, as do the v1.2 changes.

| # | Issue in v1.0 | Fix in v1.1 |
|---|---|---|
| R1 | Cover says "KOJLO". | "Khojlo". |
| R2 | Table of contents shows "Error! Bookmark not defined." for UC-1 to UC-12. | 📝 In Word, right-click the table of contents → Update Field → Update entire table. |
| R3 | Revision history is empty. | Filled in. |
| R4 | Scope (1.2) leaves out chat, push notifications and personalization, although Modules 3, 9 and 10 include them. | Added. |
| R5 | OE-5 and CO-2 say Python 3.12; development uses 3.14. | "Python 3.12 or later". |
| R6 | OE-6 requires PostgreSQL 18.3 or later; the team's databases run earlier versions. | "PostgreSQL 14 or later". |
| R7 | CO-1 says Flutter 3.24+ / Dart 3.5+; the project needs Dart 3.11 (`pubspec.yaml`). | "Flutter 3.41+ and Dart 3.11+". |
| R8 | CO-4 allows only REST, which rules out a real-time chat channel. | REST, plus WebSocket for real-time features. |
| R9 | No environment entry or constraint for push notifications. | OE-10 and CO-11 (Firebase Cloud Messaging; iOS out of scope). |
| R10 | Use case diagram: Verify Business is linked to the Business Owner, but UC-12 says Admin. | Linked to Admin. See [diagrams/use_case.puml](diagrams/use_case.puml). |
| R11 | Use case diagram: "FireBase API" is linked to Login and Manage Profile, but login uses Google Sign-In and the system's own accounts. | Login → Google Sign-In; Firebase Cloud Messaging → Receive Notifications. |
| R12 | Use case diagram: "Googel Maps API" typo; "User" actor vs "Customer" in the tables; Admin not linked to Login. | Fixed. |
| R13 | No use cases for chat or notifications. | UC-13 Message a Business, UC-14 Respond to Customer Messages, UC-15 Receive Notifications. |
| R14 | UC-3 rule "Verified prioritized" contradicts FR-11 BR-6 "New businesses prioritized". | UC-3 now says "New businesses prioritized (BR-6)", matching the app. |
| R15 | Implemented or planned features with no FR: profile management (UC-2), email verification and password reset, comparison (UC-5), reporting reviews, analytics, push notifications, personalization, chat. | FR-16 to FR-25, with business rules BR-11 to BR-16. Existing numbers are unchanged. |
| R16 | FR-9: "shall be update business information". | "shall be able to update". |
| R17 | No non-functional requirements for messaging. | PER-6, REL-5 and SEC-5 added; REL-4, SEC-4 and SCA-3 extended. |
| R18 | References: "McGrew-Hill"; no Firebase reference. | Fixed and added. |
| R19 | Nothing maps the ten modules to the requirements. | Appendix A. |

The Module 5 record reported that the UC-7 table in `SRS.pdf` is misaligned. It isn't: the tables render correctly, and the misalignment came from the PDF's extracted text. That note is now corrected.

---

## SDD

| # | Issue | Suggested fix |
|---|---|---|
| D1 | 📝 Cover says "KOJLO"; revision history is empty. | "Khojlo"; fill in the history. |
| D2 | 📝 Table of contents omits 5.1 (Database / Data Storage) and 8.2 (Screen objects and actions); "3.1Architectural" is missing a space. | Update the field in Word. |
| D3 | 📝 Architecture (3.1, Figure 3.1) and data design (5) mention only REST and have no push notification service. | Ready-to-paste text and diagram changes are in `development_roadmap/module9_chat_and_push_plan.md` → "SDD additions". |
| D4 | 📝 Chat design is incomplete. There is no Conversation, Notification or device token entity. The data dictionary's Message has only content, sentAt and isRead, while the ER diagram's MESSAGE has sender, receiver and business. The class diagram's `BusinessOwner.sendMessageToUser()` doesn't match the dictionary's `replyMessage()`. | Data dictionary tables, class diagram changes and Algorithms 8, 14 and 15 are in the Module 9 record → "SDD additions". |
| D5 | 📝 IDs are UUIDs in the dictionary and ER diagram; the implementation uses integer IDs throughout. | Change the types to Integer, or add a note that the implementation uses auto-increment integers. |
| D6 | 📝 The ER diagram (Figure 5.1) has separate ADMIN, CUSTOMER and BUSINESS_OWNER tables. The section 5 text and the implementation use one USER table with a role. | Remove the three subtype tables from the figure. |
| D7 | 📝 The data dictionary misses implemented entities: Category, Service, OpeningHours, SavedList (named favourite lists), BusinessView (analytics), Media and BusinessPhoto, ReviewPhoto, ReviewVote, ReviewReport, SearchQuery and OtpCode. | Add them, or list them in an appendix. |
| D8 | 📝 Offer: `discount` is Decimal in the dictionary and string in the ER diagram. The implementation has neither discount nor description, and stores dates as text. | Settle this with decision 3, then make the dictionary, the ER diagram and the code match. |
| D9 | 📝 Section 4.3: the text describes LoggedOut and LoggedIn states, but Figure 4.3 shows LoginPage, DiscoveryFeed, ViewingBusiness and so on. The caption is also repeated as body text. | Describe the states the figure shows; remove the duplicate line. |
| D10 | 📝 The traceability matrix (section 7) uses its own FR01–FR20 numbering, so its IDs mean different things from the SRS IDs; for example, SDD FR03 is Business Registration but SRS FR-3 is Search. It also cites a "Business Lifecycle" state diagram (Draft, Pending, Verified, Rejected, Suspended, Archived) that the SDD doesn't contain. | Replace it with the table below. The business lifecycle diagram (as built by Module 8) is ready to paste in the Module 8 record → "SDD additions". |
| D11 | 📝 Screens (8.1 and 8.2) show a 4-tab bar (Home, Discover, Chat, Saved); the app has 5 tabs (Home, Explore, Map, Chat, Business). Screen 4 lists a Voice Input Button, which the app doesn't have. | Replace the screenshots with the current app and update the tables. Confirm voice input with the Module 7 owner. |
| D12 | 📝 Section 8 calls onboarding "AI-powered"; it is interest selection. | "Guided onboarding". |
| D13 | 📝 Algorithm 2 retrieves "all verified businesses"; the Screen 3 Trust Score has no definition. | Decision 1 is answered: Algorithm 2 should retrieve all listed (published, not suspended) businesses. The Trust Score is still decision 7. |

### Corrected traceability matrix (for D10)

Uses the SRS v1.1 IDs. "Not yet designed" marks requirements whose design the SDD still has to add.

| SRS ID | Requirement | Design component | Component item(s) |
|---|---|---|---|
| FR-1 | User Registration | Class diagram: User | (add `register()`) |
| FR-2 | User Login | Class diagram: User | `login()`, Algorithm 1 |
| FR-3 | Search Businesses | Customer, SearchEngine | `searchBusiness()`, `search()`, Algorithms 2 and 11 |
| FR-4 | Filter Businesses | SearchEngine, SearchStrategy | `search()` with strategies |
| FR-5 | View Business Details | Sequence diagram | Steps 7–12 |
| FR-6 | Submit Reviews | Customer, Review | `submitReview()`, Algorithm 7 |
| FR-7 | Save Favorites | Customer, Favourite | `saveFavourite()` |
| FR-8 | Business Registration | BusinessOwner | `registerBusiness()`, Algorithm 4 |
| FR-9 | Manage Business Profile | BusinessOwner, Business | `updateBusiness()`, `updateInformation()`, Algorithm 5 |
| FR-10 | Manage Promotions | BusinessOwner, Offer | `createOffer()`, Algorithm 6 |
| FR-11 | Discovery Feed | Sequence diagram | Business discovery process |
| FR-12 | Map Integration | MapService, GoogleMapsService | `displayLocation()`, Algorithm 12 |
| FR-13 | AI Chatbot | Chatbot, RAGChatbot | `answerQuery()`, Algorithm 13 |
| FR-14 | Business Verification | VerificationService, Admin | `refresh()`, `verifyBusiness()`, Algorithm 9 (revised), business lifecycle |
| FR-15 | Content Moderation | Admin | `moderateContent()`, Algorithm 10 (revised) |
| FR-16 | Manage Profile | User | `updateProfile()` |
| FR-17 | Email Verification and Password Reset | Not yet designed | — |
| FR-18 | Compare Businesses | Customer | `compareBusinesses()`, Algorithm 3 |
| FR-19 | Report Content | Review, Conversation, Business reports | Input to Algorithm 10 |
| FR-20 | Business Analytics | Not yet designed | — |
| FR-21 | Push Notifications | NotificationService, PushSender (FcmSender) | `notify()`, `send()`, Algorithms 14 and 15 |
| FR-22 | Personalized Recommendations | UserPreference | `getRecommendations()` |
| FR-23 | Send Message to Business | Customer, Conversation, Message | `openConversation()`, `sendMessage()`, Algorithm 8 |
| FR-24 | Respond to Customer Messages | BusinessOwner, Message | `replyMessage()` |
| FR-25 | Manage Conversations | Conversation | `markRead()` |
| FR-26 | Account Moderation | Admin | `actOnAccount()` |
| FR-27 | Automatic Flagging | ModerationRules, ModerationFlag | `scanText()`, `checkBusiness()`, `checkReview()` |
| FR-28 | Block a Conversation | Conversation | `block()`, `unblock()` |
| FR-29 | Community Guidelines and Notices | NotificationService | `notify()` |
| FR-30 | Moderation Audit Log | ModerationAction | — |

---

## Feasibility Report

| # | Issue | Suggested fix |
|---|---|---|
| F1 | 📝 Cover says "KOJLO"; the Gantt chart title says "KHOLJO". | "Khojlo". |
| F2 | 📝 The table of contents lists Module 5 as Maps and Module 6 as Reviews (the body has them the other way round), stops at Module 7, shows "Error! Bookmark not defined.", and has a stray "s" after page 19. | Update the field in Word. The body text is correct. |
| F3 | 📝 The Project Category boxes are all unticked. | Tick B (Web Application), C (Problem Solving and Artificial Intelligence) and E (Smartphone Application). |
| F4 | 📝 The Abstract, Problem Solution and Scope describe a "lightweight AI chatbot" for basic queries, while Module 7 is RAG-based. Scope leaves out reviews, chat, push notifications, personalization and admin moderation, which the module list includes. | Describe the chatbot as RAG-based, and extend Scope to match the module list (the SRS 1.2 wording can be reused). |
| F5 | 📝 "Software Process Methodology" describes Object-Oriented Methodology, which is a design methodology. The process model is Agile Scrum (Concept-9, SDD 2.1, SRS CO-8). | Rename the section "Design and Process Methodology" and add a Scrum paragraph. |
| F6 | 📝 Tools table: "MS Visual Studio 1.96+" (Visual Studio Code is meant); FastAPI "0.13" (the project uses 0.115 or later); Python 3.12; PostgreSQL 18.3; no Firebase or chatbot API, although the references list Firebase. | Visual Studio Code 1.96+, FastAPI 0.115+, Python 3.12+, PostgreSQL 14+, and add Firebase Cloud Messaging and the chatbot's model API (decision 6). |
| F7 | 📝 Table 4 headings say "Module 1 – Module 3" and "Module 7 – Module 8" but also list Modules 9 and 10. | Fix the headings along with decision 2. |
| F8 | 📝 The Gantt chart doesn't match the actual iterations. It puts messaging (Sprint 6) before the 30% increment and admin (Sprint 8) before 60%, and it has no push notifications or personalization. Its 60% milestone is 6 October 2026. | Update the chart to the actual 30% / 60% / 100% scope in `implementation_plan.md`. |
| F9 | 📝 The mockups show an early purple concept, not the current design (cream, gold and emerald; `docs/design/`). | Replace them with current screens. |
| F10 | 📝 Concept-1 describes only REST; Concept-3 describes intent handling rather than RAG. | Mention the real-time chat channel; describe RAG. |

---

## Repository

| # | Issue | Status |
|---|---|---|
| G1 | `docs/requirement/` duplicated `docs/requirements/`: the three PDFs were byte-identical. Its README linked to a non-existent `doc/requirement/` folder. | ✅ Removed; a new README with working links is in `docs/requirements/`. |
| G2 | The HTML mockup sat in `khojlo-mockup/` at the repository root. | ✅ Moved to `docs/design/khojlo-mockup/`. |
| G3 | The design bundle `Khojlo App.dc.html` sat loose in `docs/`, and the design notes were in a vague `docs/design/files/` folder. | ✅ Both moved into `docs/design/`; references in the module records updated. |
| G4 | No overview of the docs folder. | ✅ [docs/README.md](../README.md). |
| G5 | `implementation_plan.md` put push notifications and admin moderation at 100%, and the chatbot and personalization at 60%, unlike the 60% slide. | ✅ Aligned with the slide (decision 4). |
| G6 | `README.md` still called itself the 30% build and listed Modules 5 and 6 as prototypes. | ✅ Updated. |
| G7 | The Module 5 record's "UC-7 table misaligned" issue was a text-extraction artifact. | ✅ Corrected. |
| G8 | The Module 4 record's documentation issues are partly resolved by SRS v1.1. | ✅ Marked. |
| G9 | `.claude/launch.json` and `frontend/.claude/launch.json` are tracked although `.gitignore` ignores `.claude/`. | Not changed: removing them from git would also delete them from teammates' checkouts on their next pull. Untrack them together if the team agrees. |
