import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/photo.dart';
import '../providers.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(ref.watch(dioProvider));
});

/// Uploads photos (`POST /media`). The returned [Photo.key] is then attached to
/// a business gallery or set as the profile picture.
class MediaRepository {
  MediaRepository(this._dio);
  final Dio _dio;

  Future<Photo> upload(
    Uint8List bytes, {
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final res = await _dio.post(
      '/media',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}),
      options: Options(
        contentType: 'multipart/form-data',
        // The server resizes and re-encodes before it answers.
        receiveTimeout: const Duration(seconds: 60),
      ),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
    return Photo.fromJson(res.data as Map<String, dynamic>);
  }
}
