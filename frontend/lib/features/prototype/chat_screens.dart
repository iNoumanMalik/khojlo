import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import 'mock_data.dart';

/// Chat tab — Kai pinned above business conversations (Module 7 · 9 prototype).
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 64, 22, 120),
        children: [
          Text('Messages', style: AppType.serif(size: 30)),
          const SizedBox(height: 18),
          GestureDetector(
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
                  const _Orb(size: 44),
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
          ),
          const SizedBox(height: 24),
          Text('CONVERSATIONS', style: AppType.label()),
          const SizedBox(height: 6),
          for (final c in Mock.conversations) _ConversationRow(c: c),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.c});
  final ({String name, String tone, String last, String time, bool unread}) c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/conversation'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            KhojloAvatar(initials: c.name[0], tone: c.tone, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: AppType.sans(size: 14.5, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(c.last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(
                          size: 12.5, color: AppColors.inkA(0.55))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(c.time,
                    style: AppType.mono(size: 10, color: AppColors.inkA(0.4))),
                const SizedBox(height: 6),
                if (c.unread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.emerald, shape: BoxShape.circle),
                  ),
              ],
            ),
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
                const Center(child: _Orb(size: 72)),
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

/// 1:1 business conversation (prototype).
class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
              title: 'Ember & Oak',
              subtitle: 'Usually replies within an hour',
              onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                ChatBubble(text: 'Hi! Do you have a table for 2 at 8PM tonight?', isMe: true),
                const SizedBox(height: 12),
                ChatBubble(text: 'Absolutely — would you like the terrace or indoor?'),
                const SizedBox(height: 12),
                ChatBubble(text: 'Terrace, please 🌆', isMe: true),
                const SizedBox(height: 12),
                ChatBubble(
                  text: '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BOOKING CONFIRMED', style: AppType.label()),
                      const SizedBox(height: 8),
                      Text('Table for 2 · Terrace',
                          style: AppType.sans(size: 14, weight: FontWeight.w700)),
                      Text('Today · 8:00 PM',
                          style: AppType.mono(
                              size: 11.5, color: AppColors.inkA(0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _QuickReplies(),
          const _Composer(),
        ],
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final q in ['Thanks!', 'What’s the dress code?', 'Add to calendar'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KhojloChip(label: q),
            ),
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
class _Orb extends StatelessWidget {
  const _Orb({required this.size});
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
