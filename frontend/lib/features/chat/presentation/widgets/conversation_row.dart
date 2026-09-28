import 'package:flutter/material.dart';

import '../../../../core/models/chat.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// A row in the Chat tab: who it's with, the last message and unread count.
class ConversationRow extends StatelessWidget {
  const ConversationRow({super.key, required this.conversation, this.onTap});
  final ConversationSummary conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final last = c.lastMessage;
    final unread = c.unreadCount > 0;
    final avatar = c.iAmTheBusiness
        ? KhojloAvatar(
            initials: c.customer.initials, tone: c.customer.tone, size: 48, photo: c.customer.avatar)
        : KhojloAvatar(
            initials: c.business.name.isEmpty ? '?' : c.business.name[0],
            tone: c.business.tone,
            size: 48,
            photo: c.business.cover);
    final preview = last == null ? '' : '${last.isMine ? 'You: ' : ''}${last.preview}';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(size: 14.5, weight: FontWeight.w700)),
                  // Owners may have several businesses: say which one it's about.
                  if (c.iAmTheBusiness)
                    Text('to ${c.business.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.mono(size: 10, color: AppColors.emerald)),
                  const SizedBox(height: 3),
                  Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(
                          size: 12.5,
                          weight: unread ? FontWeight.w600 : FontWeight.w400,
                          color: unread ? AppColors.ink : AppColors.inkA(0.55))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (c.lastMessageAt != null)
                  Text(conversationTime(c.lastMessageAt!),
                      style: AppType.mono(
                          size: 10, color: unread ? AppColors.emerald : AppColors.inkA(0.4))),
                const SizedBox(height: 6),
                if (unread) CountBadge(count: c.unreadCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small emerald pill with a count ("3", "99+").
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.color = AppColors.emerald});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Text(count > 99 ? '99+' : '$count',
          style: AppType.sans(size: 10.5, weight: FontWeight.w700, color: Colors.white)),
    );
  }
}
