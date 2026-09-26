import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A photo the user picked, not uploaded yet.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

/// Where photos come from: the gallery / camera roll, or a file picker on web.
/// A provider so widget tests can substitute a fake.
abstract class PhotoSource {
  /// Up to [limit] photos; empty if the user cancels.
  Future<List<PickedPhoto>> pickMany(int limit);

  /// One photo, or null if the user cancels.
  Future<PickedPhoto?> pickOne();
}

final photoSourceProvider = Provider<PhotoSource>((ref) => DevicePhotoSource());

class DevicePhotoSource implements PhotoSource {
  final _picker = ImagePicker();

  // Shrink big camera photos on the device first: faster uploads, and the
  // server keeps at most 1600 px anyway.
  static const _maxEdge = 2400.0;
  static const _quality = 88;

  @override
  Future<List<PickedPhoto>> pickMany(int limit) async {
    if (limit <= 0) return const [];
    if (limit == 1) {
      final one = await pickOne();
      return one == null ? const [] : [one];
    }
    final files = await _picker.pickMultiImage(
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
      limit: limit,
    );
    return [for (final f in files.take(limit)) await _read(f)];
  }

  @override
  Future<PickedPhoto?> pickOne() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
    return file == null ? null : _read(file);
  }

  Future<PickedPhoto> _read(XFile f) async =>
      PickedPhoto(bytes: await f.readAsBytes(), name: f.name.isEmpty ? 'photo.jpg' : f.name);
}
