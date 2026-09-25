import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// Google's own sign-in button. On web, sign-in can only be started from this
/// button; the result arrives on `GoogleSignIn.instance.authenticationEvents`.
Widget googleWebSignInButton({required double width}) => gsi.renderButton(
      configuration: gsi.GSIButtonConfiguration(
        theme: gsi.GSIButtonTheme.outline,
        size: gsi.GSIButtonSize.large,
        text: gsi.GSIButtonText.continueWith,
        shape: gsi.GSIButtonShape.pill,
        // Google caps the button at 400px wide.
        minimumWidth: width.clamp(200, 400).toDouble(),
      ),
    );
