import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Routes of notifications clicked on the web. web/firebase-messaging-sw.js
/// posts `{type: "khojlo-open", route}` to the open app tab.
Stream<String> serviceWorkerOpenedRoutes() {
  final routes = StreamController<String>.broadcast();
  final container = web.window.navigator.serviceWorker;
  container.addEventListener(
    'message',
    ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is Map && data['type'] == 'khojlo-open' && data['route'] is String) {
        routes.add(data['route'] as String);
      }
    }).toJS,
  );
  return routes.stream;
}
