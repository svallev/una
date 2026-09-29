import 'dart:js_interop';

/// `window.open(address, '_blank', 'noopener,noreferrer')`. Sin paquetes:
/// solo `dart:js_interop`, como `WebImageImporter`. Navegar no depende de la
/// CSP de la web de pruebas (no hay `connect-src` ni `frame-src` nuevos).
void openInNewTab(String address) {
  _window.open(address, '_blank', 'noopener,noreferrer');
}

@JS('window')
external _Window get _window;

extension type _Window(JSObject _) implements JSObject {
  external JSObject? open(String url, String target, String features);
}
