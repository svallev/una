import 'dart:io';

import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/services/privacy_link.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_release_config.dart';

/// Una política sin huecos (mínima, con las dos partes y las notas al final).
const _cleanPolicy = '''
# Política de privacidad / Privacy policy — BORRADOR

> Los huecos entre corchetes son [Pendiente]: `[NOMBRE DE LA APP]`, `[FECHA]`.

---

# Política de privacidad (ES)

**Última actualización:** 30 de septiembre de 2026

Escribe a hola@ejemplo.org.

---

# Privacy policy (EN)

**Last updated:** September 30, 2026

Write to hello@sample.org.

---

## Notas para la revisión (no forman parte del texto publicado)

1. Rellenar `[NOMBRE DE LA APP]`, `[RESPONSABLE]`, `[CONTACTO]` y `[FECHA]`.
''';

/// Ejecuta el script de la puerta con [args]; devuelve el resultado.
ProcessResult _runScript(List<String> args) => Process.runSync(
  'bash',
  ['../tools/check-release-config.sh', ...args],
  environment: {...Platform.environment},
);

void main() {
  group('CA-012-05: la dirección de la política (checkPrivacyUrl)', () {
    test('CA-012-05: el marcador de hoy falla con un mensaje claro', () {
      final errors = checkPrivacyUrl('https://example.com/privacy');
      expect(errors, hasLength(1));
      expect(errors.single, contains('reservado'));
      expect(errors.single, contains('example.com'));
    });

    test('CA-012-05: una dirección con dominio propio pasa', () {
      expect(checkPrivacyUrl('https://una-app.dev/privacy'), isEmpty);
      expect(
        checkPrivacyUrl('https://politica.mi-app.es/es/privacidad'),
        isEmpty,
      );
    });

    for (final (address, reason) in <(String, String)>[
      ('https://EXAMPLE.com/privacy', 'mayúsculas'),
      ('https://example.com./privacy', 'punto final'),
      ('https://www.example.com/privacy', 'subdominio'),
      ('https://a.b.example.net/privacy', 'subdominio profundo de example.net'),
      ('https://example.org/privacy', 'example.org'),
      ('https://foo.example/privacy', 'TLD .example'),
      ('https://foo.test/privacy', 'TLD .test'),
      ('https://foo.invalid/privacy', 'TLD .invalid'),
      ('https://foo.localhost/privacy', 'TLD .localhost'),
      ('https://localhost/privacy', 'localhost'),
      ('https://LOCALHOST./privacy', 'localhost con punto y mayúsculas'),
    ]) {
      test('CA-012-05: falla con un dominio reservado ($reason)', () {
        expect(checkPrivacyUrl(address), isNotEmpty, reason: address);
      });
    }

    test('CA-012-05: "notexample.com" no es un dominio reservado', () {
      expect(checkPrivacyUrl('https://notexample.com/privacy'), isEmpty);
    });

    for (final (address, reason) in <(String, String)>[
      ('http://una-app.dev/privacy', 'http'),
      ('HTTP://una-app.dev/privacy', 'http en mayúsculas'),
      ('ftp://una-app.dev/privacy', 'otro esquema'),
      ('javascript:alert(1)', 'javascript'),
      ('una-app.dev/privacy', 'sin esquema'),
      ('', 'vacía'),
      ('https://', 'sin dominio'),
      ('https://user@una-app.dev/privacy', 'usuario'),
      ('https://user:clave@una-app.dev/privacy', 'usuario y clave'),
      ('https://una-app.dev:8443/privacy', 'puerto'),
      ('https://192.168.1.10/privacy', 'IPv4'),
      ('https://8.8.8.8/privacy', 'IPv4 pública'),
      ('https://[2001:db8::1]/privacy', 'IPv6'),
      ('https://2130706433/privacy', 'IPv4 en decimal'),
      ('https://0x7f.0.0.1/privacy', 'IPv4 en hexadecimal'),
      ('https://intranet/privacy', 'sin punto (no es público)'),
      ('https://una app.dev/privacy', 'espacio'),
    ]) {
      test('CA-012-05: falla con una dirección no válida ($reason)', () {
        expect(checkPrivacyUrl(address), isNotEmpty, reason: address);
      });
    }

    test('CA-012-05: los espacios de los extremos no la esconden', () {
      expect(checkPrivacyUrl('  https://example.com/privacy  '), isNotEmpty);
      expect(checkPrivacyUrl('  https://una-app.dev/privacy  '), isEmpty);
    });

    test('CA-012-05: nunca es más permisiva que privacyLink (misma regla que la app)', () {
      // La herramienta no puede importar `privacyLink` (arrastra `flutter`,
      // y `dart run` no tiene `dart:ui`): este test evita que se separen.
      const samples = [
        'https://una-app.dev/privacy',
        'https://example.com/privacy',
        'http://una-app.dev/privacy',
        'https://user@una-app.dev/privacy',
        'https://una-app.dev:8443/x',
        'https://192.168.1.10/x',
        'https://[::1]/x',
        'https://intranet/x',
        'https://una app.dev/x',
        'https://',
        '',
        'javascript:alert(1)',
        'mailto:a@b.co',
        '  https://una-app.dev/privacy  ',
        'https://xn--e1afmkfd.xn--p1ai/x',
        'https://a.b.c.d.e.fr/x',
      ];
      for (final s in samples) {
        if (checkPrivacyUrl(s).isEmpty) {
          expect(privacyLink(s), isA<WebLink>(), reason: s);
        }
      }
    });
  });

  group('CA-012-05: los huecos de la política (checkPolicyText)', () {
    test('CA-012-05: sin huecos pasa; las notas y la cabecera no cuentan', () {
      expect(checkPolicyText(_cleanPolicy), isEmpty);
    });

    for (final gap in [
      '[NOMBRE DE LA APP]',
      '[FECHA]',
      '[RESPONSABLE]',
      '[CONTACTO]',
    ]) {
      test('CA-012-05: falla con $gap en la parte española', () {
        final policy = _cleanPolicy.replaceFirst(
          'Escribe a hola@ejemplo.org.',
          'Escribe a $gap.',
        );
        final errors = checkPolicyText(policy);
        expect(errors, hasLength(1));
        expect(errors.single, contains(gap));
        expect(errors.single, contains('ES'));
      });
    }

    for (final gap in ['[APP NAME]', '[DATE]', '[CONTROLLER]', '[CONTACT]']) {
      test('CA-012-05: falla con $gap en la parte inglesa', () {
        final policy = _cleanPolicy.replaceFirst(
          'Write to hello@sample.org.',
          'Write to $gap.',
        );
        final errors = checkPolicyText(policy);
        expect(errors, hasLength(1));
        expect(errors.single, contains(gap));
        expect(errors.single, contains('EN'));
      });
    }

    test('CA-012-05: el borrador real de hoy falla (huecos ES y EN)', () {
      final text = File('../docs/legal/privacy-policy.md').readAsStringSync();
      final errors = checkPolicyText(text);
      expect(errors, isNotEmpty);
      expect(errors.join('\n'), contains('[NOMBRE DE LA APP]'));
      expect(errors.join('\n'), contains('[APP NAME]'));
    });

    test('CA-012-05: falla si falta una de las dos partes', () {
      final onlyEs = _cleanPolicy.replaceFirst(
        '# Privacy policy (EN)',
        '# Otra',
      );
      expect(checkPolicyText(onlyEs), isNotEmpty);
      final onlyEn = _cleanPolicy.replaceFirst(
        '# Política de privacidad (ES)',
        '# Otra',
      );
      expect(checkPolicyText(onlyEn), isNotEmpty);
    });

    test(
      'CA-012-05: un hueco escrito en minúsculas o con espacios también cuenta',
      () {
        final policy = _cleanPolicy.replaceFirst(
          'Escribe a hola@ejemplo.org.',
          'Escribe a [ Contacto ].',
        );
        expect(checkPolicyText(policy), isNotEmpty);
      },
    );
  });

  group('CA-012-05: el script tools/check-release-config.sh', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('release_config_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    File policy(String text) =>
        File('${tmp.path}/policy.md')..writeAsStringSync(text);

    test('CA-012-05: hoy falla (marcador y huecos) con mensajes claros', () {
      final result = _runScript([]);
      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      final out = '${result.stdout}${result.stderr}';
      expect(out, contains('example.com'));
      expect(out, contains('[NOMBRE DE LA APP]'));
    });

    test('CA-012-05: falla con una dirección reservada aunque la política esté limpia', () {
      final result = _runScript([
        '--url',
        'https://www.EXAMPLE.com/privacy',
        '--policy',
        policy(_cleanPolicy).path,
      ]);
      expect(result.exitCode, 1);
      expect('${result.stdout}${result.stderr}', contains('reservado'));
    });

    test('CA-012-05: falla con una política con huecos aunque la dirección sea buena', () {
      final result = _runScript([
        '--url',
        'https://una-app.dev/privacy',
        '--policy',
        policy(_cleanPolicy.replaceFirst('30 de septiembre de 2026', '[FECHA]'))
            .path,
      ]);
      expect(result.exitCode, 1);
      expect('${result.stdout}${result.stderr}', contains('[FECHA]'));
    });

    test('CA-012-05: pasa con valores de prueba en un directorio temporal', () {
      final result = _runScript([
        '--url',
        'https://una-app.dev/privacy',
        '--policy',
        policy(_cleanPolicy).path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('CA-012-05: una política que no existe falla', () {
      final result = _runScript([
        '--url',
        'https://una-app.dev/privacy',
        '--policy',
        '${tmp.path}/no-existe.md',
      ]);
      expect(result.exitCode, 1);
    });

    test('CA-012-05: un argumento desconocido falla (no se ignora)', () {
      final result = _runScript(['--nope']);
      expect(result.exitCode, isNot(0));
    });
  }, skip: Platform.isWindows ? 'necesita bash' : null);
}
