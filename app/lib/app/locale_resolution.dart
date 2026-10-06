import 'dart:ui';

import '../domain/entities/locale_choice.dart';

/// Resuelve el idioma de "Como el sistema" (CA-010-01/02, CA-015-09): lo decide
/// el sistema. Con "Español" o "English" elegidos en Ajustes no se llama
/// (spec 015, ADR-0023). Se usa el primer idioma preferido del dispositivo que la app admita
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

/// El `Locale` fijo de un idioma elegido en Ajustes; `null` con "Como el
/// sistema" (lo decide [resolveAppLocale]). Se construye de constantes, nunca
/// del texto guardado (CA-015-26).
Locale? localeOfChoice(LocaleChoice choice) => switch (choice) {
  LocaleChoice.system => null,
  LocaleChoice.es => const Locale('es'),
  LocaleChoice.en => const Locale('en'),
};
