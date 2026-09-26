import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../theme/app_typography.dart';

/// Opens [photos] full screen at [initialIndex]: swipe between them, pinch to zoom.
Future<void> showPhotoViewer(BuildContext context, List<Photo> photos, {int initialIndex = 0}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => PhotoViewer(photos: photos, initialIndex: initialIndex),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  ));
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.initialIndex = 0});
  final List<Photo> photos;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final photo = widget.photos[i];
              return InteractiveViewer(
                maxScale: 4,
                child: Center(
                  // Uncropped here: the whole photo, at its own aspect ratio.
                  child: AspectRatio(
                    aspectRatio: photo.aspectRatio,
                    child: CachedNetworkImage(
                      imageUrl: photo.url,
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          CachedNetworkImage(imageUrl: photo.thumbUrl, fit: BoxFit.contain),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined, color: Colors.white54, size: 40),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (widget.photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text('${_index + 1} / ${widget.photos.length}',
                          style: AppType.mono(size: 12.5, color: Colors.white70)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
