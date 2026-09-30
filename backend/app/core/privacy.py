"""The privacy policy users agree to.

The policy text lives in the app (`frontend/lib/features/legal/privacy_policy.dart`); the
server only records which version each user accepted. Bump the version (the date the
wording changed) in both places whenever the policy changes: every user is then asked to
agree again the next time they open the app.
"""

PRIVACY_POLICY_VERSION = "2026-09-30"
