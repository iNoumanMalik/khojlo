/// Config for Google Sign-In. The web client ID is not a secret — it's the
/// audience the backend checks Google ID tokens against, and what Android
/// needs to actually receive an ID token (not just an access token).
class GoogleAuthConfig {
  GoogleAuthConfig._();

  /// The "Web client (auto created by Google Service)" OAuth client ID
  /// (client_type 3) from google-services.json.
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '156196820923-pq71ltadr7ime89pgv581hkdm7b9194o.apps.googleusercontent.com',
  );
}
