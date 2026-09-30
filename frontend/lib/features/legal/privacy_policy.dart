/// Khojlo's privacy policy (SRS FR-26).
///
/// The server records which version each user agreed to. When the wording changes, bump
/// [kPrivacyPolicyVersion] here and `PRIVACY_POLICY_VERSION` in
/// `backend/app/core/privacy.py` together: everyone is then asked to agree again.
library;

const kPrivacyPolicyVersion = '2026-09-30';
const kPrivacyPolicyEffective = '30 September 2026';
const kPrivacyContactEmail = 'privacy@khojlo.app';

class PolicySection {
  const PolicySection(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
}

/// The short version shown on the consent screen.
const kPrivacyHighlights = <(String, String)>[
  ('Your account', 'Your name, email and anything you add to your profile.'),
  ('Your location', 'Only when you allow it, to show places near you. We never save it.'),
  ('Your messages', 'Stored so both sides of a chat can read them.'),
  ('Your control', 'Change your details, switch off notifications or delete your account '
      'at any time.'),
];

const kPrivacyPolicy = <PolicySection>[
  PolicySection('Who we are', [
    'Khojlo helps you discover new and hidden local businesses, and helps those businesses '
        'get found. This policy explains what we collect when you use Khojlo, why, who can '
        'see it and how to remove it.',
  ]),
  PolicySection('What we collect', [
    'Account details: your name, email address and password (stored only as a secure '
        'hash, never as plain text). If you sign in with Google we receive your name, email '
        'and Google account ID.',
    'Profile details you choose to add: phone number, profile photo and interests.',
    'Business details, if you list a business: its name, description, category, address, '
        'map pin, opening hours, prices, offers, contact details and photos.',
    'What you do in Khojlo: reviews and their photos, “helpful” votes, reports, saved '
        'lists, searches you submit (the words and filters, not where you were), and the '
        'business pages you open.',
    'Messages you send in chat, including photos.',
    'For notifications: a token that identifies this device to Firebase Cloud Messaging, '
        'and which kinds of notification you’ve turned off.',
  ]),
  PolicySection('Your location', [
    'Khojlo asks for your location only when you use a feature that needs it, such as '
        '“near me” results, distances or the map. It is sent with that request to find '
        'nearby places and is not saved to your account or search history.',
    'You can say no, or turn it off later in your device or browser settings. Khojlo still '
        'works; you can search by area or move the map instead.',
    'A business’s map pin is public, because that is how customers find it.',
  ]),
  PolicySection('How we use it', [
    'To run your account and sign you in, including emailing you one-time codes to verify '
        'your email or reset your password.',
    'To show you places, sort them by distance and personalise your feed from your '
        'interests and activity.',
    'To deliver messages and send the notifications you’ve left on.',
    'To show business owners how their listing is doing: they see view and save counts, '
        'never who viewed or saved it.',
    'To keep Khojlo safe: moderators review content that has been reported.',
    'We do not sell your data and we do not show advertising.',
  ]),
  PolicySection('Who can see it', [
    'Everyone: business listings, and reviews with the reviewer’s first name and initial.',
    'The other person in a chat: your messages, name and profile photo. Khojlo moderators '
        'can read a conversation only if one side reports it.',
    'Service providers who help us run Khojlo: Google (Sign-In, Maps and Firebase Cloud '
        'Messaging) and our email provider. They receive only what their part needs.',
  ]),
  PolicySection('How long we keep it', [
    'We keep your data while your account exists. You can clear your search history at any '
        'time from Explore.',
    'When you delete your account we permanently remove your profile, photos, businesses, '
        'reviews, votes, saved lists, conversations and messages (for both sides), '
        'notifications, devices and search history. Business view counts stay, without any '
        'link to you. This cannot be undone.',
  ]),
  PolicySection('Your choices', [
    'See and edit your profile from Account › Edit profile.',
    'Choose which notifications you get from Account › Notification settings, or block them '
        'in your device settings.',
    'Allow or block location in your device or browser settings.',
    'Delete your account from Account › Delete account.',
  ]),
  PolicySection('Security', [
    'Passwords are hashed with bcrypt, signed-in sessions use tokens that expire, and the '
        'released app talks to our server over HTTPS.',
  ]),
  PolicySection('Children', [
    'Khojlo is not meant for children under 13, and we don’t knowingly collect their data.',
  ]),
  PolicySection('Changes to this policy', [
    'If we change this policy we’ll ask you to read and agree to the new version the next '
        'time you open Khojlo.',
  ]),
  PolicySection('Contact', [
    'Questions or requests about your data: $kPrivacyContactEmail.',
  ]),
];
