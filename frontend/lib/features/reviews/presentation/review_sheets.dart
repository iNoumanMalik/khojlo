import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/media/photo_source.dart';
import '../../../core/models/photo.dart';
import '../../../core/models/review.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../reviews_providers.dart';
import 'widgets/stars.dart';

const _maxPhotos = 3;
const _maxComment = 1000;

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: child,
      ),
    );

Widget _handle() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.inkA(0.15),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppType.sans(size: 13.5, color: AppColors.inkA(0.4)),
      filled: true,
      fillColor: AppColors.whiteA(0.8),
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.inkA(0.08))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.4)),
    );

// ─────────────── write / edit (UC-7) ───────────────

/// Opens the review form; resolves to the saved review, or null if dismissed.
Future<Review?> showWriteReviewSheet(
  BuildContext context, {
  required int businessId,
  required String businessName,
  Review? existing,
}) =>
    _sheet<Review>(
      context,
      _WriteReviewSheet(businessId: businessId, businessName: businessName, existing: existing),
    );

class _PhotoSlot {
  _PhotoSlot.uploaded(this.photo) : picked = null;
  _PhotoSlot.picked(this.picked);

  Photo? photo;
  final PickedPhoto? picked;
  double progress = 0;
  String? error;

  bool get uploading => photo == null && error == null;
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({
    required this.businessId,
    required this.businessName,
    this.existing,
  });

  final int businessId;
  final String businessName;
  final Review? existing;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment ?? '');
  late final List<_PhotoSlot> _photos = [
    for (final p in widget.existing?.photos ?? const <Photo>[]) _PhotoSlot.uploaded(p),
  ];
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) return;
    final picked = await ref.read(photoSourceProvider).pickMany(room);
    if (!mounted || picked.isEmpty) return;
    final fresh = [for (final p in picked.take(room)) _PhotoSlot.picked(p)];
    setState(() => _photos.addAll(fresh));
    await Future.wait(fresh.map(_upload));
  }

  Future<void> _upload(_PhotoSlot slot) async {
    setState(() {
      slot.error = null;
      slot.progress = 0;
    });
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
  }

  Future<void> _submit() async {
    // "Invalid review" (UC-7 exception): say what's wrong, next to the form (USE-3).
    if (_rating == 0) {
      setState(() => _error = 'Pick a star rating first.');
      return;
    }
    if (_photos.any((s) => s.uploading)) {
      setState(() => _error = 'Wait for your photos to finish uploading.');
      return;
    }
    if (_photos.any((s) => s.error != null)) {
      setState(() => _error = 'Remove the photos that didn’t upload, or try them again.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref.read(reviewActionsProvider).save(
            businessId: widget.businessId,
            existing: widget.existing,
            rating: _rating,
            comment: _comment.text.trim(),
            photos: [for (final s in _photos) s.photo!.key],
          );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = describeApiError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          Text(_editing ? 'Edit your review' : 'Rate your visit',
              textAlign: TextAlign.center, style: AppType.serif(size: 24)),
          const SizedBox(height: 4),
          Text(widget.businessName,
              textAlign: TextAlign.center,
              style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
          const SizedBox(height: 18),
          StarPicker(
            value: _rating,
            onChanged: (v) => setState(() {
              _rating = v;
              if (_error == 'Pick a star rating first.') _error = null;
            }),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _comment,
            minLines: 4,
            maxLines: 8,
            maxLength: _maxComment,
            textCapitalization: TextCapitalization.sentences,
            style: AppType.sans(size: 14, height: 1.45),
            decoration: _fieldDecoration(
                'What stood out? Service, prices, the place itself… (optional)'),
          ),
          const SizedBox(height: 6),
          _PhotoRow(
            slots: _photos,
            onAdd: _photos.length < _maxPhotos ? _addPhotos : null,
            onRemove: (slot) => setState(() => _photos.remove(slot)),
            onRetry: _upload,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.plum),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      style: AppType.sans(size: 12.5, color: AppColors.plum, height: 1.35)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: _editing ? 'Save changes' : 'Post review',
            tone: ButtonTone.emerald,
            loading: _saving,
            onTap: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.slots,
    required this.onAdd,
    required this.onRemove,
    required this.onRetry,
  });

  final List<_PhotoSlot> slots;
  final VoidCallback? onAdd;
  final ValueChanged<_PhotoSlot> onRemove;
  final ValueChanged<_PhotoSlot> onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PHOTOS · ${slots.length}/$_maxPhotos', style: AppType.label()),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final slot in slots) _slot(slot),
              if (onAdd != null)
                Semantics(
                  button: true,
                  label: 'Add photos',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 76,
                      decoration: BoxDecoration(
                        color: AppColors.whiteA(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.inkA(0.12)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, color: AppColors.emerald),
                          const SizedBox(height: 4),
                          Text('Add', style: AppType.sans(size: 11, color: AppColors.emerald)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slot(_PhotoSlot slot) {
    Widget image;
    if (slot.photo != null) {
      image = ImageTile(photo: slot.photo, radius: 14, tone: 'gold');
    } else {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(slot.picked!.bytes, fit: BoxFit.cover),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (slot.uploading)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: slot.progress > 0 && slot.progress < 1 ? slot.progress : null,
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ),
            if (slot.error != null)
              GestureDetector(
                onTap: () => onRetry(slot),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.plum.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ),
            Positioned(
              top: 3,
              right: 3,
              child: Semantics(
                button: true,
                label: 'Remove photo',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onRemove(slot),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────── owner reply ───────────────

/// The owner's public reply; resolves to the text, or null if dismissed.
Future<String?> showReplySheet(BuildContext context,
        {required String reviewerName, String? initial}) =>
    _sheet<String>(context, _ReplySheet(reviewerName: reviewerName, initial: initial));

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.reviewerName, this.initial});
  final String reviewerName;
  final String? initial;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final _text = TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write a reply first.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          Text(widget.initial == null ? 'Reply publicly' : 'Edit your reply',
              style: AppType.serif(size: 22)),
          const SizedBox(height: 4),
          Text('Everyone will see your reply under ${widget.reviewerName}’s review.',
              style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            style: AppType.sans(size: 14, height: 1.45),
            decoration: _fieldDecoration('Thank them, or explain what you’ll improve…'),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null)
            Text(_error!, style: AppType.sans(size: 12.5, color: AppColors.plum)),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Post reply', tone: ButtonTone.emerald, onTap: _send),
        ],
      ),
    );
  }
}

// ─────────────── report ───────────────

/// Why the review should be looked at; resolves to (reason, note), or null.
Future<(ReportReason, String)?> showReportSheet(BuildContext context) =>
    _sheet<(ReportReason, String)>(context, const _ReportSheet());

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          Text('Report this review', style: AppType.serif(size: 22)),
          const SizedBox(height: 4),
          Text('Khojlo’s team will check it. The reviewer won’t know who reported it.',
              style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
          const SizedBox(height: 10),
          RadioGroup<ReportReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final reason in ReportReason.values)
                  RadioListTile<ReportReason>(
                    value: reason,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.emerald,
                    title: Text(reason.label, style: AppType.sans(size: 14)),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            style: AppType.sans(size: 14),
            decoration: _fieldDecoration('Anything else we should know? (optional)'),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Send report',
            tone: ButtonTone.ink,
            onTap: _reason == null
                ? null
                : () => Navigator.of(context).pop((_reason!, _note.text.trim())),
          ),
        ],
      ),
    );
  }
}

/// "Delete your review?" confirmation.
Future<bool> confirmDeleteReview(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      title: Text('Delete your review?', style: AppType.serif(size: 20)),
      content: Text('It will disappear from the business page, and its rating will update. '
          'You can write a new review later.',
          style: AppType.sans(size: 13.5, height: 1.45, color: AppColors.inkA(0.7))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: AppType.sans(weight: FontWeight.w700, color: AppColors.plum)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
