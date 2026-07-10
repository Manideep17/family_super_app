import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/invite_link_hosts.dart';
import '../router/app_link.dart';

/// Handles invite URLs:
/// - `famsuperapp://join/CODE` (custom scheme; see Android manifest + iOS URL types)
/// - `https://<allowed-host>/join/CODE` or same with `?code=` / `?join=` query
///
/// Host allowlist: [InviteLinkHosts]. Configure HTTPS App Links on the server
/// (see `docs/HTTPS_APP_LINKS.md`).
class DeepLinkBootstrap {
  DeepLinkBootstrap._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static Future<void> init() async {
    await _handle(await _appLinks.getInitialLink());
    await _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) {
        if (kDebugMode) {
          debugPrint('DeepLinkBootstrap stream error: $e');
        }
      },
    );
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static Future<void> _handle(Uri? uri) async {
    if (uri == null) return;
    final code = _parseJoinCode(uri);
    if (code == null || code.length != 6) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_join_code', code);
    AppLink.go('/onboarding');
  }

  static String? _parseJoinCode(Uri uri) {
    if (uri.scheme == 'famsuperapp' && uri.host == 'join') {
      return _normalizeJoinCodeFromPath(uri.path);
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (!InviteLinkHosts.isAllowed(uri.host)) return null;
      final fromPath = _parseHttpsPath(uri.path);
      if (fromPath != null) return fromPath;
      final q = uri.queryParameters;
      final raw = q['code'] ?? q['join'] ?? q['c'];
      if (raw != null && raw.isNotEmpty) {
        return _normalizeJoinCode(raw);
      }
    }
    return null;
  }

  /// `/join/ABC123` or `/join/ABC123/extra`
  static String? _parseHttpsPath(String path) {
    var p = path;
    if (p.startsWith('/')) p = p.substring(1);
    final parts = p.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0].toLowerCase() == 'join') {
      return _normalizeJoinCode(parts[1]);
    }
    return null;
  }

  static String? _normalizeJoinCodeFromPath(String path) {
    var raw = path;
    if (raw.startsWith('/')) raw = raw.substring(1);
    return _normalizeJoinCode(raw);
  }

  static String? _normalizeJoinCode(String raw) {
    var s = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (s.length < 6) return null;
    return s.length > 6 ? s.substring(0, 6) : s;
  }
}
