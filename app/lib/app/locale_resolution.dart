import 'dart:ui';

/// Idiomas de la app (R15).
const supportedAppLocales = [Locale('es'), Locale('en')];

/// Resuelve el idioma (CA-010-01/02): el ajuste manual manda; si es "system",
/// se usa el primer idioma preferido del dispositivo que la app admita
/// (cualquier `es-*` → español); si ninguno, inglés.
Locale resolveAppLocale(List<Locale>? device, {String setting = 'system'}) {
  if (setting == 'es' || setting == 'en') return Locale(setting);
  for (final l in device ?? const <Locale>[]) {
    if (l.languageCode == 'es') return const Locale('es');
    if (l.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}
