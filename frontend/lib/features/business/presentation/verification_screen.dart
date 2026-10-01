import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/media/photo_source.dart';
import '../../../core/models/moderation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/email_verification_sheet.dart';
import '../business_providers.dart';
import '../data/business_repository.dart';

/// Module 8 — getting the Verified badge (SRS FR-14, UC-12; decision 1).
///
/// The listing is live already. Khojlo verifies it automatically once every check
/// passes, so no one has to wait for an admin: verify the email, complete the
/// listing, and take a photo of the shop front in the app.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key, required this.businessId});
  final int businessId;

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _uploading = false;
  bool _sending = false;
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
      ));
  }

  void _refresh() {
    ref.invalidate(verificationProvider(widget.businessId));
    ref.invalidate(myBusinessesProvider);
  }

  Future<void> _takeStorefront() async {
    final photo = await ref.read(photoSourceProvider).takePhoto();
    if (photo == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final uploaded =
          await ref.read(mediaRepositoryProvider).upload(photo.bytes, filename: photo.name);
      final info = await ref
          .read(businessRepositoryProvider)
          .setStorefront(widget.businessId, uploaded.key);
      _refresh();
      if (mounted) {
        _snack(info.isVerified
            ? 'You’re verified! Your listing now shows the badge.'
            : 'Storefront photo saved.');
      }
    } catch (e) {
      if (mounted) _snack(describeApiError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _requestReview() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(businessRepositoryProvider)
          .requestReview(widget.businessId, note: _reply.text.trim());
      _reply.clear();
      _refresh();
      if (mounted) _snack('Sent. Khojlo’s team will take another look.');
    } catch (e) {
      if (mounted) _snack(describeApiError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyEmail() async {
    await showEmailVerificationSheet(context);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(verificationProvider(widget.businessId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(children: [
        TopBar(title: 'Verification', subtitle: 'The Verified badge', onBack: () => context.pop()),
        Expanded(
          child: value.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(describeApiError(e),
                      textAlign: TextAlign.center,
                      style: AppType.sans(size: 13.5, color: AppColors.inkA(0.6))),
                  const SizedBox(height: 12),
                  GhostButton(label: 'Try again', expand: false, onTap: _refresh),
                ]),
              ),
            ),
            data: _body,
          ),
        ),
      ]),
    );
  }

  Widget _body(VerificationInfo v) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 48),
      children: [
        _StatusCard(info: v),
        if (v.note.isNotEmpty && !v.isVerified) ...[
          const SizedBox(height: 12),
          _Note(text: v.note),
        ],
        if (v.canRequestReview) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _reply,
            maxLength: 1000,
            maxLines: 3,
            minLines: 1,
            style: AppType.sans(size: 14),
            decoration: InputDecoration(
              hintText: 'Tell Khojlo what you changed (optional)',
              hintStyle: AppType.sans(size: 13.5, color: AppColors.inkA(0.4)),
              filled: true,
              fillColor: AppColors.whiteA(0.8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          PrimaryButton(
            label: 'Ask Khojlo to look again',
            loading: _sending,
            onTap: v.storefront == null ? null : _requestReview,
          ),
          if (v.storefront == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Take a storefront photo first.',
                  style: AppType.sans(size: 12, color: AppColors.inkA(0.55))),
            ),
        ],
        if (!v.isVerified && !v.isSuspended) ...[
          const SizedBox(height: 22),
          Text('THE CHECKS · ${v.passedCount} OF ${v.checks.length} DONE', style: AppType.label()),
          const SizedBox(height: 10),
          for (final c in v.checks) _CheckRow(check: c, action: _actionFor(c, v)),
        ],
        const SizedBox(height: 22),
        Text('STOREFRONT PHOTO', style: AppType.label()),
        const SizedBox(height: 6),
        Text('Stand outside and take a photo of your shop front or signboard, with the name '
            'showing. Only you and Khojlo’s team can see it.',
            style: AppType.sans(size: 12.5, height: 1.45, color: AppColors.inkA(0.6))),
        const SizedBox(height: 10),
        if (v.storefront != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ImageTile(tone: 'ink', radius: 18, height: 200, photo: v.storefront),
          ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: v.storefront == null ? 'Take storefront photo' : 'Retake photo',
          icon: Icons.photo_camera_outlined,
          tone: v.storefront == null ? ButtonTone.emerald : ButtonTone.ink,
          loading: _uploading,
          onTap: v.isSuspended ? null : _takeStorefront,
        ),
        const SizedBox(height: 18),
        Text('Changing your business’s name or location later needs a new storefront photo.',
            style: AppType.sans(size: 12, color: AppColors.inkA(0.5))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.push('/guidelines'),
          child: Text('Read the Community Guidelines',
              style: AppType.sans(size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
        ),
      ],
    );
  }

  /// The next step for a check that hasn't passed.
  Widget? _actionFor(VerificationCheck c, VerificationInfo v) {
    if (c.passed) return null;
    return switch (c.key) {
      'email' => GhostButton(label: 'Verify email', small: true, expand: false, onTap: _verifyEmail),
      'profile' => GhostButton(
          label: 'Edit listing',
          small: true,
          expand: false,
          onTap: () async {
            await context.push('/edit-business/${widget.businessId}');
            _refresh();
          }),
      'storefront' => GhostButton(
          label: 'Take photo', small: true, expand: false, onTap: _uploading ? null : _takeStorefront),
      _ => null,
    };
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.info});
  final VerificationInfo info;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, body) = info.isSuspended
        ? (
            AppColors.plum,
            Icons.block_rounded,
            'Suspended by Khojlo',
            'Your listing is hidden${info.suspensionReason != null ? ' (${info.suspensionReason!.toLowerCase()})' : ''}. '
                'It stays hidden until Khojlo’s team reinstates it.',
          )
        : switch (info.status) {
            VerificationStatus.verified => (
                AppColors.emerald,
                Icons.verified_rounded,
                'You’re verified',
                'Customers see the Verified badge on your listing.',
              ),
            VerificationStatus.pendingReview => (
                const Color(0xFF8A5B15),
                Icons.hourglass_top_rounded,
                'Khojlo’s team is reviewing your listing',
                'Your checks are done. Someone will look at it soon; you don’t need to do '
                    'anything.',
              ),
            VerificationStatus.needsInfo => (
                const Color(0xFF8A5B15),
                Icons.mark_email_unread_outlined,
                'Khojlo needs a little more',
                'Read the message below, make the change, then ask for another look.',
              ),
            VerificationStatus.rejected => (
                AppColors.plum,
                Icons.info_outline_rounded,
                'Not verified',
                'Your listing is still live, without the badge. Fix what’s below and ask '
                    'Khojlo to look again.',
              ),
            VerificationStatus.unverified => (
                AppColors.ink,
                Icons.shield_outlined,
                'Get the Verified badge',
                'Your listing is live already. Finish the checks and Khojlo verifies it '
                    'automatically — no waiting for approval.',
              ),
          };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.14),
          color.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppType.serif(size: 20, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(body, style: AppType.sans(size: 13, height: 1.45, color: AppColors.inkA(0.7))),
          ]),
        ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FROM KHOJLO’S TEAM', style: AppType.label()),
        const SizedBox(height: 6),
        Text(text, style: AppType.sans(size: 14, height: 1.45)),
      ]),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, this.action});
  final VerificationCheck check;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkA(0.06)),
      ),
      child: Row(children: [
        Icon(check.passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: check.passed ? AppColors.emerald : AppColors.inkA(0.3)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(check.label, style: AppType.sans(size: 14, weight: FontWeight.w700)),
            if (!check.passed && check.hint.isNotEmpty)
              Text(check.hint, style: AppType.sans(size: 12.5, color: AppColors.inkA(0.6))),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ]),
    );
  }
}
