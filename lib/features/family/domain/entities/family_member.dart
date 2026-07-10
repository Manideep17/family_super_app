import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/family_role.dart';

/// `families/{familyId}/members/{uid}` — one doc per joined member. Holds
/// per-family identity (display name, role, custom greeting) so the same
/// human can show up differently in different families.
class FamilyMember extends Equatable {
  const FamilyMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.greeting,
    required this.joinedAt,
    this.avatarUrl,
  });

  final String uid;
  final String email;
  final String displayName;
  final FamilyRole role;

  /// Personal phrase the dashboard uses ("Hey rockstar"). Empty falls back to
  /// a time-aware greeting.
  final String greeting;
  final DateTime joinedAt;
  final String? avatarUrl;

  bool get isParent => false;

  String get initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  FamilyMember copyWith({
    String? displayName,
    FamilyRole? role,
    String? greeting,
    String? avatarUrl,
  }) {
    return FamilyMember(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      greeting: greeting ?? this.greeting,
      joinedAt: joinedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        role,
        greeting,
        joinedAt,
        avatarUrl,
      ];
}
