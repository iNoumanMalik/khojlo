// Module 8 — admin and moderation, mirroring backend/app/schemas/admin.py and
// backend/app/schemas/moderation.py.

import 'photo.dart';
import 'user.dart';

DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    (v as List?)?.map((e) => f(e as Map<String, dynamic>)).toList() ?? <T>[];

/// Why content or an account was acted on. Each is a section of the Community
/// Guidelines (BR-10), so every notice can point to the rule that was broken.
enum ModerationReason {
  spam('spam', 'Spam or advertising',
      'Adverts, links, phone numbers or repeated messages that have nothing to do with the business.'),
  scam('scam', 'Scam or fraud',
      'Asking for money in advance, fake prizes, pretending to be Khojlo, or deals that don’t exist.'),
  adult('adult', 'Adult or sexual content',
      'Sexual services, nudity or explicit material, in words or photos.'),
  prohibited('prohibited', 'Prohibited items or services',
      'Drugs, alcohol, weapons without a licence, fake documents, or anything else illegal to sell.'),
  harassment('harassment', 'Harassment, hate or threats',
      'Insults, abusive language, threats, or attacks on someone’s religion, ethnicity or gender.'),
  fake('fake', 'Fake or misleading information',
      'Reviews of places you haven’t visited, businesses that don’t exist, or copies of other listings.'),
  other('other', 'Something else', 'Anything else that breaks these guidelines.');

  const ModerationReason(this.api, this.label, this.description);
  final String api;
  final String label;
  final String description;

  static ModerationReason fromApi(String? s) =>
      values.firstWhere((r) => r.api == s, orElse: () => other);
}

/// Why a user is reporting a business listing.
enum BusinessReportReason {
  scam('scam', 'A scam or fraud'),
  prohibited('prohibited', 'Adult content or prohibited items'),
  fake('fake', 'Not a real business'),
  wrongInfo('wrong_info', 'Wrong information'),
  offensive('offensive', 'Offensive content'),
  other('other', 'Something else');

  const BusinessReportReason(this.api, this.label);
  final String api;
  final String label;
}

/// Where a business is in verification (SRS FR-14, UC-12).
enum VerificationStatus {
  unverified('unverified', 'Not verified yet'),
  pendingReview('pending_review', 'Being reviewed'),
  needsInfo('needs_info', 'More information needed'),
  verified('verified', 'Verified'),
  rejected('rejected', 'Not verified');

  const VerificationStatus(this.api, this.label);
  final String api;
  final String label;

  static VerificationStatus fromApi(String? s) =>
      values.firstWhere((v) => v.api == s, orElse: () => unverified);
}

class VerificationCheck {
  const VerificationCheck(
      {required this.key, required this.label, required this.passed, this.hint = ''});

  /// email | profile | storefront | record
  final String key;
  final String label;
  final bool passed;

  /// What to do next when it hasn't passed.
  final String hint;

  factory VerificationCheck.fromJson(Map<String, dynamic> j) => VerificationCheck(
        key: j['key'] as String,
        label: j['label'] as String? ?? '',
        passed: j['passed'] as bool? ?? false,
        hint: j['hint'] as String? ?? '',
      );
}

/// The owner's verification checklist for one business.
class VerificationInfo {
  const VerificationInfo({
    required this.businessId,
    required this.status,
    required this.isVerified,
    required this.checks,
    this.storefront,
    this.storefrontAt,
    this.note = '',
    this.verifiedAt,
    this.canRequestReview = false,
    this.isSuspended = false,
    this.suspensionReason,
  });

  final int businessId;
  final VerificationStatus status;
  final bool isVerified;
  final List<VerificationCheck> checks;
  final Photo? storefront;
  final DateTime? storefrontAt;

  /// The admin's message when they rejected it or asked for more.
  final String note;
  final DateTime? verifiedAt;
  final bool canRequestReview;
  final bool isSuspended;
  final String? suspensionReason;

  int get passedCount => checks.where((c) => c.passed).length;

  factory VerificationInfo.fromJson(Map<String, dynamic> j) => VerificationInfo(
        businessId: j['business_id'] as int,
        status: VerificationStatus.fromApi(j['status'] as String?),
        isVerified: j['is_verified'] as bool? ?? false,
        checks: _list(j['checks'], VerificationCheck.fromJson),
        storefront: Photo.maybe(j['storefront']),
        storefrontAt: _date(j['storefront_at']),
        note: j['note'] as String? ?? '',
        verifiedAt: _date(j['verified_at']),
        canRequestReview: j['can_request_review'] as bool? ?? false,
        isSuspended: j['is_suspended'] as bool? ?? false,
        suspensionReason: j['suspension_reason'] as String?,
      );
}

// ─────────────── the admin panel ───────────────

enum AccountStatus {
  active,
  suspended,
  banned;

  static AccountStatus fromApi(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => active);
}

class AdminPerson {
  const AdminPerson({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.initials,
    required this.tone,
    required this.emailVerified,
    required this.status,
    required this.createdAt,
    this.avatar,
    this.suspendedUntil,
    this.suspensionReason,
  });

  final int id;
  final String fullName;
  final String email;
  final UserRole role;
  final String initials;
  final String tone;
  final Photo? avatar;
  final bool emailVerified;
  final AccountStatus status;
  final DateTime? suspendedUntil;
  final String? suspensionReason;
  final DateTime createdAt;

  String get roleLabel => switch (role) {
        UserRole.businessOwner => 'Business owner',
        UserRole.admin => 'Admin',
        UserRole.customer => 'Customer',
      };

  factory AdminPerson.fromJson(Map<String, dynamic> j) => AdminPerson(
        id: j['id'] as int,
        fullName: j['full_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: roleFromString(j['role'] as String? ?? 'customer'),
        initials: j['initials'] as String? ?? '?',
        tone: j['tone'] as String? ?? 'gold',
        avatar: Photo.maybe(j['avatar']),
        emailVerified: j['email_verified'] as bool? ?? false,
        status: AccountStatus.fromApi(j['status'] as String?),
        suspendedUntil: _date(j['suspended_until']),
        suspensionReason: j['suspension_reason'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AdminUserRow extends AdminPerson {
  const AdminUserRow({
    required super.id,
    required super.fullName,
    required super.email,
    required super.role,
    required super.initials,
    required super.tone,
    required super.emailVerified,
    required super.status,
    required super.createdAt,
    super.avatar,
    super.suspendedUntil,
    super.suspensionReason,
    this.businesses = 0,
    this.reviews = 0,
    this.reportsAgainst = 0,
    this.openFlags = 0,
    this.warnings = 0,
  });

  final int businesses;
  final int reviews;
  final int reportsAgainst;
  final int openFlags;
  final int warnings;

  factory AdminUserRow.fromJson(Map<String, dynamic> j) {
    final p = AdminPerson.fromJson(j);
    return AdminUserRow(
      id: p.id,
      fullName: p.fullName,
      email: p.email,
      role: p.role,
      initials: p.initials,
      tone: p.tone,
      avatar: p.avatar,
      emailVerified: p.emailVerified,
      status: p.status,
      suspendedUntil: p.suspendedUntil,
      suspensionReason: p.suspensionReason,
      createdAt: p.createdAt,
      businesses: j['businesses'] as int? ?? 0,
      reviews: j['reviews'] as int? ?? 0,
      reportsAgainst: j['reports_against'] as int? ?? 0,
      openFlags: j['open_flags'] as int? ?? 0,
      warnings: j['warnings'] as int? ?? 0,
    );
  }
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.row,
    this.phone,
    this.removedReviews = 0,
    this.owned = const [],
    this.flags = const [],
    this.history = const [],
  });

  final AdminUserRow row;
  final String? phone;
  final int removedReviews;
  final List<AdminBusinessBrief> owned;
  final List<AdminFlag> flags;
  final List<AdminAction> history;

  factory AdminUserDetail.fromJson(Map<String, dynamic> j) => AdminUserDetail(
        row: AdminUserRow.fromJson(j),
        phone: j['phone'] as String?,
        removedReviews: j['removed_reviews'] as int? ?? 0,
        owned: _list(j['owned'], AdminBusinessBrief.fromJson),
        flags: _list(j['flags'], AdminFlag.fromJson),
        history: _list(j['history'], AdminAction.fromJson),
      );
}

class AdminBusinessBrief {
  const AdminBusinessBrief({
    required this.id,
    required this.name,
    required this.tone,
    required this.ownerId,
    required this.ownerName,
    required this.verificationStatus,
    required this.isVerified,
    required this.isPublished,
    required this.isSuspended,
    required this.createdAt,
    this.cover,
    this.categoryLabel,
    this.address = '',
    this.suspensionReason,
    this.rating = 0,
    this.reviewCount = 0,
    this.verifiedAt,
    this.autoVerified = false,
    this.storefront,
    this.openReports = 0,
    this.openFlags = 0,
  });

  final int id;
  final String name;
  final String tone;
  final Photo? cover;
  final String? categoryLabel;
  final String address;
  final int ownerId;
  final String ownerName;
  final VerificationStatus verificationStatus;
  final bool isVerified;
  final bool isPublished;
  final bool isSuspended;
  final String? suspensionReason;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime? verifiedAt;

  /// Verified by the automatic checks rather than an admin.
  final bool autoVerified;
  final Photo? storefront;

  /// Only in lists and the detail (0 elsewhere).
  final int openReports;
  final int openFlags;

  factory AdminBusinessBrief.fromJson(Map<String, dynamic> j) => AdminBusinessBrief(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        tone: j['tone'] as String? ?? 'gold',
        cover: Photo.maybe(j['cover']),
        categoryLabel: j['category_label'] as String?,
        address: j['address'] as String? ?? '',
        ownerId: j['owner_id'] as int? ?? 0,
        ownerName: j['owner_name'] as String? ?? '',
        verificationStatus: VerificationStatus.fromApi(j['verification_status'] as String?),
        isVerified: j['is_verified'] as bool? ?? false,
        isPublished: j['is_published'] as bool? ?? true,
        isSuspended: j['is_suspended'] as bool? ?? false,
        suspensionReason: j['suspension_reason'] as String?,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: j['review_count'] as int? ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
        verifiedAt: _date(j['verified_at']),
        autoVerified: j['auto_verified'] as bool? ?? false,
        storefront: Photo.maybe(j['storefront']),
        openReports: j['open_reports'] as int? ?? 0,
        openFlags: j['open_flags'] as int? ?? 0,
      );
}

class AdminBusinessDetail {
  const AdminBusinessDetail({
    required this.brief,
    required this.owner,
    this.description = '',
    this.tagline = '',
    this.phone,
    this.photos = const [],
    this.storefrontAt,
    this.verificationNote = '',
    this.verifiedBy,
    this.ownerNote,
    this.checks = const [],
    this.flags = const [],
    this.reports = const [],
    this.history = const [],
  });

  final AdminBusinessBrief brief;
  final AdminPerson owner;
  final String description;
  final String tagline;
  final String? phone;
  final List<Photo> photos;
  final DateTime? storefrontAt;
  final String verificationNote;
  final String? verifiedBy;
  final String? ownerNote;
  final List<VerificationCheck> checks;
  final List<AdminFlag> flags;
  final List<ReportEntry> reports;
  final List<AdminAction> history;

  factory AdminBusinessDetail.fromJson(Map<String, dynamic> j) => AdminBusinessDetail(
        brief: AdminBusinessBrief.fromJson(j),
        owner: AdminPerson.fromJson(j['owner'] as Map<String, dynamic>),
        description: j['description'] as String? ?? '',
        tagline: j['tagline'] as String? ?? '',
        phone: j['phone'] as String?,
        photos: _list(j['photos'], Photo.fromJson),
        storefrontAt: _date(j['storefront_at']),
        verificationNote: j['verification_note'] as String? ?? '',
        verifiedBy: j['verified_by'] as String?,
        ownerNote: j['owner_note'] as String?,
        checks: _list(j['checks'], VerificationCheck.fromJson),
        flags: _list(j['flags'], AdminFlag.fromJson),
        reports: _list(j['reports'], ReportEntry.fromJson),
        history: _list(j['history'], AdminAction.fromJson),
      );
}

class AdminAction {
  const AdminAction({
    required this.id,
    required this.action,
    required this.label,
    required this.by,
    required this.automatic,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    this.targetTitle,
    this.subjectUserId,
    this.subjectName,
    this.reasonLabel,
    this.note = '',
  });

  final int id;
  final String action;
  final String label;
  final String by;
  final bool automatic;
  final String targetType;
  final int targetId;
  final String? targetTitle;
  final int? subjectUserId;
  final String? subjectName;
  final String? reasonLabel;
  final String note;
  final DateTime createdAt;

  factory AdminAction.fromJson(Map<String, dynamic> j) => AdminAction(
        id: j['id'] as int,
        action: j['action'] as String? ?? '',
        label: j['label'] as String? ?? '',
        by: j['by'] as String? ?? '',
        automatic: j['automatic'] as bool? ?? false,
        targetType: j['target_type'] as String? ?? '',
        targetId: j['target_id'] as int? ?? 0,
        targetTitle: j['target_title'] as String?,
        subjectUserId: j['subject_user_id'] as int?,
        subjectName: j['subject_name'] as String?,
        reasonLabel: j['reason_label'] as String?,
        note: j['note'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AdminFlag {
  const AdminFlag({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.rule,
    required this.label,
    required this.detail,
    required this.status,
    required this.createdAt,
    this.businessId,
    this.userId,
    this.userName,
    this.excerpt = '',
  });

  final int id;

  /// business | review | offer | campaign | user
  final String targetType;
  final int targetId;
  final String targetTitle;
  final int? businessId;
  final int? userId;
  final String? userName;
  final String rule;

  /// spam | scam | adult | offensive | prohibited | fake_reviews | duplicate
  final String label;
  final String detail;
  final String excerpt;

  /// open | actioned | dismissed | cleared
  final String status;
  final DateTime createdAt;

  bool get isOpen => status == 'open';

  String get labelText => switch (label) {
        'fake_reviews' => 'Fake reviews',
        'duplicate' => 'Duplicate listing',
        'adult' => 'Adult content',
        'prohibited' => 'Prohibited items',
        _ => label.isEmpty ? '' : '${label[0].toUpperCase()}${label.substring(1)}',
      };

  /// What upholding does to the content (none for account flags).
  String get upholdLabel => switch (targetType) {
        'review' => 'Remove review',
        'offer' => 'Switch off offer',
        'campaign' => 'Unpublish campaign',
        'business' => 'Suspend business',
        _ => 'Confirm',
      };

  factory AdminFlag.fromJson(Map<String, dynamic> j) => AdminFlag(
        id: j['id'] as int,
        targetType: j['target_type'] as String? ?? '',
        targetId: j['target_id'] as int? ?? 0,
        targetTitle: j['target_title'] as String? ?? '',
        businessId: j['business_id'] as int?,
        userId: j['user_id'] as int?,
        userName: j['user_name'] as String?,
        rule: j['rule'] as String? ?? '',
        label: j['label'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        excerpt: j['excerpt'] as String? ?? '',
        status: j['status'] as String? ?? 'open',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// What kind of thing was reported.
enum ReportKind {
  review('review', 'Review', 'Remove review'),
  conversation('conversation', 'Conversation', 'Close conversation'),
  business('business', 'Business', 'Suspend business');

  const ReportKind(this.api, this.label, this.upholdLabel);
  final String api;
  final String label;
  final String upholdLabel;

  static ReportKind fromApi(String? s) =>
      values.firstWhere((k) => k.api == s, orElse: () => review);
}

class ReportEntry {
  const ReportEntry({
    required this.id,
    required this.reason,
    required this.reasonLabel,
    required this.reporterId,
    required this.reporterName,
    required this.status,
    required this.createdAt,
    this.note = '',
  });

  final int id;
  final String reason;
  final String reasonLabel;
  final String note;
  final int reporterId;
  final String reporterName;
  final String status;
  final DateTime createdAt;

  factory ReportEntry.fromJson(Map<String, dynamic> j) => ReportEntry(
        id: j['id'] as int,
        reason: j['reason'] as String? ?? '',
        reasonLabel: j['reason_label'] as String? ?? '',
        note: j['note'] as String? ?? '',
        reporterId: j['reporter_id'] as int? ?? 0,
        reporterName: j['reporter_name'] as String? ?? '',
        status: j['status'] as String? ?? 'open',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Everything reported about one review, conversation or business.
class ReportItem {
  const ReportItem({
    required this.kind,
    required this.targetId,
    required this.title,
    required this.reportCount,
    required this.reasons,
    required this.firstAt,
    required this.latestAt,
    required this.open,
    this.snippet = '',
    this.businessId,
  });

  final ReportKind kind;
  final int targetId;
  final String title;
  final String snippet;
  final int reportCount;

  /// Reason label → how many reports gave it.
  final Map<String, int> reasons;
  final DateTime firstAt;
  final DateTime latestAt;
  final bool open;
  final int? businessId;

  factory ReportItem.fromJson(Map<String, dynamic> j) => ReportItem(
        kind: ReportKind.fromApi(j['kind'] as String?),
        targetId: j['target_id'] as int,
        title: j['title'] as String? ?? '',
        snippet: j['snippet'] as String? ?? '',
        reportCount: j['report_count'] as int? ?? 0,
        reasons: ((j['reasons'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        firstAt: DateTime.parse(j['first_at'] as String),
        latestAt: DateTime.parse(j['latest_at'] as String),
        open: j['open'] as bool? ?? true,
        businessId: j['business_id'] as int?,
      );
}

class AdminReview {
  const AdminReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.isVisible,
    required this.author,
    required this.business,
    this.photos = const [],
  });

  final int id;
  final int rating;
  final String comment;
  final List<Photo> photos;
  final DateTime createdAt;
  final bool isVisible;
  final AdminPerson author;
  final AdminBusinessBrief business;

  factory AdminReview.fromJson(Map<String, dynamic> j) => AdminReview(
        id: j['id'] as int,
        rating: j['rating'] as int? ?? 0,
        comment: j['comment'] as String? ?? '',
        photos: _list(j['photos'], Photo.fromJson),
        createdAt: DateTime.parse(j['created_at'] as String),
        isVisible: j['is_visible'] as bool? ?? true,
        author: AdminPerson.fromJson(j['author'] as Map<String, dynamic>),
        business: AdminBusinessBrief.fromJson(j['business'] as Map<String, dynamic>),
      );
}

class AdminMessage {
  const AdminMessage(
      {required this.id, required this.fromBusiness, required this.body, required this.createdAt, this.photo});

  final int id;
  final bool fromBusiness;
  final String body;
  final Photo? photo;
  final DateTime createdAt;

  factory AdminMessage.fromJson(Map<String, dynamic> j) => AdminMessage(
        id: j['id'] as int,
        fromBusiness: j['side'] == 'business',
        body: j['body'] as String? ?? '',
        photo: Photo.maybe(j['photo']),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AdminConversation {
  const AdminConversation({
    required this.id,
    required this.business,
    required this.customer,
    required this.owner,
    required this.messages,
    this.closed = false,
    this.blockedBy,
  });

  final int id;
  final AdminBusinessBrief business;
  final AdminPerson customer;
  final AdminPerson owner;
  final List<AdminMessage> messages;
  final bool closed;
  final String? blockedBy;

  factory AdminConversation.fromJson(Map<String, dynamic> j) => AdminConversation(
        id: j['id'] as int,
        business: AdminBusinessBrief.fromJson(j['business'] as Map<String, dynamic>),
        customer: AdminPerson.fromJson(j['customer'] as Map<String, dynamic>),
        owner: AdminPerson.fromJson(j['owner'] as Map<String, dynamic>),
        messages: _list(j['messages'], AdminMessage.fromJson),
        closed: j['closed'] as bool? ?? false,
        blockedBy: j['blocked_by'] as String?,
      );
}

class ReportDetail {
  const ReportDetail({
    required this.kind,
    required this.targetId,
    required this.title,
    required this.open,
    required this.reports,
    this.review,
    this.conversation,
    this.business,
    this.accounts = const [],
    this.flags = const [],
    this.history = const [],
  });

  final ReportKind kind;
  final int targetId;
  final String title;
  final bool open;
  final List<ReportEntry> reports;
  final AdminReview? review;
  final AdminConversation? conversation;
  final AdminBusinessBrief? business;

  /// Accounts an action could apply to, the most likely one first.
  final List<AdminPerson> accounts;
  final List<AdminFlag> flags;
  final List<AdminAction> history;

  factory ReportDetail.fromJson(Map<String, dynamic> j) => ReportDetail(
        kind: ReportKind.fromApi(j['kind'] as String?),
        targetId: j['target_id'] as int,
        title: j['title'] as String? ?? '',
        open: j['open'] as bool? ?? false,
        reports: _list(j['reports'], ReportEntry.fromJson),
        review: j['review'] == null
            ? null
            : AdminReview.fromJson(j['review'] as Map<String, dynamic>),
        conversation: j['conversation'] == null
            ? null
            : AdminConversation.fromJson(j['conversation'] as Map<String, dynamic>),
        business: j['business'] == null
            ? null
            : AdminBusinessBrief.fromJson(j['business'] as Map<String, dynamic>),
        accounts: _list(j['accounts'], AdminPerson.fromJson),
        flags: _list(j['flags'], AdminFlag.fromJson),
        history: _list(j['history'], AdminAction.fromJson),
      );
}

class DayCount {
  const DayCount(
      {required this.label, this.users = 0, this.businesses = 0, this.reports = 0, this.flags = 0});

  final String label;
  final int users;
  final int businesses;
  final int reports;
  final int flags;

  factory DayCount.fromJson(Map<String, dynamic> j) => DayCount(
        label: j['label'] as String? ?? '',
        users: j['users'] as int? ?? 0,
        businesses: j['businesses'] as int? ?? 0,
        reports: j['reports'] as int? ?? 0,
        flags: j['flags'] as int? ?? 0,
      );
}

class AdminOverview {
  const AdminOverview({
    this.pendingReview = 0,
    this.needsInfo = 0,
    this.openReports = 0,
    this.openReviewReports = 0,
    this.openConversationReports = 0,
    this.openBusinessReports = 0,
    this.openFlags = 0,
    this.suspendedAccounts = 0,
    this.bannedAccounts = 0,
    this.suspendedBusinesses = 0,
    this.usersTotal = 0,
    this.businessesTotal = 0,
    this.verifiedTotal = 0,
    this.newUsersToday = 0,
    this.newBusinessesToday = 0,
    this.reviewsToday = 0,
    this.messagesToday = 0,
    this.autoVerifiedWeek = 0,
    this.daily = const [],
    this.recent = const [],
  });

  final int pendingReview;
  final int needsInfo;
  final int openReports;
  final int openReviewReports;
  final int openConversationReports;
  final int openBusinessReports;
  final int openFlags;
  final int suspendedAccounts;
  final int bannedAccounts;
  final int suspendedBusinesses;
  final int usersTotal;
  final int businessesTotal;
  final int verifiedTotal;
  final int newUsersToday;
  final int newBusinessesToday;
  final int reviewsToday;
  final int messagesToday;
  final int autoVerifiedWeek;
  final List<DayCount> daily;
  final List<AdminAction> recent;

  factory AdminOverview.fromJson(Map<String, dynamic> j) {
    int n(String k) => j[k] as int? ?? 0;
    return AdminOverview(
      pendingReview: n('pending_review'),
      needsInfo: n('needs_info'),
      openReports: n('open_reports'),
      openReviewReports: n('open_review_reports'),
      openConversationReports: n('open_conversation_reports'),
      openBusinessReports: n('open_business_reports'),
      openFlags: n('open_flags'),
      suspendedAccounts: n('suspended_accounts'),
      bannedAccounts: n('banned_accounts'),
      suspendedBusinesses: n('suspended_businesses'),
      usersTotal: n('users_total'),
      businessesTotal: n('businesses_total'),
      verifiedTotal: n('verified_total'),
      newUsersToday: n('new_users_today'),
      newBusinessesToday: n('new_businesses_today'),
      reviewsToday: n('reviews_today'),
      messagesToday: n('messages_today'),
      autoVerifiedWeek: n('auto_verified_week'),
      daily: _list(j['daily'], DayCount.fromJson),
      recent: _list(j['recent'], AdminAction.fromJson),
    );
  }
}

/// One page of a list, plus how many there are in total.
class Paged<T> {
  const Paged({required this.items, required this.total});
  final List<T> items;
  final int total;

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) =>
      Paged(items: _list(j['items'], item), total: j['total'] as int? ?? 0);
}

/// An admin's decision on a report or flag (SDD Algorithm 10), with an optional
/// follow-up on the account behind the content.
class Resolution {
  const Resolution({
    required this.uphold,
    this.reason = ModerationReason.other,
    this.note = '',
    this.accountAction = 'none',
    this.accountUserId,
    this.suspendDays = 7,
    this.hideReviews = false,
  });

  final bool uphold;
  final ModerationReason reason;
  final String note;

  /// none | warn | suspend | ban
  final String accountAction;
  final int? accountUserId;
  final int suspendDays;
  final bool hideReviews;

  Map<String, dynamic> toJson() => {
        'decision': uphold ? 'uphold' : 'dismiss',
        'reason': reason.api,
        'note': note,
        'account_action': accountAction,
        if (accountUserId != null) 'account_user_id': accountUserId,
        'suspend_days': suspendDays,
        'hide_reviews': hideReviews,
      };
}
