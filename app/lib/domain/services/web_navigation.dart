import 'package:flutter/foundation.dart';

import '../entities/link_target.dart';
import 'host_display.dart';
import 'link_policy.dart';
import 'public_suffix.dart';

/// Qué hace una petición de navegación de la página de una tarea web
/// (CA-009-11, T-5; `decideWebNavigation`).
@immutable
sealed class WebNavigation {
  const WebNavigation();
}

/// Se carga dentro de la tarea. Si [upgraded] no es null, la petición era
/// `http://` y en su lugar se carga esta, con `https://` (CA-009-09).
final class StayInTask extends WebNavigation {
  const StayInTask([this.upgraded]);
  final Uri? upgraded;

  @override
  bool operator ==(Object other) =>
      other is StayInTask && other.upgraded == upgraded;
  @override
  int get hashCode => upgraded.hashCode;

  // Sin la dirección: no va a ningún registro (CL-009-9).
  @override
  String toString() => 'StayInTask(${upgraded == null ? '' : 'https'})';
}

/// No navega dentro de la tarea: se confirma y, si se acepta, sale. [target]
/// es un [WebLink] (al navegador, `openInBrowserConfirm`), un [MailLink] o un
/// [PhoneLink] (a otra app, `openInAppConfirm`), como los enlaces del PDF.
final class LeaveTask extends WebNavigation {
  const LeaveTask(this.target);
  final LinkTarget target;

  @override
  String toString() => 'LeaveTask($target)';
}

/// No hace nada.
final class BlockNavigation extends WebNavigation {
  const BlockNavigation();

  @override
  bool operator ==(Object other) => other is BlockNavigation;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'BlockNavigation()';
}

/// Decide qué hace la petición de navegar a [url] (CA-009-11, CL-009-1).
///
/// - [referenceSite] es el sitio de la página que se ve ([webSiteOf] de la
///   del primer `onPageStarted`); null durante la **carga inicial**, en la que
///   se siguen las redirecciones, también a otro sitio (CL-009-1).
/// - Un marco interno ([isMainFrame] a false) es parte de la página: se carga
///   si es web, de cualquier sitio (o `about:blank`/`about:srcdoc`), y nunca
///   sale de la tarea.
/// - En el marco principal, `http(s)` del mismo sitio navega dentro de la
///   tarea (`http://` se carga como `https://`); de otro sitio, o `mailto:` y
///   `tel:`, sale tras confirmar (`classifyLink`, la regla del PDF).
/// - `usuario:clave@`, una web sin dominio y cualquier otro esquema
///   (`javascript:`, `file:`, `content:`, `intent:`, `data:`, `about:`, de
///   otras apps…) no hacen nada.
WebNavigation decideWebNavigation(
  Uri url, {
  required String? referenceSite,
  required bool isMainFrame,
  required PublicSuffixList psl,
}) {
  final scheme = url.scheme.toLowerCase();
  final isWeb = scheme == 'http' || scheme == 'https';
  if (isWeb && (url.userInfo.isNotEmpty || url.host.isEmpty)) {
    return const BlockNavigation();
  }
  if (!isMainFrame) {
    final isBlankFrame =
        scheme == 'about' && (url.path == 'blank' || url.path == 'srcdoc');
    return isWeb || isBlankFrame ? const StayInTask() : const BlockNavigation();
  }
  if (isWeb &&
      (referenceSite == null || webSiteOf(url, psl) == referenceSite)) {
    return StayInTask(scheme == 'http' ? httpsVersion(url) : null);
  }
  // Durante la carga inicial nadie ha tocado nada: solo se siguen webs.
  if (referenceSite == null) return const BlockNavigation();
  return switch (classifyLink(url: url)) {
    final LinkTarget t when t is WebLink || t is MailLink || t is PhoneLink =>
      LeaveTask(t),
    _ => const BlockNavigation(),
  };
}

/// El sitio de [url]: su dominio registrable (PSL), en minúsculas y en
/// punycode, para comparar sin importar cómo llegó el dominio. Una IP o un
/// sufijo público son su propio sitio. Null si no tiene dominio.
String? webSiteOf(Uri url, PublicSuffixList psl) {
  var host = _decodePercent(url.host).toLowerCase();
  if (host.endsWith('.')) host = host.substring(0, host.length - 1);
  if (host.isEmpty) return null;
  final ascii = host.contains(':')
      ? host
      : host.split('.').map(toPunycodeLabel).join('.');
  return psl.registrableDomain(ascii) ?? ascii;
}

/// El dominio que se avisa con `urlRedirected` si la carga inicial de la
/// dirección guardada [saved] ha acabado en otro sitio ([started], la del
/// primer `onPageStarted`), como en la barra (sin `www.`); null si es el
/// mismo sitio (CL-009-1).
String? redirectNoticeHost({
  required Uri saved,
  required Uri started,
  required PublicSuffixList psl,
}) {
  final site = webSiteOf(started, psl);
  if (site == null || site == webSiteOf(saved, psl)) return null;
  final host = displayHost(started.host, dropWww: true);
  return host.isEmpty ? null : host;
}

/// [url] con `https://` en lugar de `http://` (CA-009-09); el puerto 80, el de
/// http, pasa a ser el de https. Cualquier otra dirección, tal cual.
Uri httpsVersion(Uri url) {
  if (url.scheme.toLowerCase() != 'http') return url;
  final port = url.hasPort && url.port != 80 ? url.port : null;
  return Uri(
    scheme: 'https',
    host: url.host,
    port: port,
    path: url.path,
    query: url.hasQuery ? url.query : null,
    fragment: url.hasFragment ? url.fragment : null,
  );
}

String _decodePercent(String s) {
  try {
    return Uri.decodeComponent(s);
  } on ArgumentError {
    return s;
  }
}
