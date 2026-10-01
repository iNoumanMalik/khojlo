import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/moderation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../admin_providers.dart';
import '../data/admin_repository.dart';
import 'admin_screen.dart';
import 'widgets/admin_widgets.dart';

/// The page each audit-log entry is about, if it has one.
void openActionTarget(BuildContext context, AdminAction a) {
  switch (a.targetType) {
    case 'business':
      context.push('/admin/business/${a.targetId}');
    case 'user':
      context.push('/admin/user/${a.targetId}');
    case 'review' || 'conversation':
      context.push('/admin/report/${a.targetType}/${a.targetId}');
    default:
      if (a.subjectUserId != null) context.push('/admin/user/${a.subjectUserId}');
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppType.serif(size: 26)),
        const SizedBox(height: 2),
        Text(subtitle, style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
      ]),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.options, required this.value, required this.onChanged});
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (key, label) in options)
          KhojloChip(
              label: label,
              dense: true,
              active: key == value,
              activeTone: AppColors.ink,
              onTap: () => onChanged(key)),
      ]),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.hint, required this.onSearch});
  final String hint;
  final ValueChanged<String> onSearch;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TextField(
        controller: _text,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSearch,
        style: AppType.sans(size: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppType.sans(size: 13.5, color: AppColors.inkA(0.4)),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkA(0.45)),
          suffixIcon: IconButton(
            icon: Icon(Icons.arrow_forward_rounded, color: AppColors.inkA(0.55)),
            onPressed: () => widget.onSearch(_text.text),
          ),
          filled: true,
          fillColor: AppColors.whiteA(0.8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

// ─────────────── overview ───────────────
class OverviewSection extends ConsumerWidget {
  const OverviewSection({super.key, required this.onOpen});
  final ValueChanged<AdminSection> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminOverviewProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Heading('Overview', 'What needs you now, and how Khojlo is doing today.'),
      AsyncSection<AdminOverview>(
        value: value,
        onRetry: () => ref.invalidate(adminOverviewProvider),
        builder: (o) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const AdminSectionTitle('Needs you'),
          AdminGrid(children: [
            AdminStat(
                label: 'Verification',
                value: o.pendingReview,
                note: 'referred by the checks',
                alert: true,
                onTap: () => onOpen(AdminSection.verification)),
            AdminStat(
                label: 'Open reports',
                value: o.openReports,
                note: '${plural(o.openReviewReports, 'review')} · '
                    '${plural(o.openConversationReports, 'chat')} · '
                    '${plural(o.openBusinessReports, 'listing')}',
                alert: true,
                onTap: () => onOpen(AdminSection.reports)),
            AdminStat(
                label: 'Automatic flags',
                value: o.openFlags,
                note: 'spam, scams, adult content',
                alert: true,
                onTap: () => onOpen(AdminSection.flags)),
            AdminStat(
                label: 'Suspended',
                value: o.suspendedAccounts + o.bannedAccounts,
                note: '${o.bannedAccounts} banned · '
                    '${plural(o.suspendedBusinesses, 'listing')} down',
                onTap: () => onOpen(AdminSection.users)),
          ]),
          const AdminSectionTitle("Today's stats"),
          AdminGrid(minTileWidth: 150, children: [
            AdminStat(label: 'New users', value: o.newUsersToday, note: '${o.usersTotal} in all'),
            AdminStat(
                label: 'New businesses',
                value: o.newBusinessesToday,
                note: '${o.businessesTotal} in all'),
            AdminStat(label: 'Reviews', value: o.reviewsToday),
            AdminStat(label: 'Messages', value: o.messagesToday),
          ]),
          const AdminSectionTitle('Verification'),
          AdminCard(
            child: Row(children: [
              const Icon(Icons.verified_rounded, color: AppColors.emerald),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    '${o.verifiedTotal} of ${o.businessesTotal} businesses are verified. '
                    '${o.autoVerifiedWeek} passed the automatic checks this week; '
                    'only businesses with a report or flag wait for you.',
                    style: AppType.sans(size: 13, color: AppColors.inkA(0.7), height: 1.45)),
              ),
            ]),
          ),
          const AdminSectionTitle('Last 14 days'),
          ActivityChart(days: o.daily),
          AdminSectionTitle('Recent activity',
              trailing: GestureDetector(
                onTap: () => onOpen(AdminSection.activity),
                child: Text('See all',
                    style: AppType.sans(
                        size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
              )),
          ActionTimeline(
              actions: o.recent, onTapTarget: (a) => openActionTarget(context, a)),
        ]),
      ),
    ]);
  }
}

// ─────────────── verification (FR-14, UC-12) ───────────────
class VerificationSection extends ConsumerStatefulWidget {
  const VerificationSection({super.key});

  @override
  ConsumerState<VerificationSection> createState() => _VerificationSectionState();
}

class _VerificationSectionState extends ConsumerState<VerificationSection> {
  String _status = 'pending_review';

  static const _options = [
    ('pending_review', 'Needs review'),
    ('recently_verified', 'Recently verified'),
    ('needs_info', 'Waiting on the owner'),
    ('rejected', 'Not verified'),
  ];

  String get _empty => switch (_status) {
        'pending_review' => 'Nothing to review. The automatic checks are handling it.',
        'recently_verified' => 'Nothing was verified in the last week.',
        'needs_info' => 'No owner owes you anything right now.',
        _ => 'No rejected businesses.',
      };

  @override
  Widget build(BuildContext context) {
    final query = (status: _status, q: '');
    final value = ref.watch(adminBusinessesProvider(query));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Heading('Verification',
          'The system verifies businesses that pass every check. You only see the rest.'),
      _Filters(options: _options, value: _status, onChanged: (v) => setState(() => _status = v)),
      if (_status == 'recently_verified')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Spot-check these: open one to see its storefront photo, and revoke the '
              'badge if something is off.',
              style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
        ),
      const SizedBox(height: 14),
      AsyncSection<Paged<AdminBusinessBrief>>(
        value: value,
        onRetry: () => ref.invalidate(adminBusinessesProvider(query)),
        builder: (page) => page.items.isEmpty
            ? AdminEmpty(message: _empty)
            : Column(children: [
                for (final b in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BusinessRow(
                        business: b,
                        showStorefront: true,
                        onTap: () => context.push('/admin/business/${b.id}')),
                  ),
              ]),
      ),
    ]);
  }
}

// ─────────────── reports (FR-15, FR-19) ───────────────
class ReportsSection extends ConsumerStatefulWidget {
  const ReportsSection({super.key});

  @override
  ConsumerState<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends ConsumerState<ReportsSection> {
  String _kind = 'all';
  String _status = 'open';

  @override
  Widget build(BuildContext context) {
    final query = (kind: _kind, status: _status);
    final value = ref.watch(adminReportsProvider(query));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Heading('Reports',
          'What people reported, most-reported first. Content stays up until you decide.'),
      _Filters(
        options: const [
          ('all', 'Everything'),
          ('review', 'Reviews'),
          ('conversation', 'Conversations'),
          ('business', 'Businesses'),
        ],
        value: _kind,
        onChanged: (v) => setState(() => _kind = v),
      ),
      _Filters(
        options: const [('open', 'Open'), ('resolved', 'Resolved')],
        value: _status,
        onChanged: (v) => setState(() => _status = v),
      ),
      const SizedBox(height: 14),
      AsyncSection<Paged<ReportItem>>(
        value: value,
        onRetry: () => ref.invalidate(adminReportsProvider(query)),
        builder: (page) => page.items.isEmpty
            ? AdminEmpty(
                message: _status == 'open' ? 'No open reports. All clear.' : 'Nothing resolved yet.')
            : Column(children: [
                for (final item in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReportRow(
                      item: item,
                      onTap: () =>
                          context.push('/admin/report/${item.kind.api}/${item.targetId}'),
                    ),
                  ),
              ]),
      ),
    ]);
  }
}

// ─────────────── spam and automatic flags ───────────────
class FlagsSection extends ConsumerStatefulWidget {
  const FlagsSection({super.key});

  @override
  ConsumerState<FlagsSection> createState() => _FlagsSectionState();
}

class _FlagsSectionState extends ConsumerState<FlagsSection> {
  String _status = 'open';
  int? _busy;

  Future<void> _decide(AdminFlag flag) async {
    final result = await showResolutionSheet(
      context,
      title: flag.detail,
      upholdLabel: flag.upholdLabel,
      accounts: [if (flag.userId != null) (flag.userId!, flag.userName ?? 'The account')],
    );
    if (result == null || !mounted) return;
    setState(() => _busy = flag.id);
    try {
      await ref.read(adminRepositoryProvider).resolveFlag(flag.id, result);
      refreshAdmin(ref);
      if (mounted) adminSnack(context, result.uphold ? 'Done. Everyone affected has been told.' : 'Dismissed.');
    } catch (e) {
      if (mounted) adminSnack(context, describeApiError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _view(AdminFlag flag) {
    if (flag.targetType == 'user') {
      context.push('/admin/user/${flag.targetId}');
    } else if (flag.businessId != null) {
      context.push('/admin/business/${flag.businessId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminFlagsProvider(_status));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Heading('Spam & flags',
          'What the automatic rules noticed. Nothing is hidden until you decide.'),
      _Filters(
        options: const [('open', 'Open'), ('resolved', 'Resolved')],
        value: _status,
        onChanged: (v) => setState(() => _status = v),
      ),
      const SizedBox(height: 14),
      AsyncSection<Paged<AdminFlag>>(
        value: value,
        onRetry: () => ref.invalidate(adminFlagsProvider(_status)),
        builder: (page) => page.items.isEmpty
            ? AdminEmpty(
                message: _status == 'open'
                    ? 'No open flags. The rules haven’t caught anything new.'
                    : 'Nothing resolved yet.',
                icon: Icons.auto_awesome_outlined)
            : Column(children: [
                for (final f in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      FlagRow(flag: f),
                      if (f.isOpen)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            if (f.businessId != null || f.targetType == 'user')
                              GhostButton(
                                  label: 'View', small: true, expand: false,
                                  onTap: () => _view(f)),
                            const Spacer(),
                            PrimaryButton(
                                label: 'Decide',
                                small: true,
                                expand: false,
                                loading: _busy == f.id,
                                onTap: () => _decide(f)),
                          ]),
                        ),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}

// ─────────────── users ───────────────
class UsersSection extends ConsumerStatefulWidget {
  const UsersSection({super.key});

  @override
  ConsumerState<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends ConsumerState<UsersSection> {
  String _status = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final query = (status: _status, q: _q);
    final value = ref.watch(adminUsersProvider(query));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Heading('Users', 'Find an account to see its history, warn, suspend or ban it.'),
      _SearchBox(hint: 'Name or email', onSearch: (q) => setState(() => _q = q)),
      _Filters(
        options: const [
          ('all', 'Everyone'),
          ('active', 'Active'),
          ('suspended', 'Suspended'),
          ('banned', 'Banned'),
        ],
        value: _status,
        onChanged: (v) => setState(() => _status = v),
      ),
      const SizedBox(height: 14),
      AsyncSection<Paged<AdminUserRow>>(
        value: value,
        onRetry: () => ref.invalidate(adminUsersProvider(query)),
        builder: (page) => page.items.isEmpty
            ? const AdminEmpty(message: 'No accounts match.', icon: Icons.person_search_outlined)
            : Column(children: [
                for (final u in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PersonRow(
                      person: u,
                      trailing: u.reportsAgainst + u.openFlags > 0
                          ? StatusPill(
                              label: '${u.reportsAgainst + u.openFlags} open',
                              color: AppColors.plum,
                              icon: Icons.flag_outlined)
                          : null,
                      onTap: () => context.push('/admin/user/${u.id}'),
                    ),
                  ),
                if (page.total > page.items.length)
                  Text('Showing ${page.items.length} of ${page.total}. Search to narrow it down.',
                      style: AppType.sans(size: 12, color: AppColors.inkA(0.5))),
              ]),
      ),
    ]);
  }
}

// ─────────────── businesses ───────────────
class BusinessesSection extends ConsumerStatefulWidget {
  const BusinessesSection({super.key});

  @override
  ConsumerState<BusinessesSection> createState() => _BusinessesSectionState();
}

class _BusinessesSectionState extends ConsumerState<BusinessesSection> {
  String _status = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final query = (status: _status, q: _q);
    final value = ref.watch(adminBusinessesProvider(query));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Heading('Businesses', 'Every listing, with its verification and moderation status.'),
      _SearchBox(hint: 'Business name', onSearch: (q) => setState(() => _q = q)),
      _Filters(
        options: const [
          ('all', 'All'),
          ('verified', 'Verified'),
          ('unverified', 'Not verified yet'),
          ('suspended', 'Suspended'),
        ],
        value: _status,
        onChanged: (v) => setState(() => _status = v),
      ),
      const SizedBox(height: 14),
      AsyncSection<Paged<AdminBusinessBrief>>(
        value: value,
        onRetry: () => ref.invalidate(adminBusinessesProvider(query)),
        builder: (page) => page.items.isEmpty
            ? const AdminEmpty(message: 'No businesses match.', icon: Icons.storefront_outlined)
            : Column(children: [
                for (final b in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BusinessRow(
                        business: b, onTap: () => context.push('/admin/business/${b.id}')),
                  ),
                if (page.total > page.items.length)
                  Text('Showing ${page.items.length} of ${page.total}. Search to narrow it down.',
                      style: AppType.sans(size: 12, color: AppColors.inkA(0.5))),
              ]),
      ),
    ]);
  }
}

// ─────────────── activity (the audit log) ───────────────
class ActivitySection extends ConsumerWidget {
  const ActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminActionsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Heading('Activity',
          'Every decision, by an admin or the automatic checks, newest first.'),
      const SizedBox(height: 14),
      AsyncSection<Paged<AdminAction>>(
        value: value,
        onRetry: () => ref.invalidate(adminActionsProvider),
        builder: (page) => ActionTimeline(
            actions: page.items, onTapTarget: (a) => openActionTarget(context, a)),
      ),
    ]);
  }
}
