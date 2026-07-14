import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';
import '../account_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final saved = ref.watch(savedListsProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      );
    }

    final savedCount = saved.maybeWhen(
      data: (lists) => lists.fold<int>(0, (s, l) => s + l.count),
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              const SizedBox(
                  height: 250, child: MeshBackground()),
              Positioned(
                top: 52,
                left: 20,
                child: GlassIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => context.pop()),
              ),
              Positioned(
                top: 52,
                right: 20,
                child: GlassIconButton(
                    icon: Icons.settings_outlined, onTap: () {}),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 96, 24, 0),
                child: Column(
                  children: [
                    KhojloAvatar(
                        initials: user.initials, tone: user.avatarTone, size: 88),
                    const SizedBox(height: 14),
                    Text(user.fullName, style: AppType.serif(size: 26)),
                    const SizedBox(height: 4),
                    Text(user.email,
                        style: AppType.sans(
                            size: 13, color: AppColors.inkA(0.53))),
                    const SizedBox(height: 8),
                    KhojloBadge(
                        label: user.isOwner ? 'Business owner' : 'Explorer',
                        tone: BadgeTone.gold),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                    child: StatCard(label: 'Saved', value: '$savedCount')),
                const SizedBox(width: 10),
                Expanded(
                    child: StatCard(
                        label: 'Interests',
                        value: '${user.interests.length}')),
                const SizedBox(width: 10),
                const Expanded(
                    child: StatCard(label: 'Visited', value: '0')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                _Row(
                    icon: Icons.bookmark_outline_rounded,
                    label: 'Saved collections',
                    onTap: () => context.push('/saved')),
                _Row(
                    icon: Icons.storefront_outlined,
                    label: 'My business',
                    onTap: () => context.go('/business')),
                _Row(icon: Icons.reviews_outlined, label: 'My reviews'),
                _Row(
                    icon: Icons.emoji_events_outlined,
                    label: 'Achievements'),
                _Row(icon: Icons.settings_outlined, label: 'Settings'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: GhostButton(
              label: 'Sign out',
              tone: AppColors.plum,
              icon: Icons.logout_rounded,
              onTap: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/onboarding');
              },
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.ink),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(label,
                        style:
                            AppType.sans(size: 14, weight: FontWeight.w600))),
                Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.33)),
              ],
            ),
          ),
        ),
        const Hairline(),
      ],
    );
  }
}
