/// Idioma que elige el usuario en Ajustes (spec 015, ADR-0023).
///
/// Dominio puro: no es un `Locale`. `app/` construye el `Locale('es'|'en')` a
/// partir de esta elección y **nunca** de un texto guardado (CA-015-26).
enum LocaleChoice {
  /// "Como el sistema": rige la regla de la spec 010 (`resolveAppLocale`).
  system,
  es,
  en;

  /// Texto que se guarda y que se valida contra `system|es|en`.
  String get code => name;
}
