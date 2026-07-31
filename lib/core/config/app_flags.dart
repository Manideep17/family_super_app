/// Runtime feature toggles.
///
/// Media-upload features can be toggled per build. Uploads go straight to
/// this project's Firebase Storage bucket (see
/// `lib/core/media/media_upload_service.dart` and `storage.rules`) — Storage
/// requires the Blaze plan (no Spark/free tier), which is why this still
/// stays behind its own flag rather than being unconditionally on.
class AppFlags {
  AppFlags._();

  /// Legacy name kept for existing UI checks.
  static const bool storageEnabled =
      bool.fromEnvironment('MEDIA_UPLOADS_ENABLED', defaultValue: false);
  static const bool mediaUploadsEnabled = storageEnabled;

  /// Cloud Functions deploy is blocked on Spark by default.
  static const bool functionsEnabled =
      bool.fromEnvironment('FUNCTIONS_ENABLED', defaultValue: false);

  /// Gemini-powered weekly family digest (see `FamilyDigestService`). Uses
  /// Firebase AI Logic's Gemini Developer API backend, which is free on the
  /// Spark plan — but it still needs a one-time "AI Logic" setup step in the
  /// Firebase console (see docs/AI_LOGIC_SETUP.md) before it'll respond, so
  /// this stays off by default like the other backend-dependent flags here.
  static const bool aiDigestEnabled =
      bool.fromEnvironment('AI_DIGEST_ENABLED', defaultValue: false);

  /// Optional: OneSignal + free worker bridge.
  static const String oneSignalAppId =
      String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');
  static const String pushWorkerEndpoint =
      String.fromEnvironment('PUSH_WORKER_ENDPOINT', defaultValue: '');
  static const String pushWorkerKey =
      String.fromEnvironment('PUSH_WORKER_KEY', defaultValue: '');

  static bool get pushBridgeConfigured =>
      oneSignalAppId.isNotEmpty &&
      pushWorkerEndpoint.isNotEmpty &&
      pushWorkerKey.isNotEmpty;

  /// Play Console subscription product id for the monthly premium plan (AI
  /// digest, extra vault storage, AI quiz). See docs/BILLING_SETUP.md for
  /// creating this exact product id in Play Console.
  static const String premiumMonthlyProductId = String.fromEnvironment(
    'PREMIUM_MONTHLY_PRODUCT_ID',
    defaultValue: 'fam_premium_monthly',
  );

  /// Purchases can't be verified without the `verifySubscriptionPurchase`
  /// Cloud Function deployed, so the paywall stays hidden behind the same
  /// flag as other Functions-backed features until that's live — never let
  /// someone pay before the unlock path actually works.
  static bool get billingEnabled => functionsEnabled;

  /// Free-tier vault cap (item count, not bytes — simplest thing to check
  /// without tracking cumulative upload size). Premium families skip this
  /// check entirely; see Family.isPremium.
  static const int freeVaultItemLimit = 200;
}
