import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_page_driver.dart';
import 'webview_page_driver.dart'
    if (dart.library.js_interop) 'web_page_driver_unsupported.dart'
    as impl;

/// Crea la WebView de la tarea web: `webview_flutter` en el móvil; en los
/// tests, un falso. La web de pruebas no la usa (CL-009-5) y no incluye el
/// paquete (importación condicional).
final webPageDriverFactoryProvider = Provider<WebPageDriverFactory>(
  (ref) => impl.createWebPageDriver,
);
