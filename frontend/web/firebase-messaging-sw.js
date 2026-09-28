// Push notifications on the web (Firebase Cloud Messaging).
//
// Firebase registers this file when the app asks for a push token. It shows each
// notification itself, so it needs no Firebase configuration, and handles clicks:
// an open Khojlo tab is focused and told which screen to open (see
// lib/core/push/sw_messages_web.dart); otherwise a new tab opens on that screen.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    return;
  }
  const notification = payload.notification || {};
  const data = payload.data || {};
  if (!notification.title) return;
  event.waitUntil(
    self.registration.showNotification(notification.title, {
      body: notification.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-maskable-192.png',
      // Newer messages in the same conversation replace the older notification.
      tag: data.route || undefined,
      renotify: Boolean(data.route),
      data: { route: data.route || '/notifications' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = (event.notification.data && event.notification.data.route) || '/notifications';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((tabs) => {
      for (const tab of tabs) {
        if (new URL(tab.url).origin === self.location.origin) {
          tab.postMessage({ type: 'khojlo-open', route });
          return tab.focus();
        }
      }
      // The app uses hash URLs (e.g. /#/conversations/12).
      return self.clients.openWindow(`/#${route}`);
    }),
  );
});
