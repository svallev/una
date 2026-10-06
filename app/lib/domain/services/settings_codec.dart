import 'dart:convert';

import '../entities/locale_choice.dart';

/// Claves de la tabla `settings` (las mismas en Drift y en memoria).
abstract final class SettingKeys {
  static const firstRunDone = 'firstRunDone';
  static const hasEverHadTasks = 'hasEverHadTasks';
  static const keepScreenOn = 'keepScreenOn';
  static const locale = 'locale';
}

/// Más largo que esto no puede ser un ajuste válido (`"system"` son 8
/// caracteres): se descarta **antes** de `jsonDecode` (CA-015-26).
const _maxRawLength = 16;

/// Decodificadores únicos de los ajustes guardados (CA-015-26). Los usan los
/// dos repositorios (Drift y memoria): **nunca lanzan** y ante cualquier cosa
/// que no sea exactamente un valor válido dan el valor por defecto.
Object? _decode(String? raw) {
  if (raw == null || raw.length > _maxRawLength) return null;
  try {
    return jsonDecode(raw);
  } on Object {
    // Dato corrupto (también de una copia de seguridad, CL-015-18): defecto.
    return null;
  }
}

/// El idioma guardado: solo `"system"`, `"es"` o `"en"` exactos; lo demás,
/// "Como el sistema". Nunca se construye un `Locale` de lo que se lee.
LocaleChoice decodeLocaleChoice(String? raw) {
  final value = _decode(raw);
  if (value is! String) return LocaleChoice.system;
  for (final choice in LocaleChoice.values) {
    if (value == choice.code) return choice;
  }
  return LocaleChoice.system;
}

/// "Pantalla siempre activa": encendida solo si el valor es exactamente el
/// booleano `true`; lo demás, apagada (por defecto).
bool decodeKeepScreenOn(String? raw) => _decode(raw) == true;

/// Marcas de un solo uso (`firstRunDone`, `hasEverHadTasks`): `true` exacto;
/// lo demás falla cerrado a `false`.
bool decodeFlag(String? raw) => _decode(raw) == true;

String encodeLocaleChoice(LocaleChoice choice) => jsonEncode(choice.code);

String encodeFlag(bool value) => jsonEncode(value);
