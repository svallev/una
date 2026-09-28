/// Por qué no se ve la página de una tarea web (spec 009 §5). Cada uno tiene su
/// aviso bajo la barra, en lugar de la página, y sus acciones.
enum WebLoadFailure {
  /// Sin conexión o tiempo agotado (CA-009-08): `urlNeedsConnection`.
  offline(canRetry: true, canOpenInBrowser: false),

  /// La dirección era `http://` y el servidor no admite https (CA-009-09):
  /// `urlInsecure`.
  insecure(canRetry: false, canOpenInBrowser: true),

  /// Certificado no válido, que nunca se acepta (CA-009-10): `urlLoadFailed`
  /// con `urlReasonCertificate`.
  certificate(canRetry: true, canOpenInBrowser: true),

  /// La dirección es un PDF u otro archivo (CL-009-4): `urlNotAPage`.
  notAPage(canRetry: false, canOpenInBrowser: true);

  const WebLoadFailure({
    required this.canRetry,
    required this.canOpenInBrowser,
  });

  /// Muestra "Reintentar" (vuelve a cargar la dirección guardada).
  final bool canRetry;

  /// Muestra "Abrir en el navegador" (la dirección guardada, sin confirmar).
  final bool canOpenInBrowser;
}

/// Lo que ha fallado al cargar, ya traducido desde la WebView (el
/// `WebPageDriver` lo hace; el dominio no conoce el paquete).
enum WebLoadError {
  /// No se ha podido resolver el dominio: sin red, casi siempre.
  hostLookup,

  /// No se ha podido conectar con el servidor.
  connect,

  /// Ha fallado la negociación TLS (sin llegar al certificado).
  secureHandshake,

  /// El certificado no es válido (se ha cancelado).
  certificate,

  /// La respuesta es una descarga, no una página (se ha descartado).
  download,

  /// Tiempo agotado: el de la WebView o los [webLoadTimeout] sin que la página
  /// empiece a verse.
  timeout,

  /// Cualquier otro error de red.
  other,
}

/// Tiempo sin que la página empiece a verse (`onPageStarted`) tras el que se
/// da por "sin conexión" (CA-009-08, CL-009-7).
const Duration webLoadTimeout = Duration(seconds: 20);

/// Qué aviso corresponde a [error] (plan §1, "Estado de la página").
///
/// - Solo cuentan los errores del marco principal: los de un recurso suelto o
///   un marco interno no tapan la página (null).
/// - Un certificado no válido es siempre [WebLoadFailure.certificate], y una
///   descarga, [WebLoadFailure.notAPage].
/// - Si la dirección guardada era `http://` y se ha intentado como `https://`
///   ([upgradedFromHttp]), un fallo de conexión o de TLS significa que el
///   servidor no admite https: [WebLoadFailure.insecure].
/// - El resto (incluido el DNS, que es lo que falla sin red aunque antes llegue
///   `onPageStarted`) es [WebLoadFailure.offline].
WebLoadFailure? classifyLoadError(
  WebLoadError error, {
  required bool isMainFrame,
  required bool upgradedFromHttp,
}) {
  if (!isMainFrame) return null;
  return switch (error) {
    WebLoadError.certificate => WebLoadFailure.certificate,
    WebLoadError.download => WebLoadFailure.notAPage,
    WebLoadError.connect || WebLoadError.secureHandshake
        when upgradedFromHttp =>
      WebLoadFailure.insecure,
    _ => WebLoadFailure.offline,
  };
}
