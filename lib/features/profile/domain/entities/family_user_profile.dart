import 'package:equatable/equatable.dart';

/// `users/{uid}` — optional avatar + FCM token for notifications.
class FamilyUserProfile extends Equatable {
  const FamilyUserProfile({
    required this.uid,
    required this.email,
    required this.familyId,
    required this.displayName,
    required this.isParent,
    required this.greeting,
    this.avatarUrl,
    this.fcmToken,
  });

  final String uid;
  final String email;
  final String familyId;
  final String displayName;
  final bool isParent;
  final String greeting;
  final String? avatarUrl;
  final String? fcmToken;

  @override
  List<Object?> get props => [
        uid,
        email,
        familyId,
        displayName,
        isParent,
        greeting,
        avatarUrl,
        fcmToken,
      ];
}
