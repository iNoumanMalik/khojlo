# How Chat and Push Notifications Work

A guide to the Module 9 chat system and the push notifications (Module 3): the ideas behind them, what happens step by step, and which file does what. For the decisions, setup steps and test results, see [module9_chat_and_push_plan.md](module9_chat_and_push_plan.md).

Contents:

1. [The big picture](#1-the-big-picture)
2. [Key ideas](#2-key-ideas)
3. [Step-by-step flows](#3-step-by-step-flows)
4. [The data](#4-the-data)
5. [Every file, and what it does](#5-every-file-and-what-it-does)
6. [Settings and secret files](#6-settings-and-secret-files)
7. [Limits worth knowing](#7-limits-worth-knowing)
8. [Trying it yourself](#8-trying-it-yourself)

---

## 1. The big picture

Three systems work together:

| System | What it's for | Needs Firebase? |
|---|---|---|
| **Chat** | Customers and owners send each other messages; the other side sees them instantly | No |
| **Notifications list** | The bell screen: offers, trending places, new reviews and replies | No |
| **Push notifications** | Pop-ups on the phone or in the browser, even when the app is closed | Yes |

```
     CUSTOMER (phone)                    BACKEND (FastAPI + PostgreSQL)                OWNER (browser)
 ┌─────────────────────┐   1 REST    ┌────────────────────────────────┐          ┌─────────────────────┐
 │ types "Do you       │ ──────────▶ │ saves the message              │          │                     │
 │ deliver to G-9?"    │             │                                │ 2a live  │                     │
 │                     │ ◀────────── │ owner has the app open? ──yes──┼────────▶ │ message appears     │
 │ "Sending…" → sent   │   reply     │                        (WebSocket)        │ instantly           │
 │                     │             │                          no ───┼──┐       │                     │
 └─────────────────────┘             └────────────────────────────────┘  │       └─────────────────────┘
                                                                          │ 2b push
                                                             ┌────────────▼────────────┐
                                                             │ Firebase Cloud Messaging │──▶ pop-up on the
                                                             │ (Google's servers)       │    owner's device
                                                             └──────────────────────────┘
```

---

## 2. Key ideas

**REST vs WebSocket.** The app talks to the backend in two ways:
- **REST** is one request, one answer: "send this message" → "saved, here it is". Everything that *changes* data goes this way, because it's reliable, easy to test, and gives a clear error when something is wrong.
- A **WebSocket** is one connection that stays open while the app is on screen. The server uses it to *announce* events the moment they happen: a new message, a read receipt, someone typing. Without it, the app would have to ask "anything new?" every few seconds.

**Presence = having a socket open.** The app opens its WebSocket in the foreground and closes it when you leave (switch app, lock the phone, hide the browser tab). So for the server, "this person has a socket open" means "this person is looking at the app". That decides live delivery versus push.

**Push token.** When a phone or browser allows notifications, Firebase gives it an address called a **token** (a long random string). The app sends this token to our backend, which stores it. To notify a person, the backend sends the message *to Firebase* with that person's tokens, and Firebase delivers it to the device. Our server never talks to phones directly.

**Service account.** Firebase only accepts messages from servers that prove they belong to the project. `backend/secrets/firebase-service-account.json` is that proof: the backend uses it to get a short-lived access token from Google, then calls Firebase's HTTP API with it.

**Service worker (web only).** Browsers can only show notifications while a page is closed through a small background script, the service worker (`frontend/web/firebase-messaging-sw.js`). The browser wakes it up when a push arrives; it shows the pop-up and handles the click.

**Optimistic sending.** Your message appears straight away ("Sending…"), before the server confirms it. When the server answers, it becomes a normal message; if it fails, it shows "Not sent · Tap to retry". Each send carries a random **client id**, so a retry, or a live echo arriving before the reply, never creates a duplicate.

**Read markers instead of read flags.** Each conversation stores two numbers: the newest message the customer has read, and the newest the business has read. From them:
- **unread** = messages from the other side newer than *my* marker;
- **"Seen"** = my messages up to *their* marker.

Sending a message also moves your own marker (you've obviously seen the conversation).

**Polling fallback.** If the WebSocket is down (bad network, server restart), an open conversation asks for new messages every 8 seconds. Nothing is lost either way, because messages are always saved in the database before anything is delivered.

---

## 3. Step-by-step flows

File names below are short: backend files are under `backend/app/`, app files under `frontend/lib/`.

### A. The app starts and you sign in

1. `main.dart` calls `initFirebase()` (`core/push/firebase_setup.dart`).
   - **Android:** Firebase starts from `android/app/google-services.json`.
   - **Web:** it starts from the `FIREBASE_*` values in `dart_defines.json`.
   - If that fails or isn't configured, push is simply off (`firebaseReadyProvider` = false).
2. The whole app is wrapped in `SessionServices` (`core/router/session_services.dart`). When you become signed in, it:
   - starts the WebSocket (`realtimeProvider.start()`);
   - loads your conversations, which gives the Chat tab badge;
   - fetches the unread count for the bell;
   - calls `PushController.onSignedIn()`, which checks notification permission, registers this device's token if it's allowed, and opens a notification's screen if one launched the app.

### B. A customer opens a chat

1. On the business page (`features/discovery/presentation/business_detail_screen.dart`), **Message** calls `openConversationWith()`, which sends `POST /conversations {business_id}`.
2. The backend (`api/chat.py → open_conversation`) checks the business exists and is published, and that you're not its owner (owners get 403). It then returns your existing conversation, or creates one.
3. The app goes to `/conversations/{id}` → `ConversationScreen` (`features/chat/presentation/conversation_screen.dart`).
4. `ConversationController` (`features/chat/chat_providers.dart`) loads the header (`GET /conversations/{id}`) and the latest 30 messages, then marks the conversation read.

A new, empty conversation doesn't show in anyone's list until its first message is sent.

### C. Sending a message (the core flow)

**On the sender's device**

1. You type and tap send (`widgets/chat_composer.dart`). The composer calls `ConversationController.send(text)`.
2. A **pending** message with a random client id is added to the screen immediately ("Sending…").
3. `ChatRepository.send()` sends `POST /conversations/{id}/messages {body, client_id, photo?}`.

**On the server** (`api/chat.py → send_message`)

4. **Who are you?** It checks you take part in this conversation (anyone else gets 404) and works out your side: customer, or the business's owner.
5. **Seen this send before?** If the same client id is already stored, it returns that message instead of saving a duplicate.
6. **Validate.** The text is trimmed and must be 1–2,000 characters, unless a photo is attached. A photo must be one you uploaded.
7. **Store.** It saves the message, updates the conversation's "last message" time, and moves *your* read marker to this message.
8. **Push or not?** If the recipient has no open socket (`realtime.manager.is_online`), it prepares a push (`notification_service.notify`, kind `message`, titled with your name or the business name).
9. **Commit, answer, deliver.** It commits to the database and answers **201** with the saved message. Then, as background tasks after the answer:
   - sends `message.new` over the WebSocket to **both** participants, each with their own view of it ("is mine" and their unread total);
   - hands the push job to Firebase, if one was prepared.

**Back on the sender's device**

10. The saved message replaces the pending one, matched by client id. If the WebSocket echo arrived first, it's de-duplicated.
11. The conversation moves to the top of your Chat tab (`ConversationsController.sent`).

**On the recipient's device**

- **App open:** the socket receives `message.new`.
  - `ConversationsController` updates the list and the **badge**.
  - If that conversation is on screen, `ConversationController` adds the message and immediately marks it read. That sends "Seen" back to you.
- **App closed:** a push arrives (flow G). Opening the app later loads everything from the database.

### D. "Seen" and "typing…"

- **Seen:** opening a conversation (or receiving a message in an open one) sends `POST /conversations/{id}/read`.
  1. The server moves your read marker to the newest message.
  2. It sends `conversation.read` to the other person; their screen shows "Seen" under their latest message you've now read.
  3. It also sends the event to your other devices, whose badges clear.
- **Typing:** while you type, the app sends `{"type": "typing"}` over the socket, at most once every 3 seconds. The server checks you're in that conversation and forwards it to the other side, which shows "typing…" in the header for 4 seconds.

### E. The WebSocket connection's life (`core/realtime/realtime_service.dart`)

1. **Connect:** it opens `ws://<backend>/api/v1/ws`, with `wss://` in production.
2. **Authenticate:** its first message is `{"type": "auth", "token": <your access token>}`.
   - The token isn't put in the URL, because servers write URLs to their logs.
   - The server (`api/chat.py → realtime`) must receive it within 10 seconds. If it's wrong, the server closes the socket with code **4401**.
3. **Ready:** the server replies `{"type": "ready"}` and remembers the socket under your user id (`services/realtime.py`).
4. **Keep-alive:** the app sends `ping` every 25 seconds and the server answers `pong`.
5. **Drops:** if the connection drops, the app reconnects after 1, 2, 4… up to 30 seconds.
6. **Expired token:** if the server closed with 4401 (usually a 30-minute access token expiring), the app refreshes its login once (through `/users/me`, which refreshes the token) and reconnects.
7. **Background:** when the app goes to the background, the socket closes, so the server switches to push.
8. **Coming back:** the app reconnects, reloads the conversation list, and the open conversation fetches anything it missed (`catchUp`).

### F. Turning notifications on (registering a device)

1. The **Turn on notifications** card (`features/notifications/presentation/push_prompt_card.dart`) shows in the Chat tab, the Notifications screen and settings while permission isn't granted. The app also asks once after your first message.
2. Tapping it calls `PushController.enable()` (`features/notifications/push_controller.dart`), which calls `PushPlatform.requestPermission()` (`core/push/push_platform.dart`) and shows the phone's or browser's own "Allow notifications?" prompt.
3. If you allow it, the app asks Firebase for this device's token. On the web this needs the `FIREBASE_WEB_VAPID_KEY` from `dart_defines.json`.
4. It sends `PUT /notifications/devices {token, platform}` (`api/notifications.py`), and the backend stores it in `device_tokens`.
   - If that device was signed in as someone else before, the token moves to you, so the previous person stops getting your notifications.
5. When Firebase replaces the token, which happens occasionally, the app registers the new one automatically.

### G. Sending a push (server side)

Something happens, for example a customer writes a review:

1. **The endpoint calls `notification_service.notify()`** (`api/reviews.py → create_review`) with who to tell, the kind, the text and the screen to open (`route`).
2. **`notify()` filters by settings.** It drops people who switched that kind off (`users.notification_prefs`), adds a row to their **Notifications list** (except for chat messages), and collects their device tokens.
3. **The endpoint commits and schedules the push.** The returned `PushJob` runs as a background task, so the API answers without waiting for Google.
4. **`PushJob` calls the sender.** `push.get_sender()` returns:
   - `FcmSender` when the key file is configured;
   - `NullSender` when it isn't, which sends nothing.
5. **`FcmSender` calls Firebase** (`services/push.py`). It gets a Google access token from the service account, then posts one request per device to `https://fcm.googleapis.com/v1/projects/khojlo-c5ba0/messages:send`. Each request carries the title, the body, `data: {route, kind}`, high priority on Android, and a tag so newer messages replace older ones.
6. **Dead tokens are removed.** If Firebase says a token is dead (the app was uninstalled, or the token was replaced), `PushJob` deletes it from `device_tokens`.

**What triggers a push:**

| Event | Code | Who is told | In the Notifications list? |
|---|---|---|---|
| New chat message | `api/chat.py → send_message` | the other side, if not in the app | No (the Chat tab is its list) |
| New review | `api/reviews.py → create_review` | the business owner | Yes |
| Owner replies to a review | `api/reviews.py → reply` (first reply only) | the reviewer | Yes |
| New active offer | `api/businesses.py → create_offer` | people who saved the business | Yes |
| New business | `api/businesses.py → create_business` | people with that category in their interests | Yes |
| Trending | `jobs/trending_digest.py` (run by hand) | each user with interests, once per 20 hours | Yes |

### H. Receiving a push (device side)

**Android**
- **App closed or in the background:** Android shows the notification in the status bar, with the white star icon (`res/drawable/ic_stat_khojlo.xml`) in Khojlo green. Tapping it opens the app, and `PushPlatform.openedRoutes` / `launchRoute` tell `PushController` which screen to open (e.g. `/conversations/12`).
- **App open:** Android doesn't show it. The app shows its own banner at the bottom (`core/ui/messenger.dart`) with an **Open** button, and refreshes the bell count.

**Web**
1. The browser wakes the service worker (`web/firebase-messaging-sw.js`), which reads the title, body and route, and shows a system notification.
2. **Clicking it:**
   - if a Khojlo tab is open, the worker focuses it and posts `{type: "khojlo-open", route}` to it. The app receives that (`core/push/sw_messages_web.dart`) and opens the screen;
   - if no tab is open, it opens a new one at that screen.
3. On the web the pop-up appears even while the app is open, because the worker shows every push itself.

### I. The Notifications screen and settings

- `NotificationsScreen` (`features/notifications/presentation/notifications_screen.dart`) loads `GET /notifications` and groups them into **Today** and **Earlier**. Unread ones have a green dot.
  - Tapping one marks it read and opens its screen.
  - **Mark all read** sends `POST /notifications/read`.
- The bell dots on Home and the dashboard come from `unreadNotificationsProvider`. It refreshes on sign-in, when the app comes back to the foreground, when a push arrives, and after reading.
- **Notification settings** (`notification_settings_screen.dart`, also under Profile) has five switches: Messages, Reviews & replies, Offers from saved places, New places for you, Trending. Each change is saved at once with `PUT /notifications/preferences`. The server checks these before notifying (step G2).

### J. The trending digest

`python -m app.jobs.trending_digest` (add `--dry-run` to only list what it would send):

1. It counts each published business's profile views over the last 7 days.
2. For every user with interests who hasn't had a trending notification in the last 20 hours, it picks the business with the most views in their interest categories, skipping businesses they own. Ties go to the better weighted rating.
3. It sends "Trending in Cafés — Brew & Bloom is popular this week" through `notify()`, the same as any other notification.

It's safe to run again, or from a daily scheduled job later.

### K. Signing out

1. `AuthController.logout()` first calls `PushController.unregister()`, while you're still signed in. That sends `POST /notifications/devices/unregister` and deletes the Firebase token, so this device stops getting your notifications.
2. The login tokens are cleared.
3. `SessionServices` closes the WebSocket and empties the chat list and badges, so the next person to sign in doesn't see them.

---

## 4. The data

New tables (migration `backend/alembic/versions/d9a4e1c7b3f5_module9_chat_and_push.py`, additive only):

| Table | Key columns | Notes |
|---|---|---|
| `conversations` | `customer_id`, `business_id`, `last_message_at`, `customer_last_read_id`, `business_last_read_id` | One per customer and business. |
| `messages` | `conversation_id`, `sender_id`, `from_business`, `body`, `media_id`, `client_id`, `created_at` | `(conversation_id, client_id)` is unique, which stops duplicates. |
| `conversation_reports` | `conversation_id`, `reporter_id`, `reason`, `note`, `status` | For the Module 8 admin queue. |
| `device_tokens` | `user_id`, `token` (unique), `platform` | Where to push each user. |
| `notifications` | `user_id`, `kind`, `title`, `body`, `route`, `read_at` | The bell screen's list. |
| `users.notification_prefs` | JSON, e.g. `{"offers": false}` | Missing keys mean "on". |

Chat photos reuse the existing `media` table and upload endpoint (`POST /media`).

---

## 5. Every file, and what it does

### Backend (`backend/`)

| File | New? | Role |
|---|---|---|
| `app/models/chat.py` | New | `Conversation`, `Message`, `ConversationReport` tables. |
| `app/models/notification.py` | New | `DeviceToken`, `Notification` tables; notification kinds. |
| `app/models/user.py` | Changed | Adds `notification_prefs`. |
| `app/models/__init__.py` | Changed | Exports the new models. |
| `alembic/versions/d9a4e1c7b3f5_module9_chat_and_push.py` | New | Creates the tables above. |
| `app/schemas/chat.py` | New | Request and response shapes for chat (e.g. `MessageOut`, `ConversationDetail`). |
| `app/schemas/notification.py` | New | Shapes for devices, the list and settings. |
| `app/schemas/business.py` | Changed | `BusinessDetail.is_owner`; `BusinessAnalytics.unread_messages`. |
| `app/api/chat.py` | New | The chat REST endpoints and the `/ws` WebSocket. |
| `app/api/notifications.py` | New | Device registration, the Notifications list, settings. |
| `app/api/reviews.py` | Changed | Notifies owners about reviews and reviewers about replies. |
| `app/api/businesses.py` | Changed | Notifies about new offers and new businesses; returns `is_owner`. |
| `app/services/chat_service.py` | New | Chat logic: who's who, unread counts, response building, dashboard counts. |
| `app/services/realtime.py` | New | The list of open WebSockets per user; sending events to them. |
| `app/services/push.py` | New | `FcmSender` (talks to Firebase) and `NullSender` (push off). |
| `app/services/notification_service.py` | New | `notify()`: settings, list rows, device tokens, `PushJob`. |
| `app/services/business_service.py` | Changed | Real message counts for the dashboard. |
| `app/services/media_service.py` | Changed | Chat photos are never cleaned up as unused uploads. |
| `app/core/database.py` | Changed | `session_scope()`: database sessions for WebSocket events and background jobs. |
| `app/core/config.py` | Changed | Comment only (the Firebase settings already existed). |
| `app/jobs/trending_digest.py` | New | The trending digest command. |
| `app/db/seed.py` | Changed | Three demo conversations and two notifications. |
| `app/main.py` | Changed | Registers the chat and notification routes. |
| `.env.example` | Changed | Firebase section; working defaults. |
| `tests/test_chat.py`, `test_realtime.py`, `test_notifications.py`, `test_push_sender.py` | New | 49 tests. |
| `tests/conftest.py` | Changed | Tests record pushes instead of sending them. |

### App (`frontend/`)

| File | New? | Role |
|---|---|---|
| `lib/main.dart` | Changed | Starts Firebase; installs `SessionServices` and the banner messenger. |
| `lib/core/push/firebase_setup.dart` | New | Starts Firebase from `google-services.json` (Android) or `dart_defines.json` (web). |
| `lib/core/push/push_platform.dart` | New | The phone or browser side of push: permission, token, taps, foreground messages. |
| `lib/core/push/sw_messages_web.dart`, `sw_messages_stub.dart` | New | Web: receives notification clicks from the service worker. |
| `lib/core/realtime/realtime_service.dart` | New | The WebSocket client: auth, ping, reconnect, events. |
| `lib/core/router/session_services.dart` | New | Starts and stops the connection, push and badges on sign-in, sign-out and backgrounding. |
| `lib/core/router/app_router.dart` | Changed | Routes `/conversations/:id`, `/notifications`, `/notification-settings`. |
| `lib/core/router/shell_scaffold.dart`, `lib/core/widgets/floating_tab_bar.dart` | Changed | Unread badge on the Chat tab. |
| `lib/core/ui/messenger.dart` | New | The in-app banner for pushes that arrive while the app is open. |
| `lib/core/models/chat.dart`, `notification.dart` | New | The app's versions of the API data; time labels ("Yesterday", "Mon 22 Sep"). |
| `lib/core/models/business.dart`, `analytics.dart` | Changed | `isOwner`; `unreadMessages`. |
| `lib/core/network/api_config.dart` | Changed | The WebSocket address. |
| `lib/core/providers.dart` | Changed | `appResumedProvider` (the app came back to the foreground). |
| `lib/features/chat/data/chat_repository.dart` | New | Calls the chat REST endpoints. |
| `lib/features/chat/chat_providers.dart` | New | `ConversationsController` (list and badge) and `ConversationController` (one chat: sending, retry, Seen, typing, polling). |
| `lib/features/chat/presentation/messages_screen.dart` | New | The Chat tab. |
| `lib/features/chat/presentation/conversation_screen.dart` | New | A conversation: header, quick actions, messages, offers, composer. |
| `lib/features/chat/presentation/widgets/*` | New | Message bubble, composer, conversation row, report sheet. |
| `lib/features/notifications/data/notifications_repository.dart` | New | Calls the notification endpoints. |
| `lib/features/notifications/notifications_providers.dart` | New | The list, the bell count, settings. |
| `lib/features/notifications/push_controller.dart` | New | Permission, device registration, taps, banners, sign-out. |
| `lib/features/notifications/presentation/*` | New | Notifications screen, settings screen, "Turn on notifications" card. |
| `lib/features/discovery/presentation/business_detail_screen.dart` | Changed | Message / View customer messages. |
| `lib/features/business/presentation/dashboard_screen.dart` | Changed | Real Messages card; bell dot. |
| `lib/features/discovery/presentation/home_screen.dart` | Changed | Bell dot. |
| `lib/features/account/presentation/profile_screen.dart` | Changed | Notification settings row. |
| `lib/features/auth/auth_controller.dart` | Changed | Unregisters push before signing out. |
| `lib/features/prototype/kai_screen.dart` | New | Kai (Module 7 prototype), moved here from the deleted chat prototype. |
| `lib/features/prototype/chat_screens.dart`, `notifications_screen.dart` | Deleted | Replaced by the real screens. |
| `web/firebase-messaging-sw.js` | New | Web service worker: shows notifications, handles clicks. |
| `android/app/src/main/AndroidManifest.xml` | Changed | Notification permission, icon and colour. |
| `android/app/src/main/res/drawable/ic_stat_khojlo.xml`, `res/values/colors.xml` | New | The notification icon and colour. |
| `pubspec.yaml` | Changed | `web_socket_channel`, `firebase_core`, `firebase_messaging`. |
| `dart_defines.example.json` | Changed | Firebase web settings and Web Push key (placeholders). |
| `test/chat_test.dart`, `test/notifications_test.dart` | New | 27 tests. |

### Documentation (`docs/`)

| File | Role |
|---|---|
| `development_roadmap/module9_chat_and_push_plan.md` | Decisions, your manual steps, SDD text for Word, implementation record. |
| `development_roadmap/module9_how_it_works.md` | This guide. |
| `team_setup.md` | What to share privately with teammates. |
| `development_roadmap/implementation_plan.md`, `requirements/SRS.md`, `requirements/document_review.md`, `README.md`, `docs/README.md` | Status and cross-references updated. |

---

## 6. Settings and secret files

| File | Where | Used by | Secret? | In git? |
|---|---|---|---|---|
| `firebase-service-account.json` | `backend/secrets/` | Backend, to **send** pushes | **Yes** | No |
| `.env` (`GOOGLE_APPLICATION_CREDENTIALS`) | `backend/` | Backend: points to the file above | Yes (other values in it) | No |
| `dart_defines.json` (`FIREBASE_*`, `FIREBASE_WEB_VAPID_KEY`) | `frontend/` | Web app: Firebase settings and Web Push key | Not really (browsers receive them) | No |
| `google-services.json` | `frontend/android/app/` | Android app: Firebase settings | No | Yes |

Without the service account file, push is off. Without `dart_defines.json`, web push is off. Chat works in every case. What to give teammates: [team_setup.md](../team_setup.md).

---

## 7. Limits worth knowing

- **One backend process.** The list of open sockets lives in the server's memory, so run the API without `--workers`. Two devices get live messages only if they use the **same** running backend. Push works regardless.
- **Web shows every push as a system pop-up**, even while the app is open. Android shows a banner inside the app instead.
- **Messages aren't in the Notifications list.** The Chat tab and its badge are their list.
- **Only customers start chats.** Owners reply, but can't message people first or message their own business.
- **iOS push is out of scope.** It needs a paid Apple Developer account (SRS CO-11).
- **Web push needs `localhost` or HTTPS**, and doesn't work in incognito windows.
- **The trending digest isn't scheduled.** Run it by hand, e.g. before a demo.

---

## 8. Trying it yourself

1. **Backend,** from `backend/`: `alembic upgrade head`, then `python -m app.db.seed`, then `uvicorn app.main:app --reload`.
2. **App:** in VS Code, run **Khojlo (Chrome)**. In another browser profile or on your phone, run **Khojlo**.
3. **Sign in** as `customer@khojlo.app` on one and `owner@khojlo.app` on the other (password `password123`).
4. **Chat:** customer: open Brew & Bloom → **Message** → send something. It appears on the owner's side instantly; try typing and "Seen".
5. **Push:** tap **Turn on notifications** on both, allow, then put the customer's app in the background and reply as the owner. A push arrives.
6. **Trending:** run `python -m app.jobs.trending_digest` and open the bell.
