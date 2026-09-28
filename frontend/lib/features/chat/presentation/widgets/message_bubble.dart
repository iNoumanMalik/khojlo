import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/models/chat.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../../core/widgets/widgets.dart';

/// One message: text and/or a photo, with its time and — for my messages —
/// "Sending…", "Seen", or "Not sent · Tap to retry".
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.seen = false, this.onRetry});

  final ChatMessage message;

  /// This is my newest message the other side has read.
  final bool seen;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final failed = m.status == SendStatus.failed;
    final bubble = ChatBubble(
      text: m.body,
      isMe: m.isMine,
      child: m.hasPhoto ? _withPhoto(context) : null,
    );
    final meta = Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
      child: Text(
        switch ((m.isMine, m.status)) {
          (true, SendStatus.sending) => 'Sending…',
          (true, SendStatus.failed) => 'Not sent · Tap to retry',
          (true, _) when seen => '${messageTime(m.createdAt)} · Seen',
          _ => messageTime(m.createdAt),
        },
        style: AppType.mono(size: 10, color: failed ? AppColors.plum : AppColors.inkA(0.4)),
      ),
    );
    final content = GestureDetector(
      onTap: failed ? onRetry : null,
      child: Opacity(
        opacity: m.status == SendStatus.sending ? 0.7 : 1,
        child: Column(
          crossAxisAlignment: m.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [bubble, meta],
        ),
      ),
    );
    // Only new messages animate in, not history scrolled back into view.
    final isNew = DateTime.now().difference(m.createdAt.toLocal()).inSeconds.abs() < 10;
    return isNew
        ? content.animate().fadeIn(duration: 220.ms).slideY(begin: 0.15, curve: Curves.easeOut)
        : content;
  }

  Widget _withPhoto(BuildContext context) {
    final m = message;
    final photo = m.photo;
    final aspect = (photo?.aspectRatio ?? 1).clamp(0.6, 1.6);
    const width = 210.0;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: photo != null
          ? GestureDetector(
              onTap: () => showPhotoViewer(context, [photo]),
              child: ImageTile(photo: photo, width: width, height: width / aspect, radius: 12),
            )
          : Image.memory(m.localPhoto!, width: width, height: width / aspect, fit: BoxFit.cover),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        image,
        if (m.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(m.body,
              style: AppType.sans(
                  size: 13.5, height: 1.45, color: m.isMine ? Colors.white : AppColors.ink)),
        ],
      ],
    );
  }
}

/// "Today", "Yesterday", "Mon 22 Sep" between days.
class DaySeparator extends StatelessWidget {
  const DaySeparator({super.key, required this.when});
  final DateTime when;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.whiteA(0.7),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(dayLabel(when).toUpperCase(),
              style: AppType.mono(size: 9.5, color: AppColors.inkA(0.5), letterSpacing: 1)),
        ),
      ),
    );
  }
}
