import 'web_page_driver.dart';

/// Web de pruebas: sin WebView (CL-009-5); la tarea web se ve como tarjeta.
WebPageDriver createWebPageDriver() =>
    throw UnsupportedError('No WebView in the web preview');
