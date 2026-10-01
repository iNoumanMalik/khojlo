import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/moderation.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../admin_providers.dart';
import '../data/admin_repository.dart';
import 'admin_sections.dart';
import 'widgets/admin_widgets.dart';

/// One account: its standing, businesses, flags and history, and the account
/// actions (warn, suspend, ban, lift).
class AdminUserScreen extends ConsumerStatefulWidget {
  const AdminUserScreen({super.key, required this.userId});
  final int userId;

  @override
  ConsumerState<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends ConsumerState<AdminUserScreen> {
  bool _busy = false;

  Future<void> _act(String action) async {
    final repo = ref.read(adminRepositoryProvider);
    Future<AdminUserDetail> Function() call;
    if (action == 'lift') {
      final note = await showNoteSheet(context,
          title: 'Lift the suspension or ban',
          hint: 'Why? (optional)',
          confirmLabel: 'Lift',
          required: false);
      if (note == null) return;
      call = () => repo.actOnUser(widget.userId, 'lift', note: note);
    } else {
      final result = await showAccountActionSheet(
        context,
        title: switch (action) {
          'warn' => 'Warn this account',
          'suspend' => 'Suspend this account',
          _ => 'Ban this account',
        },
        confirmLabel: switch (action) {
          'warn' => 'Send warning',
          'suspend' => 'Suspend',
          _ => 'Ban',
        },
        askDays: action == 'suspend',
        askHideReviews: action == 'ban',
      );
      if (result == null) return;
      final (reason, note, days, hide) = result;
      call = () => repo.actOnUser(widget.userId, action,
          reason: reason, note: note, days: days, hideReviews: hide);
    }
    setState(() => _busy = true);
    try {
      await call();
      ref.invalidate(adminUserProvider(widget.userId));
      refreshAdmin(ref);
      if (mounted) adminSnack(context, 'Done. They have been told.');
    } catch (e) {
      if (mounted) adminSnack(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminUserProvider(widget.userId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(children: [
        TopBar(
          title: value.valueOrNull?.row.fullName ?? 'Account',
          subtitle: 'Admin · account',
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: AsyncSection<AdminUserDetail>(
                    value: value,
                    onRetry: () => ref.invalidate(adminUserProvider(widget.userId)),
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

  Widget _body(AdminUserDetail d) {
    final u = d.row;
    final isAdmin = u.role == UserRole.admin;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminCard(
        child: Row(children: [
          KhojloAvatar(initials: u.initials, tone: u.tone, size: 56, photo: u.avatar),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName, style: AppType.serif(size: 22)),
              Text([u.email, if (d.phone != null) d.phone!].join(' · '),
                  style: AppType.sans(size: 12.5, color: AppColors.inkA(0.6))),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                StatusPill(label: u.roleLabel, color: AppColors.inkA(0.6)),
                StatusPill(
                    label: switch (u.status) {
                      AccountStatus.active => 'Active',
                      AccountStatus.suspended => u.suspendedUntil != null
                          ? 'Suspended until ${shortDate(u.suspendedUntil!)}'
                          : 'Suspended',
                      AccountStatus.banned => 'Banned',
                    },
                    color: accountColor(u.status)),
                if (u.suspensionReason != null)
                  StatusPill(label: u.suspensionReason!, color: AppColors.plum),
                StatusPill(
                    label: u.emailVerified ? 'Email verified' : 'Email not verified',
                    color: u.emailVerified ? AppColors.emerald : AppColors.inkA(0.5)),
                StatusPill(label: 'Joined ${shortDate(u.createdAt)}', color: AppColors.inkA(0.5)),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      AdminGrid(minTileWidth: 150, children: [
        AdminStat(label: 'Reviews', value: u.reviews, note: '${d.removedReviews} removed'),
        AdminStat(label: 'Businesses', value: u.businesses),
        AdminStat(label: 'Open reports', value: u.reportsAgainst, alert: true),
        AdminStat(label: 'Warnings', value: u.warnings, note: '${u.openFlags} open flags'),
      ]),
      if (!isAdmin)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            if (u.status == AccountStatus.active) ...[
              GhostButton(
                  label: 'Warn', small: true, expand: false,
                  onTap: _busy ? null : () => _act('warn')),
              GhostButton(
                  label: 'Suspend', small: true, expand: false, tone: AppColors.plum,
                  onTap: _busy ? null : () => _act('suspend')),
              GhostButton(
                  label: 'Ban', icon: Icons.block_rounded, small: true, expand: false,
                  tone: AppColors.plum, onTap: _busy ? null : () => _act('ban')),
            ] else
              PrimaryButton(
                  label: u.status == AccountStatus.banned ? 'Lift the ban' : 'Lift the suspension',
                  small: true,
                  expand: false,
                  loading: _busy,
                  onTap: () => _act('lift')),
          ]),
        ),
      if (d.owned.isNotEmpty) ...[
        AdminSectionTitle('Businesses', count: d.owned.length),
        for (final b in d.owned)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BusinessRow(business: b, onTap: () => context.push('/admin/business/${b.id}')),
          ),
      ],
      AdminSectionTitle('Automatic flags', count: d.flags.length),
      if (d.flags.isEmpty)
        const AdminEmpty(message: 'No flags on this account.', icon: Icons.auto_awesome_outlined)
      else
        for (final f in d.flags)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: FlagRow(flag: f)),
      const AdminSectionTitle('History'),
      ActionTimeline(actions: d.history, onTapTarget: (a) => openActionTarget(context, a)),
    ]);
  }
}
