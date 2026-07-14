import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import 'mock_data.dart';

/// Module 3 — grouped notifications timeline (UI only, no push at 30%).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(title: 'Notifications', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
              children: [
                Text('TODAY', style: AppType.label()),
                const SizedBox(height: 12),
                for (final n in Mock.notificationsToday) _NotifCard(n: n),
                const SizedBox(height: 24),
                Text('EARLIER', style: AppType.label()),
                const SizedBox(height: 12),
                for (final n in Mock.notificationsEarlier) _NotifCard(n: n),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.n});
  final ({String icon, String title, String body, String tone}) n;

  IconData get _icon => switch (n.icon) {
        'offer' => Icons.local_offer_rounded,
        'trending' => Icons.trending_up_rounded,
        'message' => Icons.chat_bubble_rounded,
        _ => Icons.auto_awesome,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkA(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.solidFor(n.tone).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, size: 20, color: AppColors.solidFor(n.tone)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: AppType.sans(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(n.body,
                    style: AppType.sans(
                        size: 12.5, height: 1.4, color: AppColors.inkA(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
