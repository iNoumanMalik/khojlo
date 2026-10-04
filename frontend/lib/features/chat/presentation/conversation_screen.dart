import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/media/photo_source.dart';
import '../../../core/models/chat.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../maps/presentation/route_screen.dart';
import '../chat_providers.dart';
import '../data/chat_repository.dart';
import 'widgets/chat_composer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/report_conversation_sheet.dart';

/// Quick questions for a customer's first message (design: "Suggested Replies").
const customerStarters = [
  'Are you open today?',
  'What are your prices?',
  'Do you have any offers?',
  'Can I book an appointment?',
];
const customerFollowUps = ['Thanks!', 'See you soon.', 'Is it available today?'];
const ownerReplies = [
  'Thanks for reaching out!',
  'Yes, we’re open today.',
  'Please call us to book.',
  'We’ll get back to you shortly.',
];

/// A conversation between a customer and a business (UC-13, UC-14), laid out
/// as in the design: business header → quick actions → messages → suggested
/// replies → offers → attachment.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});
  final int conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scroll = ScrollController();

  ConversationController get _controller =>
      ref.read(conversationControllerProvider(widget.conversationId).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // The list is reversed: its end is the oldest message.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
        _controller.loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
      ));
  }

  Future<void> _sendPhoto() async {
    final photo = await ref.read(photoSourceProvider).pickOne();
    if (photo != null) await _controller.sendPhoto(photo);
  }

  Future<void> _report() async {
    final result = await showReportConversationSheet(context);
    if (result == null || !mounted) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .report(widget.conversationId, result.$1, note: result.$2);
      _snack('Thanks for letting us know. Our team will take a look.');
    } catch (e) {
      _snack(describeApiError(e));
    }
  }

  /// Module 8: block or unblock the other person in this conversation.
  Future<void> _toggleBlock(ConversationDetail detail) async {
    final blocking = !detail.blockedByMe;
    if (blocking) {
      final other = detail.title;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cream,
          title: Text('Block $other?', style: AppType.serif(size: 20)),
          content: Text(
              'Neither of you will be able to send messages here until you unblock. '
              'If they broke the rules, report the conversation too.',
              style: AppType.sans(size: 13.5, color: AppColors.inkA(0.7))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Block', style: AppType.sans(weight: FontWeight.w700, color: AppColors.plum))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    try {
      final updated =
          await ref.read(chatRepositoryProvider).setBlocked(widget.conversationId, blocking);
      _controller.setDetail(updated);
      _snack(blocking ? 'Blocked. You can unblock from the menu.' : 'Unblocked.');
    } catch (e) {
      _snack(describeApiError(e));
    }
  }

  Future<void> _call(ChatBusiness b) async {
    final phone = b.phone;
    if (phone == null) {
      _snack('${b.name} hasn’t added a phone number yet.');
      return;
    }
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')));
    if (!opened && mounted) _snack('Couldn’t open the dialer. The number is $phone.');
  }

  void _directions(ChatBusiness b) {
    final point = b.location;
    if (point == null) {
      _snack('${b.name} hasn’t pinned its location yet.');
      return;
    }
    showRoute(context, destination: point, name: b.name);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationControllerProvider(widget.conversationId));
    final detail = state.detail;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: switch (state.status) {
        ChatLoad.ready when detail != null => Column(
            children: [
              _Header(
                detail: detail,
                typing: state.otherTyping,
                onReport: _report,
                onBlock: () => _toggleBlock(detail),
                onViewBusiness: () => context.push('/business/${detail.business.id}'),
              ),
              if (!detail.iAmTheBusiness)
                _QuickActions(
                  business: detail.business,
                  onCall: () => _call(detail.business),
                  onDirections: () => _directions(detail.business),
                  onView: () => context.push('/business/${detail.business.id}'),
                ),
              Expanded(child: _messages(state)),
              if (!detail.iAmTheBusiness && detail.business.offers.isNotEmpty)
                _Offers(
                  business: detail.business,
                  onAsk: (title) => _controller.send('Is the “$title” offer still on?'),
                ),
              if (detail.canSend)
                ChatComposer(
                  onSend: _controller.send,
                  onTyping: _controller.typing,
                  onPhoto: _sendPhoto,
                  suggestions: detail.iAmTheBusiness
                      ? ownerReplies
                      : state.messages.isEmpty
                          ? customerStarters
                          : customerFollowUps,
                )
              else
                _CantSend(detail: detail, onUnblock: () => _toggleBlock(detail)),
            ],
          ),
        ChatLoad.error => _Problem(
            message: state.error ?? 'Couldn’t load this conversation.',
            onRetry: _controller.load,
          ),
        _ => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      },
    );
  }

  Widget _messages(ConversationState state) {
    final messages = state.messages;
    if (messages.isEmpty) {
      final name = state.detail!.title;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            state.detail!.iAmTheBusiness
                ? 'No messages yet.'
                : 'Ask $name about products, prices, availability or appointments.',
            textAlign: TextAlign.center,
            style: AppType.sans(size: 13.5, height: 1.5, color: AppColors.inkA(0.55)),
          ),
        ),
      );
    }
    final seenId = state.seenMessageId;
    // Oldest first, with a separator whenever the day changes; shown reversed.
    final items = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final previous = i == 0 ? null : messages[i - 1];
      if (previous == null || !_sameDay(previous.createdAt, m.createdAt)) {
        items.add(DaySeparator(key: ValueKey('day-${m.id}'), when: m.createdAt));
      }
      items.add(MessageBubble(
        key: ValueKey(m.clientId ?? m.id),
        message: m,
        seen: m.id == seenId,
        onRetry: () => _controller.retry(m),
      ));
    }
    if (state.loadingOlder) {
      items.insert(
          0,
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald))),
          ));
    }
    final reversed = items.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      itemCount: reversed.length,
      itemBuilder: (_, i) => reversed[i],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.detail,
    required this.typing,
    required this.onReport,
    required this.onBlock,
    required this.onViewBusiness,
  });

  final ConversationDetail detail;
  final bool typing;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onViewBusiness;

  @override
  Widget build(BuildContext context) {
    final b = detail.business;
    final ownerView = detail.iAmTheBusiness;
    final subtitle = typing
        ? 'typing…'
        : ownerView
            ? 'about ${b.name}'
            : (b.openLabel ?? b.categoryLabel ?? 'Usually replies within a day');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 12, 10),
      child: Row(
        children: [
          GlassIconButton(
              icon: Icons.chevron_left_rounded, size: 38, onTap: () => context.pop()),
          const SizedBox(width: 12),
          ownerView
              ? KhojloAvatar(
                  initials: detail.customer.initials,
                  tone: detail.customer.tone,
                  size: 40,
                  photo: detail.customer.avatar)
              : KhojloAvatar(
                  initials: b.name.isEmpty ? '?' : b.name[0], tone: b.tone, size: 40, photo: b.cover),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: ownerView ? null : onViewBusiness,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(detail.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sans(size: 16, weight: FontWeight.w700)),
                      ),
                      if (!ownerView && b.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 15, color: AppColors.emerald),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(
                          size: 11.5,
                          color: typing ? AppColors.emerald : AppColors.inkA(0.5),
                          weight: typing ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.inkA(0.6)),
            color: AppColors.cream,
            onSelected: (v) => switch (v) {
              'report' => onReport(),
              'block' => onBlock(),
              _ => onViewBusiness(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'business', child: Text('View ${b.name}')),
              const PopupMenuItem(value: 'report', child: Text('Report conversation')),
              if (!detail.closed && !detail.blockedByThem)
                PopupMenuItem(
                    value: 'block',
                    child: Text(detail.blockedByMe
                        ? 'Unblock'
                        : ownerView
                            ? 'Block this customer'
                            : 'Block ${b.name}')),
            ],
          ),
        ],
      ),
    );
  }
}

/// In place of the composer when the viewer can't send (Module 8).
class _CantSend extends StatelessWidget {
  const _CantSend({required this.detail, required this.onUnblock});
  final ConversationDetail detail;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final message = detail.closed
        ? 'Khojlo’s moderators closed this conversation after a report. You can still read it.'
        : detail.blockedByMe
            ? 'You blocked this conversation.'
            : 'You can’t reply to this conversation.';
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inkA(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(detail.closed ? Icons.gavel_rounded : Icons.block_rounded,
              size: 18, color: AppColors.inkA(0.55)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message, style: AppType.sans(size: 13, color: AppColors.inkA(0.7)))),
          if (detail.blockedByMe && !detail.closed)
            GhostButton(label: 'Unblock', small: true, expand: false, onTap: onUnblock),
        ]),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.business,
    required this.onCall,
    required this.onDirections,
    required this.onView,
  });

  final ChatBusiness business;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap, {bool dimmed = false}) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Opacity(
            opacity: dimmed ? 0.45 : 1,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.whiteA(0.7),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.inkA(0.06)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 15, color: AppColors.emerald),
                  const SizedBox(width: 6),
                  Text(label, style: AppType.sans(size: 12, weight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          action(Icons.call_rounded, 'Call', onCall, dimmed: business.phone == null),
          action(Icons.directions_rounded, 'Directions', onDirections,
              dimmed: business.location == null),
          action(Icons.storefront_outlined, 'View business', onView),
        ],
      ),
    );
  }
}

/// The business's active offers; tapping one asks about it.
class _Offers extends StatelessWidget {
  const _Offers({required this.business, required this.onAsk});
  final ChatBusiness business;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
        children: [
          for (final o in business.offers)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onAsk(o.title),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_offer_rounded, size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(o.title, style: AppType.sans(size: 12, weight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopBar(title: 'Conversation', onBack: () => context.pop()),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message,
                      textAlign: TextAlign.center,
                      style: AppType.sans(size: 13.5, color: AppColors.inkA(0.6))),
                  const SizedBox(height: 12),
                  GhostButton(label: 'Try again', expand: false, onTap: onRetry),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
