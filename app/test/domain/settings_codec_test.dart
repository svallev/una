import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/services/settings_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Valores guardados que no son válidos (CA-015-26): ninguno debe fallar.
final _garbage = <String?>[
  null,
  '',
  ' ',
  'fr',
  '"fr"',
  '"es-MX"',
  'es', // sin comillas: no es JSON
  '"ES"',
  '"System"',
  '"es "',
  '[[[[[[[[[[[[[[[[',
  '{"a":',
  '1',
  '0',
  '1.0',
  '"true"',
  'false',
  'null',
  '[]',
  '["es"]',
  '[true]',
  '{"locale":"es"}',
  '"${'a' * 5000}"',
  'x' * 100000,
  '\u0000',
];

void main() {
  group('decodeLocaleChoice', () {
    test('CA-015-26: solo system, es y en exactos dan su valor', () {
      expect(decodeLocaleChoice('"system"'), LocaleChoice.system);
      expect(decodeLocaleChoice('"es"'), LocaleChoice.es);
      expect(decodeLocaleChoice('"en"'), LocaleChoice.en);
    });

    test(
      'CA-015-26: cualquier otro valor da "Como el sistema", sin lanzar',
      () {
        for (final raw in [..._garbage, 'true']) {
          expect(
            decodeLocaleChoice(raw),
            LocaleChoice.system,
            reason: 'entrada: ${raw?.substring(0, raw.length.clamp(0, 20))}',
          );
        }
      },
    );

    test('CA-015-26: lo que se escribe se lee igual', () {
      for (final choice in LocaleChoice.values) {
        expect(decodeLocaleChoice(encodeLocaleChoice(choice)), choice);
      }
    });

    test('CA-015-26: una cadena de más de 16 caracteres ni se decodifica', () {
      // Cabría en `"es"` más relleno: el tope corta antes de jsonDecode.
      expect(decodeLocaleChoice('"es"${' ' * 20}'), LocaleChoice.system);
      expect(decodeLocaleChoice('"es"${' ' * 12}'), LocaleChoice.es);
    });
  });

  group('decodeKeepScreenOn', () {
    test('CA-015-26: solo el booleano true exacto enciende', () {
      expect(decodeKeepScreenOn('true'), isTrue);
    });

    test('CA-015-26: cualquier otro valor está apagado, sin lanzar', () {
      for (final raw in [..._garbage, '"es"', '"system"']) {
        expect(
          decodeKeepScreenOn(raw),
          isFalse,
          reason: 'entrada: ${raw?.substring(0, raw.length.clamp(0, 20))}',
        );
      }
    });

    test('CA-015-26: lo que se escribe se lee igual', () {
      expect(decodeKeepScreenOn(encodeFlag(true)), isTrue);
      expect(decodeKeepScreenOn(encodeFlag(false)), isFalse);
    });
  });

  group('decodeLockZoom', () {
    test('CA-017-03: solo el texto `true` exacto enciende el bloqueo', () {
      expect(decodeLockZoom('true'), isTrue);
      expect(decodeLockZoom(encodeFlag(true)), isTrue);
    });

    test('CA-017-03: cualquier otro valor está apagado, sin lanzar', () {
      for (final raw in [
        ..._garbage,
        '"es"',
        '"system"',
        ' true',
        'true ',
        'true\n',
        '\ttrue',
        'TRUE',
        'True',
        '"true"',
        'tru',
        'truee',
        '[[[[[[[[[[[[[[[[[',
        // En la frontera de 16 y 17 caracteres (tope del decodificador).
        'true${' ' * 12}',
        'true${' ' * 13}',
        'a' * 16,
        'a' * 17,
        'true${'e' * 100000}',
      ]) {
        expect(
          decodeLockZoom(raw),
          isFalse,
          reason: 'entrada: ${raw?.substring(0, raw.length.clamp(0, 20))}',
        );
      }
    });

    test('CA-017-03: lo que se escribe se lee igual', () {
      expect(decodeLockZoom(encodeFlag(true)), isTrue);
      expect(decodeLockZoom(encodeFlag(false)), isFalse);
    });
  });

  group('SettingKeys', () {
    test(
      'CA-017-16: la clave del bloqueo es `lockZoom`, junto a las otras dos',
      () {
        expect(SettingKeys.lockZoom, 'lockZoom');
        expect(SettingKeys.keepScreenOn, 'keepScreenOn');
        expect(SettingKeys.locale, 'locale');
      },
    );
  });

  group('decodeFlag (firstRunDone, hasEverHadTasks)', () {
    test('CL-015-18: solo true exacto; lo demás falla cerrado a false', () {
      expect(decodeFlag('true'), isTrue);
      for (final raw in _garbage) {
        expect(decodeFlag(raw), isFalse);
      }
    });
  });
}
