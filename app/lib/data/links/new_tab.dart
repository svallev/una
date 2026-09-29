import 'new_tab_native.dart'
    if (dart.library.js_interop) 'new_tab_web.dart'
    as impl;

/// Abre [address] en una pestaña nueva del navegador, sin que la página
/// abierta pueda tocar la de la app (`noopener`) ni sepa de dónde viene
/// (`noreferrer`). Solo en la web de pruebas (CL-009-5); en el móvil no hace
/// nada. Solo direcciones `http` y `https`.
void openInNewTab(Uri address) {
  if (address.scheme != 'https' && address.scheme != 'http') return;
  impl.openInNewTab(address.toString());
}
