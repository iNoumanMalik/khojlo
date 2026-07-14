import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';

/// Thin wrapper over Dio with a JWT interceptor that attaches the access token
/// and transparently refreshes it on a 401.
class ApiClient {
  ApiClient(this._tokens) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(_authInterceptor());
  }

  final TokenStorage _tokens;
  late final Dio dio;
  bool _refreshing = false;

  InterceptorsWrapper _authInterceptor() => InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _tokens.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final is401 = err.response?.statusCode == 401;
          final alreadyRetried = err.requestOptions.extra['retried'] == true;
          if (is401 && !alreadyRetried && !_refreshing) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final opts = err.requestOptions;
                opts.extra['retried'] = true;
                final token = await _tokens.accessToken;
                opts.headers['Authorization'] = 'Bearer $token';
                final clone = await dio.fetch(opts);
                return handler.resolve(clone);
              } catch (_) {
                // fall through to the original error
              }
            }
          }
          handler.next(err);
        },
      );

  Future<bool> _tryRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    _refreshing = true;
    try {
      final res = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {'skipAuth': true}),
      );
      await _tokens.save(
        access: res.data['access_token'] as String,
        refresh: res.data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      await _tokens.clear();
      return false;
    } finally {
      _refreshing = false;
    }
  }
}

/// Normalizes Dio errors into a friendly message for the UI.
String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is Map && data['detail'] is List) {
      final first = (data['detail'] as List).first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Can’t reach the server. Is the backend running?';
      default:
        return error.message ?? 'Something went wrong.';
    }
  }
  return 'Something went wrong.';
}
