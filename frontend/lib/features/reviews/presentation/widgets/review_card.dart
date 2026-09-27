import 'package:flutter/material.dart';

import '../../../../core/models/review.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../../core/widgets/widgets.dart';
import 'stars.dart';

/// One review: author (with the Verified badge), stars, text, photos, "Helpful", the
/// owner's reply, and the actions that fit the viewer.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.isOwner = false,
    this.onHelpful,
    this.onReport,
    this.onReply,
    this.onDeleteReply,
    this.onEdit,
    this.onDelete,
    this.compact = false,
  });

  final Review review;

  /// The viewer owns the business, so they can reply.
  final bool isOwner;
  final VoidCallback? onHelpful;
  final VoidCallback? onReport;
  final VoidCallback? onReply;
  final VoidCallback? onDeleteReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Business page preview: text clamped, no actions row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.whiteA(r.isMine ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: r.isMine ? AppColors.emerald.withValues(alpha: 0.35) : AppColors.inkA(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KhojloAvatar(
                  initials: r.author.initials, tone: r.author.tone, size: 38, photo: r.author.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(r.isMine ? 'You' : r.author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.sans(size: 14, weight: FontWeight.w700)),
                        ),
                        if (r.author.isVerified) ...[
                          const SizedBox(width: 6),
                          const _VerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        StarRow(rating: r.rating.toDouble(), size: 13),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            [reviewAge(r.createdAt), if (r.isEdited) 'edited'].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.mono(size: 10, color: AppColors.inkA(0.45)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!compact) _menu(context),
            ],
          ),
          if (!r.isVisible) ...[
            const SizedBox(height: 10),
            _Note(
              icon: Icons.visibility_off_outlined,
              text: 'Hidden by Khojlo’s moderators. Only you can see it.',
              color: AppColors.plum,
            ),
          ],
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                r.comment,
                maxLines: compact ? 3 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: AppType.sans(size: 13.5, height: 1.5, color: AppColors.inkA(0.78)),
              ),
            ),
          ],
          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: compact ? 64 : 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => showPhotoViewer(context, r.photos, initialIndex: i),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ImageTile(photo: r.photos[i], radius: 12, tone: 'gold'),
                  ),
                ),
              ),
            ),
          ],
          if (r.ownerReply != null) ...[
            const SizedBox(height: 12),
            _OwnerReplyBox(
              reply: r.ownerReply!,
              compact: compact,
              onEdit: isOwner && !compact ? onReply : null,
              onDelete: isOwner && !compact ? onDeleteReply : null,
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (!r.isMine)
                  _HelpfulButton(
                      count: r.helpfulCount, voted: r.votedHelpful, onTap: onHelpful)
                else if (r.helpfulCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${r.helpfulCount} found this helpful',
                      style: AppType.mono(size: 10.5, color: AppColors.inkA(0.5)),
                    ),
                  ),
                const Spacer(),
                if (isOwner && r.ownerReply == null && onReply != null)
                  TextButton.icon(
                    onPressed: onReply,
                    icon: const Icon(Icons.reply_rounded, size: 16, color: AppColors.emerald),
                    label: Text('Reply',
                        style: AppType.sans(
                            size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final r = review;
    final items = <(String, IconData, String, VoidCallback?)>[
      if (r.isMine) ('edit', Icons.edit_outlined, 'Edit review', onEdit),
      if (r.isMine) ('delete', Icons.delete_outline_rounded, 'Delete review', onDelete),
      if (!r.isMine)
        ('report', Icons.flag_outlined, r.reported ? 'Reported' : 'Report review',
            r.reported ? null : onReport),
    ].where((e) => e.$4 != null || e.$1 == 'report').toList();
    if (items.isEmpty) return const SizedBox(width: 8);
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_horiz_rounded, color: AppColors.inkA(0.45)),
      color: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (key) {
        for (final item in items) {
          if (item.$1 == key) item.$4?.call();
        }
      },
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(
            value: item.$1,
            enabled: item.$4 != null,
            child: Row(
              children: [
                Icon(item.$2,
                    size: 18, color: item.$1 == 'delete' ? AppColors.plum : AppColors.ink),
                const SizedBox(width: 10),
                Text(item.$3, style: AppType.sans(size: 13.5)),
              ],
            ),
          ),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'This reviewer verified their email',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.emerald.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 11, color: AppColors.emerald),
            const SizedBox(width: 3),
            Text('Verified',
                style: AppType.mono(size: 9, weight: FontWeight.w600, color: AppColors.emerald)),
          ],
        ),
      ),
    );
  }
}

class _HelpfulButton extends StatelessWidget {
  const _HelpfulButton({required this.count, required this.voted, this.onTap});
  final int count;
  final bool voted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = voted ? AppColors.emerald : AppColors.inkA(0.55);
    return Semantics(
      button: true,
      toggled: voted,
      label: 'Helpful, $count',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: voted ? AppColors.emerald.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: voted ? AppColors.emerald : AppColors.inkA(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: voted ? 1.15 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(voted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                    size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Text(count > 0 ? 'Helpful ($count)' : 'Helpful',
                  style: AppType.sans(size: 12, weight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerReplyBox extends StatelessWidget {
  const _OwnerReplyBox({required this.reply, this.compact = false, this.onEdit, this.onDelete});
  final OwnerReply reply;
  final bool compact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: AppColors.gold.withValues(alpha: 0.7), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Reply from the owner · ${reviewAge(reply.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.mono(size: 10, weight: FontWeight.w600, color: AppColors.inkA(0.6))),
              ),
              if (onEdit != null)
                _TinyAction(icon: Icons.edit_outlined, label: 'Edit reply', onTap: onEdit!),
              if (onDelete != null)
                _TinyAction(icon: Icons.delete_outline_rounded, label: 'Remove reply', onTap: onDelete!),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(reply.text,
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: AppType.sans(size: 13, height: 1.45, color: AppColors.inkA(0.72))),
          ),
        ],
      ),
    );
  }
}

class _TinyAction extends StatelessWidget {
  const _TinyAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.inkA(0.5)),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppType.sans(size: 12, color: color))),
      ],
    );
  }
}
