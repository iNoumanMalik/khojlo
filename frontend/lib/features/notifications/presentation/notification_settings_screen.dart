import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/notification.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../notifications_providers.dart';
import 'push_prompt_card.dart';

/// One switch per notification type (SRS BR-14), saved as it changes.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(title: 'Notification settings', onBack: () => context.pop()),
          Expanded(
            child: prefs.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (_, __) => Center(
                child: GhostButton(
                  label: 'Try again',
                  expand: false,
                  onTap: () => ref.read(notificationPrefsProvider.notifier).load(),
                ),
              ),
              data: (p) => ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                children: [
                  const PushPromptCard(),
                  Text('TELL ME ABOUT', style: AppType.label()),
                  const SizedBox(height: 6),
                  for (final (label, detail, value, change) in <(String, String, bool,
                      NotificationPrefs Function(bool))>[
                    ('Messages', 'Replies from businesses, or customers’ messages to you',
                        p.messages, (v) => p.copyWith(messages: v)),
                    ('Reviews & replies', 'New reviews of your business, and replies to yours',
                        p.reviews, (v) => p.copyWith(reviews: v)),
                    ('Offers from saved places', 'When a place you saved posts a new offer',
                        p.offers, (v) => p.copyWith(offers: v)),
                    ('New places for you', 'New businesses in the categories you like',
                        p.newPlaces, (v) => p.copyWith(newPlaces: v)),
                    ('Trending', 'What’s popular in your interests this week',
                        p.trending, (v) => p.copyWith(trending: v)),
                  ])
                    _ToggleRow(
                      label: label,
                      detail: detail,
                      value: value,
                      onChanged: (v) async {
                        final error =
                            await ref.read(notificationPrefsProvider.notifier).update(change(v));
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(error)));
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppType.sans(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(detail,
                        style: AppType.sans(size: 12, color: AppColors.inkA(0.55))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                toggled: value,
                label: label,
                child: KhojloToggle(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }
}
