import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/moderation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../admin_providers.dart';
import 'admin_sections.dart';

/// Module 8 — the admin panel (SRS FR-14, FR-15, SEC-3). The layout follows
/// `docs/design/modules_layout.md`: Overview, Today's stats, Verification queue,
/// Reports, Spam, Analytics, Users, Businesses, with cards, a chart and an
/// activity timeline. A sidebar on wide screens (admins mostly use the web),
/// tabs on phones.
enum AdminSection {
  overview('Overview', Icons.space_dashboard_outlined),
  verification('Verification', Icons.verified_outlined),
  reports('Reports', Icons.flag_outlined),
  flags('Spam & flags', Icons.auto_awesome_outlined),
  users('Users', Icons.people_outline_rounded),
  businesses('Businesses', Icons.storefront_outlined),
  activity('Activity', Icons.history_rounded);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;

  static AdminSection fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => overview);
}

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.initial = AdminSection.overview});
  final AdminSection initial;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  late AdminSection _section = widget.initial;

  static const wideBreakpoint = 900.0;

  /// The phone tab row keeps the selected tab in view.
  final _tabKeys = {for (final s in AdminSection.values) s: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _revealTab();
  }

  @override
  void didUpdateWidget(AdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new ?section= in the link (or going back) switches the section.
    if (widget.initial != oldWidget.initial) {
      _section = widget.initial;
      _revealTab();
    }
  }

  void _go(AdminSection s) {
    setState(() => _section = s);
    _revealTab();
  }

  void _revealTab() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final tab = _tabKeys[_section]?.currentContext;
    if (tab != null && mounted) {
      Scrollable.ensureVisible(
        tab,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
      );
    }
  });

  int? _count(AdminOverview? o, AdminSection s) => switch (s) {
    AdminSection.verification => o?.pendingReview,
    AdminSection.reports => o?.openReports,
    AdminSection.flags => o?.openFlags,
    _ => null,
  };

  Widget _content() => switch (_section) {
    AdminSection.overview => OverviewSection(onOpen: _go),
    AdminSection.verification => const VerificationSection(),
    AdminSection.reports => const ReportsSection(),
    AdminSection.flags => const FlagsSection(),
    AdminSection.users => const UsersSection(),
    AdminSection.businesses => const BusinessesSection(),
    AdminSection.activity => const ActivitySection(),
  };

  void _exit() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(adminOverviewProvider).valueOrNull;
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final body = RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () async {
        refreshAdmin(ref);
        await ref.read(adminOverviewProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          wide ? 32 : 20,
          wide ? 28 : 0,
          wide ? 32 : 20,
          60,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: _content(),
            ),
          ),
        ],
      ),
    );

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: Row(
          children: [
            _Sidebar(
              selected: _section,
              onSelect: _go,
              countOf: (s) => _count(overview, s),
              onExit: _exit,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: 'Admin & moderation',
            subtitle: 'Khojlo internal tool',
            onBack: _exit,
          ),
          SizedBox(
            height: 44,
            // All seven tabs are built (not lazily), so the selected one can be scrolled to.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in AdminSection.values)
                    Padding(
                      key: _tabKeys[s],
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: KhojloChip(
                        label: switch (_count(overview, s)) {
                          final int n when n > 0 => '${s.label} · $n',
                          _ => s.label,
                        },
                        active: s == _section,
                        activeTone: AppColors.ink,
                        dense: true,
                        onTap: () => _go(s),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.countOf,
    required this.onExit,
  });

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  final int? Function(AdminSection) countOf;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.55),
        border: Border(right: BorderSide(color: AppColors.inkA(0.07))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Khojlo', style: AppType.serif(size: 24)),
                    const SizedBox(height: 2),
                    Text(
                      'ADMIN & MODERATION',
                      style: AppType.mono(
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: AppColors.emerald,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              for (final s in AdminSection.values)
                _NavItem(
                  section: s,
                  selected: s == selected,
                  count: countOf(s),
                  onTap: () => onSelect(s),
                ),
              const Spacer(),
              _NavButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back to the app',
                onTap: onExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.count,
    required this.onTap,
  });
  final AdminSection section;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 19,
                  color: selected ? Colors.white : AppColors.inkA(0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    style: AppType.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
                if ((count ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.gold : AppColors.plum,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$count',
                      style: AppType.mono(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.inkA(0.6)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: AppType.sans(size: 13, color: AppColors.inkA(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
