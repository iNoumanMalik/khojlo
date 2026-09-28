import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';

/// Kai, pinned at the top of the Chat tab (Module 7 prototype).
class KaiCard extends StatelessWidget {
  const KaiCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/kai'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.emerald, Color(0xFF123F34)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const KaiOrb(size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Kai',
                          style: AppType.serif(
                              size: 18, color: Colors.white)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.whiteA(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('AI',
                            style: AppType.mono(
                                size: 9,
                                color: Colors.white,
                                letterSpacing: 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Ask me anything about places nearby',
                      style: AppType.sans(
                          size: 12, color: AppColors.whiteA(0.8))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.whiteA(0.8)),
          ],
        ),
      ),
    );
  }
}

/// Kai — RAG assistant (prototype with canned grounded answers).
class KaiScreen extends StatelessWidget {
  const KaiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(title: 'Kai', subtitle: 'Your discovery assistant', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                const Center(child: KaiOrb(size: 72)),
                const SizedBox(height: 20),
                ChatBubble(
                    text:
                        'Hi! I can find places grounded in real Khojlo listings. Try asking about tonight’s plans.',
                    glass: true),
                const SizedBox(height: 16),
                ChatBubble(text: 'Where should I take a date near Blue Area?', isMe: true),
                const SizedBox(height: 16),
                ChatBubble(
                  text:
                      'Ember & Oak is a great pick — live-fire seasonal plates, 4.6★ and only 0.6 km away.',
                  glass: true,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.push('/business/6'),
                  child: GlassSurface(
                    radius: 18,
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 56,
                            height: 56,
                            child: ImageTile(tone: 'coral', radius: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ember & Oak',
                                  style: AppType.serif(size: 15)),
                              Text('★ 4.6 · 0.6 km · \$\$\$',
                                  style: AppType.mono(
                                      size: 10.5,
                                      color: AppColors.inkA(0.6))),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.inkA(0.4)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _Composer(),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: GlassSurface(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text('Message...',
                  style: AppType.sans(size: 14, color: AppColors.inkA(0.45))),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AppColors.ink, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Breathing AI orb.
class KaiOrb extends StatelessWidget {
  const KaiOrb({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFF3C365), AppColors.gold],
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 2),
        ],
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.4),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
            duration: 2.seconds,
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            curve: Curves.easeInOut);
  }
}
