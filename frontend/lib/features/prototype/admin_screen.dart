import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';

/// Module 8 — Admin & moderation (prototype). Utilitarian by design.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(title: 'Moderation', subtitle: 'Internal tool', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
              children: [
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Pending', value: '7', trend: 'verification')),
                    const SizedBox(width: 10),
                    Expanded(child: StatCard(label: 'Flagged', value: '3', trend: 'reviews')),
                  ],
                ),
                const SizedBox(height: 26),
                Text('VERIFICATION QUEUE', style: AppType.label()),
                const SizedBox(height: 12),
                for (final b in const [
                  ('Ember & Oak', 'Restaurant · submitted 2h ago', 'coral'),
                  ('Pixel Arena', 'Gaming · submitted 5h ago', 'ink'),
                  ('Glow Studio', 'Beauty · submitted 1d ago', 'gold'),
                ])
                  _QueueCard(name: b.$1, meta: b.$2, tone: b.$3),
                const SizedBox(height: 20),
                Text('FLAGGED CONTENT', style: AppType.label()),
                const SizedBox(height: 12),
                _FlagCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.name, required this.meta, required this.tone});
  final String name;
  final String meta;
  final String tone;

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
          SizedBox(width: 46, height: 46, child: ImageTile(tone: tone, radius: 12)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppType.sans(size: 14, weight: FontWeight.w700)),
                Text(meta,
                    style: AppType.mono(size: 10.5, color: AppColors.inkA(0.53))),
              ],
            ),
          ),
          _MiniBtn(icon: Icons.close_rounded, color: AppColors.plum),
          const SizedBox(width: 8),
          _MiniBtn(icon: Icons.check_rounded, color: AppColors.emerald),
        ],
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.plum.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.plum.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: AppColors.plum),
              const SizedBox(width: 8),
              Text('Reported review · spam',
                  style: AppType.sans(
                      size: 12.5, weight: FontWeight.w700, color: AppColors.plum)),
            ],
          ),
          const SizedBox(height: 8),
          Text('“Check out my site for cheap deals www…”',
              style: AppType.sans(size: 13, color: AppColors.inkA(0.7))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: GhostButton(
                      label: 'Dismiss', small: true, tone: AppColors.inkA(0.6))),
              const SizedBox(width: 10),
              Expanded(
                  child: PrimaryButton(
                      label: 'Remove', tone: ButtonTone.ink, small: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
