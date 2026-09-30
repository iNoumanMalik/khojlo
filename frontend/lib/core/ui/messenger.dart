import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The app's root ScaffoldMessenger, for banners raised outside a screen
/// (e.g. a push notification that arrives while the app is open).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// The router's root Navigator, for dialogs raised outside a screen (e.g. explaining
/// why Khojlo wants location before the system asks).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// A floating ink banner with an optional "Open" action.
void showInAppBanner(String title, String body, {VoidCallback? onOpen}) {
  rootMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      backgroundColor: AppColors.ink,
      duration: const Duration(seconds: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.sans(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
          if (body.isNotEmpty)
            Text(body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 12.5, color: AppColors.whiteA(0.8))),
        ],
      ),
      action: onOpen == null
          ? null
          : SnackBarAction(label: 'Open', textColor: AppColors.gold, onPressed: onOpen),
    ));
}
