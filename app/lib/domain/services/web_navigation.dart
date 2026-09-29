import 'package:flutter/foundation.dart';

import 'host_display.dart';

/// Qué hace una petición de navegación de la página de una tarea web
/// (CA-009-11, ADR-0018; `decideWebNavigation`).
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

/// No hace nada: la tarea se queda en la página que ya se ve.
final class BlockNavigation extends WebNavigation {
  const BlockNavigation();

  @override
  bool operator ==(Object other) => other is BlockNavigation;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'BlockNavigation()';
}

/// Decide qué hace la petición de navegar a [url] (CA-009-11, CL-009-1,
/// ADR-0018). La tarea web muestra **solo** la página de su dirección
/// guardada: no es un navegador.
///
/// - [shownPage] es la página que se ve (la del primer `onPageStarted`); null
///   durante la **carga inicial**, en la que se siguen las redirecciones del
///   servidor ([isServerRedirect]), también a otro sitio (CL-009-1). Una
///   navegación de la propia página que llega antes del primer
///   `onPageStarted` (un `location.href` en el `<head>`) no es una
///   redirección del servidor y no se sigue (T-009-12).
/// - Un marco interno ([isMainFrame] a false) es parte de la página: se carga
///   si es web, de cualquier sitio (o `about:blank`/`about:srcdoc`).
/// - En el marco principal, ya vista la página, solo se admite un enlace a
///   otra parte de **la misma página** (un ancla `#…`, CA-009-11). Cualquier
///   otro enlace, formulario, redirección de la propia página o ventana nueva
///   no hace nada: ni navega ni sale al navegador ni a otra app (`mailto:` y
///   `tel:` tampoco).
/// - `usuario:clave@`, una web sin dominio y cualquier otro esquema nunca se
///   cargan.
WebNavigation decideWebNavigation(
  Uri url, {
  required Uri? shownPage,
  required bool isMainFrame,
  required bool isServerRedirect,
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
  if (!isWeb) return const BlockNavigation();
  if (shownPage == null) {
    if (!isServerRedirect) return const BlockNavigation();
    return StayInTask(scheme == 'http' ? httpsVersion(url) : null);
  }
  return url.hasFragment && isSamePage(url, shownPage)
      ? const StayInTask()
      : const BlockNavigation();
}

/// El dominio que se avisa con `urlRedirected` si la carga inicial de la
/// dirección guardada [saved] ha acabado en otro dominio ([started], la del
/// primer `onPageStarted`), como en la barra (sin `www.`); null si es el
/// mismo (CL-009-1). Sin lista de sufijos públicos (ADR-0018): un cambio de
/// subdominio (`ejemplo.com` → `m.ejemplo.com`) también se avisa.
String? redirectNoticeHost({required Uri saved, required Uri started}) {
  final host = _barHost(started);
  if (host.isEmpty || host == _barHost(saved)) return null;
  return host;
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

String _barHost(Uri url) => displayHost(_host(url), dropWww: true);

/// El dominio de [url] en minúsculas y sin el punto final.
String _host(Uri url) {
  final host = url.host.toLowerCase();
  return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
}

/// Si [a] y [b] son la misma página sin contar el ancla (`#…`), con `http://`
/// como `https://`.
bool isSamePage(Uri a, Uri b) {
  final x = httpsVersion(a);
  final y = httpsVersion(b);
  String path(Uri u) => u.path.isEmpty ? '/' : u.path;
  return x.scheme.toLowerCase() == y.scheme.toLowerCase() &&
      _host(x) == _host(y) &&
      x.port == y.port &&
      path(x) == path(y) &&
      x.query == y.query;
}
