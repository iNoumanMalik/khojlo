import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/review.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../reviews_providers.dart';
import 'review_sheets.dart';
import 'widgets/confetti.dart';

void showReviewSnack(BuildContext context, String message) {
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

/// Write (or edit) a review: the form, then confetti and a confirmation (SDD §8).
Future<void> openWriteReview(
  BuildContext context, {
  required int businessId,
  required String businessName,
  Review? existing,
}) async {
  final saved = await showWriteReviewSheet(context,
      businessId: businessId, businessName: businessName, existing: existing);
  if (saved == null || !context.mounted) return;
  if (existing == null) {
    showConfetti(context);
    showReviewSnack(context, 'Thanks! Your review of $businessName is live.');
  } else {
    showReviewSnack(context, 'Your review was updated.');
  }
}

Future<void> deleteMyReview(BuildContext context, WidgetRef ref, Review review) async {
  if (!await confirmDeleteReview(context)) return;
  try {
    await ref.read(reviewActionsProvider).delete(review);
    if (context.mounted) showReviewSnack(context, 'Your review was deleted.');
  } catch (e) {
    if (context.mounted) showReviewSnack(context, describeApiError(e));
  }
}
