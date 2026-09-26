import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/media_repository.dart';
import '../../../../core/media/photo_source.dart';
import '../../../../core/models/photo.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Cover + gallery (matches the backend limit).
const maxBusinessPhotos = 10;

/// Editor for a business's photos: a cover (shown on every card) plus up to
/// nine more for the business page. Used by the registration Photos step and
/// by the dashboard's Photos screen.
///
/// Photos upload as soon as they're picked; [onChanged] reports the uploaded
/// photos in order (first = cover) and whether any upload is still running.
class PhotoManager extends ConsumerStatefulWidget {
  const PhotoManager({
    super.key,
    this.initial = const [],
    required this.onChanged,
    this.tone = 'gold',
  });

  final List<Photo> initial;
  final void Function(List<Photo> photos, bool uploading) onChanged;

  /// Fallback colour shown when there are no photos.
  final String tone;

  @override
  ConsumerState<PhotoManager> createState() => _PhotoManagerState();
}

class _Slot {
  _Slot.uploaded(Photo this.photo) : picked = null;
  _Slot.picked(PickedPhoto this.picked);

  final PickedPhoto? picked;
  Photo? photo;
  double progress = 0;
  String? error;

  bool get uploading => photo == null && error == null;
}

class _PhotoManagerState extends ConsumerState<PhotoManager> {
  late final List<_Slot> _slots = [for (final p in widget.initial) _Slot.uploaded(p)];

  int get _remaining => maxBusinessPhotos - _slots.length;

  void _notify() => widget.onChanged(
        [for (final s in _slots) if (s.photo != null) s.photo!],
        _slots.any((s) => s.uploading),
      );

  Future<void> _add() async {
    if (_remaining <= 0) return;
    final picked = await ref.read(photoSourceProvider).pickMany(_remaining);
    if (!mounted || picked.isEmpty) return;
    final fresh = [for (final p in picked.take(_remaining)) _Slot.picked(p)];
    setState(() => _slots.addAll(fresh));
    await Future.wait(fresh.map(_upload));
  }

  Future<void> _upload(_Slot slot) async {
    setState(() {
      slot.error = null;
      slot.progress = 0;
    });
    _notify();
    try {
      final photo = await ref.read(mediaRepositoryProvider).upload(
            slot.picked!.bytes,
            filename: slot.picked!.name,
            onProgress: (p) {
              if (mounted) setState(() => slot.progress = p);
            },
          );
      if (mounted) setState(() => slot.photo = photo);
    } catch (e) {
      if (mounted) setState(() => slot.error = describeApiError(e));
    }
    if (mounted) _notify();
  }

  void _makeCover(_Slot slot) {
    setState(() {
      _slots.remove(slot);
      _slots.insert(0, slot);
    });
    _notify();
  }

  void _remove(_Slot slot) {
    setState(() => _slots.remove(slot));
    _notify();
  }

  Future<void> _actions(_Slot slot) async {
    final isCover = identical(_slots.first, slot);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (slot.error != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                  child: Text(slot.error!,
                      style: AppType.sans(size: 13, color: AppColors.plum)),
                ),
                _sheetAction(ctx, 'retry', Icons.refresh_rounded, 'Try the upload again'),
              ],
              if (!isCover && slot.photo != null)
                _sheetAction(ctx, 'cover', Icons.star_outline_rounded, 'Make this the cover'),
              _sheetAction(ctx, 'remove', Icons.delete_outline_rounded, 'Remove photo',
                  color: AppColors.plum),
            ],
          ),
        ),
      ),
    );
    if (!mounted || !_slots.contains(slot)) return;
    switch (action) {
      case 'retry':
        await _upload(slot);
      case 'cover':
        _makeCover(slot);
      case 'remove':
        _remove(slot);
    }
  }

  Widget _sheetAction(BuildContext ctx, String value, IconData icon, String label,
          {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? AppColors.ink),
        title: Text(label, style: AppType.sans(size: 14.5, color: color ?? AppColors.ink)),
        onTap: () => Navigator.of(ctx).pop(value),
      );

  @override
  Widget build(BuildContext context) {
    if (_slots.isEmpty) return _EmptyState(tone: widget.tone, onTap: _add);
    final cover = _slots.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: _SlotTile(
            slot: cover,
            tone: widget.tone,
            radius: 20,
            badge: 'Cover',
            semanticLabel: 'Cover photo',
            onTap: () => _actions(cover),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          const gap = 10.0;
          final size = (box.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 1; i < _slots.length; i++)
                SizedBox.square(
                  dimension: size,
                  child: _SlotTile(
                    slot: _slots[i],
                    tone: widget.tone,
                    radius: 14,
                    semanticLabel: 'Photo ${i + 1}',
                    onTap: () => _actions(_slots[i]),
                  ),
                ),
              if (_remaining > 0)
                SizedBox.square(dimension: size, child: _AddTile(onTap: _add)),
            ],
          );
        }),
        const SizedBox(height: 10),
        Text(
          '${_slots.length} of $maxBusinessPhotos photos · tap one to make it the cover or remove it',
          style: AppType.sans(size: 12, color: AppColors.inkA(0.5)),
        ),
        if (cover.photo != null) ...[
          const SizedBox(height: 22),
          _FitPreview(photo: cover.photo!, tone: widget.tone),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tone, required this.onTap});
  final String tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add photos',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageTile(tone: tone, radius: 20),
              Center(
                child: GlassSurface(
                  radius: 18,
                  opacity: 0.8,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          size: 30, color: AppColors.ink),
                      const SizedBox(height: 8),
                      Text('Add photos',
                          style: AppType.sans(size: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('The first one becomes your cover',
                          style: AppType.sans(size: 12, color: AppColors.inkA(0.55))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add more photos',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.whiteA(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inkA(0.14), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 26, color: AppColors.inkA(0.6)),
              const SizedBox(height: 2),
              Text('Add', style: AppType.sans(size: 12, color: AppColors.inkA(0.6))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.tone,
    required this.radius,
    required this.semanticLabel,
    required this.onTap,
    this.badge,
  });

  final _Slot slot;
  final String tone;
  final double radius;
  final String semanticLabel;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final status = slot.error != null
        ? 'upload failed'
        : slot.uploading
            ? 'uploading'
            : null;
    return Semantics(
      button: true,
      label: status == null ? semanticLabel : '$semanticLabel, $status',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (slot.photo != null)
                ImageTile(photo: slot.photo, tone: tone, radius: 0)
              else
                Image.memory(slot.picked!.bytes, fit: BoxFit.cover, gaplessPlayback: true),
              if (slot.uploading) ...[
                ColoredBox(color: AppColors.whiteA(0.35)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    // Past 100% the server is still resizing: show it as busy.
                    value: slot.progress > 0 && slot.progress < 1 ? slot.progress : null,
                    minHeight: 4,
                    backgroundColor: AppColors.whiteA(0.5),
                    valueColor: const AlwaysStoppedAnimation(AppColors.emerald),
                  ),
                ),
              ],
              if (slot.error != null)
                ColoredBox(
                  color: AppColors.plum.withValues(alpha: 0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, color: Colors.white),
                        const SizedBox(height: 4),
                        Text('Tap to retry',
                            style: AppType.sans(size: 11.5, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              if (badge != null)
                Positioned(left: 10, top: 10, child: KhojloBadge(label: badge!, tone: BadgeTone.gold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cover as it will appear in a wide card, a square thumbnail and a tall tile.
class _FitPreview extends StatelessWidget {
  const _FitPreview({required this.photo, required this.tone});
  final Photo photo;
  final String tone;

  @override
  Widget build(BuildContext context) {
    const h = 84.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW YOUR COVER FITS', style: AppType.label()),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: ImageTile(photo: photo, tone: tone, height: h, radius: 14)),
            const SizedBox(width: 10),
            SizedBox.square(dimension: h, child: ImageTile(photo: photo, tone: tone, radius: 14)),
            const SizedBox(width: 10),
            SizedBox(
                width: h * 0.66,
                height: h,
                child: ImageTile(photo: photo, tone: tone, radius: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Cropped automatically around the most detailed part of your photo, so it fits wide cards, square thumbnails and tall tiles.',
          style: AppType.sans(size: 12, height: 1.45, color: AppColors.inkA(0.5)),
        ),
      ],
    );
  }
}
