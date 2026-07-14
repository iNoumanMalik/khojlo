import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business.dart';
import '../../../core/models/feed.dart';
import '../../../core/providers.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(ref.watch(dioProvider));
});

class DiscoveryRepository {
  DiscoveryRepository(this._dio);
  final Dio _dio;

  Future<Feed> feed({double? lat, double? lng}) async {
    final res = await _dio.get('/feed', queryParameters: {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return Feed.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<BusinessCard>> surprise() async {
    final res = await _dio.get('/feed/surprise');
    return (res.data as List)
        .map((e) => BusinessCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BusinessDetail> detail(int id) async {
    final res = await _dio.get('/businesses/$id');
    return BusinessDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<BusinessDetail> save(int id, {int? listId}) async {
    final res = await _dio.post('/businesses/$id/save', data: {'list_id': listId});
    return BusinessDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<BusinessDetail> unsave(int id) async {
    final res = await _dio.delete('/businesses/$id/save');
    return BusinessDetail.fromJson(res.data as Map<String, dynamic>);
  }
}
