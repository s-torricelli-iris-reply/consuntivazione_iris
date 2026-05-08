// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool launchOutlookAppDraft({
  required String to,
  required String subject,
  required String body,
}) {
  return launchDefaultMailDraft(to: to, subject: subject, body: body);
}

bool launchDefaultMailDraft({
  required String to,
  required String subject,
  required String body,
}) {
  final normalizedTo = to.trim();
  if (normalizedTo.isEmpty) {
    return false;
  }

  html.window.location.href = _composeUrl(
    schemeAndPath: 'mailto:$normalizedTo',
    to: null,
    subject: subject,
    body: body,
  );
  return true;
}

bool launchOutlookWebDraft({
  required String to,
  required String subject,
  required String body,
}) {
  final normalizedTo = to.trim();
  if (normalizedTo.isEmpty) {
    return false;
  }

  html.window.open(
    _composeUrl(
      schemeAndPath: 'https://outlook.office.com/mail/deeplink/compose',
      to: normalizedTo,
      subject: subject,
      body: body,
      extraParams: const {'popoutv2': '1'},
    ),
    '_blank',
  );
  return true;
}

String _composeUrl({
  required String schemeAndPath,
  required String? to,
  required String subject,
  required String body,
  Map<String, String> extraParams = const {},
}) {
  final params = <String>[
    if (to != null) 'to=${Uri.encodeComponent(to)}',
    'subject=${Uri.encodeComponent(subject)}',
    'body=${Uri.encodeComponent(body)}',
    ...extraParams.entries.map(
      (entry) =>
          '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
    ),
  ].join('&');
  return '$schemeAndPath?$params';
}
