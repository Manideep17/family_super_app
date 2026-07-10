import 'package:url_launcher/url_launcher.dart';

/// Opens the device mail client for app feedback (no hardcoded owner email).
abstract final class FeedbackLaunch {
  static Uri _uri({String? body}) {
    return Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'FAM app feedback',
        if (body != null && body.isNotEmpty) 'body': body,
      },
    );
  }

  static Future<bool> open({String? body}) async {
    final uri = _uri(body: body);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }
}
