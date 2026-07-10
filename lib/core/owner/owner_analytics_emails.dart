/// Lowercase emails allowed to open **in-app owner analytics** without joining a
/// family. Must match Firestore `_internal_rule_config/app_dashboard_owners.emails`
/// (or custom claim `appAnalyticsOwner`) and `owner_analytics_dashboard/config.js`
/// `allowedEmails`.
///
/// You can also pass comma-separated emails at build time:
/// `flutter run --dart-define=OWNER_ANALYTICS_EMAILS=you@example.com,other@x.com`
const String _kOwnerEmailsFromEnvironment = String.fromEnvironment(
  'OWNER_ANALYTICS_EMAILS',
  defaultValue: '',
);

/// Add permanent owner emails here (lowercase).
const Set<String> kOwnerAnalyticsEmailsBuildtime = <String>{
  'manideepbiswas@gmail.com',
};

Set<String> get ownerAnalyticsEmailSet {
  final fromEnv = _kOwnerEmailsFromEnvironment
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty);
  return {...kOwnerAnalyticsEmailsBuildtime, ...fromEnv};
}

bool isOwnerAnalyticsEmail(String? email) {
  final e = email?.trim().toLowerCase();
  if (e == null || e.isEmpty) return false;
  return ownerAnalyticsEmailSet.contains(e);
}
