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

  final query = [
    'to=${Uri.encodeComponent(normalizedTo)}',
    'subject=${Uri.encodeComponent(subject)}',
    'body=${Uri.encodeComponent(body)}',
  ].join('&');
  html.window.open(
    'https://outlook.office.com/mail/deeplink/compose?$query',
    '_blank',
  );
  return true;
}
