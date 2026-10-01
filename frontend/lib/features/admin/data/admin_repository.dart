import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/moderation.dart';
import '../../../core/providers.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioProvider));
});

/// Module 8 endpoints: `/admin/*` (admins only, SEC-3).
class AdminRepository {
  AdminRepository(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response res) => res.data as Map<String, dynamic>;

  Future<AdminOverview> overview() async =>
      AdminOverview.fromJson(_map(await _dio.get('/admin/overview')));

  // ── businesses and verification (FR-14, UC-12) ──
  Future<Paged<AdminBusinessBrief>> businesses(
      {String status = 'all', String q = '', int limit = 30, int offset = 0}) async {
    final res = await _dio.get('/admin/businesses', queryParameters: {
      'status': status,
      if (q.trim().isNotEmpty) 'q': q.trim(),
      'limit': limit,
      'offset': offset,
    });
    return Paged.fromJson(_map(res), AdminBusinessBrief.fromJson);
  }

  Future<AdminBusinessDetail> business(int id) async =>
      AdminBusinessDetail.fromJson(_map(await _dio.get('/admin/businesses/$id')));

  /// approve | reject | request_info | revoke
  Future<AdminBusinessDetail> decide(int id, String decision, {String note = ''}) async =>
      AdminBusinessDetail.fromJson(_map(await _dio.post('/admin/businesses/$id/verification',
          data: {'decision': decision, 'note': note})));

  Future<AdminBusinessDetail> suspendBusiness(int id, ModerationReason reason,
          {String note = ''}) async =>
      AdminBusinessDetail.fromJson(_map(await _dio.post('/admin/businesses/$id/suspend',
          data: {'reason': reason.api, 'note': note})));

  Future<AdminBusinessDetail> reinstateBusiness(int id, {String note = ''}) async =>
      AdminBusinessDetail.fromJson(
          _map(await _dio.post('/admin/businesses/$id/reinstate', data: {'note': note})));

  // ── reports (FR-15, FR-19, Algorithm 10) ──
  Future<Paged<ReportItem>> reports(
      {String kind = 'all', String status = 'open', int limit = 50, int offset = 0}) async {
    final res = await _dio.get('/admin/reports', queryParameters: {
      'kind': kind,
      'status': status,
      'limit': limit,
      'offset': offset,
    });
    return Paged.fromJson(_map(res), ReportItem.fromJson);
  }

  Future<ReportDetail> report(ReportKind kind, int targetId) async =>
      ReportDetail.fromJson(_map(await _dio.get('/admin/reports/${kind.api}/$targetId')));

  Future<ReportDetail> resolveReport(ReportKind kind, int targetId, Resolution r) async =>
      ReportDetail.fromJson(_map(await _dio.post(
          '/admin/reports/${kind.api}/$targetId/resolve',
          data: r.toJson())));

  // ── flags from the automatic rules ──
  Future<Paged<AdminFlag>> flags({String status = 'open', int limit = 50, int offset = 0}) async {
    final res = await _dio.get('/admin/flags',
        queryParameters: {'status': status, 'limit': limit, 'offset': offset});
    return Paged.fromJson(_map(res), AdminFlag.fromJson);
  }

  Future<AdminFlag> resolveFlag(int flagId, Resolution r) async =>
      AdminFlag.fromJson(_map(await _dio.post('/admin/flags/$flagId/resolve', data: r.toJson())));

  // ── accounts ──
  Future<Paged<AdminUserRow>> users(
      {String status = 'all', String q = '', int limit = 30, int offset = 0}) async {
    final res = await _dio.get('/admin/users', queryParameters: {
      'status': status,
      if (q.trim().isNotEmpty) 'q': q.trim(),
      'limit': limit,
      'offset': offset,
    });
    return Paged.fromJson(_map(res), AdminUserRow.fromJson);
  }

  Future<AdminUserDetail> user(int id) async =>
      AdminUserDetail.fromJson(_map(await _dio.get('/admin/users/$id')));

  /// warn | suspend | ban | lift
  Future<AdminUserDetail> actOnUser(int id, String action,
          {ModerationReason reason = ModerationReason.other,
          String note = '',
          int days = 7,
          bool hideReviews = false}) async =>
      AdminUserDetail.fromJson(_map(await _dio.post('/admin/users/$id/action', data: {
        'action': action,
        'reason': reason.api,
        'note': note,
        'days': days,
        'hide_reviews': hideReviews,
      })));

  // ── the audit log ──
  Future<Paged<AdminAction>> actions({bool? automatic, int limit = 50, int offset = 0}) async {
    final res = await _dio.get('/admin/actions', queryParameters: {
      if (automatic != null) 'automatic': automatic,
      'limit': limit,
      'offset': offset,
    });
    return Paged.fromJson(_map(res), AdminAction.fromJson);
  }
}
