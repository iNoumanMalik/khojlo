import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../notifications/presentation/push_prompt_card.dart';
import '../../prototype/kai_screen.dart';
import '../chat_providers.dart';
import 'widgets/conversation_row.dart';

/// The Chat tab (FR-25): Kai pinned on top, then my conversations with
/// businesses (and, for owners, with their customers), newest first.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    // Normally loaded at sign-in; load here too if it isn't yet.
    Future.microtask(() {
      if (ref.read(conversationsControllerProvider).status == ChatLoad.idle) {
        ref.read(conversationsControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsControllerProvider);
    final controller = ref.read(conversationsControllerProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 64, 22, 120),
          children: [
            Text('Messages', style: AppType.serif(size: 30)),
            const SizedBox(height: 18),
            const KaiCard(),
            const SizedBox(height: 16),
            const PushPromptCard(reason: 'Know the moment a business replies'),
            Text('CONVERSATIONS', style: AppType.label()),
            const SizedBox(height: 6),
            ..._body(state, controller),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(ConversationsState state, ConversationsController controller) {
    if (state.items.isNotEmpty) {
      return [
        for (final c in state.items)
          ConversationRow(
            conversation: c,
            onTap: () => context.push('/conversations/${c.id}'),
          ),
      ];
    }
    return switch (state.status) {
      ChatLoad.idle || ChatLoad.loading => [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: SkeletonBox(height: 52, radius: 16),
            ),
        ],
      ChatLoad.error => [
          const SizedBox(height: 24),
          Text(state.error ?? 'Couldn’t load your conversations.',
              textAlign: TextAlign.center,
              style: AppType.sans(size: 13.5, color: AppColors.inkA(0.6))),
          const SizedBox(height: 12),
          Center(child: GhostButton(label: 'Try again', expand: false, onTap: controller.load)),
        ],
      ChatLoad.ready => [
          const SizedBox(height: 28),
          Icon(Icons.chat_bubble_outline_rounded, size: 34, color: AppColors.inkA(0.3)),
          const SizedBox(height: 10),
          Text('No conversations yet',
              textAlign: TextAlign.center,
              style: AppType.sans(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Open a business and tap Message to ask about prices, availability or bookings.',
              textAlign: TextAlign.center,
              style: AppType.sans(size: 12.5, height: 1.5, color: AppColors.inkA(0.55))),
        ],
    };
  }
}
