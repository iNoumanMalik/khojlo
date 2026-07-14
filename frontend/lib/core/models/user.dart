enum UserRole { customer, businessOwner, admin }

UserRole roleFromString(String s) => switch (s) {
      'business_owner' => UserRole.businessOwner,
      'admin' => UserRole.admin,
      _ => UserRole.customer,
    };

String roleToString(UserRole r) => switch (r) {
      UserRole.businessOwner => 'business_owner',
      UserRole.admin => 'admin',
      UserRole.customer => 'customer',
    };

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.avatarTone,
    required this.initials,
    required this.interests,
  });

  final int id;
  final String email;
  final String fullName;
  final UserRole role;
  final String avatarTone;
  final String initials;
  final List<String> interests;

  bool get isOwner => role == UserRole.businessOwner || role == UserRole.admin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        email: j['email'] as String,
        fullName: j['full_name'] as String,
        role: roleFromString(j['role'] as String),
        avatarTone: j['avatar_tone'] as String? ?? 'gold',
        initials: j['initials'] as String? ?? '?',
        interests: (j['interests'] as List?)?.cast<String>() ?? const [],
      );
}
