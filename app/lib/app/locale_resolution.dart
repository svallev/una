import 'dart:ui';

/// Resuelve el idioma (CA-010-01/02): lo decide solo el sistema, sin ajuste
/// manual. Se usa el primer idioma preferido del dispositivo que la app admita
/// (cualquier `es-*` y también `ca-*` → español; `en-*` → inglés); si ninguno,
/// inglés (también con idiomas de derecha a izquierda, CL-010-4). El catalán
/// abre en español por decisión del propietario (2026-09-30).
Locale resolveAppLocale(List<Locale>? device) {
  for (final l in device ?? const <Locale>[]) {
    if (l.languageCode == 'es' || l.languageCode == 'ca') {
      return const Locale('es');
    }
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}
