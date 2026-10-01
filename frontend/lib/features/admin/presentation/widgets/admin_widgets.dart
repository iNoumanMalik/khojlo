import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/moderation.dart';
import '../../../../core/models/review.dart' show reviewAge;
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Shared pieces of the Module 8 admin panel ("should feel enterprise": cards,
/// charts, a timeline and an activity feed).

String ago(DateTime when) => reviewAge(when);

/// "1 review", "3 reviews".
String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

String shortDate(DateTime when) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
      'Dec'];
  final d = when.toLocal();
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// The status colours used across the panel.
Color verificationColor(VerificationStatus s) => switch (s) {
      VerificationStatus.verified => AppColors.emerald,
      VerificationStatus.pendingReview => const Color(0xFF8A5B15),
      VerificationStatus.needsInfo => const Color(0xFF8A5B15),
      VerificationStatus.rejected => AppColors.plum,
      VerificationStatus.unverified => AppColors.inkA(0.55),
    };

Color accountColor(AccountStatus s) => switch (s) {
      AccountStatus.active => AppColors.emerald,
      AccountStatus.suspended => const Color(0xFF8A5B15),
      AccountStatus.banned => AppColors.plum,
    };

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(label, style: AppType.sans(size: 10.5, weight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// A white card with a hairline border — the panel's basic surface.
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(16),
      this.onTap, this.tint});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.06) ?? AppColors.whiteA(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint?.withValues(alpha: 0.25) ?? AppColors.inkA(0.07)),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card),
    );
  }
}

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.trailing, this.count});
  final String title;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        Text(title.toUpperCase(), style: AppType.label()),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text('$count', style: AppType.mono(size: 10.5, color: AppColors.inkA(0.4))),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty({super.key, required this.message, this.icon = Icons.task_alt_rounded});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      child: Column(children: [
        Icon(icon, size: 28, color: AppColors.emerald.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
      ]),
    );
  }
}

class AdminError extends StatelessWidget {
  const AdminError({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      tint: AppColors.plum,
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.plum),
        const SizedBox(width: 10),
        Expanded(
            child: Text(describeApiError(error),
                style: AppType.sans(size: 13, color: AppColors.inkA(0.7)))),
        GhostButton(label: 'Retry', small: true, expand: false, onTap: onRetry),
      ]),
    );
  }
}

/// Loading / error / data for one provider value.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection(
      {super.key, required this.value, required this.builder, required this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          SkeletonBox(height: 72, radius: 18),
          SizedBox(height: 10),
          SkeletonBox(height: 72, radius: 18),
        ]),
      ),
      error: (e, _) => AdminError(error: e, onRetry: onRetry),
      data: builder,
    );
  }
}

/// A big number with a label, for the overview.
class AdminStat extends StatelessWidget {
  const AdminStat(
      {super.key, required this.label, required this.value, this.note, this.alert = false,
      this.onTap});
  final String label;
  final int value;
  final String? note;
  final bool alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = alert && value > 0 ? AppColors.plum : AppColors.ink;
    return AdminCard(
      onTap: onTap,
      tint: alert && value > 0 ? AppColors.plum : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppType.label(color: AppColors.inkA(0.5))),
        const SizedBox(height: 6),
        Text('$value', style: AppType.serif(size: 28, color: color)),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note!, style: AppType.mono(size: 10.5, color: AppColors.inkA(0.5))),
        ],
      ]),
    );
  }
}

/// Grid of cards that reflows from 2 to 4 columns with the width.
class AdminGrid extends StatelessWidget {
  const AdminGrid({super.key, required this.children, this.minTileWidth = 170});
  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columns = (c.maxWidth / minTileWidth).floor().clamp(2, 4);
      const gap = 10.0;
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}

/// Reports and flags per day over the last two weeks.
class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key, required this.days});
  final List<DayCount> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(1, (m, d) => [m, d.reports, d.flags, d.businesses].reduce(
        (a, b) => a > b ? a : b));
    Widget bar(int v, Color color) => Expanded(
          child: Container(
            height: 70 * (v / peak).clamp(0.04, 1.0),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: v == 0 ? AppColors.inkA(0.06) : color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 14, children: [
          _Legend(color: AppColors.plum, label: 'Reports'),
          _Legend(color: AppColors.gold, label: 'Flags'),
          _Legend(color: AppColors.emerald.withValues(alpha: 0.7), label: 'New businesses'),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final d in days)
              Expanded(
                child: Tooltip(
                  message: '${d.label}: ${d.reports} reports, ${d.flags} flags, '
                      '${d.businesses} new businesses',
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      bar(d.reports, AppColors.plum),
                      bar(d.flags, AppColors.gold),
                      bar(d.businesses, AppColors.emerald.withValues(alpha: 0.7)),
                    ]),
                    const SizedBox(height: 6),
                    Text(d.label.isEmpty ? '' : d.label[0],
                        style: AppType.mono(size: 9, color: AppColors.inkA(0.4))),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppType.sans(size: 11.5, color: AppColors.inkA(0.6))),
      ]);
}

/// The audit log as a timeline (the design's "Timeline. Activity feed.").
class ActionTimeline extends StatelessWidget {
  const ActionTimeline({super.key, required this.actions, this.onTapTarget});
  final List<AdminAction> actions;
  final void Function(AdminAction action)? onTapTarget;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const AdminEmpty(message: 'Nothing has happened here yet.');
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(children: [
        for (var i = 0; i < actions.length; i++)
          _TimelineRow(
            action: actions[i],
            last: i == actions.length - 1,
            onTap: onTapTarget == null ? null : () => onTapTarget!(actions[i]),
          ),
      ]),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.action, required this.last, this.onTap});
  final AdminAction action;
  final bool last;
  final VoidCallback? onTap;

  Color get _color => switch (action.action) {
        'auto_verify' || 'approve' || 'reinstate_business' || 'lift_suspension' =>
          AppColors.emerald,
        'dismiss_report' || 'dismiss_flag' || 'refer' || 'review_requested' => AppColors.inkA(0.4),
        'warn_user' || 'request_info' || 'unverify' => AppColors.gold,
        _ => AppColors.plum,
      };

  @override
  Widget build(BuildContext context) {
    final details = [
      if (action.targetTitle != null) action.targetTitle!,
      if (action.reasonLabel != null) action.reasonLabel!,
    ].join(' · ');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            const SizedBox(height: 4),
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
            if (!last)
              Expanded(child: Container(width: 1.5, color: AppColors.inkA(0.08))),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(action.label,
                        style: AppType.sans(size: 13, weight: FontWeight.w700)),
                  ),
                  Text(ago(action.createdAt),
                      style: AppType.mono(size: 10, color: AppColors.inkA(0.45))),
                ]),
                if (details.isNotEmpty)
                  Text(details, style: AppType.sans(size: 12, color: AppColors.inkA(0.65))),
                Text(action.automatic ? 'Automatic checks' : 'by ${action.by}',
                    style: AppType.mono(size: 10, color: AppColors.inkA(0.45))),
                if (action.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('“${action.note}”',
                        style: AppType.sans(size: 12, color: AppColors.inkA(0.6))),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.person, this.trailing, this.onTap});
  final AdminPerson person;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        KhojloAvatar(
            initials: person.initials, tone: person.tone, size: 38, photo: person.avatar),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(person.fullName, style: AppType.sans(size: 14, weight: FontWeight.w700)),
            Text('${person.email} · ${person.roleLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 11.5, color: AppColors.inkA(0.55))),
          ]),
        ),
        if (person.status != AccountStatus.active)
          StatusPill(
              label: person.status == AccountStatus.banned ? 'Banned' : 'Suspended',
              color: accountColor(person.status)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.35)),
      ]),
    );
  }
}

class BusinessRow extends StatelessWidget {
  const BusinessRow({super.key, required this.business, this.onTap, this.showStorefront = false});
  final AdminBusinessBrief business;
  final VoidCallback? onTap;
  final bool showStorefront;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final photo = showStorefront ? (b.storefront ?? b.cover) : b.cover;
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        SizedBox(
            width: 50, height: 50, child: ImageTile(tone: b.tone, radius: 12, photo: photo)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 14, weight: FontWeight.w700)),
            Text(
                [b.categoryLabel ?? 'No category', 'by ${b.ownerName}', 'joined ${ago(b.createdAt)}']
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 11.5, color: AppColors.inkA(0.55))),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              b.isSuspended
                  ? const StatusPill(label: 'Suspended', color: AppColors.plum)
                  : StatusPill(
                      label: b.autoVerified ? 'Verified automatically' : b.verificationStatus.label,
                      color: verificationColor(b.verificationStatus)),
              if (b.openReports > 0)
                StatusPill(
                    label: '${b.openReports} report${b.openReports == 1 ? '' : 's'}',
                    color: AppColors.plum,
                    icon: Icons.flag_outlined),
              if (b.openFlags > 0)
                StatusPill(
                    label: '${b.openFlags} flag${b.openFlags == 1 ? '' : 's'}',
                    color: const Color(0xFF8A5B15),
                    icon: Icons.auto_awesome_outlined),
            ]),
          ]),
        ),
        if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.35)),
      ]),
    );
  }
}

class FlagRow extends StatelessWidget {
  const FlagRow({super.key, required this.flag, this.onTap});
  final AdminFlag flag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusPill(
              label: flag.labelText,
              color: const Color(0xFF8A5B15),
              icon: Icons.auto_awesome_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(flag.targetTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 12.5, weight: FontWeight.w700)),
          ),
          Text(ago(flag.createdAt), style: AppType.mono(size: 10, color: AppColors.inkA(0.45))),
        ]),
        const SizedBox(height: 8),
        Text(flag.detail, style: AppType.sans(size: 13, weight: FontWeight.w600)),
        if (flag.excerpt.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('“${flag.excerpt}”',
              style: AppType.sans(size: 12.5, color: AppColors.inkA(0.65), height: 1.4)),
        ],
        if (!flag.isOpen) ...[
          const SizedBox(height: 6),
          Text(switch (flag.status) {
            'actioned' => 'Upheld',
            'dismissed' => 'Dismissed',
            _ => 'Cleared: the content changed',
          }, style: AppType.mono(size: 10.5, color: AppColors.inkA(0.5))),
        ],
      ]),
    );
  }
}

class ReportRow extends StatelessWidget {
  const ReportRow({super.key, required this.item, this.onTap});
  final ReportItem item;
  final VoidCallback? onTap;

  IconData get _icon => switch (item.kind) {
        ReportKind.review => Icons.rate_review_outlined,
        ReportKind.conversation => Icons.forum_outlined,
        ReportKind.business => Icons.storefront_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.plum.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(_icon, size: 19, color: AppColors.plum),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
              ),
              Text(ago(item.latestAt),
                  style: AppType.mono(size: 10, color: AppColors.inkA(0.45))),
            ]),
            if (item.snippet.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(item.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(size: 12.5, color: AppColors.inkA(0.62))),
              ),
            const SizedBox(height: 7),
            Wrap(spacing: 6, runSpacing: 4, children: [
              StatusPill(
                  label: '${item.reportCount} reporter${item.reportCount == 1 ? '' : 's'}',
                  color: AppColors.plum),
              for (final r in item.reasons.entries)
                StatusPill(
                    label: r.value > 1 ? '${r.key} ×${r.value}' : r.key,
                    color: AppColors.inkA(0.55)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class ReportEntries extends StatelessWidget {
  const ReportEntries({super.key, required this.reports});
  final List<ReportEntry> reports;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(children: [
        for (var i = 0; i < reports.length; i++) ...[
          if (i > 0) const Hairline(margin: EdgeInsets.symmetric(vertical: 8)),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.flag_outlined, size: 16, color: AppColors.plum),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reports[i].reasonLabel,
                    style: AppType.sans(size: 13, weight: FontWeight.w700)),
                Text('${reports[i].reporterName} · ${ago(reports[i].createdAt)}',
                    style: AppType.sans(size: 11.5, color: AppColors.inkA(0.55))),
                if (reports[i].note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('“${reports[i].note}”',
                        style: AppType.sans(size: 12.5, color: AppColors.inkA(0.7))),
                  ),
              ]),
            ),
            if (reports[i].status != 'open')
              Text(reports[i].status, style: AppType.mono(size: 10, color: AppColors.inkA(0.45))),
          ]),
        ],
      ]),
    );
  }
}

/// Shows an API failure after an action.
void adminSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
    ));
}

// ─────────────── sheets ───────────────
Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: child,
      ),
    );

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.inkA(0.15), borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text(title, style: AppType.serif(size: 22)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppType.sans(size: 13.5, color: AppColors.inkA(0.4)),
      filled: true,
      fillColor: AppColors.whiteA(0.85),
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );

class _ReasonPicker extends StatelessWidget {
  const _ReasonPicker({required this.value, required this.onChanged});
  final ModerationReason value;
  final ValueChanged<ModerationReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('REASON (COMMUNITY GUIDELINES)', style: AppType.label()),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in ModerationReason.values)
          KhojloChip(
              label: r.label, dense: true, active: r == value, onTap: () => onChanged(r),
              activeTone: AppColors.plum),
      ]),
    ]);
  }
}

/// An account an action could apply to: (user id, "Name (role)").
typedef AccountChoice = (int, String);

/// The accounts behind a report, in the order given (admins can't be acted on).
List<AccountChoice> accountChoices(List<AdminPerson> people) => [
      for (final p in people)
        if (p.role.name != 'admin') (p.id, '${p.fullName} (${p.roleLabel.toLowerCase()})'),
    ];

/// Uphold or dismiss a report or flag, with an optional account action.
Future<Resolution?> showResolutionSheet(
  BuildContext context, {
  required String title,
  required String upholdLabel,
  List<AccountChoice> accounts = const [],
}) =>
    _sheet<Resolution>(
        context, _ResolutionSheet(title: title, upholdLabel: upholdLabel, accounts: accounts));

class _ResolutionSheet extends StatefulWidget {
  const _ResolutionSheet({required this.title, required this.upholdLabel, required this.accounts});
  final String title;
  final String upholdLabel;
  final List<AccountChoice> accounts;

  @override
  State<_ResolutionSheet> createState() => _ResolutionSheetState();
}

class _ResolutionSheetState extends State<_ResolutionSheet> {
  bool _uphold = true;
  ModerationReason _reason = ModerationReason.spam;
  String _account = 'none';
  int _days = 7;
  bool _hideReviews = false;
  late int? _accountUser = widget.accounts.isEmpty ? null : widget.accounts.first.$1;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actOn = widget.accounts;
    return _SheetFrame(
      title: widget.title,
      subtitle: 'Everyone affected is told, and the decision goes in the audit log.',
      children: [
        Row(children: [
          Expanded(
            child: KhojloChip(
                label: widget.upholdLabel,
                active: _uphold,
                activeTone: AppColors.plum,
                onTap: () => setState(() => _uphold = true)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: KhojloChip(
                label: 'Dismiss — keep it',
                active: !_uphold,
                onTap: () => setState(() => _uphold = false)),
          ),
        ]),
        const SizedBox(height: 16),
        _ReasonPicker(value: _reason, onChanged: (r) => setState(() => _reason = r)),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          maxLength: 1000,
          maxLines: 3,
          minLines: 1,
          style: AppType.sans(size: 14),
          decoration: _fieldDecoration('Note for the audit log (optional)'),
        ),
        if (actOn.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('ALSO ACT ON THE ACCOUNT', style: AppType.label()),
          const SizedBox(height: 8),
          if (actOn.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(spacing: 8, children: [
                for (final (id, label) in actOn)
                  KhojloChip(
                      label: label,
                      dense: true,
                      active: _accountUser == id,
                      activeTone: AppColors.ink,
                      onTap: () => setState(() => _accountUser = id)),
              ]),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (value, label) in const [
              ('none', 'No'),
              ('warn', 'Warn'),
              ('suspend', 'Suspend'),
              ('ban', 'Ban'),
            ])
              KhojloChip(
                  label: label,
                  dense: true,
                  active: _account == value,
                  activeTone: value == 'none' ? AppColors.emerald : AppColors.plum,
                  onTap: () => setState(() => _account = value)),
          ]),
          if (_account == 'suspend') ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final d in const [1, 3, 7, 30])
                KhojloChip(
                    label: '$d day${d == 1 ? '' : 's'}',
                    dense: true,
                    active: _days == d,
                    activeTone: AppColors.ink,
                    onTap: () => setState(() => _days = d)),
            ]),
          ],
          if (_account == 'ban')
            CheckboxListTile(
              value: _hideReviews,
              onChanged: (v) => setState(() => _hideReviews = v ?? false),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.plum,
              title: Text('Also hide every review they wrote', style: AppType.sans(size: 13.5)),
            ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _uphold ? widget.upholdLabel : 'Dismiss',
          tone: ButtonTone.ink,
          onTap: () => Navigator.of(context).pop(Resolution(
            uphold: _uphold,
            reason: _reason,
            note: _note.text.trim(),
            accountAction: actOn.isEmpty ? 'none' : _account,
            accountUserId: _account == 'none' ? null : _accountUser,
            suspendDays: _days,
            hideReviews: _hideReviews,
          )),
        ),
      ],
    );
  }
}

/// A note for the owner (verification decisions) or the log (reinstating).
Future<String?> showNoteSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  bool required = true,
  String? subtitle,
}) =>
    _sheet<String>(
        context,
        _NoteSheet(
            title: title, hint: hint, confirmLabel: confirmLabel, required: required,
            subtitle: subtitle));

class _NoteSheet extends StatefulWidget {
  const _NoteSheet(
      {required this.title,
      required this.hint,
      required this.confirmLabel,
      required this.required,
      this.subtitle});
  final String title;
  final String hint;
  final String confirmLabel;
  final bool required;
  final String? subtitle;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = !widget.required || _note.text.trim().isNotEmpty;
    return _SheetFrame(title: widget.title, subtitle: widget.subtitle, children: [
      TextField(
        controller: _note,
        maxLength: 500,
        maxLines: 4,
        minLines: 2,
        autofocus: true,
        style: AppType.sans(size: 14),
        decoration: _fieldDecoration(widget.hint),
      ),
      const SizedBox(height: 8),
      PrimaryButton(
        label: widget.confirmLabel,
        tone: ButtonTone.ink,
        onTap: ok ? () => Navigator.of(context).pop(_note.text.trim()) : null,
      ),
    ]);
  }
}

/// A reason and a note: suspending a business, or acting on an account.
Future<(ModerationReason, String, int, bool)?> showAccountActionSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  bool askDays = false,
  bool askHideReviews = false,
}) =>
    _sheet(
        context,
        _AccountActionSheet(
            title: title,
            confirmLabel: confirmLabel,
            askDays: askDays,
            askHideReviews: askHideReviews));

class _AccountActionSheet extends StatefulWidget {
  const _AccountActionSheet(
      {required this.title,
      required this.confirmLabel,
      required this.askDays,
      required this.askHideReviews});
  final String title;
  final String confirmLabel;
  final bool askDays;
  final bool askHideReviews;

  @override
  State<_AccountActionSheet> createState() => _AccountActionSheetState();
}

class _AccountActionSheetState extends State<_AccountActionSheet> {
  ModerationReason _reason = ModerationReason.spam;
  int _days = 7;
  bool _hideReviews = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.title,
      subtitle: 'The person is told why, with a link to the Community Guidelines.',
      children: [
        _ReasonPicker(value: _reason, onChanged: (r) => setState(() => _reason = r)),
        if (widget.askDays) ...[
          const SizedBox(height: 14),
          Text('HOW LONG', style: AppType.label()),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final d in const [1, 3, 7, 30, 90])
              KhojloChip(
                  label: '$d day${d == 1 ? '' : 's'}',
                  dense: true,
                  active: _days == d,
                  activeTone: AppColors.ink,
                  onTap: () => setState(() => _days = d)),
          ]),
        ],
        if (widget.askHideReviews)
          CheckboxListTile(
            value: _hideReviews,
            onChanged: (v) => setState(() => _hideReviews = v ?? false),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.plum,
            title: Text('Also hide every review they wrote', style: AppType.sans(size: 13.5)),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          maxLength: 1000,
          maxLines: 3,
          minLines: 1,
          style: AppType.sans(size: 14),
          decoration: _fieldDecoration('Note for the audit log (optional)'),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: widget.confirmLabel,
          tone: ButtonTone.ink,
          onTap: () =>
              Navigator.of(context).pop((_reason, _note.text.trim(), _days, _hideReviews)),
        ),
      ],
    );
  }
}
