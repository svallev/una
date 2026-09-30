import 'package:flutter/services.dart';

import '../../domain/entities/link_target.dart';
import '../../domain/ports/link_opener.dart';

/// [LinkOpener] sobre el canal `una/links` (`LinkOpener.kt`).
class NativeLinkOpener implements LinkOpener {
  const NativeLinkOpener();

  static const _channel = MethodChannel('una/links');

  @override
  Future<bool> open(LinkTarget target) => _invoke('open', target);

  @override
  Future<bool> canOpen(LinkTarget target) => _invoke('canOpen', target);

  /// Cualquier fallo del canal (sin lado nativo, error de plataforma) es "no".
  Future<bool> _invoke(String method, LinkTarget target) async {
    final (kind, uri) = switch (target) {
      WebLink(:final uri) => ('web', uri),
      MailLink(:final uri) => ('mail', uri),
      PhoneLink(:final uri) => ('tel', uri),
      InternalLink() || BlockedLink() => ('', null),
    };
    if (uri == null) return false;
    try {
      return await _channel.invokeMethod<bool>(method, {
            'kind': kind,
            'uri': uri.toString(),
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
