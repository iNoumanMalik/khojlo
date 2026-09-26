import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/analytics.dart';
import '../../../core/models/business.dart';
import '../../../core/providers.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(dioProvider));
});

/// Mon–Sat 09:00–21:00, closed Sunday — the starting point for the hours editor.
List<OpeningHours> defaultWeekHours() => [
      for (var day = 0; day < 7; day++)
        OpeningHours(dayOfWeek: day, opens: '09:00', closes: '21:00', isClosed: day == 6),
    ];

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

  /// Optional price range in PKR (Module 4 budget filter + comparison).
  int? priceMin;
  int? priceMax;
  List<({String name, int? amount})> services = [];

  /// Weekly hours; sent only when [includeHours] is on.
  List<OpeningHours> hours = defaultWeekHours();
  bool includeHours = true;

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
        'price_min': priceMin,
        'price_max': priceMax,
        'services': [
          for (final s in services)
            {
              'name': s.name,
              'price': s.amount == null ? '' : formatRupees(s.amount!),
              'price_amount': s.amount,
            }
        ],
        'hours': includeHours ? [for (final h in hours) h.toJson()] : [],
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

  /// Full profile for the owner's edit screens (not counted as a profile view).
  Future<BusinessDetail> detail(int id) async {
    final res = await _dio.get('/businesses/$id', queryParameters: {'track': false});
    return BusinessDetail.fromJson(res.data as Map<String, dynamic>);
  }

  /// Partial update — send only the fields that change (null clears a field).
  Future<BusinessDetail> update(int id, Map<String, dynamic> changes) async {
    final res = await _dio.patch('/businesses/$id', data: changes);
    return BusinessDetail.fromJson(res.data as Map<String, dynamic>);
  }

  /// Replace the weekly opening hours (an empty list removes them).
  Future<BusinessDetail> replaceHours(int id, List<OpeningHours> hours) async {
    final res = await _dio.put('/businesses/$id/hours', data: {
      'hours': [for (final h in hours) h.toJson()],
    });
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
