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
    this.referralCode = '',
    this.referralCount = 0,
    this.referredByFamilyId = '',
    this.referralBonusExpiresAt,
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

  /// This family's own shareable "invite & earn" code — set once by
  /// `allocateReferralCode` (functions/src/referrals.ts), empty until the
  /// "Invite & earn" screen has been opened at least once.
  final String referralCode;

  /// How many other families have redeemed this family's referral code.
  final int referralCount;

  /// Set once, the first (and only) time this family redeemed someone
  /// else's referral code — never writable by clients.
  final String referredByFamilyId;

  /// Free-premium bonus window earned via the referral loop — entirely
  /// separate from the real, verified-purchase subscription fields above,
  /// so it can never be silently overwritten by `refreshSubscriptions`
  /// (which only ever touches families with a real purchase token) and
  /// stacks across multiple successful referrals instead of resetting.
  final DateTime? referralBonusExpiresAt;

  bool get isFull => memberLimit > 0 && memberCount >= memberLimit;

  bool get hasActiveReferralBonus =>
      referralBonusExpiresAt != null &&
      referralBonusExpiresAt!.isAfter(DateTime.now());

  /// True if the last verified subscription state is active and unexpired,
  /// OR a referral bonus is currently active — either path unlocks the
  /// same premium features.
  bool get isPremium =>
      (subscriptionActive &&
          (subscriptionExpiresAt == null ||
              subscriptionExpiresAt!.isAfter(DateTime.now()))) ||
      hasActiveReferralBonus;

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
        referralCode,
        referralCount,
        referredByFamilyId,
        referralBonusExpiresAt,
      ];
}
