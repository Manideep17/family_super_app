import 'package:equatable/equatable.dart';

/// `families/{familyId}` — one document per family group.
class Family extends Equatable {
  const Family({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.memberLimit,
    required this.createdBy,
    required this.createdAt,
    required this.memberCount,
    this.pinnedAnnouncement = '',
    this.ownerUid = '',
    this.dailyDigestOptIn = false,
  });

  final String id;
  final String name;
  final String joinCode;
  final int memberLimit;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;

  /// Account that may transfer ownership (`createdBy` at family creation).
  final String ownerUid;

  /// Short family-wide note shown on the home dashboard (optional).
  final String pinnedAnnouncement;

  /// Owner opt-in for optional daily digest push (see Cloud Functions).
  final bool dailyDigestOptIn;

  bool get isFull => memberLimit > 0 && memberCount >= memberLimit;

  @override
  List<Object?> get props => [
        id,
        name,
        joinCode,
        memberLimit,
        createdBy,
        createdAt,
        memberCount,
        pinnedAnnouncement,
        ownerUid,
        dailyDigestOptIn,
      ];
}
