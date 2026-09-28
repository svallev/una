import 'package:flutter/foundation.dart';

/// Qué hace un enlace de un PDF (CA-008-12, `classifyLink`).
@immutable
sealed class LinkTarget {
  const LinkTarget();
}

/// A otra página del mismo PDF (desde 1): se desplaza, sin confirmar.
final class InternalLink extends LinkTarget {
  const InternalLink(this.page);
  final int page;

  @override
  bool operator ==(Object other) => other is InternalLink && other.page == page;
  @override
  int get hashCode => page.hashCode;
  @override
  String toString() => 'InternalLink($page)';
}

/// Web (`http`/`https`): al navegador tras confirmar con [host].
final class WebLink extends LinkTarget {
  const WebLink(this.uri, this.host);
  final Uri uri;

  /// El dominio real, en punycode si mezcla alfabetos (T-5).
  final String host;

  @override
  String toString() => 'WebLink($host)';
}

/// Correo: la app de correo tras confirmar con [display]; sin enviar.
final class MailLink extends LinkTarget {
  const MailLink(this.uri, this.display);

  /// `mailto:` rehecho solo con destinatarios y asunto.
  final Uri uri;
  final String display;

  @override
  String toString() => 'MailLink($display)';
}

/// Teléfono: el marcador tras confirmar con [display]; no llama.
final class PhoneLink extends LinkTarget {
  const PhoneLink(this.uri, this.display);
  final Uri uri;
  final String display;

  @override
  String toString() => 'PhoneLink($display)';
}

/// Cualquier otra cosa: no hace nada.
final class BlockedLink extends LinkTarget {
  const BlockedLink();

  @override
  bool operator ==(Object other) => other is BlockedLink;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'BlockedLink()';
}
