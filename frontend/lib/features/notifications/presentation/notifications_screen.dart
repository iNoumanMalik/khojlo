import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/notification.dart';
import '../../../core/models/review.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../notifications_providers.dart';
import 'push_prompt_card.dart';

/// The Notifications list (UC-15): a grouped timeline, as in the design.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final hasUnread = state.items.any((n) => !n.isRead);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: 'Notifications',
            onBack: () => context.pop(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasUnread)
                  TextButton(
                    onPressed: controller.markAllRead,
                    child: Text('Mark all read',
                        style: AppType.sans(
                            size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
                  ),
                Semantics(
                  button: true,
                  label: 'Notification settings',
                  child: GlassIconButton(
                    icon: Icons.tune_rounded,
                    size: 38,
                    onTap: () => context.push('/notification-settings'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.emerald,
              onRefresh: controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                children: [
                  const PushPromptCard(),
                  ..._body(context, state, controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(
      BuildContext context, NotificationsState state, NotificationsController controller) {
    if (state.items.isEmpty) {
      return switch (state.status) {
        NotificationsStatus.loading => [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SkeletonBox(height: 70, radius: 16),
              ),
          ],
        NotificationsStatus.error => [
            const SizedBox(height: 40),
            Text(state.error ?? 'Couldn’t load notifications.',
                textAlign: TextAlign.center,
                style: AppType.sans(size: 13.5, color: AppColors.inkA(0.6))),
            const SizedBox(height: 12),
            Center(child: GhostButton(label: 'Try again', expand: false, onTap: controller.load)),
          ],
        NotificationsStatus.ready => [
            const SizedBox(height: 40),
            Icon(Icons.notifications_none_rounded, size: 34, color: AppColors.inkA(0.3)),
            const SizedBox(height: 10),
            Text('You’re all caught up',
                textAlign: TextAlign.center,
                style: AppType.sans(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('New places in your interests, offers from places you saved and replies to '
                'your reviews will show up here.',
                textAlign: TextAlign.center,
                style: AppType.sans(size: 12.5, height: 1.5, color: AppColors.inkA(0.55))),
          ],
      };
    }
    final now = DateTime.now();
    bool isToday(AppNotification n) {
      final t = n.createdAt.toLocal();
      return t.year == now.year && t.month == now.month && t.day == now.day;
    }

    final today = state.items.where(isToday).toList();
    final earlier = state.items.where((n) => !isToday(n)).toList();
    Widget card(AppNotification n) => _NotificationCard(
          notification: n,
          onTap: () {
            controller.opened(n);
            if (n.route.isNotEmpty) context.push(n.route);
          },
        );
    return [
      if (today.isNotEmpty) ...[
        Text('TODAY', style: AppType.label()),
        const SizedBox(height: 12),
        for (final n in today) card(n),
        const SizedBox(height: 12),
      ],
      if (earlier.isNotEmpty) ...[
        Text('EARLIER', style: AppType.label()),
        const SizedBox(height: 12),
        for (final n in earlier) card(n),
      ],
    ];
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  (IconData, String) get _look => switch (notification.kind) {
        NotificationKind.offer => (Icons.local_offer_rounded, 'gold'),
        NotificationKind.trending => (Icons.trending_up_rounded, 'gold'),
        NotificationKind.newBusiness => (Icons.auto_awesome, 'emerald'),
        NotificationKind.review => (Icons.star_rounded, 'gold'),
        NotificationKind.reviewReply => (Icons.forum_rounded, 'emerald'),
        NotificationKind.message => (Icons.chat_bubble_rounded, 'emerald'),
        NotificationKind.account => (Icons.shield_outlined, 'plum'),
        NotificationKind.verification => (Icons.verified_rounded, 'emerald'),
      };

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, tone) = _look;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? AppColors.whiteA(0.5) : AppColors.whiteA(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: n.isRead ? AppColors.inkA(0.06) : AppColors.emerald.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.solidFor(tone).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.solidFor(tone)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: AppType.sans(size: 14, weight: FontWeight.w700)),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(n.body,
                        style: AppType.sans(
                            size: 12.5, height: 1.4, color: AppColors.inkA(0.6))),
                  ],
                  const SizedBox(height: 4),
                  Text(reviewAge(n.createdAt),
                      style: AppType.mono(size: 10, color: AppColors.inkA(0.4))),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration:
                    const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
