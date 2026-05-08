// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool launchEmailDraft({
  required String to,
  required String subject,
  required String body,
}) {
  final normalizedTo = to.trim();
  if (normalizedTo.isEmpty) {
    return false;
  }

  final uri = Uri(
    scheme: 'mailto',
    path: normalizedTo,
    queryParameters: {'subject': subject, 'body': body},
  );
  html.window.open(uri.toString(), '_self');
  return true;
}
