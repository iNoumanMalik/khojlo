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

/// One business as an admin sees it: the verification checks and storefront photo
/// (UC-12), its reports and flags, the audit trail, and the decisions
/// (Algorithm 9: verify / reject, plus asking for more, revoking and suspending).
class AdminBusinessScreen extends ConsumerStatefulWidget {
  const AdminBusinessScreen({super.key, required this.businessId});
  final int businessId;

  @override
  ConsumerState<AdminBusinessScreen> createState() => _AdminBusinessScreenState();
}

class _AdminBusinessScreenState extends ConsumerState<AdminBusinessScreen> {
  bool _busy = false;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(adminBusinessProvider(widget.businessId));
      refreshAdmin(ref);
      if (mounted) adminSnack(context, done);
    } catch (e) {
      if (mounted) adminSnack(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(String decision) async {
    final id = widget.businessId;
    if (decision == 'approve') {
      return _run(() => _repo.decide(id, 'approve'), 'Verified. The owner has been told.');
    }
    final (title, hint, label) = switch (decision) {
      'request_info' => ('Ask the owner for more', 'What do they need to send or fix?', 'Send'),
      'revoke' => ('Revoke the Verified badge', 'Why? The owner sees this.', 'Revoke badge'),
      _ => ('Don’t verify this business', 'Why? The owner sees this.', 'Reject'),
    };
    final note = await showNoteSheet(context, title: title, hint: hint, confirmLabel: label);
    if (note == null) return;
    await _run(() => _repo.decide(id, decision, note: note), 'Done. The owner has been told.');
  }

  Future<void> _suspend() async {
    final result = await showAccountActionSheet(context,
        title: 'Suspend this business', confirmLabel: 'Suspend business');
    if (result == null) return;
    await _run(() => _repo.suspendBusiness(widget.businessId, result.$1, note: result.$2),
        'Suspended. It’s hidden from Khojlo until you reinstate it.');
  }

  Future<void> _reinstate() async {
    final note = await showNoteSheet(context,
        title: 'Reinstate this business',
        hint: 'Why is it back? (optional)',
        confirmLabel: 'Reinstate',
        required: false);
    if (note == null) return;
    await _run(() => _repo.reinstateBusiness(widget.businessId, note: note),
        'Reinstated. Customers can find it again.');
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminBusinessProvider(widget.businessId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(children: [
        TopBar(
          title: value.valueOrNull?.brief.name ?? 'Business',
          subtitle: 'Admin · business',
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: AsyncSection<AdminBusinessDetail>(
                    value: value,
                    onRetry: () => ref.invalidate(adminBusinessProvider(widget.businessId)),
                    builder: _body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _body(AdminBusinessDetail d) {
    final b = d.brief;
    final status = b.verificationStatus;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 64, height: 64, child: ImageTile(tone: b.tone, radius: 14, photo: b.cover)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name, style: AppType.serif(size: 22)),
              if (d.tagline.isNotEmpty)
                Text(d.tagline, style: AppType.sans(size: 13, color: AppColors.inkA(0.6))),
              const SizedBox(height: 6),
              Text([b.categoryLabel ?? 'No category', b.address, d.phone ?? 'no phone']
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: AppType.sans(size: 12, color: AppColors.inkA(0.55))),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (b.isSuspended)
                  StatusPill(
                      label: 'Suspended · ${b.suspensionReason ?? ''}', color: AppColors.plum),
                StatusPill(label: status.label, color: verificationColor(status)),
                if (d.verifiedBy != null)
                  StatusPill(label: 'by ${d.verifiedBy}', color: AppColors.inkA(0.55)),
                StatusPill(
                    label: b.isPublished ? 'Listed' : 'Not listed', color: AppColors.inkA(0.55)),
                if (b.reviewCount > 0)
                  StatusPill(
                      label: '${b.rating.toStringAsFixed(1)} ★ · ${b.reviewCount} reviews',
                      color: const Color(0xFF8A5B15)),
              ]),
            ]),
          ),
        ]),
      ),
      if (d.verificationNote.isNotEmpty || d.ownerNote != null) ...[
        const SizedBox(height: 10),
        AdminCard(
          tint: AppColors.gold,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (d.verificationNote.isNotEmpty)
              Text('Told the owner: “${d.verificationNote}”',
                  style: AppType.sans(size: 13, color: AppColors.inkA(0.75))),
            if (d.ownerNote != null) ...[
              if (d.verificationNote.isNotEmpty) const SizedBox(height: 6),
              Text('The owner replied: “${d.ownerNote}”',
                  style: AppType.sans(size: 13, weight: FontWeight.w600)),
            ],
          ]),
        ),
      ],
      _actions(d),
      const AdminSectionTitle('Verification checks'),
      AdminCard(
        child: Column(children: [
          for (final c in d.checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(c.passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 20, color: c.passed ? AppColors.emerald : AppColors.inkA(0.3)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.label, style: AppType.sans(size: 13.5, weight: FontWeight.w600)),
                    if (!c.passed && c.hint.isNotEmpty)
                      Text(c.hint, style: AppType.sans(size: 12, color: AppColors.inkA(0.55))),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
      const AdminSectionTitle('Storefront photo'),
      if (b.storefront == null)
        const AdminEmpty(message: 'No storefront photo yet.', icon: Icons.photo_camera_outlined)
      else
        AdminCard(
          padding: const EdgeInsets.all(10),
          onTap: () => showPhotoViewer(context, [b.storefront!]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ImageTile(tone: b.tone, radius: 12, height: 260, photo: b.storefront),
            const SizedBox(height: 8),
            Text(
                'Taken in the app${d.storefrontAt != null ? ' ${ago(d.storefrontAt!)}' : ''}. '
                'Does the sign match “${b.name}”?',
                style: AppType.sans(size: 12.5, color: AppColors.inkA(0.6))),
          ]),
        ),
      if (d.photos.isNotEmpty) ...[
        const AdminSectionTitle('Listing photos'),
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < d.photos.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => showPhotoViewer(context, d.photos, initialIndex: i),
                  child: SizedBox(
                      width: 128,
                      child: ImageTile(tone: b.tone, radius: 12, photo: d.photos[i])),
                ),
              ),
          ]),
        ),
      ],
      if (d.description.isNotEmpty) ...[
        const AdminSectionTitle('Description'),
        AdminCard(
            child: Text(d.description,
                style: AppType.sans(size: 13.5, height: 1.5, color: AppColors.inkA(0.75)))),
      ],
      const AdminSectionTitle('Owner'),
      PersonRow(person: d.owner, onTap: () => context.push('/admin/user/${d.owner.id}')),
      AdminSectionTitle('Reports', count: d.reports.length,
          trailing: d.brief.openReports > 0
              ? GestureDetector(
                  onTap: () => context.push('/admin/report/business/${b.id}'),
                  child: Text('Decide',
                      style: AppType.sans(
                          size: 12.5, weight: FontWeight.w700, color: AppColors.plum)))
              : null),
      if (d.reports.isEmpty)
        const AdminEmpty(message: 'Nobody has reported this business.')
      else
        ReportEntries(reports: d.reports),
      AdminSectionTitle('Automatic flags', count: d.flags.length),
      if (d.flags.isEmpty)
        const AdminEmpty(message: 'The rules haven’t flagged anything.',
            icon: Icons.auto_awesome_outlined)
      else
        for (final f in d.flags)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: FlagRow(flag: f)),
      const AdminSectionTitle('History'),
      ActionTimeline(actions: d.history, onTapTarget: (a) => openActionTarget(context, a)),
    ]);
  }

  Widget _actions(AdminBusinessDetail d) {
    final status = d.brief.verificationStatus;
    final buttons = <Widget>[
      if (status != VerificationStatus.verified)
        PrimaryButton(
            label: 'Verify',
            icon: Icons.verified_rounded,
            tone: ButtonTone.emerald,
            small: true,
            expand: false,
            loading: _busy,
            onTap: () => _decide('approve')),
      if (status != VerificationStatus.verified && status != VerificationStatus.needsInfo)
        GhostButton(
            label: 'Ask for more',
            small: true,
            expand: false,
            onTap: _busy ? null : () => _decide('request_info')),
      if (status != VerificationStatus.verified && status != VerificationStatus.rejected)
        GhostButton(
            label: 'Reject',
            small: true,
            expand: false,
            tone: AppColors.plum,
            onTap: _busy ? null : () => _decide('reject')),
      if (status == VerificationStatus.verified)
        GhostButton(
            label: 'Revoke badge',
            small: true,
            expand: false,
            tone: AppColors.plum,
            onTap: _busy ? null : () => _decide('revoke')),
      d.brief.isSuspended
          ? PrimaryButton(
              label: 'Reinstate',
              small: true,
              expand: false,
              loading: _busy,
              onTap: _reinstate)
          : GhostButton(
              label: 'Suspend business',
              icon: Icons.block_rounded,
              small: true,
              expand: false,
              tone: AppColors.plum,
              onTap: _busy ? null : _suspend),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }
}
