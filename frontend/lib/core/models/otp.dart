/// Response from an OTP-send endpoint (email verification / password reset).
class OtpSentInfo {
  const OtpSentInfo({required this.expiresInMinutes, required this.resendCooldownSeconds});

  final int expiresInMinutes;
  final int resendCooldownSeconds;

  factory OtpSentInfo.fromJson(Map<String, dynamic> j) => OtpSentInfo(
        expiresInMinutes: j['expires_in_minutes'] as int,
        resendCooldownSeconds: j['resend_cooldown_seconds'] as int,
      );
}

/// Short-lived token returned after a password-reset OTP is verified, used to
/// authorize the final "set new password" call.
class ResetTokenInfo {
  const ResetTokenInfo({required this.token, required this.expiresInMinutes});

  final String token;
  final int expiresInMinutes;

  factory ResetTokenInfo.fromJson(Map<String, dynamic> j) => ResetTokenInfo(
        token: j['reset_token'] as String,
        expiresInMinutes: j['expires_in_minutes'] as int,
      );
}
