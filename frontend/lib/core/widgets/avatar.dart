import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Circular avatar: the profile [photo] when there is one, otherwise serif
/// initials on the tone gradient (also shown while the photo loads).
class KhojloAvatar extends StatelessWidget {
  const KhojloAvatar({
    super.key,
    required this.initials,
    this.tone = 'gold',
    this.size = 44,
    this.photo,
  });

  final String initials;
  final String tone;
  final double size;
  final Photo? photo;

  @override
  Widget build(BuildContext context) {
    final initialsLabel = Text(
      initials,
      style: AppType.serif(size: size * 0.38, color: Colors.white),
    );
    final p = photo;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientFor(tone),
        ),
      ),
      child: p == null
          ? initialsLabel
          : CachedNetworkImage(
              // Thumbnails are 480 px; only big avatars on dense screens need more.
              imageUrl: size * MediaQuery.devicePixelRatioOf(context) > 420 ? p.url : p.thumbUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              alignment: p.alignmentFor(1),
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (_, __) => Center(child: initialsLabel),
              errorWidget: (_, __, ___) => Center(child: initialsLabel),
            ),
    );
  }
}
