import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/notification.dart';
import '../../../core/providers.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioProvider));
});

/// `/notifications/*`: the Notifications list, settings and push devices.
class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<NotificationPage> list({int limit = 50, int offset = 0}) async {
    final res = await _dio.get('/notifications',
        queryParameters: {'limit': limit, 'offset': offset});
    return NotificationPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<int> unreadCount() async {
    final res = await _dio.get('/notifications/unread-count');
    return (res.data as Map<String, dynamic>)['total'] as int;
  }

  /// Marks [ids] read, or everything when null. Returns the unread count left.
  Future<int> markRead({List<int>? ids}) async {
    final res = await _dio.post('/notifications/read', data: {if (ids != null) 'ids': ids});
    return (res.data as Map<String, dynamic>)['total'] as int;
  }

  Future<NotificationPrefs> preferences() async {
    final res = await _dio.get('/notifications/preferences');
    return NotificationPrefs.fromJson(res.data as Map<String, dynamic>);
  }

  Future<NotificationPrefs> savePreferences(NotificationPrefs prefs) async {
    final res = await _dio.put('/notifications/preferences', data: prefs.toJson());
    return NotificationPrefs.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> registerDevice(String token, String platform) =>
      _dio.put('/notifications/devices', data: {'token': token, 'platform': platform});

  Future<void> unregisterDevice(String token) =>
      _dio.post('/notifications/devices/unregister', data: {'token': token});
}
