import 'dart:ui';

/// Resuelve el idioma (CA-010-01/02): lo decide solo el sistema, sin ajuste
/// manual. Se usa el primer idioma preferido del dispositivo que la app admita
/// (cualquier `es-*` → español; `en-*` → inglés); si ninguno, inglés
/// (también con idiomas de derecha a izquierda, CL-010-4).
Locale resolveAppLocale(List<Locale>? device) {
  for (final l in device ?? const <Locale>[]) {
    if (l.languageCode == 'es') return const Locale('es');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}
