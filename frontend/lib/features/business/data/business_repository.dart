import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/analytics.dart';
import '../../../core/models/business.dart';
import '../../../core/providers.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(dioProvider));
});

/// Payload for the registration stepper.
class BusinessDraft {
  String name = '';
  int? categoryId;
  String tone = 'gold';
  String tagline = '';
  String description = '';
  String address = '';
  double? latitude;
  double? longitude;
  String priceLevel = '\$\$';
  List<({String name, String price})> services = [];
  List<({int day, String opens, String closes, bool closed})> hours = [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'category_id': categoryId,
        'tone': tone,
        'tagline': tagline,
        'description': description,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'price_level': priceLevel,
        'services': [
          for (final s in services) {'name': s.name, 'price': s.price}
        ],
        'hours': [
          for (final h in hours)
            {
              'day_of_week': h.day,
              'opens': h.opens,
              'closes': h.closes,
              'is_closed': h.closed
            }
        ],
      };
}

class BusinessRepository {
  BusinessRepository(this._dio);
  final Dio _dio;

  Future<List<Category>> categories() async {
    final res = await _dio.get('/categories');
    return (res.data as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BusinessCard>> mine() async {
    final res = await _dio.get('/businesses/mine');
    return (res.data as List)
        .map((e) => BusinessCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BusinessDetail> create(BusinessDraft draft) async {
    final res = await _dio.post('/businesses', data: draft.toJson());
    return BusinessDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<BusinessAnalytics> analytics(int id) async {
    final res = await _dio.get('/businesses/$id/analytics');
    return BusinessAnalytics.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Offer>> offers(int id) async {
    final res = await _dio.get('/businesses/$id/offers');
    return (res.data as List)
        .map((e) => Offer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Offer> createOffer(int id,
      {required String title, String starts = '', String ends = ''}) async {
    final res = await _dio.post('/businesses/$id/offers', data: {
      'title': title,
      'starts_on': starts,
      'ends_on': ends,
      'status': 'Active',
    });
    return Offer.fromJson(res.data as Map<String, dynamic>);
  }
}
