import 'package:flutter/widgets.dart';

/// Google's rendered sign-in button only exists on web (see
/// google_web_button_web.dart); mobile uses a GhostButton and
/// `GoogleSignIn.authenticate()` instead, so this is never shown.
Widget googleWebSignInButton({required double width}) => const SizedBox.shrink();
