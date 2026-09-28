# Module 9: Chat and Messaging, with Push Notifications (Module 3) — Plan

Status: **implemented** (28 Sep 2026, for the 60% evaluation on 6 Oct 2026). The decisions and the plan are below. **[Your manual steps](#your-manual-steps)** lists what only you can do (the Firebase console, keys and devices), and the [Implementation record](#implementation-record) at the end describes what was built and how it was tested.

Push notifications formally belong to Module 3 (Business Discovery Feed), but they're built together with chat. New chat messages are the main thing that sends a push, and both need the same real-time plumbing.

## Decisions (confirmed 28 Sep 2026)

| # | Question | Decision |
|---|---|---|
| 1 | Which push notifications | **All of these:** a new chat message (to the other side); a new review (to the owner); an owner's reply (to the reviewer); a new offer (to users who saved the business); a new business (to users interested in its category); and a **trending digest** sent with one command. |
| 2 | Chat extras | **Photos** in messages, **"Seen"** receipts, a **typing indicator**, and **reporting** a conversation (stored for Module 8). |
| 3 | Platforms | **Android and web.** iOS needs a paid Apple Developer account, so it's out of scope (SRS CO-11). |

Defaults, unless the team says otherwise:

- **Only customers start conversations.** An owner replies in conversations customers opened, and can't message their own business (BR-16). This stops owners cold-messaging people.
- **One conversation per customer and business.** Tapping Message again reopens it.
- **Live delivery** over a WebSocket, with polling when the connection drops. Sending and history use the normal REST API, so everything is testable like the other modules.
- **Chat messages don't go into the Notifications list.** The Chat tab, with its unread badges, is their inbox. Reviews, replies, offers, new places and trending do go into the list.
- **Notification settings** have one switch per type, under Profile.
- **No booking shortcut.** The design's chat layout has one, but Khojlo has no booking module (SRS CO-10).

## Sources

- `docs/requirements/SRS.md` (v1.1):
  - FR-23 Send Message to Business, FR-24 Respond to Customer Messages, FR-25 Manage Conversations
  - UC-13 Message a Business, UC-14 Respond to Customer Messages
  - FR-21 Push Notifications, UC-15 Receive Notifications
  - BR-14, BR-15, BR-16; PER-6, REL-4, REL-5, SEC-4, SEC-5; OE-10, CO-4, CO-11
- `docs/requirements/SDD.pdf`:
  - §3.1 (Chat and Messaging module; messages stored in PostgreSQL)
  - §4.1 class diagram (`Message`, `Customer.sendMessage()`, `BusinessOwner.replyMessage()`)
  - §4.2 sequence diagram "Message Business" (steps 23–28), §4.3 state diagram "Chatting"
  - §5.2 data dictionary and Figure 5.1 (`MESSAGE`), Algorithm 8 `Customer.sendMessage()` ("notify business owner")
  - Screen 3 "Message Button"
- `docs/requirements/Feasibility_Report.pdf`: Module 3 (push notifications about new businesses, trending listings and offers) and Module 9 (inquiries about products, services, pricing, availability or appointments; owners respond in real time).
- `docs/design/modules_layout.md`:
  - Module 9 layout: business header → quick actions → messages → suggested replies → offers → booking shortcut → attachment; "Messages animate. Business profile collapses while scrolling."
  - Notifications: a grouped timeline with Offers, Messages and Trending.
- Existing code:
  - the prototype `features/prototype/chat_screens.dart` (Kai card above the conversations; the conversation screen) and `prototype/notifications_screen.dart`
  - the Firebase settings already in `backend/app/core/config.py`
  - `BusinessAnalytics.messages` (always 0 until now)

## What the documents ask for

| Source | Requirement |
|---|---|
| FR-23, UC-13 | A signed-in customer sends a message to a business from its profile or an existing conversation. Exceptions: empty or too-long message; message not sent (retry). |
| FR-24, UC-14 | The owner reads and replies **in real time**. Alternative flow: open the conversation from a notification. |
| FR-25 | A conversation list with the latest message and unread count; messages are marked read when opened. |
| BR-15, SEC-5 | Only the two participants can read a conversation. |
| BR-16 | Only the business's owner replies on its behalf. |
| PER-6 | A message reaches a recipient who has the app open within 2 seconds. |
| REL-5 | Messages to an offline recipient are stored and shown when they next open the app. |
| FR-21, UC-15, BR-14 | Push notifications about new businesses, trending listings, offers and messages, only to users who allowed them, with a way to turn them off. |
| SDD Algorithm 8 | Validate → store → **notify the business owner** → confirm. |
| SDD Screen 3 | A **Message** button on the business profile opens direct messaging. |

## How it works

```
Customer taps "Message" on a business page
  → POST /conversations {business_id}          (reopens the conversation, or starts one)
  → POST /conversations/{id}/messages          (saved in PostgreSQL)
      ├─ the owner has the app open?  → delivered instantly over their WebSocket
      └─ the app is closed or in the background? → a push through Firebase Cloud Messaging
                                                    "Ali: Do you deliver to G-9?" → tap opens the chat
```

- The app keeps **one WebSocket** open while it's in the foreground. It closes it when the app goes to the background, so the server knows to send a push instead.
- The server keeps the list of open sockets in memory, so it runs as **one process**. Both demo devices must use the **same running backend** for live delivery. Push works either way.
- Without the Firebase key, push is switched off and everything else keeps working, like Maps without its key.

### API (all under `/api/v1`)

| Method and path | Purpose |
|---|---|
| `POST /conversations` | Reopen or start a conversation with a business (UC-13). |
| `GET /conversations` | My conversations, as a customer and as an owner, newest first. |
| `GET /conversations/unread` | Unread message count for the Chat tab badge. |
| `GET /conversations/{id}` | The conversation header: the business (for the customer) or the customer (for the owner). |
| `GET /conversations/{id}/messages` | Message history, paged. |
| `POST /conversations/{id}/messages` | Send a message, optionally with a photo (FR-23, FR-24). |
| `POST /conversations/{id}/read` | Mark as read ("Seen", FR-25). |
| `POST /conversations/{id}/report` | Report a conversation for the admin (Module 8). |
| `WS /ws` | Live events: new messages, "Seen", typing. |
| `PUT /notifications/devices` | Register this device for push. |
| `POST /notifications/devices/unregister` | Stop push to this device (on logout). |
| `GET /notifications`, `GET /notifications/unread-count`, `POST /notifications/read` | The Notifications list. |
| `GET /notifications/preferences`, `PUT /notifications/preferences` | Notification settings. |

### New data

| Table | Holds |
|---|---|
| `conversations` | One per customer and business, the time of the last message, and how far each side has read. |
| `messages` | The sender, which side sent it, the text, an optional photo, and the time. |
| `conversation_reports` | Reports for the Module 8 moderation queue. |
| `device_tokens` | The devices each user gets push notifications on. |
| `notifications` | The Notifications list (reviews, replies, offers, new places, trending). |
| `users.notification_prefs` | Which notification types the user has turned off. |

---

## Your manual steps

Everything below needs your accounts, a browser login or a physical device, so it can't be done from the code. Do steps 1–5 as early as possible: the push features can't be tested until they're done. Chat itself works without any of them.

### A. Firebase (for push notifications)

1. **Get access to the Firebase project.**
   - Open `frontend/android/app/google-services.json` and note the `project_id`.
   - Go to [console.firebase.google.com](https://console.firebase.google.com) and open that project. It already exists, because Google Sign-In uses it.
   - If a teammate created it, ask them to add you under Project settings → **Users and permissions** as **Owner** or **Editor**.
2. **Check that Cloud Messaging is on.** Project settings → **Cloud Messaging** tab. "Firebase Cloud Messaging API (V1)" should say **Enabled**. If it doesn't, use the ⋮ menu next to it to enable it in Google Cloud.
3. **Create the server key** (lets the backend send pushes).
   - Project settings → **Service accounts** → **Generate new private key** → Generate key. A JSON file downloads.
   - Create the folder `backend/secrets/` and save the file there as **`firebase-service-account.json`**. That folder is already in `.gitignore`.
   - In `backend/.env` add: `GOOGLE_APPLICATION_CREDENTIALS=./secrets/firebase-service-account.json`
   - **Never commit this file or paste it into chat.** It can send notifications as your project. If it leaks, delete the key on the same page and generate a new one.
   - A teammate who wants push on their own backend needs the same file (share it privately) or their own key. Without it, their backend simply sends no pushes.
4. **Register the web app and copy its settings.**
   - Project settings → **General** → Your apps → **Add app** → the **Web** icon (`</>`). Nickname: `Khojlo web`. Leave Firebase Hosting unticked.
   - Firebase then shows a `firebaseConfig` snippet (you can find it again later under Your apps → Khojlo web → SDK setup and configuration → **Config**).
   - Copy its values into `frontend/dart_defines.json`, the same gitignored file as the Maps keys (copy `dart_defines.example.json` if you don't have one):

     | `firebaseConfig` field | `dart_defines.json` key |
     |---|---|
     | `apiKey` | `FIREBASE_API_KEY` |
     | `appId` | `FIREBASE_APP_ID` |
     | `projectId` | `FIREBASE_PROJECT_ID` |
     | `messagingSenderId` | `FIREBASE_MESSAGING_SENDER_ID` |
     | `authDomain` | `FIREBASE_AUTH_DOMAIN` |
     | `storageBucket` | `FIREBASE_STORAGE_BUCKET` |

   - Android needs nothing here: it reads the same project from `frontend/android/app/google-services.json`, which is already in the repository.
5. **Create the Web Push key.**
   - Project settings → **Cloud Messaging** → Web configuration → **Web Push certificates** → **Generate key pair**.
   - Copy the long public key into `frontend/dart_defines.json` as `"FIREBASE_WEB_VAPID_KEY": "<the key>"`.
6. **Optional, recommended before any public deployment.** In [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → Credentials, restrict the "Browser key (auto created by Firebase)" to HTTP referrers `http://localhost:*` plus your deployed domain.

**How to check it worked:** start the backend. If the key is found, the first push is sent without complaint; if not, the log says "Push notifications are off: Firebase credentials are not configured." In the app, the Chat tab shows a **Turn on notifications** card; if it doesn't appear on the web, the values from step 4 are missing.

### B. Devices for testing

7. **Android.** Use a real phone (with Google Play services, as nearly all are), or an emulator whose system image says **Google Play**. Plain AOSP images can't receive push.
   - Connect as the README describes (`adb reverse tcp:8000 tcp:8000`).
   - Run with `flutter run --dart-define-from-file=dart_defines.json`.
   - On Android 13 and later, tap **Allow** when the app asks to send notifications. If you tapped Don't allow: Settings → Apps → khojlo → Notifications.
8. **Web.** Use Chrome on `http://localhost` (push needs localhost or HTTPS), not an incognito window, which blocks push.
   - Run with `flutter run -d chrome --dart-define-from-file=dart_defines.json`.
   - Tap **Turn on notifications** in the Chat tab, then click **Allow**. If you blocked it, click the icon left of the address bar → Notifications → Allow.
   - Test with the tab in the background or minimised, not closed: the browser must be running. On the web a notification appears as a system notification even while Khojlo is open.

### C. Database and demo

9. **Shared database.** When the team is ready, run on the shared Supabase database: `alembic upgrade head`, then `python -m app.db.seed`. Tell Sayyam first, so nobody generates a migration from an older branch in between. The migration only adds tables and one column.
10. **Rehearse the demo.** The phone is the customer (`customer@khojlo.app`) and Chrome is the owner (`owner@khojlo.app`), both against **your** backend (password `password123`):
    1. On the phone, open a business → **Message** → send "Do you deliver to G-9?". It appears instantly in Chrome; the owner starts typing and the phone shows "typing…"; the owner opens it and the phone shows "Seen".
    2. Put the phone app in the background and reply from Chrome. A push arrives on the phone, and tapping it opens the conversation.
    3. As the customer, write a review. The owner's Chrome gets a push, which opens the reviews.
    4. As the owner, add an offer. Customers who saved that business get a push.
    5. Just before the demo, run `python -m app.jobs.trending_digest` in `backend/` to send everyone a "Trending in …" notification.
11. **Update the Word documents.** Paste the [SDD additions](#sdd-additions-to-paste-into-the-word-file) below into the SDD, and add a row to its revision history.

---

## SDD additions to paste into the Word file

These close the chat and notification gaps listed in `docs/requirements/document_review.md` (items D3 and D4). IDs are integers, as in the rest of the implementation.

### Architecture (SDD §3.1, Figure 3.1)

Add to the Presentation Layer text: *"…communicating with the backend using RESTful APIs, and a WebSocket connection that delivers chat messages, read receipts and typing indicators live while the app is open."*

Add to the Application Layer text: *"A Notification Service sends push notifications through Firebase Cloud Messaging when the recipient isn't using the app: new messages, new reviews, replies to reviews, offers from saved businesses, new businesses in the user's interests, and a weekly trending digest."*

In Figure 3.1, add **Firebase Cloud Messaging** as an external service connected to a new **Notification Service** box in the Application Layer, and a **WebSocket (live events)** link between the Flutter apps and **Chat & Messaging**.

### Class diagram (SDD §4.1, Figure 4.1)

- Add **Conversation** (`id`, `customerId`, `businessId`, `lastMessageAt`, `customerLastReadId`, `businessLastReadId`; `markRead()`). Customer 1 — * Conversation; Business 1 — * Conversation; Conversation 1 — * Message.
- **Message** now belongs to a Conversation instead of holding sender, receiver and business itself.
- Rename `BusinessOwner.sendMessageToUser()` to `replyMessage(conversationId, content)`, matching the data dictionary.
- Add a **PushSender** interface with `send(tokens, message)`, implemented by **FcmSender** (and NullSender when Firebase isn't configured), in the same way as MapService / GoogleMapsService.
- Add **NotificationService** (`notify(recipients, kind, title, body, route)`), which uses PushSender; **Notification** and **DeviceToken**, each belonging to a User (1 — *).

### Data dictionary (SDD §5.2)

**Conversation**

| Attribute | Type | Description |
|---|---|---|
| id | Integer | Conversation identifier |
| customerId | Integer | The customer who started it |
| businessId | Integer | The business it is with |
| createdAt | DateTime | When it was opened |
| lastMessageAt | DateTime | Time of the latest message |
| customerLastReadId | Integer | Newest message the customer has read |
| businessLastReadId | Integer | Newest message the business has read ("Seen") |

**Message** (replaces the current table)

| Attribute | Type | Description |
|---|---|---|
| id | Integer | Message identifier |
| conversationId | Integer | The conversation it belongs to |
| senderId | Integer | The user who sent it |
| fromBusiness | Boolean | Sent by the business owner rather than the customer |
| content | Text | Message body, up to 2,000 characters (may be empty with a photo) |
| photoId | Integer | An attached photo (optional) |
| clientId | String | The app's id for this send, so a retry isn't stored twice |
| sentAt | DateTime | Sending time |

Read status comes from the conversation's last-read ids, which replaces `isRead`.

**ConversationReport**

| Attribute | Type | Description |
|---|---|---|
| id | Integer | Report identifier |
| conversationId | Integer | The reported conversation |
| reporterId | Integer | The participant who reported it |
| reason | ReportReason | Spam, harassment, scam or other |
| note | String | Optional details |
| status | ReportStatus | Open, removed or dismissed (Module 8) |
| createdAt | DateTime | When it was reported |

**DeviceToken**

| Attribute | Type | Description |
|---|---|---|
| id | Integer | Identifier |
| userId | Integer | The signed-in user of the device |
| token | String | Firebase Cloud Messaging registration token |
| platform | DevicePlatform | Android or web |
| createdAt, lastSeenAt | DateTime | First and latest registration |

**Notification**

| Attribute | Type | Description |
|---|---|---|
| id | Integer | Notification identifier |
| userId | Integer | The recipient |
| kind | NotificationKind | Review, review reply, offer, new business or trending |
| title, body | String | What the notification says |
| route | String | The app screen it opens |
| readAt | DateTime | When it was read (empty while unread) |
| createdAt | DateTime | When it was created |

Add to **User**: `notificationPrefs` (JSON): the notification types the user has turned off.

**Methods**

| Class | Method | Parameters | Description |
|---|---|---|---|
| Customer | openConversation() | businessId | Opens or starts the conversation with a business |
| Customer | sendMessage() | conversationId, content, photo | Sends a message |
| BusinessOwner | replyMessage() | conversationId, content, photo | Replies to a customer |
| Conversation | markRead() | — | Marks the other side's messages as read |
| NotificationService | notify() | recipients, kind, title, body, route | Stores and pushes a notification |
| PushSender | send() | tokens, message | Delivers a push through Firebase Cloud Messaging |

### Algorithms (SDD §6)

**Algorithm 8: Customer.sendMessage()** (updated)

```
BEGIN SendMessage
INPUT conversation, content, optional photo
IF sender is not a participant of the conversation THEN
    Display "Conversation not found"
ELSE IF content is empty AND there is no photo, OR content exceeds 2,000 characters THEN
    Display validation error
ELSE IF this send was already stored (same client id) THEN
    Return the stored message
ELSE
    Store message
    Update the conversation's last message time and the sender's read position
    Deliver the message live to every open app of both participants
    IF the recipient has no open app THEN
        NotificationService.notify(recipient, "message", sender name, content)
    ENDIF
    Display message as sent
ENDIF
END
```

**Algorithm 14: NotificationService.notify()** (new)

```
BEGIN Notify
INPUT recipients, kind, title, body, screen to open
Remove recipients who turned this kind of notification off
IF kind is not a chat message THEN
    Store a notification for each recipient
ENDIF
Retrieve the recipients' device tokens
FOR each token
    Send the push through Firebase Cloud Messaging
    IF Firebase reports the token as no longer valid THEN
        Delete the token
    ENDIF
ENDFOR
END
```

**Algorithm 15: TrendingDigest.run()** (new)

```
BEGIN TrendingDigest
FOR each user with interests who wasn't sent a trending notification in the last 20 hours
    Find the published business in the user's interest categories
        with the most profile views in the last 7 days (ties: higher weighted rating)
    IF one exists THEN
        NotificationService.notify(user, "trending", "Trending in <category>", business)
    ENDIF
ENDFOR
END
```

### Sequence diagram (SDD §4.2, "Message Business")

After step 26 "Message Stored", split step 27: **27a** the Messaging Service sends the message over the WebSocket to the Business Owner's app, if it is open; **27b** otherwise it asks Firebase Cloud Messaging to push a notification to the owner's device. Step 28 "Message Sent" is unchanged.

### Traceability matrix rows (SDD §7, using SRS v1.1 IDs)

| Req. No. | Requirement | Ref. Item | Design Component | Component Item(s) |
|---|---|---|---|---|
| FR-21 | Push Notifications | Class diagram | NotificationService, PushSender (FcmSender) | notify(), send(), Algorithms 14 and 15 |
| FR-23 | Send Message to Business | Class diagram | Customer, Conversation, Message | openConversation(), sendMessage(), Algorithm 8 |
| FR-24 | Respond to Customer Messages | Class diagram | BusinessOwner, Message | replyMessage(), Algorithm 8 |
| FR-25 | Manage Conversations | Class diagram | Conversation | markRead() |

---

## Implementation record

### Backend

| Piece | Where | Notes |
|---|---|---|
| Models | `app/models/chat.py`, `app/models/notification.py`, `User.notification_prefs` | `Conversation` (one per customer and business, with each side's last-read message), `Message` (optional photo; a unique client id per conversation makes retries safe), `ConversationReport`, `DeviceToken`, `Notification`. |
| Migration | `alembic/versions/d9a4e1c7b3f5_module9_chat_and_push.py` | Additive only. Tested on PostgreSQL 14: upgrade, `alembic check` (no drift), downgrade and upgrade again. |
| Chat API | `app/api/chat.py`, `app/services/chat_service.py` | The endpoints listed above. Anyone who isn't a participant gets 404 (BR-15, SEC-5). Owners can't open a conversation with their own business (403, BR-16). A body of 1–2,000 characters is required unless there's a photo, and the photo must be the sender's own upload. Unread counts and "Seen" come from each side's last-read id; sending counts as reading. |
| Live events | `app/services/realtime.py`, `WS /api/v1/ws` | The token arrives in the first message (it's not in the URL, so it's never logged) and is checked within 10 seconds, else the socket closes with code 4401. Events are `message.new` (each participant gets their own view, including the unread total), `conversation.read`, `typing` (forwarded only between the two participants) and `pong`. Delivery runs as a background task after the response. |
| Push | `app/services/push.py`, `app/services/notification_service.py`, `app/api/notifications.py` | `FcmSender` calls the FCM HTTP v1 API with the service account (via `google-auth` and `requests`, with no new dependency) and drops tokens that FCM reports as invalid. Without credentials, `NullSender` turns push off. `notify()` checks each person's settings, stores the list entry and returns a background job. |
| Triggers | `api/chat.py`, `api/reviews.py`, `api/businesses.py` | A message goes to the other side only if they have no open socket. A new review notifies the owner. A reply notifies the reviewer (the first reply only, not later edits). A new active offer notifies people who saved the business. A new published business notifies users interested in its category. |
| Trending | `app/jobs/trending_digest.py` | `python -m app.jobs.trending_digest [--dry-run]`. Picks the business with the most views in each user's interests; nobody gets more than one within 20 hours. |
| Business data | `BusinessDetail.is_owner`; `BusinessAnalytics.messages` / `unread_messages` | The dashboard's Messages card shows customer messages received in the last 7 days and how many are unread; it was always 0 before. |
| Photos | `media_service._referenced()` | Photos attached to messages are never cleaned up as abandoned uploads. |
| Seed | `app/db/seed.py` | Three demo conversations between `customer@khojlo.app` and Brew & Bloom, Forno Italiano and Glow Studio. The owner has one unread message and the customer has one. The seed also adds two Notifications-list entries for the customer. Running it again changes nothing. |

### Flutter

| Piece | Where | Notes |
|---|---|---|
| Live connection | `core/realtime/realtime_service.dart` | One socket while signed in and in the foreground; closed in the background, so the server pushes instead. Sends the auth message first, pings every 25 seconds, and reconnects with backoff up to 30 seconds. After a 4401 close it refreshes the session once and retries. |
| Session | `core/router/session_services.dart` | On sign-in it connects, loads the conversation list (for the badge) and the notification count, and sets up push. On sign-out it clears them. When the app comes back to the foreground it reconnects and catches up. |
| Chat tab | `features/chat/presentation/messages_screen.dart` | Kai stays pinned on top. Conversation rows show a "You:" prefix, "📷 Photo", times and unread counts, and owner rows name the business. Also: the notifications card, pull to refresh, and loading, empty and error states. An unread badge appears on the Chat tab in the dock. |
| Conversation | `features/chat/presentation/conversation_screen.dart`, `chat_providers.dart` | **Header:** business header with open status and "typing…", plus quick actions (Call, Directions, View business). **Messages:** grouped by day and animated in, with photo bubbles that open the viewer and "Seen" under your newest read message. **Composer:** suggested replies (for customers or owners), the business's active offers (tapping one asks about it), and photo attachments. **Sending:** optimistic, with retry when it fails, and no duplicate when the live echo arrives first. **Offline:** polls every 8 seconds while the socket is down. **Report:** in the ⋮ menu. |
| Business page | `business_detail_screen.dart` | **Message** and **Chat** open (or start) the conversation. The owner sees **View customer messages**, which opens the Chat tab. |
| Notifications | `features/notifications/` | The real Notifications screen (Today / Earlier, mark read, tap to open, mark all read) and **Notification settings** (five switches, also under Profile). The bells on Home and the dashboard show a dot for unread notifications. |
| Push | `core/push/`, `features/notifications/push_controller.dart`, `web/firebase-messaging-sw.js` | Firebase starts from `google-services.json` (Android) or the web settings in `dart_defines.json`; without them push is off and nothing else changes. **Permission:** asked from the **Turn on notifications** button, or once after your first message. **Device registration:** the device is registered, re-registered when its token changes, and unregistered on sign-out. **Taps:** a tapped notification opens its screen, even when it launched the app. **Foreground:** a push arriving while the app is open shows a banner with **Open**. **Web:** the service worker shows notifications and forwards taps to the open tab. |
| Android | `AndroidManifest.xml`, `res/drawable/ic_stat_khojlo.xml` | The `POST_NOTIFICATIONS` permission, and a white four-point-star status-bar icon in Khojlo emerald. |
| Removed | `prototype/chat_screens.dart`, `prototype/notifications_screen.dart`, mock conversations and notifications | Kai moved to `prototype/kai_screen.dart` (Module 7). |

### Testing

- **Backend:** 205 tests pass, 49 of them new.
  - `test_chat.py` (21): UC-13 and UC-14, unread counts and "Seen", validation, retries, participants only, paging, photos, reports, analytics, and push to offline recipients.
  - `test_realtime.py` (9): socket authentication (including refresh tokens being refused), live delivery with no push while online, the sender's other devices, "Seen" and typing.
  - `test_notifications.py` (12): devices, every trigger, dead tokens, settings, the list, and the trending digest.
  - `test_push_sender.py` (7): the FCM payload, invalid-token handling, credentials that can't authorise, and push switched off without credentials.
- **Flutter:** 87 tests pass, 27 of them new, and `flutter analyze` finds no issues.
  - `test/chat_test.dart` (17): models and times; the conversation list's live updates; optimistic send, echo de-duplication, retry, live receive, "Seen" and typing; both screens; the business page for customers and owners.
  - `test/notifications_test.dart` (10): the screen, settings, the push prompt, registration, tap routing, the foreground banner, the launch route and sign-out.
- **Builds:** `flutter build web --release` and `flutter build apk --debug` both succeed.
- **Live check** against a real server and a seeded PostgreSQL database:
  - two WebSocket clients received `message.new` **20 ms** after a REST send (PER-6 asks for under 2 s), along with typing, "Seen" and the dashboard counts;
  - the app's own `RealtimeService` received a live message in 27 ms, and with an invalid token it stopped after one refresh attempt;
  - no access token appeared in the server log.
- **Not tested here:** delivery through Firebase itself, which needs your keys and a device. Follow the [demo script](#c-database-and-demo) once steps 1–5 are done.

### Rollout notes

- **Shared database:** `alembic upgrade head` (it only adds tables and one column), then `python -m app.db.seed`.
- **One worker:** run the API as a single process (`uvicorn app.main:app`, no `--workers`). Live events are held in memory.
- **Teammates' backends:** a teammate running their own backend against the shared database gets chat with polling and refresh, but live events only reach clients connected to the same backend.
- **New Flutter dependencies:** `web_socket_channel`, `firebase_core`, `firebase_messaging`. Run `flutter pub get`.
- **No new backend dependencies.**
