/// Hostnames allowed for `https` invite links (must match Android manifest + iOS
/// Associated Domains + Digital Asset Links / apple-app-site-association).
///
/// Override at build time:
/// `--dart-define=INVITE_HTTPS_HOSTS=join.myapp.com,www.myapp.com`
abstract final class InviteLinkHosts {
  InviteLinkHosts._();

  static const String _env = String.fromEnvironment(
    'INVITE_HTTPS_HOSTS',
    defaultValue: '',
  );

  /// Default when no dart-define is set (replace in your deployment).
  static const List<String> _defaults = ['invite.example.com'];

  static List<String> get allowed {
    if (_env.trim().isEmpty) return _defaults;
    return _env
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static bool isAllowed(String host) {
    final h = host.toLowerCase();
    return allowed.contains(h);
  }

  /// Shown in "copy HTTPS link" and docs; first configured host.
  static String get displayHost => allowed.first;

  static String httpsJoinUrl(String joinCode) {
    final code = joinCode.trim().toUpperCase();
    return 'https://$displayHost/join/$code';
  }
}
