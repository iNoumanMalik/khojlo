import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/map_types.dart';
import '../../../core/models/search.dart';
import '../../../core/providers.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(dioProvider));
});

/// Module 4 endpoints: `/search/*` and `/compare` (plus the Module 6 map area).
class SearchRepository {
  SearchRepository(this._dio);
  final Dio _dio;

  Future<SearchPage> search(
    SearchFilters filters, {
    double? lat,
    double? lng,
    int limit = 20,
    int offset = 0,
    bool record = false,
    GeoBounds? bounds,
  }) async {
    final res = await _dio.get('/search', queryParameters: {
      ...filters.toQuery(lat: lat, lng: lng),
      // Module 6: only places inside the visible map area.
      if (bounds != null) ...bounds.toQuery(),
      'limit': limit,
      'offset': offset,
      if (record) 'record': true,
    });
    return SearchPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<SearchSuggestion>> suggestions(String q) async {
    final res = await _dio.get('/search/suggestions', queryParameters: {'q': q});
    return (res.data as List)
        .map((e) => SearchSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> popular() async {
    final res = await _dio.get('/search/popular');
    return (res.data as List).cast<String>();
  }

  Future<List<String>> history() async {
    final res = await _dio.get('/search/history');
    return (res.data as List)
        .map((e) => (e as Map<String, dynamic>)['query'] as String)
        .toList();
  }

  Future<void> clearHistory() => _dio.delete('/search/history');

  Future<CompareResult> compare(List<int> ids, {double? lat, double? lng}) async {
    final res = await _dio.get('/compare', queryParameters: {
      'ids': ids,
      if (lat != null && lng != null) 'lat': lat,
      if (lat != null && lng != null) 'lng': lng,
    });
    return CompareResult.fromJson(res.data as Map<String, dynamic>);
  }
}
