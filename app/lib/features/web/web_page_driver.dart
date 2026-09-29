import 'package:flutter/widgets.dart';

import '../../domain/entities/web_load_failure.dart';

/// Lo que cuenta la WebView de una tarea web a su `WebPageController`, ya
/// traducido del paquete (spec 009, plan §1 "Estado de la página"). Nunca lleva
/// contenido de la página; las direcciones no se registran (CL-009-9).
abstract interface class WebPageListener {
  /// Petición de navegar a [url] (null si no se puede analizar). `true` la
  /// deja cargar; `false` no hace nada (CA-009-11, ADR-0018).
  bool onNavigationRequest(Uri? url, {required bool isMainFrame});

  /// Empieza a verse la página de [url] (`onPageStarted`).
  void onPageStarted(Uri url);

  /// La página de [url] ha terminado de cargar (`onPageFinished`).
  void onPageFinished(Uri url);

  /// Progreso de la carga, de 0 a 100.
  void onProgress(int percent);

  /// Error de red al cargar un recurso ([isMainFrame]: el de la página).
  void onLoadError(WebLoadError error, {required bool isMainFrame});

  /// Certificado no válido. El driver ya lo ha cancelado: nunca se acepta
  /// (CA-009-10).
  void onCertificateError();

  /// Una descarga que no se ha hecho (CL-009-4, CA-009-13).
  void onDownloadBlocked();

  /// Ha muerto el proceso de la página (ADR-0017): esta WebView ya no sirve.
  /// [crashed] es `false` si lo mató el sistema (memoria).
  void onProcessGone({required bool crashed});
}

/// Una WebView de la tarea web (CA-009-06..13). La implementación real usa
/// `webview_flutter` (`WebViewPageDriver`); en los tests, un falso que emite
/// los eventos a mano, como el visor del PDF.
///
/// Un driver es **una** WebView: tras el fallo de su proceso se destruye
/// ([destroy]) y el `WebPageController` crea otro (ADR-0017).
abstract interface class WebPageDriver {
  /// Identificador nativo de la WebView (canal `una/webview`), para borrar sus
  /// datos al salir; null si no hay (tests, otras plataformas).
  int? get nativeId;

  /// Prepara la WebView y le da [listener]: endurecimiento desde Dart,
  /// delegado de navegación y, **después**, el endurecimiento nativo con el
  /// envoltorio del cliente (ADR-0017). Una sola vez: nunca se vuelve a poner
  /// el delegado. `true` solo si quedó endurecida; si no, no se carga nada.
  /// Se llama con la vista ([buildView]) ya en pantalla.
  Future<bool> attach(WebPageListener listener);

  /// Carga [url] en el marco principal.
  Future<void> load(Uri url);

  /// Deja de cargar y quita la página (se queda en blanco).
  Future<void> stop();

  /// Destruye la WebView (tras el fallo de su proceso, ya fuera de la
  /// pantalla). No se puede volver a usar.
  Future<void> destroy();

  /// Deja de escuchar sus avisos. No toca la WebView.
  void dispose();

  /// La vista de la WebView, para la pantalla (T-009-11).
  Widget buildView({Key? key});
}

/// Crea la WebView de una tarea web.
typedef WebPageDriverFactory = WebPageDriver Function();
