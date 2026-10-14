import 'dart:convert';

import '../entities/locale_choice.dart';
import '../entities/notification_settings.dart';

/// Claves de la tabla `settings` (las mismas en Drift y en memoria).
abstract final class SettingKeys {
  static const firstRunDone = 'firstRunDone';
  static const hasEverHadTasks = 'hasEverHadTasks';
  static const keepScreenOn = 'keepScreenOn';
  static const lockZoom = 'lockZoom';
  static const locale = 'locale';
  static const notificationsOn = 'notificationsOn';
  static const notificationsPerDay = 'notificationsPerDay';
}

/// Más largo que esto no puede ser un ajuste válido (`"system"` son 8
/// caracteres): se descarta **antes** de `jsonDecode` (CA-015-26) y, en la base
/// de datos, antes de llegar a Dart (CA-020-16).
const settingMaxRawLength = 16;

/// Lo más que puede ocupar en UTF-8 un valor de [settingMaxRawLength]
/// caracteres (4 bytes cada uno): la segunda cota de la lectura en SQL, que no
/// depende de que `length()` cuente más allá de un NUL.
const settingMaxRawBytes = settingMaxRawLength * 4;

/// El valor guardado de un ajuste tal como lo lee la app (CA-020-16): `null`
/// (ilegible, con su valor por defecto) si no hay fila o mide más de
/// [settingMaxRawLength] caracteres. La misma regla que aplica la consulta de
/// `DriftTaskRepository`, para el repositorio en memoria.
String? boundedSetting(String? raw) =>
    raw == null || raw.length > settingMaxRawLength ? null : raw;

/// Decodificadores únicos de los ajustes guardados (CA-015-26). Los usan los
/// dos repositorios (Drift y memoria): **nunca lanzan** y ante cualquier cosa
/// que no sea exactamente un valor válido dan el valor por defecto.
Object? _decode(String? raw) {
  if (raw == null || raw.length > settingMaxRawLength) return null;
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

/// "Bloquear zoom" (CA-017-03): encendido solo si el texto guardado es
/// **exactamente** `true`. A diferencia de los demás, ni siquiera pasa por
/// `jsonDecode`: ` true`, `true\n` o `"true"` son basura y dan apagado.
bool decodeLockZoom(String? raw) => raw == encodeFlag(true);

/// "Notificaciones" (CA-019-05): encendido solo si el texto guardado es
/// **exactamente** `true` (como [decodeLockZoom], sin `jsonDecode`).
bool decodeNotificationsOn(String? raw) => raw == encodeFlag(true);

/// Cantidad al día (CA-019-05): solo los textos `1`, `2` y `3` exactos; `0`,
/// `4`, `-1`, `1.5`, `2.0`, `"2"`, listas o un valor ilegible dan 1. Una
/// comparación de texto, sin `jsonDecode` ni `int.parse` (que aceptarían
/// `02` o ` 2`).
NotificationsPerDay decodeNotificationsPerDay(String? raw) {
  for (final value in NotificationsPerDay.values) {
    if (raw == encodeNotificationsPerDay(value)) return value;
  }
  return NotificationsPerDay.defaultValue;
}

/// Marcas de un solo uso (`firstRunDone`, `hasEverHadTasks`): `true` exacto;
/// lo demás falla cerrado a `false`.
bool decodeFlag(String? raw) => _decode(raw) == true;

String encodeLocaleChoice(LocaleChoice choice) => jsonEncode(choice.code);

String encodeFlag(bool value) => jsonEncode(value);

String encodeNotificationsPerDay(NotificationsPerDay value) => '${value.count}';
