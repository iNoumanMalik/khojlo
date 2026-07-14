import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/saved.dart';
import '../../../core/providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(dioProvider));
});

class AccountRepository {
  AccountRepository(this._dio);
  final Dio _dio;

  Future<List<SavedList>> savedLists() async {
    final res = await _dio.get('/users/me/saved');
    return (res.data as List)
        .map((e) => SavedList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SavedList> createList(String name, {String tone = 'gold'}) async {
    final res = await _dio.post('/users/me/saved', data: {'name': name, 'tone': tone});
    return SavedList.fromJson(res.data as Map<String, dynamic>);
  }
}
