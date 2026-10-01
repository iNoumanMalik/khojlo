import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/moderation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Khojlo's Community Guidelines (SRS BR-10 "Moderation policies enforced").
/// Every removal, warning and suspension names one of these sections, and the
/// notices link here.
class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key});

  static const _icons = {
    ModerationReason.spam: Icons.campaign_outlined,
    ModerationReason.scam: Icons.report_gmailerrorred_outlined,
    ModerationReason.adult: Icons.no_adult_content_outlined,
    ModerationReason.prohibited: Icons.block_rounded,
    ModerationReason.harassment: Icons.front_hand_outlined,
    ModerationReason.fake: Icons.fact_check_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(children: [
        TopBar(
          title: 'Community Guidelines',
          subtitle: 'What’s allowed on Khojlo',
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 48),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Khojlo helps people find new local businesses they can trust. '
                        'These rules apply to listings, offers, reviews, photos and messages.',
                        style: AppType.sans(size: 14, height: 1.55, color: AppColors.inkA(0.75))),
                    const SizedBox(height: 20),
                    Text('NOT ALLOWED', style: AppType.label()),
                    const SizedBox(height: 10),
                    for (final r in ModerationReason.values)
                      if (_icons.containsKey(r))
                        _Rule(icon: _icons[r]!, title: r.label, body: r.description),
                    const SizedBox(height: 14),
                    Text('WHAT HAPPENS', style: AppType.label()),
                    const SizedBox(height: 10),
                    const _Step(
                        n: '1',
                        text: 'Anyone can report a review, a conversation or a business. '
                            'Automatic checks also flag likely spam and scams.'),
                    const _Step(
                        n: '2',
                        text: 'Reported content stays up until Khojlo’s team decides. A '
                            'moderator can read a conversation only after someone in it '
                            'reports it.'),
                    const _Step(
                        n: '3',
                        text: 'If it breaks these rules, it’s removed and you’re told why. '
                            'Breaking them again can lead to a warning, a suspension, or a '
                            'ban.'),
                    const _Step(
                        n: '4',
                        text: 'Whoever reported it hears back too. Nobody is told who '
                            'reported them.'),
                    const SizedBox(height: 14),
                    Text('THE VERIFIED BADGE', style: AppType.label()),
                    const SizedBox(height: 10),
                    Text(
                        'A business is verified automatically when its owner has verified '
                        'their email, the listing is complete, the owner has taken a photo '
                        'of the shop front in the app, and there are no open reports. '
                        'Khojlo’s team looks at the rest, and can remove a badge.',
                        style: AppType.sans(size: 13.5, height: 1.55, color: AppColors.inkA(0.72))),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkA(0.06)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: AppColors.plum),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppType.sans(size: 14, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body, style: AppType.sans(size: 13, height: 1.45, color: AppColors.inkA(0.65))),
          ]),
        ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
          child: Text(n, style: AppType.mono(size: 11, weight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: AppType.sans(size: 13.5, height: 1.5, color: AppColors.inkA(0.72)))),
      ]),
    );
  }
}
