import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/notification.dart';
import '../../core/network/api_client.dart';
import 'data/notifications_repository.dart';

/// Unread notifications: the bell badges. Refreshed on sign-in, when the app
/// comes back to the foreground and when a push arrives; cleared on sign-out.
class UnreadNotifications extends StateNotifier<int> {
  UnreadNotifications(this._ref) : super(0);
  final Ref _ref;

  Future<void> refresh() async {
    try {
      final n = await _ref.read(notificationsRepositoryProvider).unreadCount();
      if (mounted) state = n;
    } catch (_) {}
  }

  void set(int n) => state = n;
}

final unreadNotificationsProvider =
    StateNotifierProvider<UnreadNotifications, int>((ref) => UnreadNotifications(ref));

enum NotificationsStatus { loading, ready, error }

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.status = NotificationsStatus.loading,
    this.error,
  });
  final List<AppNotification> items;
  final NotificationsStatus status;
  final String? error;
}

/// The Notifications screen's list.
class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._ref) : super(const NotificationsState()) {
    load();
  }
  final Ref _ref;

  NotificationsRepository get _repo => _ref.read(notificationsRepositoryProvider);

  Future<void> load() async {
    try {
      final page = await _repo.list();
      if (!mounted) return;
      state = NotificationsState(items: page.items, status: NotificationsStatus.ready);
      _ref.read(unreadNotificationsProvider.notifier).set(page.unread);
    } catch (e) {
      if (mounted) {
        state = NotificationsState(
            items: state.items, status: NotificationsStatus.error, error: describeApiError(e));
      }
    }
  }

  Future<void> markAllRead() async {
    state = NotificationsState(items: [for (final n in state.items) n.read()], status: state.status);
    try {
      _ref.read(unreadNotificationsProvider.notifier).set(await _repo.markRead());
    } catch (_) {}
  }

  Future<void> opened(AppNotification notification) async {
    if (notification.isRead) return;
    state = NotificationsState(
      items: [for (final n in state.items) n.id == notification.id ? n.read() : n],
      status: state.status,
    );
    try {
      _ref.read(unreadNotificationsProvider.notifier)
          .set(await _repo.markRead(ids: [notification.id]));
    } catch (_) {}
  }
}

final notificationsControllerProvider =
    StateNotifierProvider.autoDispose<NotificationsController, NotificationsState>(
        (ref) => NotificationsController(ref));

/// Notification settings (BR-14): one switch per type, saved as they change.
class NotificationPrefsController extends StateNotifier<AsyncValue<NotificationPrefs>> {
  NotificationPrefsController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref _ref;

  NotificationsRepository get _repo => _ref.read(notificationsRepositoryProvider);

  Future<void> load() async {
    state = await AsyncValue.guard(_repo.preferences);
  }

  /// Saves the change; returns an error message if it couldn't be saved.
  Future<String?> update(NotificationPrefs prefs) async {
    final previous = state;
    state = AsyncValue.data(prefs);
    try {
      final saved = await _repo.savePreferences(prefs);
      if (mounted) state = AsyncValue.data(saved);
      return null;
    } catch (e) {
      if (mounted) state = previous;
      return describeApiError(e);
    }
  }
}

final notificationPrefsProvider = StateNotifierProvider.autoDispose<NotificationPrefsController,
    AsyncValue<NotificationPrefs>>((ref) => NotificationPrefsController(ref));
