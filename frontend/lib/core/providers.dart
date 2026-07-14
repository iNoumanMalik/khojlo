import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import 'storage/token_storage.dart';

/// Secure token store.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Configured API client (Dio + JWT interceptor).
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});

/// Convenience accessor for the raw Dio instance.
final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);
