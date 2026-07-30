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
    this.subscriptionActive = false,
    this.subscriptionProductId = '',
    this.subscriptionExpiresAt,
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

  /// Set only by the `verifySubscriptionPurchase` Cloud Function (see
  /// functions/src/billing.ts) — never writable by clients directly, both
  /// by Firestore rule (families/{fid} update allowlist doesn't include
  /// these fields) and by convention. Reflects the *last verified* state of
  /// the subscription with Google Play, not a client-side promise.
  final bool subscriptionActive;
  final String subscriptionProductId;

  /// When the currently-verified subscription period ends. Re-verify (or
  /// let the app re-check on launch) once this passes, since Play doesn't
  /// push renewal/cancellation events to us without additional
  /// (not-yet-built) Realtime Developer Notifications plumbing — see
  /// docs/BILLING_SETUP.md.
  final DateTime? subscriptionExpiresAt;

  bool get isFull => memberLimit > 0 && memberCount >= memberLimit;

  /// True only if the last verified subscription state is active AND its
  /// verified expiry hasn't passed yet — computed client-side too so a
  /// stale `subscriptionActive: true` doesn't outlive its real expiry
  /// between re-verifications.
  bool get isPremium =>
      subscriptionActive &&
      (subscriptionExpiresAt == null ||
          subscriptionExpiresAt!.isAfter(DateTime.now()));

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
        subscriptionActive,
        subscriptionProductId,
        subscriptionExpiresAt,
      ];
}
