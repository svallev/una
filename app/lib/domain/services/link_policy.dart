import '../entities/link_target.dart';
import 'host_display.dart';
import 'text_safety.dart';

/// Decide qué hace un enlace de un PDF (CA-008-12, T-5). [destPage] es el
/// destino interno (desde 1); [url], la dirección de un enlace externo. Todo lo
/// que no sea una página del PDF, `http(s)`, `mailto:` o `tel:` se bloquea.
LinkTarget classifyLink({Uri? url, int? destPage}) {
  if (destPage != null && destPage >= 1) return InternalLink(destPage);
  if (url == null) return const BlockedLink();
  return switch (url.scheme.toLowerCase()) {
    'http' || 'https' => _web(url),
    'mailto' => _mail(url),
    'tel' => _phone(url),
    _ => const BlockedLink(),
  };
}

LinkTarget _web(Uri url) {
  // `usuario:clave@` sirve para disfrazar el dominio real (T-5).
  if (url.userInfo.isNotEmpty || url.host.isEmpty) return const BlockedLink();
  final host = displayHost(url.host);
  if (host.isEmpty) return const BlockedLink();
  return WebLink(url, host);
}

String _decode(String s) {
  try {
    return Uri.decodeComponent(s);
  } on ArgumentError {
    return s;
  }
}

final _address = RegExp(r'^[^@\s,;<>"]+@[^@\s,;<>"]+\.[^@\s,;<>"]+$');

LinkTarget _mail(Uri url) {
  final raw = <String>[
    ..._decode(url.path).split(','),
    for (final e in url.queryParametersAll.entries)
      if (e.key.toLowerCase() == 'to') ...e.value.expand((v) => v.split(',')),
  ];
  final to = [
    for (final r in raw)
      if (stripUnsafeChars(r).trim() case final a when _address.hasMatch(a)) a,
  ];
  if (to.isEmpty) return const BlockedLink();
  final subject = url.queryParametersAll.entries
      .where((e) => e.key.toLowerCase() == 'subject')
      .expand((e) => e.value)
      .map(stripUnsafeChars)
      .firstOrNull;
  return MailLink(
    Uri(
      scheme: 'mailto',
      path: to.join(','),
      queryParameters: subject == null ? null : {'subject': subject},
    ),
    to.join(', '),
  );
}

LinkTarget _phone(Uri url) {
  final number = _decode(url.path).split(';').first;
  final digits = number.replaceAll(RegExp(r'[\s\-().]'), '');
  if (!RegExp(r'^\+?[0-9]{3,20}$').hasMatch(digits)) return const BlockedLink();
  return PhoneLink(Uri.parse('tel:$digits'), digits);
}
