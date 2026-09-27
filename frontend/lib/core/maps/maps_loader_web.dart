import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

@JS('khojloMapsReady')
external set _onMapsReady(JSFunction callback);

/// Google calls this when the key is rejected (wrong referrer, API not enabled, no billing).
@JS('gm_authFailure')
external set _onAuthFailure(JSFunction callback);

Future<bool>? _loading;

/// True once Google rejected the key; the app then shows its fallback map.
final mapsKeyRejected = ValueNotifier<bool>(false);

/// Adds the Google Maps JavaScript API to the page (once) and waits for it.
Future<bool> loadGoogleMaps(String apiKey) => _loading ??= _load(apiKey);

Future<bool> _load(String apiKey) {
  final ready = Completer<bool>();
  _onMapsReady = (() {
    if (!ready.isCompleted) ready.complete(true);
  }).toJS;
  _onAuthFailure = (() {
    mapsKeyRejected.value = true;
  }).toJS;
  final script = web.HTMLScriptElement()
    ..src =
        'https://maps.googleapis.com/maps/api/js'
        '?key=${Uri.encodeQueryComponent(apiKey)}&callback=khojloMapsReady&v=weekly'
    ..async = true
    ..defer = true;
  script.onerror = ((web.Event _) {
    if (!ready.isCompleted) ready.complete(false);
  }).toJS;
  web.document.head!.append(script);
  return ready.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
}
