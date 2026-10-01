import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/moderation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/photo_viewer.dart';
import '../../../core/widgets/widgets.dart';
import '../admin_providers.dart';
import '../data/admin_repository.dart';
import 'admin_sections.dart';
import 'widgets/admin_widgets.dart';

/// Everything reported about one review, conversation or business, and the
/// decision (SDD Algorithm 10: remove the content, or keep it).
///
/// A reported conversation's messages are shown because a participant reported it
/// (decision 8, the SEC-5 exception); admins can't open any other conversation.
class AdminReportScreen extends ConsumerStatefulWidget {
  const AdminReportScreen({super.key, required this.kind, required this.targetId});
  final ReportKind kind;
  final int targetId;

  @override
  ConsumerState<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends ConsumerState<AdminReportScreen> {
  bool _busy = false;

  (ReportKind, int) get _key => (widget.kind, widget.targetId);

  Future<void> _decide(ReportDetail d) async {
    final result = await showResolutionSheet(
      context,
      title: 'Decide on this ${widget.kind.label.toLowerCase()}',
      upholdLabel: widget.kind.upholdLabel,
      accounts: accountChoices(d.accounts),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).resolveReport(widget.kind, widget.targetId, result);
      ref.invalidate(adminReportProvider(_key));
      refreshAdmin(ref);
      if (mounted) {
        adminSnack(context, result.uphold
            ? 'Done. The people involved and the reporters have been told.'
            : 'Dismissed. The reporters have been told.');
      }
    } catch (e) {
      if (mounted) adminSnack(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminReportProvider(_key));
    final detail = value.valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(children: [
        TopBar(
          title: 'Reported ${widget.kind.label.toLowerCase()}',
          subtitle: detail?.title,
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: AsyncSection<ReportDetail>(
                    value: value,
                    onRetry: () => ref.invalidate(adminReportProvider(_key)),
                    builder: _body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: detail != null && detail.open
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Center(
                  heightFactor: 1, // a bottom bar must not take the body's height
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: PrimaryButton(
                      label: 'Decide',
                      icon: Icons.gavel_rounded,
                      loading: _busy,
                      onTap: () => _decide(detail),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _body(ReportDetail d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!d.open)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: AdminCard(
            tint: AppColors.emerald,
            child: Text('Resolved. The history below shows what was decided.'),
          ),
        ),
      if (d.review != null) _review(d.review!),
      if (d.conversation != null) _conversation(d.conversation!),
      if (d.business != null) ...[
        BusinessRow(
            business: d.business!,
            onTap: () => context.push('/admin/business/${d.business!.id}')),
      ],
      AdminSectionTitle('Reports', count: d.reports.length),
      ReportEntries(reports: d.reports),
      if (d.flags.isNotEmpty) ...[
        AdminSectionTitle('Automatic flags', count: d.flags.length),
        for (final f in d.flags)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: FlagRow(flag: f)),
      ],
      if (d.accounts.isNotEmpty) ...[
        const AdminSectionTitle('Accounts involved'),
        for (final a in d.accounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PersonRow(person: a, onTap: () => context.push('/admin/user/${a.id}')),
          ),
      ],
      const AdminSectionTitle('History'),
      ActionTimeline(actions: d.history, onTapTarget: (a) => openActionTarget(context, a)),
    ]);
  }

  Widget _review(AdminReview r) {
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KhojloAvatar(
              initials: r.author.initials, tone: r.author.tone, size: 34, photo: r.author.avatar),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.author.fullName, style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
              Text('on ${r.business.name} · ${ago(r.createdAt)}',
                  style: AppType.sans(size: 11.5, color: AppColors.inkA(0.55))),
            ]),
          ),
          Text('${'★' * r.rating}${'☆' * (5 - r.rating)}',
              style: AppType.sans(size: 14, color: AppColors.gold)),
        ]),
        const SizedBox(height: 10),
        Text(r.comment.isEmpty ? '(no text, just a rating)' : r.comment,
            style: AppType.sans(size: 14, height: 1.5)),
        if (r.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < r.photos.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => showPhotoViewer(context, r.photos, initialIndex: i),
                  child: SizedBox(
                      width: 72,
                      height: 72,
                      child: ImageTile(tone: 'ink', radius: 10, photo: r.photos[i])),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        StatusPill(
            label: r.isVisible ? 'Visible to everyone' : 'Hidden by a moderator',
            color: r.isVisible ? AppColors.emerald : AppColors.plum),
      ]),
    );
  }

  Widget _conversation(AdminConversation c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminCard(
        tint: AppColors.gold,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF8A5B15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'You can read this conversation because a participant reported it. '
                'Keep what you see here private.',
                style: AppType.sans(size: 12.5, color: AppColors.inkA(0.7))),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${c.customer.fullName} (customer) and ${c.business.name} '
              '(${c.owner.fullName})',
              style: AppType.sans(size: 12.5, weight: FontWeight.w700)),
          if (c.closed || c.blockedBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  c.closed ? 'Closed by a moderator.' : 'Blocked by the ${c.blockedBy}.',
                  style: AppType.mono(size: 10.5, color: AppColors.plum)),
            ),
          const SizedBox(height: 10),
          for (final m in c.messages)
            Align(
              alignment: m.fromBusiness ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: m.fromBusiness ? AppColors.ink : AppColors.inkA(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment:
                      m.fromBusiness ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (m.photo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SizedBox(
                            width: 160,
                            height: 110,
                            child: ImageTile(tone: 'ink', radius: 10, photo: m.photo)),
                      ),
                    if (m.body.isNotEmpty)
                      Text(m.body,
                          style: AppType.sans(
                              size: 13.5,
                              color: m.fromBusiness ? Colors.white : AppColors.ink)),
                    Text('${m.fromBusiness ? c.business.name : c.customer.fullName} · '
                        '${ago(m.createdAt)}',
                        style: AppType.mono(
                            size: 9.5,
                            color: m.fromBusiness ? AppColors.whiteA(0.6) : AppColors.inkA(0.45))),
                  ],
                ),
              ),
            ),
          if (c.messages.isEmpty)
            Text('No messages.', style: AppType.sans(size: 13, color: AppColors.inkA(0.5))),
        ]),
      ),
    ]);
  }
}
