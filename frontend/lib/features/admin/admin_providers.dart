import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/moderation.dart';
import 'data/admin_repository.dart';

/// Module 8 — the admin panel's data. Screens invalidate these after an action.

final adminOverviewProvider = FutureProvider.autoDispose<AdminOverview>(
    (ref) => ref.watch(adminRepositoryProvider).overview());

/// (status filter, search text)
typedef ListQuery = ({String status, String q});

final adminBusinessesProvider =
    FutureProvider.autoDispose.family<Paged<AdminBusinessBrief>, ListQuery>(
        (ref, query) => ref
            .watch(adminRepositoryProvider)
            .businesses(status: query.status, q: query.q));

final adminBusinessProvider = FutureProvider.autoDispose.family<AdminBusinessDetail, int>(
    (ref, id) => ref.watch(adminRepositoryProvider).business(id));

/// (kind filter, open / resolved)
typedef ReportQuery = ({String kind, String status});

final adminReportsProvider = FutureProvider.autoDispose.family<Paged<ReportItem>, ReportQuery>(
    (ref, query) =>
        ref.watch(adminRepositoryProvider).reports(kind: query.kind, status: query.status));

final adminReportProvider =
    FutureProvider.autoDispose.family<ReportDetail, (ReportKind, int)>(
        (ref, key) => ref.watch(adminRepositoryProvider).report(key.$1, key.$2));

final adminFlagsProvider = FutureProvider.autoDispose.family<Paged<AdminFlag>, String>(
    (ref, status) => ref.watch(adminRepositoryProvider).flags(status: status));

final adminUsersProvider = FutureProvider.autoDispose.family<Paged<AdminUserRow>, ListQuery>(
    (ref, query) =>
        ref.watch(adminRepositoryProvider).users(status: query.status, q: query.q));

final adminUserProvider = FutureProvider.autoDispose.family<AdminUserDetail, int>(
    (ref, id) => ref.watch(adminRepositoryProvider).user(id));

final adminActionsProvider = FutureProvider.autoDispose<Paged<AdminAction>>(
    (ref) => ref.watch(adminRepositoryProvider).actions(limit: 100));

/// After any admin action: refresh every list and count.
void refreshAdmin(WidgetRef ref) {
  ref.invalidate(adminOverviewProvider);
  ref.invalidate(adminBusinessesProvider);
  ref.invalidate(adminReportsProvider);
  ref.invalidate(adminFlagsProvider);
  ref.invalidate(adminUsersProvider);
  ref.invalidate(adminActionsProvider);
}
