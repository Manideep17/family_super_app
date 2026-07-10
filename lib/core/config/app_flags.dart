/// Runtime feature toggles.
///
/// Media-upload features can be toggled per build. When enabled, this project
/// uses Cloudinary settings below for upload handling.
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

  /// Cloudinary (free tier) configuration.
  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');
  static const String cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: '');

  /// Optional: OneSignal + free worker bridge.
  static const String oneSignalAppId =
      String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');
  static const String pushWorkerEndpoint =
      String.fromEnvironment('PUSH_WORKER_ENDPOINT', defaultValue: '');
  static const String pushWorkerKey =
      String.fromEnvironment('PUSH_WORKER_KEY', defaultValue: '');

  static bool get cloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;
  static bool get pushBridgeConfigured =>
      oneSignalAppId.isNotEmpty &&
      pushWorkerEndpoint.isNotEmpty &&
      pushWorkerKey.isNotEmpty;
}
