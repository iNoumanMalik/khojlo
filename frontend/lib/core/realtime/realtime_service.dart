import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_config.dart';
import '../providers.dart';

enum RealtimeStatus { offline, connecting, online }

/// Live events from the backend's `/ws` socket (Module 9): `message.new`,
/// `conversation.read` and `typing`. The app keeps it open while it's in the
/// foreground, so the server knows to push to the phone instead when it's not.
abstract class Realtime {
  Stream<Map<String, dynamic>> get events;
  Stream<RealtimeStatus> get statusChanges;
  RealtimeStatus get status;

  /// Connect, and keep reconnecting until [stop].
  void start();
  void stop();

  /// Send an event (e.g. `typing`) if connected; dropped otherwise.
  void send(Map<String, dynamic> event);
}

final realtimeProvider = Provider<Realtime>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  final dio = ref.watch(dioProvider);
  final service = RealtimeService(
    accessToken: () => tokens.accessToken,
    // Any authenticated call refreshes an expired access token (see ApiClient).
    refreshSession: () async {
      try {
        await dio.get('/users/me');
        return true;
      } catch (_) {
        return false;
      }
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

class RealtimeService implements Realtime {
  RealtimeService({
    required Future<String?> Function() accessToken,
    required Future<bool> Function() refreshSession,
    WebSocketChannel Function(Uri uri)? connect,
    Uri? uri,
  })  : _accessToken = accessToken,
        _refreshSession = refreshSession,
        _connect = connect ?? WebSocketChannel.connect,
        _uri = uri ?? ApiConfig.realtimeUri;

  /// The server closes with this code when the access token is missing or invalid.
  static const unauthorized = 4401;
  static const pingEvery = Duration(seconds: 25);
  static const maxBackoff = Duration(seconds: 30);

  final Future<String?> Function() _accessToken;
  final Future<bool> Function() _refreshSession;
  final WebSocketChannel Function(Uri uri) _connect;
  final Uri _uri;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _statusChanges = StreamController<RealtimeStatus>.broadcast();
  RealtimeStatus _status = RealtimeStatus.offline;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _retryTimer;
  bool _wanted = false;
  int _attempt = 0;
  bool _refreshedAfterReject = false;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Stream<RealtimeStatus> get statusChanges => _statusChanges.stream;
  @override
  RealtimeStatus get status => _status;

  @override
  void start() {
    if (_wanted) return;
    _wanted = true;
    _attempt = 0;
    _open();
  }

  @override
  void stop() {
    _wanted = false;
    _retryTimer?.cancel();
    _close();
    _setStatus(RealtimeStatus.offline);
  }

  @override
  void send(Map<String, dynamic> event) {
    if (_status == RealtimeStatus.online) _channel?.sink.add(jsonEncode(event));
  }

  void dispose() {
    stop();
    _events.close();
    _statusChanges.close();
  }

  Future<void> _open() async {
    if (!_wanted || _channel != null) return;
    _setStatus(RealtimeStatus.connecting);
    final token = await _accessToken();
    if (!_wanted || _channel != null) return;
    if (token == null) {
      _setStatus(RealtimeStatus.offline);
      return;
    }
    final WebSocketChannel channel;
    try {
      channel = _connect(_uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      _onData,
      onDone: () => _onClosed(channel),
      onError: (_) {}, // followed by onDone
    );
    try {
      await channel.ready;
      // The token goes in the first message, not the URL (servers log URLs).
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));
    } catch (_) {
      // Couldn't connect; onDone schedules the retry.
    }
  }

  void _onData(dynamic raw) {
    final Map<String, dynamic> event;
    try {
      event = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (event['type']) {
      case 'ready':
        _attempt = 0;
        _refreshedAfterReject = false;
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(pingEvery, (_) => send({'type': 'ping'}));
        _setStatus(RealtimeStatus.online);
      case 'pong':
        break;
      default:
        _events.add(event);
    }
  }

  Future<void> _onClosed(WebSocketChannel channel) async {
    if (!identical(channel, _channel)) return;
    final code = channel.closeCode;
    _close();
    _setStatus(RealtimeStatus.offline);
    if (!_wanted) return;
    if (code == unauthorized) {
      // An expired access token: refresh it once and try again.
      if (!_refreshedAfterReject) {
        _refreshedAfterReject = true;
        if (await _refreshSession()) {
          _open();
          return;
        }
      }
      return; // signed out elsewhere; the app will stop us
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = min(maxBackoff.inSeconds, 1 << min(_attempt, 5));
    _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), _open);
  }

  void _close() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    channel?.sink.close();
  }

  void _setStatus(RealtimeStatus status) {
    if (status == _status) return;
    _status = status;
    if (!_statusChanges.isClosed) _statusChanges.add(status);
  }
}
