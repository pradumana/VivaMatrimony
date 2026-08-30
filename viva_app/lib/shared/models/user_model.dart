class UserModel {
  final String userId;
  final String phoneNormalized;
  final String accountStatus;
  final bool onboardingCompleted;
  final String maskedPhone;

  const UserModel({
    required this.userId,
    required this.phoneNormalized,
    required this.accountStatus,
    required this.onboardingCompleted,
    required this.maskedPhone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        userId: json['user_id'] as String,
        phoneNormalized: json['phone_normalized'] as String? ?? '',
        accountStatus: json['account_status'] as String? ?? 'active',
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
        maskedPhone: json['masked_phone'] as String? ?? '',
      );
}

class ProfileSummary {
  final String userId;
  final String fullName;
  final int age;
  final String? location;
  final String? photoUrl;
  final String? qualification;
  final String? profession;
  final bool isVerified;
  final int? compatibilityScore;

  const ProfileSummary({
    required this.userId,
    required this.fullName,
    required this.age,
    this.location,
    this.photoUrl,
    this.qualification,
    this.profession,
    this.isVerified = false,
    this.compatibilityScore,
  });

  factory ProfileSummary.fromJson(Map<String, dynamic> json) => ProfileSummary(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        age: json['age'] as int,
        location: json['location'] as String?,
        photoUrl: json['primary_photo_url'] as String?,
        qualification: json['highest_qualification'] as String?,
        profession: json['profession'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        compatibilityScore: json['compatibility_score'] as int?,
      );
}

class InterestModel {
  final String interestId;
  final String userId;
  final String fullName;
  final int? age;
  final String? location;
  final String? photoUrl;
  final String status;
  final DateTime? sentAt;

  const InterestModel({
    required this.interestId,
    required this.userId,
    required this.fullName,
    this.age,
    this.location,
    this.photoUrl,
    required this.status,
    this.sentAt,
  });

  factory InterestModel.fromJson(Map<String, dynamic> json) => InterestModel(
        interestId: json['interest_id'] as String,
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        age: json['age'] as int?,
        location: json['location'] as String?,
        photoUrl: json['primary_photo_url'] as String?,
        status: json['status'] as String,
        sentAt: json['sent_at'] != null
            ? DateTime.tryParse(json['sent_at'] as String)
            : null,
      );
}


class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? entityType;
  final String? entityId;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.entityType,
    this.entityId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
      );
}

class VerificationStatus {
  final String verificationStatus;
  final String? method;
  final String? requestStatus;
  final String? certificateStatus;
  final String? certificateRejectionReason;
  final String? referenceStatus;

  const VerificationStatus({
    required this.verificationStatus,
    this.method,
    this.requestStatus,
    this.certificateStatus,
    this.certificateRejectionReason,
    this.referenceStatus,
  });

  factory VerificationStatus.fromJson(Map<String, dynamic> json) =>
      VerificationStatus(
        verificationStatus: json['verification_status'] as String? ?? 'unverified',
        method: json['method'] as String?,
        requestStatus: json['request_status'] as String?,
        certificateStatus: json['certificate_status'] as String?,
        certificateRejectionReason:
            json['certificate_rejection_reason'] as String?,
        referenceStatus: json['reference_status'] as String?,
      );

  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => requestStatus == 'pending';
}
