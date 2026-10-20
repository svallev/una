import 'dart:convert';
import 'dart:io';

import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/services/privacy_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/check_release_config.dart' as gate;
import '../../tool/check_release_config.dart' show GateIssueKind;

// Las comprobaciones de la puerta devuelven errores con clase (`GateIssue`); casi todos los tests
// de aquí miran solo su texto (`<clave>: <motivo>`), y los de la clase usan `gate.` directamente.
List<String> checkAddress(String key, Object? value) => [
  for (final i in gate.checkAddress(key, value)) i.line,
];
List<String> checkAddresses(Map<String, Object?> values) => [
  for (final i in gate.checkAddresses(values)) i.line,
];
List<String> checkIdentity(Object? root) => [
  for (final i in gate.checkIdentity(root)) i.line,
];
List<String> checkPolicyText(String text) => [
  for (final i in gate.checkPolicyText(text)) i.line,
];

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

/// Las tres claves de `identity.yaml` que son direcciones (CA-015-13b).
const _keys = ['privacyPolicyUrl', 'thirdPartyLicensesUrl', 'helpUrl'];

/// El marcador de hoy de [page] (`privacy`, `licenses` o `help`).
String _marker(String page) => 'https://example.com/$page';

/// Los archivos (relativos a `app/`) que escribe `tool/gen_identity.dart`.
const _generatedFiles = [
  'identity.yaml',
  'lib/app/app_identity.g.dart',
  'android/app/src/main/res/values/strings.xml',
  'ios/Flutter/Identity.xcconfig',
  'ios/Flutter/Debug.xcconfig',
  'ios/Flutter/Release.xcconfig',
  'ios/Runner/Info.plist',
  'web/index.html',
  'web/manifest.json',
];

/// Ejecuta el script de la puerta con [args]; devuelve el resultado.
ProcessResult _runScript(List<String> args) => Process.runSync(
  'bash',
  ['../tools/check-release-config.sh', ...args],
  environment: {...Platform.environment},
);

void main() {
  group('CA-015-13b: una dirección (checkAddress)', () {
    test('CA-012-05: el marcador de hoy falla con un mensaje claro', () {
      final errors = checkAddress('privacyPolicyUrl', _marker('privacy'));
      expect(errors, hasLength(1));
      expect(errors.single, contains('privacyPolicyUrl'));
      expect(errors.single, contains('reservado'));
      expect(errors.single, contains('example.com'));
    });

    test('CA-012-05: una dirección con dominio propio pasa', () {
      for (final key in _keys) {
        expect(checkAddress(key, 'https://una-app.dev/privacy'), isEmpty);
        expect(
          checkAddress(key, 'https://politica.mi-app.es/es/privacidad'),
          isEmpty,
        );
        expect(checkAddress(key, 'https://una-app.dev'), isEmpty);
      }
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
      ('https://foo.local/privacy', 'TLD .local'),
      ('https://foo.internal/privacy', 'TLD .internal'),
      ('https://foo.lan/privacy', 'TLD .lan'),
      ('https://foo.localdomain/privacy', 'TLD .localdomain'),
      ('https://foo.onion/privacy', 'TLD .onion'),
      ('https://home.arpa/privacy', 'home.arpa'),
      ('https://router.home.arpa/privacy', 'subdominio de home.arpa'),
      ('https://yourdomain.com/privacy', 'yourdomain.com'),
      ('https://www.yourdomain.com/privacy', 'subdominio de yourdomain.com'),
      ('https://foo.xn--0zwm56d/privacy', 'IDN de prueba (chino simplificado)'),
      ('https://foo.xn--g6w251d/privacy', 'IDN de prueba (chino tradicional)'),
      ('https://foo.xn--80akhbyknj4f/privacy', 'IDN de prueba (ruso)'),
      ('https://foo.xn--11b5bs3a9aj6g/privacy', 'IDN de prueba (hindi)'),
      ('https://foo.xn--jxalpdlp/privacy', 'IDN de prueba (griego)'),
      ('https://foo.xn--9t4b11yi5a/privacy', 'IDN de prueba (coreano)'),
      ('https://foo.xn--deba0ad/privacy', 'IDN de prueba (yidis)'),
      ('https://foo.xn--zckzah/privacy', 'IDN de prueba (japonés)'),
      ('https://foo.xn--hlcj6aya9esc7a/privacy', 'IDN de prueba (tamil)'),
      ('https://foo.xn--kgbechtv/privacy', 'IDN de prueba (árabe)'),
      ('https://foo.xn--hgbk6aj7f53bba/privacy', 'IDN de prueba (persa)'),
    ]) {
      test('CA-015-13b: falla con un dominio reservado ($reason)', () {
        for (final key in _keys) {
          final errors = checkAddress(key, address);
          expect(errors, isNotEmpty, reason: '$key $address');
          expect(errors.join('\n'), contains(key));
        }
      });
    }

    test('CA-012-05: "notexample.com" no es un dominio reservado', () {
      expect(
        checkAddress('privacyPolicyUrl', 'https://notexample.com/privacy'),
        isEmpty,
      );
      expect(
        checkAddress('helpUrl', 'https://mi-yourdomain.com/help'),
        isEmpty,
      );
    });

    for (final (address, reason) in <(String, String)>[
      ('http://una-app.dev/privacy', 'http'),
      ('HTTP://una-app.dev/privacy', 'http en mayúsculas'),
      ('ftp://una-app.dev/privacy', 'otro esquema'),
      ('javascript:alert(1)', 'javascript'),
      ('una-app.dev/privacy', 'sin esquema'),
      ('', 'vacía'),
      ('   ', 'solo espacios'),
      ('https://', 'sin dominio'),
      ('https:///privacy', 'sin dominio y con ruta'),
      ('https://user@una-app.dev/privacy', 'usuario'),
      ('https://user:clave@una-app.dev/privacy', 'usuario y clave'),
      ('https://@una-app.dev/privacy', 'arroba vacía'),
      ('https://una-app.dev:8443/privacy', 'puerto'),
      ('https://una-app.dev:443/privacy', 'puerto 443 explícito'),
      ('https://una-app.dev:/privacy', 'dos puntos sin número'),
      ('https://192.168.1.10/privacy', 'IPv4'),
      ('https://8.8.8.8/privacy', 'IPv4 pública'),
      ('https://[2001:db8::1]/privacy', 'IPv6'),
      ('https://[2001:db8::1]:8443/privacy', 'IPv6 con puerto'),
      ('https://2130706433/privacy', 'IPv4 en decimal'),
      ('https://0x7f.0.0.1/privacy', 'IPv4 en hexadecimal'),
      ('https://intranet/privacy', 'sin punto (no es público)'),
      ('https://una app.dev/privacy', 'espacio'),
      ('https://una-app.dev/pri\tvacy', 'tabulador'),
      ('https://una-app.dev/pri\x00vacy', 'carácter de control'),
      ('https://una-app.dev/privacy?lang=es', 'consulta'),
      ('https://una-app.dev/privacy?', 'consulta vacía'),
      ('https://una-app.dev/privacy#top', 'fragmento'),
      ('https://una-app.dev/privacy#', 'fragmento vacío'),
      (r'https://una-app.dev\@evil.dev/privacy', 'barra invertida'),
      (r'https://una-app.dev/pri\vacy', 'barra invertida en la ruta'),
      ('https://ñandú.es/privacy', 'host con caracteres no ASCII'),
      ('https://una-app.dév/privacy', 'host con una vocal acentuada'),
      ('https://exa%6dple-app.dev/privacy', '% en el host'),
      ('https://una%2eapp.dev/privacy', '% que codifica un punto'),
      ('mailto:a@una-app.dev', 'mailto'),
    ]) {
      test('CA-015-13b: falla con una dirección no válida ($reason)', () {
        for (final key in _keys) {
          final errors = checkAddress(key, address);
          expect(errors, isNotEmpty, reason: '$key $address');
          expect(errors.join('\n'), contains(key));
        }
      });
    }

    for (final (value, reason) in <(Object?, String)>[
      (null, 'ausente o sin valor'),
      (42, 'un número'),
      (true, 'un booleano'),
      (<String>['https://una-app.dev/privacy'], 'una lista'),
      (<String, String>{'u': 'https://una-app.dev/privacy'}, 'un mapa'),
    ]) {
      test(
        'CA-015-13b: una clave que es $reason es un error con su nombre',
        () {
          for (final key in _keys) {
            final errors = checkAddress(key, value);
            expect(errors, hasLength(1), reason: '$key $value');
            expect(errors.single, startsWith('$key:'));
          }
        },
      );
    }

    test('CA-012-05: los espacios de los extremos no la esconden', () {
      expect(
        checkAddress('privacyPolicyUrl', '  https://example.com/privacy  '),
        isNotEmpty,
      );
      expect(
        checkAddress('privacyPolicyUrl', '  https://una-app.dev/privacy  '),
        isEmpty,
      );
    });

    test(
      'CA-015-13b: el mensaje nombra la clave que falla y no a las otras',
      () {
        final errors = checkAddresses({
          'privacyPolicyUrl': 'https://una-app.dev/privacy',
          'thirdPartyLicensesUrl': 'https://una-app.dev/licenses',
          'helpUrl': 'https://help.example.com/help',
        });
        expect(errors, hasLength(1));
        expect(errors.single, startsWith('helpUrl:'));
      },
    );

    test('CA-015-13b: nunca es más permisiva que privacyLink (misma regla '
        'que la app, para las tres claves)', () {
      // La herramienta no puede importar `privacyLink` (arrastra `flutter`,
      // y `dart run` no tiene `dart:ui`): este test evita que se separen.
      const samples = [
        'https://una-app.dev/privacy',
        'https://example.com/privacy',
        'http://una-app.dev/privacy',
        'https://user@una-app.dev/privacy',
        'https://una-app.dev:8443/x',
        'https://una-app.dev:443/x',
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
        'https://una-app.dev/x?y=1',
        'https://una-app.dev/x#y',
        r'https://una-app.dev\@evil.dev/x',
        'https://ñandú.es/x',
        'https://exa%6dple-app.dev/x',
        'https://foo.local/x',
        'https://home.arpa/x',
      ];
      for (final key in _keys) {
        for (final s in samples) {
          if (checkAddress(key, s).isEmpty) {
            expect(privacyLink(s), isA<WebLink>(), reason: '$key $s');
          }
        }
      }
    });
  });

  group('CA-020-09: la ruta de una dirección, restringida', () {
    /// Los caracteres invisibles o de dirección que la spec rechaza.
    final invisible = <int>[
      0x200B,
      0x200E,
      0x200F,
      for (var c = 0x202A; c <= 0x202E; c++) c,
      for (var c = 0x2066; c <= 0x2069; c++) c,
    ];

    for (final path in [
      '',
      '/',
      '/privacy',
      '/Privacy',
      '/privacy/',
      '/a/b-c_d.e~f/',
      '/es/privacidad.html',
      '/.well-known',
      '/a..b',
      '/...',
    ]) {
      test('CA-020-09: la ruta "$path" es válida', () {
        for (final key in _keys) {
          expect(
            checkAddress(key, 'https://una-app.dev$path'),
            isEmpty,
            reason: '$key $path',
          );
        }
      });
    }

    for (final c in invisible) {
      final hex = c.toRadixString(16).toUpperCase();
      test('CA-020-09: falla con el carácter invisible U+$hex en la ruta', () {
        final address = 'https://una-app.dev/pri${String.fromCharCode(c)}vacy';
        for (final key in _keys) {
          final issues = gate.checkAddress(key, address);
          expect(issues, isNotEmpty, reason: '$key U+$hex');
          expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
          expect(issues.map((i) => i.line).join('\n'), contains('invisible'));
          expect(issues.every((i) => i.subject == key), isTrue);
        }
      });
    }

    test('CA-020-09: el invisible al final de la ruta tampoco se cuela', () {
      final address =
          'https://una-app.dev/privacy${String.fromCharCode(0x200B)}';
      expect(checkAddress('helpUrl', address), isNotEmpty);
    });

    for (final (path, reason) in <(String, String)>[
      ('/%2e', '%2e (un punto)'),
      ('/%2E', '%2E'),
      ('/%2f', '%2f (una barra)'),
      ('/%5c', '%5c (una barra invertida)'),
      ('/%00', '%00 (un nulo)'),
      ('/a%20b', '%20 (un espacio)'),
      ('/%', 'un % suelto'),
      ('/privacy%', 'un % al final'),
    ]) {
      test('CA-020-09: falla con $reason en la ruta', () {
        for (final key in _keys) {
          final issues = gate.checkAddress(key, 'https://una-app.dev$path');
          expect(issues, isNotEmpty, reason: '$key $path');
          expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
          expect(issues.map((i) => i.line).join('\n'), contains('`%`'));
        }
      });
    }

    for (final path in ['/.', '/..', '/a/./b', '/a/../b', '/a/..', '/./a']) {
      test('CA-020-09: falla con el segmento . o .. en "$path"', () {
        for (final key in _keys) {
          final issues = gate.checkAddress(key, 'https://una-app.dev$path');
          expect(issues, isNotEmpty, reason: '$key $path');
          expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
          expect(issues.map((i) => i.line).join('\n'), contains('segmento'));
        }
      });
    }

    for (final path in ['//', '//privacy', '/a//b', '/a//', '///']) {
      test('CA-020-09: falla con la barra doble en "$path"', () {
        for (final key in _keys) {
          final issues = gate.checkAddress(key, 'https://una-app.dev$path');
          expect(issues, isNotEmpty, reason: '$key $path');
          expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
          expect(issues.map((i) => i.line).join('\n'), contains('//'));
        }
      });
    }

    // Todo lo que no sea letra ASCII, cifra, `. _ ~ - /` se rechaza, aunque `Uri` lo admita.
    for (final ch in [
      'ñ',
      ':',
      "'",
      '@',
      ';',
      ',',
      '(',
      ')',
      '+',
      '=',
      '&',
      '!',
      '*',
      r'$',
      '"',
      '<',
      '|',
      '^',
      '`',
      '[',
      '{',
    ]) {
      test('CA-020-09: falla con "$ch" en la ruta (solo ASCII permitido)', () {
        for (final key in _keys) {
          final issues = gate.checkAddress(key, 'https://una-app.dev/a${ch}b');
          expect(issues, isNotEmpty, reason: '$key $ch');
          expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
        }
      });
    }

    test('CA-020-09: las reglas de hoy se mantienen (https, sin usuario ni '
        'puerto, sin ? # ni barra invertida)', () {
      for (final address in [
        'http://una-app.dev/privacy',
        'https://user@una-app.dev/privacy',
        'https://una-app.dev:8443/privacy',
        'https://una-app.dev/privacy?x=1',
        'https://una-app.dev/privacy#x',
        r'https://una-app.dev/pri\vacy',
        'https://ñandú.es/privacy',
      ]) {
        final issues = gate.checkAddress('privacyPolicyUrl', address);
        expect(issues, isNotEmpty, reason: address);
        expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
      }
    });

    test('CA-020-09: la puerta no es más permisiva que privacyLink con las '
        'rutas restringidas', () {
      for (final path in [
        '/privacy',
        '/a/./b',
        '/a/../b',
        '//x',
        '/%2e',
        '/a%2fb',
        '/a b',
        '/ñ',
        '/a@b',
      ]) {
        final address = 'https://una-app.dev$path';
        if (checkAddress('helpUrl', address).isEmpty) {
          expect(privacyLink(address), isA<WebLink>(), reason: address);
        }
      }
    });
  });

  group('CA-020-10: dominios reservados completos y con fuente', () {
    for (final suffix in [
      'alt',
      'home',
      'corp',
      'mail',
      'intranet',
      'private',
      'arpa',
    ]) {
      for (final (host, reason) in [
        ('foo.$suffix', 'en minúsculas'),
        ('FOO.${suffix.toUpperCase()}', 'en mayúsculas'),
        ('foo.$suffix.', 'con punto final'),
        ('Foo.${suffix.toUpperCase()}.', 'en mayúsculas y con punto final'),
        ('a.b.$suffix', 'con subdominios'),
      ]) {
        test('CA-020-10: rechaza el sufijo .$suffix ($reason)', () {
          for (final key in _keys) {
            final issues = gate.checkAddress(key, 'https://$host/privacy');
            expect(issues, isNotEmpty, reason: '$key $host');
            expect(
              issues.map((i) => i.kind),
              everyElement(GateIssueKind.placeholderAddress),
              reason: '$key $host',
            );
          }
        });
      }
    }

    test('CA-020-10: los de hoy también aguantan mayúsculas y punto final', () {
      for (final host in [
        'FOO.EXAMPLE.',
        'Foo.Test.',
        'foo.INVALID.',
        'foo.LOCALHOST.',
        'Foo.Local.',
        'foo.INTERNAL.',
        'foo.LAN.',
        'foo.LOCALDOMAIN.',
        'foo.ONION.',
        'EXAMPLE.COM.',
        'Www.Example.Net.',
        'x.EXAMPLE.ORG.',
        'YOURDOMAIN.COM.',
        'HOME.ARPA.',
      ]) {
        expect(
          gate.checkAddress('helpUrl', 'https://$host/privacy'),
          isNotEmpty,
          reason: host,
        );
      }
    });

    test(
      'CA-020-10: un dominio que solo contiene el sufijo no se confunde',
      () {
        for (final host in [
          'altitud.es',
          'homes.es',
          'mi-home.com',
          'corporacion.com',
          'mailing.org',
          'intranets.net',
          'private-app.dev',
          'arpanet.com',
          'mail.com',
        ]) {
          expect(
            checkAddress('helpUrl', 'https://$host/help'),
            isEmpty,
            reason: host,
          );
        }
      },
    );

    test('CA-020-10: la fuente y la fecha de la lista IDN constan en el '
        'código y la [Suposición] ha desaparecido', () {
      expect(gate.idnTestTldsSource, startsWith('https://www.iana.org/'));
      expect(gate.idnTestTldsCheckedOn, matches(r'^\d{4}-\d{2}-\d{2}$'));
      final source = File('tool/check_release_config.dart').readAsStringSync();
      expect(source, isNot(contains('escrita de memoria')));
      expect(source, isNot(contains('pendiente de contrastar')));
      expect(source, contains(gate.idnTestTldsSource));
      expect(source, contains(gate.idnTestTldsCheckedOn));
    });

    // Los 11 TLD de «Test IDN top-level domains» de IANA (2026-10-14), con las mayúsculas y el punto.
    for (final tld in [
      'xn--kgbechtv',
      'xn--hgbk6aj7f53bba',
      'xn--0zwm56d',
      'xn--g6w251d',
      'xn--80akhbyknj4f',
      'xn--11b5bs3a9aj6g',
      'xn--jxalpdlp',
      'xn--9t4b11yi5a',
      'xn--deba0ad',
      'xn--zckzah',
      'xn--hlcj6aya9esc7a',
    ]) {
      test('CA-020-10: el TLD de prueba IDN $tld se rechaza', () {
        for (final host in ['foo.$tld', 'FOO.${tld.toUpperCase()}.']) {
          final issues = gate.checkAddress('helpUrl', 'https://$host/help');
          expect(issues, isNotEmpty, reason: host);
          expect(
            issues.map((i) => i.kind),
            everyElement(GateIssueKind.placeholderAddress),
            reason: host,
          );
        }
      });
    }

    test('CL-020-8: un punycode que no es de prueba se admite', () {
      for (final host in [
        'xn--e1afmkfd.xn--p1ai',
        'xn--nding-0ra.es',
        'una.xn--80asehdb',
        'xn--mgbaam7a8h.example-app.ae',
      ]) {
        expect(
          checkAddress('helpUrl', 'https://$host/help'),
          isEmpty,
          reason: host,
        );
      }
    });
  });

  group('CL-020-6 a 8: direcciones válidas y su normalización', () {
    test('CL-020-6: un dominio propio sin ruta o con "/" es válido', () {
      for (final key in _keys) {
        expect(checkAddress(key, 'https://dominio-propio.es'), isEmpty);
        expect(checkAddress(key, 'https://dominio-propio.es/'), isEmpty);
      }
    });

    test('CL-020-7: el dominio en mayúsculas es válido y las rutas distinguen '
        'mayúsculas', () {
      for (final key in _keys) {
        expect(checkAddress(key, 'https://DOMINIO-PROPIO.ES/Privacy'), isEmpty);
      }
      // El mismo dominio con rutas que solo difieren en mayúsculas no son la misma dirección.
      expect(
        checkAddresses({
          'privacyPolicyUrl': 'https://dominio-propio.es/Privacy',
          'thirdPartyLicensesUrl': 'https://DOMINIO-PROPIO.ES/privacy',
          'helpUrl': 'https://dominio-propio.es/help',
        }),
        isEmpty,
      );
    });

    test(
      'CL-020-7: pero el dominio reservado en mayúsculas sigue fallando',
      () {
        expect(
          checkAddress('helpUrl', 'https://EXAMPLE.COM/Privacy'),
          isNotEmpty,
        );
      },
    );
  });

  group('CA-020-05 (a): la clase de cada error de una dirección', () {
    GateIssueKind kindOf(String address, {String key = 'helpUrl'}) {
      final issues = gate.checkAddress(key, address);
      expect(issues, isNotEmpty, reason: address);
      final kinds = issues.map((i) => i.kind).toSet();
      expect(kinds, hasLength(1), reason: '$address $kinds');
      return kinds.single;
    }

    for (final address in [
      'https://example.com/help',
      'https://www.EXAMPLE.net/help',
      'https://example.org/help',
      'https://yourdomain.com/help',
      'https://home.arpa/help',
      'https://foo.example/help',
      'https://foo.test/help',
      'https://foo.invalid/help',
      'https://foo.localhost/help',
      'https://localhost/help',
      'https://foo.local/help',
      'https://foo.internal/help',
      'https://foo.lan/help',
      'https://foo.localdomain/help',
      'https://foo.onion/help',
      'https://foo.corp/help',
      'https://foo.xn--zckzah/help',
    ]) {
      test('CA-020-05: $address es un marcador o dominio reservado', () {
        expect(kindOf(address), GateIssueKind.placeholderAddress);
      });
    }

    for (final address in [
      'http://una-app.dev/help',
      'ftp://una-app.dev/help',
      'una-app.dev/help',
      '',
      'https://',
      'https://user@una-app.dev/help',
      'https://una-app.dev:8443/help',
      'https://192.168.1.10/help',
      'https://[2001:db8::1]/help',
      'https://intranet/help',
      'https://una-app.dev/help?x=1',
      'https://una-app.dev/help#x',
      'https://una-app.dev/a/../help',
      'https://una-app.dev/%2e',
      'https://ñandú.es/help',
      'https://una%2eapp.dev/help',
    ]) {
      test('CA-020-05: "$address" es un fallo, no un aviso', () {
        expect(kindOf(address), GateIssueKind.fault);
      });
    }

    for (final value in <Object?>[
      null,
      42,
      true,
      <String>['a'],
    ]) {
      test('CA-020-05: la clave con $value es un fallo', () {
        final issues = gate.checkAddress('helpUrl', value);
        expect(issues, hasLength(1));
        expect(issues.single.kind, GateIssueKind.fault);
        expect(issues.single.subject, 'helpUrl');
      });
    }

    test('CL-020-20: un aviso y un fallo a la vez en la misma dirección son '
        'todos fallos (https://example.com/%2e)', () {
      for (final key in _keys) {
        final issues = gate.checkAddress(key, 'https://example.com/%2e');
        expect(issues.length, greaterThanOrEqualTo(2), reason: key);
        expect(
          issues.map((i) => i.kind),
          everyElement(GateIssueKind.fault),
          reason: '$key: sin ningún aviso suelto',
        );
        expect(issues.map((i) => i.line).join('\n'), contains('example.com'));
      }
    });

    test(
      'CL-020-20: lo mismo con una dirección http de un dominio reservado',
      () {
        final issues = gate.checkAddress('helpUrl', 'http://foo.test/help');
        expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
      },
    );

    test('CA-020-05: el error nombra la clave y cada GateIssue la lleva como '
        'subject', () {
      final issues = gate.checkAddress(
        'privacyPolicyUrl',
        'https://example.com/x',
      );
      expect(issues.single.subject, 'privacyPolicyUrl');
      expect(issues.single.line, startsWith('privacyPolicyUrl: '));
      expect(issues.single.toJson(), {
        'kind': 'placeholderAddress',
        'subject': 'privacyPolicyUrl',
        'message': issues.single.message,
      });
    });

    test('CA-020-05: dos direcciones iguales son un fallo; si además eran '
        'marcadores, sus avisos pasan a fallo', () {
      final same = gate.checkAddresses({
        'privacyPolicyUrl': 'https://una-app.dev/web',
        'thirdPartyLicensesUrl': 'https://una-app.dev/web/',
        'helpUrl': 'https://una-app.dev/help',
      });
      expect(same, hasLength(1));
      expect(same.single.kind, GateIssueKind.fault);

      final markers = gate.checkAddresses({
        'privacyPolicyUrl': 'https://example.com/web',
        'thirdPartyLicensesUrl': 'https://example.com/web/',
        'helpUrl': 'https://example.com/help',
      });
      final byKey = {
        for (final key in _keys)
          key: markers.where((i) => i.line.contains(key)).toList(),
      };
      expect(markers.map((i) => i.kind).toSet(), contains(GateIssueKind.fault));
      for (final key in ['privacyPolicyUrl', 'thirdPartyLicensesUrl']) {
        expect(
          byKey[key]!.map((i) => i.kind),
          everyElement(GateIssueKind.fault),
          reason: key,
        );
      }
      // La tercera no está repetida: su aviso sigue siendo un aviso.
      expect(
        markers.where((i) => i.subject == 'helpUrl').map((i) => i.kind),
        everyElement(GateIssueKind.placeholderAddress),
      );
    });

    test('CA-020-05: un yaml sin las tres claves da fallos; los marcadores de '
        'hoy dan avisos', () {
      final missing = gate.checkIdentity(<String, Object?>{});
      expect(missing.map((i) => i.kind), everyElement(GateIssueKind.fault));
      expect(
        gate.checkIdentity('no es un mapa').single.kind,
        GateIssueKind.fault,
      );
      final today = gate.checkIdentity(
        loadYaml(File('identity.yaml').readAsStringSync()),
      );
      expect(
        today.map((i) => i.kind),
        everyElement(GateIssueKind.placeholderAddress),
      );
    });

    test('CA-020-05: la política con huecos es policyGap y sin las dos partes '
        'es un fallo', () {
      final gaps = gate.checkPolicyText(
        _cleanPolicy.replaceFirst('30 de septiembre de 2026', '[FECHA]'),
      );
      expect(gaps.single.kind, GateIssueKind.policyGap);
      expect(
        gate.checkPolicyText('# Otra cosa').single.kind,
        GateIssueKind.fault,
      );
    });
  });

  group('CA-015-13b: las tres direcciones a la vez (checkAddresses)', () {
    Map<String, Object?> three({
      Object? privacy = 'https://una-app.dev/privacy',
      Object? licenses = 'https://una-app.dev/licenses',
      Object? help = 'https://una-app.dev/help',
    }) => {
      'privacyPolicyUrl': privacy,
      'thirdPartyLicensesUrl': licenses,
      'helpUrl': help,
    };

    test('CA-015-13b: tres direcciones propias y distintas pasan', () {
      expect(checkAddresses(three()), isEmpty);
    });

    test(
      'CA-015-13b: los tres marcadores de hoy fallan, cada uno con su clave',
      () {
        final errors = checkAddresses(
          three(
            privacy: _marker('privacy'),
            licenses: _marker('licenses'),
            help: _marker('help'),
          ),
        );
        expect(errors, hasLength(3));
        for (final key in _keys) {
          expect(errors.where((e) => e.startsWith('$key:')), hasLength(1));
        }
      },
    );

    for (final (a, b, reason) in <(String, String, String)>[
      (
        'https://una-app.dev/privacy',
        'https://una-app.dev/privacy',
        'idénticas',
      ),
      (
        'https://una-app.dev/privacy',
        'https://una-app.dev/privacy/',
        'una con barra final',
      ),
      (
        'https://una-app.dev/privacy/',
        'https://una-app.dev/privacy',
        'la otra con barra final',
      ),
      (
        'https://UNA-APP.dev/privacy',
        'https://una-app.dev./privacy',
        'host en mayúsculas y con punto final',
      ),
      (
        'https://una-app.dev/a/../privacy',
        'https://una-app.dev/privacy',
        'ruta con ..',
      ),
      ('https://una-app.dev', 'https://una-app.dev/', 'solo el dominio'),
      (
        '  https://una-app.dev/privacy  ',
        'https://una-app.dev/privacy',
        'espacios en los extremos',
      ),
    ]) {
      test('CA-015-13b: dos direcciones iguales fallan ($reason)', () {
        for (final (k1, k2) in [
          ('privacyPolicyUrl', 'thirdPartyLicensesUrl'),
          ('privacyPolicyUrl', 'helpUrl'),
          ('thirdPartyLicensesUrl', 'helpUrl'),
        ]) {
          final other = _keys.firstWhere((k) => k != k1 && k != k2);
          final values = {
            k1: a,
            k2: b,
            other: 'https://otra.mi-app.dev/${other.length}',
          };
          final errors = checkAddresses(values);
          expect(errors, isNotEmpty, reason: '$k1 $k2 $a $b');
          expect(
            errors.join('\n'),
            allOf(contains(k1), contains(k2)),
            reason: '$k1 $k2',
          );
        }
      });
    }

    test('CA-015-13b: mismo dominio con otra ruta no es repetida', () {
      expect(
        checkAddresses(
          three(
            privacy: 'https://una-app.dev/privacy',
            licenses: 'https://una-app.dev/privacy/licenses',
            help: 'https://una-app.dev/Privacy',
          ),
        ),
        isEmpty,
      );
    });

    test(
      'CA-015-13b: una clave ausente, vacía o que no es texto es un error',
      () {
        expect(
          checkAddresses(three(help: null)).single,
          startsWith('helpUrl:'),
        );
        expect(
          checkAddresses(three(licenses: '')).single,
          startsWith('thirdPartyLicensesUrl:'),
        );
        expect(
          checkAddresses(three(privacy: 7)).single,
          startsWith('privacyPolicyUrl:'),
        );
      },
    );

    test('CA-015-13b: dos claves sin valor no cuentan como repetidas', () {
      final errors = checkAddresses(three(licenses: null, help: null));
      expect(errors, hasLength(2));
      expect(errors.join('\n'), isNot(contains('misma')));
    });
  });

  group('CA-015-13b: el contenido de identity.yaml (checkIdentity)', () {
    test('CA-015-13b: la raíz que no es un mapa es un error de la puerta', () {
      for (final root in <Object?>[
        null,
        'texto',
        3,
        <String>['a'],
      ]) {
        final errors = checkIdentity(root);
        expect(errors, isNotEmpty, reason: '$root');
        expect(errors.join('\n'), contains('identity.yaml'));
      }
    });

    test('CA-015-13b: un mapa sin las tres claves da un error por clave', () {
      final errors = checkIdentity(<String, Object?>{});
      expect(errors, hasLength(3));
      for (final key in _keys) {
        expect(errors.where((e) => e.startsWith('$key:')), hasLength(1));
      }
    });

    test('CA-015-13b: el yaml del repositorio tiene las tres claves y los '
        'marcadores fallan por reservados', () {
      final yaml = loadYaml(File('identity.yaml').readAsStringSync());
      final errors = checkIdentity(yaml);
      expect(errors, hasLength(3));
      expect(errors.join('\n'), contains('reservado'));
    });
  });

  group('CA-012-05: los huecos de la política (checkPolicyText)', () {
    test('CA-012-05: sin huecos pasa; las notas y la cabecera no cuentan', () {
      expect(checkPolicyText(_cleanPolicy), isEmpty);
    });

    for (final gap in ['[WEB]', '[FECHA]', '[RESPONSABLE]', '[CONTACTO]']) {
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

    for (final gap in ['[WEBSITE]', '[DATE]', '[CONTROLLER]', '[CONTACT]']) {
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

  group('CA-020-11: las marcas de documento de la política', () {
    /// La política mínima con [text] en lugar de `Escribe a hola@ejemplo.org.` (parte ES) o de
    /// `Write to hello@sample.org.` (parte EN).
    String inEs(String text) =>
        _cleanPolicy.replaceFirst('Escribe a hola@ejemplo.org.', text);
    String inEn(String text) =>
        _cleanPolicy.replaceFirst('Write to hello@sample.org.', text);

    // CA-023-01: una marca ya no es un aviso de identidad sino un `fault` (en los dos modos).
    List<gate.GateIssue> marks(String policy) => [
      for (final i in gate.checkPolicyText(policy))
        if (i.message.contains('lleva la marca')) i,
    ];

    int lineOf(String policy, String needle) =>
        policy.split('\n').indexWhere((l) => l.contains(needle)) + 1;

    final nfd = 'Suposicio${String.fromCharCode(0x301)}n';
    final zeroWidth = String.fromCharCode(0x200B);

    final variants = <String>[
      '[Suposición]',
      '[SUPOSICIÓN]',
      '[suposición]',
      '[Suposicion]',
      '[ Suposición ]',
      '[\tSuposición\t]',
      '[Suposición, PD-9]',
      '[Suposición PD-9: comprobar]',
      '[$nfd]',
      '[$zeroWidth Suposición]',
      '[Pendiente]',
      '[PENDIENTE]',
      '[ pendiente ]',
      '[Pendiente PD-2]',
      '[Assumption]',
      '[ASSUMPTION]',
      '[assumption]',
      '[ Assumption ]',
      '[Assumption, PD-9]',
      '[Pending]',
      '[PENDING]',
      '[ pending ]',
      '[Pending PD-2]',
    ];

    for (final mark in variants) {
      test('CA-020-11: ${mark.replaceAll(zeroWidth, '<ZWSP>')} cuenta en la '
          'parte española y en la inglesa, con su línea', () {
        for (final (label, build, marker)
            in <(String, String Function(String), String)>[
              ('ES', inEs, 'Escribe aquí'),
              ('EN', inEn, 'Write here'),
            ]) {
          final policy = build('$marker $mark fin.');
          final found = marks(policy);
          expect(found, hasLength(1), reason: '$label $mark');
          expect(found.single.subject, 'política ($label)');
          expect(
            found.single.message,
            contains('línea ${lineOf(policy, marker)}'),
          );
        }
      });
    }

    test('CA-020-11: [Hecho] no es una marca (CA-023-01: pero sí texto entre '
        'corchetes, que falla), y las palabras sin corchetes no cuentan', () {
      for (final ok in [
        'Suposición sin corchetes y pendiente sin corchetes',
        'assumption pending',
      ]) {
        expect(gate.checkPolicyText(inEs('A $ok B.')), isEmpty, reason: ok);
        expect(gate.checkPolicyText(inEn('A $ok B.')), isEmpty, reason: ok);
      }
      for (final other in [
        '[Hecho]',
        '[HECHO]',
        '[Hecho, PD-1]',
        '[ Hecho ]',
        '[Done]',
      ]) {
        for (final build in [inEs, inEn]) {
          final found = gate.checkPolicyText(build('A $other B.'));
          expect(found, hasLength(1), reason: other);
          expect(found.single.kind, GateIssueKind.fault);
          expect(marks(build('A $other B.')), isEmpty, reason: other);
        }
      }
    });

    test('CA-020-11: una marca en la cabecera o en las notas de revisión '
        '(fuera de las partes publicadas) no cuenta', () {
      final withNotes = _cleanPolicy.replaceFirst(
        '1. Rellenar',
        '1. [Suposición] [Assumption] [Pendiente] [Pending] Rellenar',
      );
      expect(withNotes, contains('[Assumption] [Pendiente]'));
      expect(gate.checkPolicyText(withNotes), isEmpty);
      final header = _cleanPolicy.replaceFirst(
        '> Los huecos',
        '> [Suposición] [Pending] Los huecos',
      );
      expect(header, contains('[Suposición] [Pending]'));
      expect(gate.checkPolicyText(header), isEmpty);
    });

    test('CA-020-11: cada marca es una entrada, también varias en la misma '
        'línea, con el número de línea de cada una', () {
      final policy = _cleanPolicy
          .replaceFirst(
            'Escribe a hola@ejemplo.org.',
            'Uno [Suposición] y dos [Pendiente PD-2].\n\nTres [Suposición].',
          )
          .replaceFirst(
            'Write to hello@sample.org.',
            'Four [Assumption].\n\nFive [Pending].',
          );
      final found = marks(policy);
      expect(found, hasLength(5));
      expect(found.map((i) => i.subject), [
        'política (ES)',
        'política (ES)',
        'política (ES)',
        'política (EN)',
        'política (EN)',
      ]);
      final lines = [
        lineOf(policy, 'Uno'),
        lineOf(policy, 'Uno'),
        lineOf(policy, 'Tres'),
        lineOf(policy, 'Four'),
        lineOf(policy, 'Five'),
      ];
      for (var i = 0; i < 5; i++) {
        expect(found[i].message, contains('línea ${lines[i]}'), reason: '$i');
      }
      expect(found[1].message, contains('[Pendiente PD-2]'));
    });

    test('CL-020-9: dentro de un bloque de código, de código en línea o de un '
        'comentario HTML cuenta igual', () {
      for (final wrapped in [
        '```\n[Suposición]\n```',
        '`[Pendiente]`',
        '<!-- [Assumption] -->',
        '<!--\n[Pending]\n-->',
        '~~~\n[Suposición PD-9]\n~~~',
      ]) {
        expect(marks(inEs(wrapped)), hasLength(1), reason: wrapped);
        expect(marks(inEn(wrapped)), hasLength(1), reason: wrapped);
      }
    });

    test('CA-020-11: una marca y un hueco a la vez salen con su clase cada '
        'uno, y con un hueco el resto sigue igual', () {
      final policy = inEs('[FECHA] y [Suposición].');
      final kinds = [for (final i in gate.checkPolicyText(policy)) i.kind];
      expect(
        kinds,
        unorderedEquals([GateIssueKind.policyGap, GateIssueKind.fault]),
      );
    });

    test('CA-020-11: una marca sin cerrar el corchete también cuenta', () {
      expect(marks(inEs('Falta [Pendiente de revisar')), hasLength(1));
    });

    test('CA-020-11: con la política real hay 12 o más marcas (ES y EN)', () {
      final text = File('../docs/legal/privacy-policy.md').readAsStringSync();
      final found = marks(text);
      expect(found.length, greaterThanOrEqualTo(12));
      expect(found.where((i) => i.subject == 'política (ES)'), isNotEmpty);
      expect(found.where((i) => i.subject == 'política (EN)'), isNotEmpty);
      // Y ninguna cae en la cabecera ni en las notas: su línea es la de una frase de las partes.
      final notesLine = lineOf(text, '## Notas para la revisión');
      final headerLine = lineOf(text, '# Política de privacidad (ES)');
      for (final i in found) {
        final n = int.parse(RegExp(r'línea (\d+)').firstMatch(i.message)![1]!);
        expect(n, greaterThan(headerLine));
        expect(n, lessThan(notesLine));
      }
    });
  });

  group('CA-023-01: huecos de identidad admitidos y texto entre corchetes', () {
    String inEs(String text) =>
        _cleanPolicy.replaceFirst('Escribe a hola@ejemplo.org.', text);
    String inEn(String text) =>
        _cleanPolicy.replaceFirst('Write to hello@sample.org.', text);

    int lineOf(String policy, String needle) =>
        policy.split('\n').indexWhere((l) => l.contains(needle)) + 1;

    final zeroWidth = String.fromCharCode(0x200B);

    // La lista cerrada de huecos de identidad: aviso en testers, fallo en estricto.
    for (final gap in [
      '[RESPONSABLE]',
      '[CONTROLLER]',
      '[CONTACTO]',
      '[CONTACT]',
      '[FECHA]',
      '[DATE]',
      '[WEB]',
      '[WEBSITE]',
      '[ web ]',
      '[Contacto]',
      '[ website ]',
    ]) {
      test('CA-023-01: $gap es un hueco de identidad (aviso) en las dos '
          'partes', () {
        for (final (label, build, marker)
            in <(String, String Function(String), String)>[
              ('ES', inEs, 'Escribe aquí'),
              ('EN', inEn, 'Write here'),
            ]) {
          final policy = build('$marker $gap fin.');
          final found = gate.checkPolicyText(policy);
          expect(found, hasLength(1), reason: '$label $gap');
          expect(found.single.kind, GateIssueKind.policyGap);
          expect(found.single.subject, 'política ($label)');
          expect(
            found.single.message,
            contains('línea ${lineOf(policy, marker)}'),
          );
        }
      });
    }

    for (final name in ['[NOMBRE DE LA APP]', '[APP NAME]', '[ app name ]']) {
      test('CA-023-01: $name ya no es un hueco admitido: falla en los dos '
          'modos (el nombre sale de {appName})', () {
        for (final build in [inEs, inEn]) {
          final found = gate.checkPolicyText(build('Soy $name fin.'));
          expect(found, hasLength(1), reason: name);
          expect(found.single.kind, GateIssueKind.fault);
          expect(found.single.message, contains(name.trim()));
          expect(found.single.message, contains('{appName}'));
        }
      });
    }

    for (final other in [
      '[XYZ]',
      '[1]',
      '[x]',
      '[^1]',
      '[CONTACTO EXTRA]',
      '[CONT${zeroWidth}ACTO]',
      '[Hecho]',
      '[]',
      '[ ]',
      '[PD-2]',
      '[texto][referencia]',
    ]) {
      test('CA-023-01: texto entre corchetes que no es un enlace '
          '(${other.replaceAll(zeroWidth, '<ZWSP>')}) falla, con su línea', () {
        for (final (label, build, marker)
            in <(String, String Function(String), String)>[
              ('ES', inEs, 'Escribe aquí'),
              ('EN', inEn, 'Write here'),
            ]) {
          final policy = build('$marker $other fin.');
          final found = gate.checkPolicyText(policy);
          expect(found, isNotEmpty, reason: '$label $other');
          expect(found.map((i) => i.kind), everyElement(GateIssueKind.fault));
          expect(found.first.subject, 'política ($label)');
          expect(
            found.first.message,
            contains('línea ${lineOf(policy, marker)}'),
          );
        }
      });
    }

    test('CA-023-01: el texto de un enlace no cuenta (enlace, imagen, '
        'mailto y ruta)', () {
      for (final ok in [
        '[Política de privacidad](https://una-app.dev/privacy)',
        '[escríbenos](mailto:hola@una-app.dev)',
        '[la ayuda](/help)',
        '[arriba](#es)',
        '![logo](logo.png)',
        '[dos\nlíneas](https://una-app.dev/x)',
        '[a](b) y [c](d)',
      ]) {
        expect(
          gate.checkPolicyText(inEs('Mira $ok fin.')),
          isEmpty,
          reason: ok,
        );
        expect(gate.checkPolicyText(inEn('See $ok end.')), isEmpty, reason: ok);
      }
    });

    test('CA-023-01: un enlace no esconde una marca ni un hueco dentro de su '
        'texto', () {
      final mark = gate.checkPolicyText(inEs('[Pendiente](https://x.dev/a)'));
      expect(mark.single.kind, GateIssueKind.fault);
      expect(mark.single.message, contains('marca'));
      final gap = gate.checkPolicyText(inEs('[[CONTACTO]](mailto:a@x.dev)'));
      expect(gap.single.kind, GateIssueKind.policyGap);
    });

    test('CA-023-01: un corchete suelto no se traga el resto del documento '
        '(un grupo no cruza una línea en blanco)', () {
      expect(gate.checkPolicyText(inEs('Falta [algo\n\nmás] fin.')), isEmpty);
      expect(gate.checkPolicyText(inEn('Falta algo]\n\n[más fin.')), isEmpty);
      // En el mismo párrafo sí es un grupo.
      expect(
        gate.checkPolicyText(inEs('Falta [algo\nmás] fin.')),
        hasLength(1),
      );
    });

    test('CA-023-01: {appName} se admite (también junto a un enlace)', () {
      expect(gate.checkPolicyText(inEs('{appName} no recoge datos.')), isEmpty);
      expect(
        gate.checkPolicyText(
          inEn('{appName} and [the help](https://una-app.dev/help).'),
        ),
        isEmpty,
      );
    });

    test('CA-023-01: una marca cuenta una sola vez (no también como texto '
        'entre corchetes) y es un fallo, no un aviso', () {
      for (final mark in [
        '[Suposición]',
        '[Assumption]',
        '[Pendiente]',
        '[Pending]',
        '[Pendiente PD-2]',
        '[Suposición, PD-9]',
      ]) {
        for (final build in [inEs, inEn]) {
          final found = gate.checkPolicyText(build('Dato $mark fin.'));
          expect(found, hasLength(1), reason: mark);
          expect(found.single.kind, GateIssueKind.fault, reason: mark);
          expect(found.single.message, contains('marca'));
        }
      }
    });

    test('CA-023-01: un fallo no esconde un hueco (cada uno con su clase)', () {
      final kinds = [
        for (final i in gate.checkPolicyText(inEs('[CONTACTO] y [XYZ].')))
          i.kind,
      ];
      expect(
        kinds,
        unorderedEquals([GateIssueKind.policyGap, GateIssueKind.fault]),
      );
    });

    test('CA-023-01: la cabecera y las notas de revisión no cuentan, ni con '
        'marcas ni con texto entre corchetes', () {
      final withNotes = _cleanPolicy.replaceFirst(
        '1. Rellenar',
        '1. [XYZ] [NOMBRE DE LA APP] [Pendiente] Rellenar',
      );
      expect(withNotes, contains('[XYZ] [NOMBRE'));
      expect(gate.checkPolicyText(withNotes), isEmpty);
    });

    test(
      'CA-023-01: dentro de código o de un comentario HTML también cuenta '
      '(la política publicada no lleva corchetes sueltos en ninguna parte)',
      () {
        for (final wrapped in [
          '`[XYZ]`',
          '```\n[XYZ]\n```',
          '<!-- [XYZ] -->',
        ]) {
          expect(
            gate.checkPolicyText(inEs(wrapped)),
            hasLength(1),
            reason: wrapped,
          );
        }
      },
    );

    test('CA-023-01: una política limpia, solo con {appName} y huecos de la '
        'lista, da solo avisos de identidad', () {
      final policy = _cleanPolicy
          .replaceFirst(
            'Escribe a hola@ejemplo.org.',
            '{appName}. Responsable: [RESPONSABLE]. Contacto: [CONTACTO]. '
                'Web: [WEB]. Fecha: [FECHA]. Más en [la ayuda](/help).',
          )
          .replaceFirst(
            'Write to hello@sample.org.',
            '{appName}. Controller: [CONTROLLER]. Contact: [CONTACT]. '
                'Website: [WEBSITE]. Date: [DATE]. More in [the help](/help).',
          );
      final found = gate.checkPolicyText(policy);
      expect(found, hasLength(8));
      expect(found.map((i) => i.kind), everyElement(GateIssueKind.policyGap));
    });
  });

  group('CA-023-01: los textos de la web (strings.json y la Ayuda)', () {
    String strings(Map<String, Object?> value) => jsonEncode(value);

    List<gate.GateIssue> checkJson(String json) =>
        gate.checkWebStrings(json, subject: 'strings.json');
    List<gate.GateIssue> checkMd(String md) =>
        gate.checkWebMarkdown(md, subject: 'help.es.md');

    test('CA-023-01: strings.json con los huecos de la lista da avisos, con la '
        'clave de cada uno', () {
      final found = checkJson(
        strings({
          'es': {'webContact': 'Contacto: [CONTACTO]'},
          'en': {'webContact': 'Contact: [CONTACT]'},
        }),
      );
      expect(found, hasLength(2));
      expect(found.map((i) => i.kind), everyElement(GateIssueKind.policyGap));
      expect(found.map((i) => i.subject), everyElement('strings.json'));
      expect(found[0].message, contains('es.webContact'));
      expect(found[1].message, contains('en.webContact'));
    });

    test(
      'CA-023-01: strings.json con {appName}, enlaces, números, nulos y '
      'listas de textos limpios no da nada (la sintaxis de JSON no cuenta)',
      () {
        expect(
          checkJson(
            strings({
              'es': {
                'webHomeTitle': '{appName}',
                'webLink': 'Mira [la ayuda](/help)',
                'n': 3,
                'x': null,
                'list': ['uno', 'dos'],
              },
            }),
          ),
          isEmpty,
        );
      },
    );

    test('CA-023-01: strings.json con texto entre corchetes, una marca o '
        '[NOMBRE DE LA APP] falla, también dentro de una lista', () {
      for (final bad in [
        '[XYZ]',
        '[Pendiente]',
        '[NOMBRE DE LA APP]',
        '[APP NAME]',
      ]) {
        for (final json in [
          strings({
            'es': {'a': 'Hola $bad'},
          }),
          strings({
            'es': {
              'a': ['bien', 'Hola $bad'],
            },
          }),
        ]) {
          final found = checkJson(json);
          expect(found, hasLength(1), reason: '$bad $json');
          expect(found.single.kind, GateIssueKind.fault);
          expect(found.single.subject, 'strings.json');
          expect(found.single.message, contains('es.a'));
        }
      }
    });

    test('CA-023-01: strings.json que no es JSON válido es un fallo', () {
      for (final bad in ['{', 'no es json', '[1, 2,]']) {
        final found = checkJson(bad);
        expect(found, hasLength(1), reason: bad);
        expect(found.single.kind, GateIssueKind.fault);
        expect(found.single.message, contains('JSON'));
      }
    });

    test(
      'CA-023-01: la Ayuda (Markdown) sigue las mismas reglas, con la línea',
      () {
        const md = '''
# Ayuda

Escribe a [CONTACTO]. Mira [la política](/privacy) de {appName}.

<!-- spec 019 -->
Aquí falta [Pendiente] algo y [XYZ] otra cosa.
''';
        final found = checkMd(md);
        expect(found, hasLength(3));
        expect(found.map((i) => i.subject), everyElement('help.es.md'));
        expect(
          found.where((i) => i.kind == GateIssueKind.policyGap),
          hasLength(1),
        );
        expect(found.where((i) => i.kind == GateIssueKind.fault), hasLength(2));
        expect(found.map((i) => i.message).join('\n'), contains('línea 3'));
        expect(found.map((i) => i.message).join('\n'), contains('línea 6'));
        expect(checkMd('# Ayuda\n\nTodo bien con {appName}.\n'), isEmpty);
      },
    );

    group('los archivos (checkWebTextFile / checkWebTexts)', () {
      late Directory tmp;
      setUp(() => tmp = Directory.systemTemp.createTempSync('gate_web_'));
      tearDown(() => tmp.deleteSync(recursive: true));

      String write(String name, String text) {
        final f = File('${tmp.path}/$name')..writeAsStringSync(text);
        return f.path;
      }

      test(
        'CA-023-01: elige el lector por la extensión y nombra el archivo',
        () {
          final json = write('strings.json', '{"es":{"a":"[CONTACTO]"}}');
          final md = write('help.es.md', 'Escribe a [CONTACTO].\n');
          expect(gate.checkWebTextFile(json).single.subject, 'strings.json');
          expect(gate.checkWebTextFile(md).single.subject, 'help.es.md');
          final other = write('notas.txt', 'hola');
          final bad = gate.checkWebTextFile(other);
          expect(bad.single.kind, GateIssueKind.fault);
          expect(bad.single.subject, 'notas.txt');
        },
      );

      test('CA-023-01: ausente, carpeta, vacío o no UTF-8 es un fallo que lo '
          'nombra (falla cerrada)', () {
        final missing = gate.checkWebTextFile('${tmp.path}/no-existe.json');
        expect(missing.single.kind, GateIssueKind.fault);
        expect(missing.single.subject, 'no-existe.json');
        expect(missing.single.message, contains('no existe'));
        Directory('${tmp.path}/dir.md').createSync();
        expect(
          gate.checkWebTextFile('${tmp.path}/dir.md').single.message,
          contains('no es un archivo'),
        );
        expect(
          gate.checkWebTextFile(write('vacio.md', '  \n')).single.message,
          contains('vací'),
        );
        File('${tmp.path}/raro.md').writeAsBytesSync([0xff, 0xfe, 0x41, 0x80]);
        expect(
          gate.checkWebTextFile('${tmp.path}/raro.md').single.kind,
          GateIssueKind.fault,
        );
      });

      test(
        'CA-023-01: qué textos de la web se miran: los dados (obligatorios), '
        'los del repositorio sin --policy o con --web-defaults, y nada con una '
        'política de prueba',
        () {
          final given = gate.selectWebTexts(
            explicit: ['a.json'],
            policyGiven: true,
            webDefaults: true,
          );
          expect(given.$1, ['a.json']);
          expect(given.$2, isTrue);
          for (final (policyGiven, webDefaults) in [
            (false, false),
            (true, true),
          ]) {
            final repo = gate.selectWebTexts(
              explicit: [],
              policyGiven: policyGiven,
              webDefaults: webDefaults,
            );
            expect(repo.$1, gate.defaultWebTexts);
            expect(repo.$2, gate.webTextsRequired);
          }
          final none = gate.selectWebTexts(
            explicit: [],
            policyGiven: true,
            webDefaults: false,
          );
          expect(none.$1, isEmpty);
        },
      );

      test('CA-023-01: los archivos por defecto son los tres de landing/src y '
          'hoy no hace falta que existan (T-023-07 lo exige)', () {
        expect(gate.defaultWebTexts, [
          '../landing/src/strings.json',
          '../landing/src/help.es.md',
          '../landing/src/help.en.md',
        ]);
        expect(gate.webTextsRequired, isFalse);
        final present = write('strings.json', '{}');
        final absent = '${tmp.path}/help.es.md';
        expect(gate.webTextsToCheck([present, absent], required: false), [
          present,
        ]);
        expect(gate.webTextsToCheck([present, absent], required: true), [
          present,
          absent,
        ]);
        expect(gate.checkWebTexts([absent], required: false), isEmpty);
        final required = gate.checkWebTexts([absent], required: true);
        expect(required.single.kind, GateIssueKind.fault);
        expect(required.single.subject, 'help.es.md');
      });
    });
  });

  group(
    'CA-020-12: la puerta falla cerrada (ficheros que no se pueden leer)',
    () {
      late Directory tmp;
      setUp(() => tmp = Directory.systemTemp.createTempSync('gate_closed_'));
      tearDown(() => tmp.deleteSync(recursive: true));

      String path(String name) => '${tmp.path}/$name';

      void expectFault(List<gate.GateIssue> issues, String named) {
        expect(issues, isNotEmpty, reason: 'no puede dar por buena la lectura');
        expect(issues.map((i) => i.kind), everyElement(GateIssueKind.fault));
        expect(
          issues.map((i) => '${i.subject} ${i.message}').join('\n'),
          contains(named),
        );
      }

      String valid() =>
          'displayName: "X"\nwordmark: "x"\n'
          'privacyPolicyUrl: "https://una-app.dev/privacy"\n'
          'thirdPartyLicensesUrl: "https://una-app.dev/licenses"\n'
          'helpUrl: "https://una-app.dev/help"\n';

      group('identity.yaml (checkIdentityFile)', () {
        test('CA-020-12: con un archivo bueno no da errores (control)', () {
          File(path('identity.yaml')).writeAsStringSync(valid());
          expect(gate.checkIdentityFile(path('identity.yaml')), isEmpty);
        });

        test('CA-020-12: ausente falla y nombra el archivo', () {
          expectFault(
            gate.checkIdentityFile(path('no-existe.yaml')),
            'no-existe.yaml',
          );
        });

        test('CA-020-12: una carpeta en su lugar falla y la nombra', () {
          Directory(path('carpeta.yaml')).createSync();
          expectFault(
            gate.checkIdentityFile(path('carpeta.yaml')),
            'carpeta.yaml',
          );
          expect(
            gate.checkIdentityFile(path('carpeta.yaml')).single.message,
            contains('no es un archivo'),
          );
        });

        for (final (name, content) in <(String, String)>[
          ('vacío', ''),
          ('solo espacios y saltos', '  \n\n\t \n'),
          ('solo comentarios', '# nada\n# más nada\n'),
          ('solo el separador', '---\n'),
          ('null', 'null\n'),
        ]) {
          test('CA-020-12: $name falla y nombra el archivo', () {
            File(path('identity.yaml')).writeAsStringSync(content);
            final issues = gate.checkIdentityFile(path('identity.yaml'));
            expectFault(issues, 'identity.yaml');
            expect(issues.single.message, contains('vací'));
          });
        }

        for (final (name, content) in <(String, String)>[
          ('yaml roto', 'a: [\n'),
          ('una lista', '- a\n- b\n'),
          ('un texto suelto', 'solo texto\n'),
          ('claves repetidas', 'a: 1\na: 2\n'),
        ]) {
          test('CA-020-12: $name falla y nombra el archivo', () {
            File(path('identity.yaml')).writeAsStringSync(content);
            expectFault(
              gate.checkIdentityFile(path('identity.yaml')),
              'identity.yaml',
            );
          });
        }

        test('CA-020-12: bytes que no son UTF-8 fallan sin excepción', () {
          File(path('identity.yaml'))
              .writeAsBytesSync([0xff, 0xfe, 0x41, 0x80]);
          expectFault(
            gate.checkIdentityFile(path('identity.yaml')),
            'identity.yaml',
          );
        });

        test(
          'CA-020-12: sin permiso de lectura falla y lo nombra',
          () {
            final f = File(path('identity.yaml'))..writeAsStringSync(valid());
            Process.runSync('chmod', ['000', f.path]);
            addTearDown(() => Process.runSync('chmod', ['644', f.path]));
            expectFault(gate.checkIdentityFile(f.path), 'identity.yaml');
          },
          skip: Process.runSync('id', ['-u']).stdout.toString().trim() == '0'
              ? 'root lee igualmente un archivo sin permisos'
              : null,
        );
      });

      group('política (checkPolicyFile)', () {
        test('CA-020-12: con una política buena delega en checkPolicyText', () {
          File(path('p.md')).writeAsStringSync(_cleanPolicy);
          expect(gate.checkPolicyFile(path('p.md')), isEmpty);
          File(path('p.md')).writeAsStringSync(
            _cleanPolicy.replaceFirst('30 de septiembre de 2026', '[FECHA]'),
          );
          expect(
            gate.checkPolicyFile(path('p.md')).single.kind,
            GateIssueKind.policyGap,
          );
        });

        test('CA-020-12: ausente falla y nombra el archivo', () {
          expectFault(
            gate.checkPolicyFile(path('no-existe.md')),
            'no-existe.md',
          );
        });

        test('CA-020-12: una carpeta en su lugar falla y la nombra', () {
          Directory(path('carpeta.md')).createSync();
          expectFault(gate.checkPolicyFile(path('carpeta.md')), 'carpeta.md');
          expect(
            gate.checkPolicyFile(path('carpeta.md')).single.message,
            contains('no es un archivo'),
          );
        });

        for (final (name, content) in <(String, String)>[
          ('vacía', ''),
          ('solo espacios y saltos', '  \n\n\t \n'),
        ]) {
          test('CA-020-12: $name falla y nombra el archivo', () {
            File(path('p.md')).writeAsStringSync(content);
            final issues = gate.checkPolicyFile(path('p.md'));
            expectFault(issues, 'p.md');
            expect(issues.single.message, contains('vací'));
          });
        }

        test(
          'CA-020-12: bytes que no son UTF-8 fallan y nombran el archivo',
          () {
            File(path('p.md')).writeAsBytesSync([0xff, 0xfe, 0x41, 0x80]);
            expectFault(gate.checkPolicyFile(path('p.md')), 'p.md');
          },
        );

        test('CA-020-12: sin las dos partes falla (fault, no aviso)', () {
          File(path('p.md')).writeAsStringSync('# Otra cosa\n\nTexto.\n');
          expectFault(gate.checkPolicyFile(path('p.md')), 'política');
        });
      });

      group('lo generado (checkGenerated)', () {
        Directory copyOfGenerated() {
          final root = Directory(path('app'))..createSync();
          for (final p in _generatedFiles) {
            File('${root.path}/$p')
              ..parent.createSync(recursive: true)
              ..writeAsStringSync(File(p).readAsStringSync());
          }
          return root;
        }

        test('CA-020-12: al día no da errores (control)', () {
          expect(gate.checkGenerated(copyOfGenerated().path), isEmpty);
        });

        test('CA-020-12: desfasado es un fallo que nombra los archivos', () {
          final root = copyOfGenerated();
          File('${root.path}/lib/app/app_identity.g.dart')
              .writeAsStringSync('// viejo\n');
          final issues = gate.checkGenerated(root.path);
          expectFault(issues, 'app_identity.g.dart');
          expect(issues.single.subject, contains('gen_identity'));
        });

        test('CA-020-12: un archivo generado ausente es un fallo', () {
          final root = copyOfGenerated();
          File('${root.path}/web/manifest.json').deleteSync();
          // gen_identity no sabe construir sin el archivo actual y se detiene con un error: sigue
          // siendo un fallo (código distinto de 0), nunca un visto bueno.
          expectFault(gate.checkGenerated(root.path), 'gen_identity');
        });

        test('CA-020-12: si no se puede comprobar (sin identity.yaml) es un '
            'fallo, nunca un visto bueno', () {
          final root = Directory(path('vacia'))..createSync();
          expectFault(gate.checkGenerated(root.path), 'gen_identity');
        });
      });
    },
  );

  group('CA-015-13b: el script tools/check-release-config.sh', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('release_config_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    File policy(String text) =>
        File('${tmp.path}/policy.md')..writeAsStringSync(text);

    /// Un `identity.yaml` de prueba con las tres direcciones (o con lo que se
    /// pase en [extra] en lugar de ellas).
    File identity({
      String privacy = 'https://una-app.dev/privacy',
      String licenses = 'https://una-app.dev/licenses',
      String help = 'https://una-app.dev/help',
      String? raw,
    }) => File('${tmp.path}/identity.yaml')
      ..writeAsStringSync(
        raw ??
            'displayName: "X"\n'
                'wordmark: "x"\n'
                'privacyPolicyUrl: "$privacy"\n'
                'thirdPartyLicensesUrl: "$licenses"\n'
                'helpUrl: "$help"\n',
      );

    ProcessResult run({File? id, File? pol, List<String> extra = const []}) =>
        _runScript([
          '--identity',
          (id ?? identity()).path,
          '--policy',
          (pol ?? policy(_cleanPolicy)).path,
          ...extra,
        ]);

    String out(ProcessResult r) => '${r.stdout}${r.stderr}';

    test(
      'CA-012-05: hoy falla (marcadores y huecos) y nombra las tres claves',
      () {
        final result = _runScript([]);
        expect(result.exitCode, 1, reason: out(result));
        final text = out(result);
        expect(text, contains('privacyPolicyUrl'));
        expect(text, contains('thirdPartyLicensesUrl'));
        expect(text, contains('helpUrl'));
        expect(text, contains('example.com'));
        expect(text, contains('[NOMBRE DE LA APP]'));
      },
    );

    group('CA-023-01: qué argumentos le pasa el script a la herramienta', () {
      /// Ejecuta el script con un `dart` de mentira que escribe sus argumentos, uno por línea.
      List<String> dartArgs(List<String> args) {
        final bin = Directory('${tmp.path}/bin')..createSync();
        File('${bin.path}/dart')
          ..writeAsStringSync('#!/bin/bash\nprintf "%s\\n" "\$@"\n')
          ..createSync();
        Process.runSync('chmod', ['+x', '${bin.path}/dart']);
        final r = Process.runSync(
          'bash',
          ['../tools/check-release-config.sh', ...args],
          environment: {
            ...Platform.environment,
            'PATH': '${bin.path}:${Platform.environment['PATH']}',
          },
        );
        expect(r.exitCode, 0, reason: out(r));
        return '${r.stdout}'.trim().split('\n');
      }

      test('CA-023-01: sin --policy ni --web-text pide los textos de la web '
          'del repositorio', () {
        final a = dartArgs([]);
        expect(a, contains('--web-defaults'));
        expect(a, isNot(contains('--web-text')));
      });

      test('CA-023-01: con --policy (valores de prueba) no mira la web', () {
        final a = dartArgs(['--policy', policy(_cleanPolicy).path]);
        expect(a, isNot(contains('--web-defaults')));
        expect(a, isNot(contains('--web-text')));
      });

      test('CA-023-01: --web-text se pasa con su ruta absoluta y sin los '
          'textos por defecto', () {
        final f = File('${tmp.path}/h.md')..writeAsStringSync('x');
        final a = dartArgs(['--web-text', 'h.md']);
        expect(a, isNot(contains('--web-defaults')));
        final i = a.indexOf('--web-text');
        expect(i, isNonNegative);
        expect(a[i + 1], endsWith('/h.md'));
        expect(a[i + 1], startsWith('/'));
        expect(f.existsSync(), isTrue);
      });
    });

    test(
      'CA-015-13b: pasa con tres dominios propios de prueba (yaml temporal)',
      () {
        final result = run();
        expect(result.exitCode, 0, reason: out(result));
      },
    );

    for (final key in _keys) {
      test(
        'CA-015-13b: falla con $key reservada aunque las otras sean buenas',
        () {
          final bad = 'https://www.EXAMPLE.com/x';
          final result = run(
            id: identity(
              privacy: key == 'privacyPolicyUrl'
                  ? bad
                  : 'https://una-app.dev/privacy',
              licenses: key == 'thirdPartyLicensesUrl'
                  ? bad
                  : 'https://una-app.dev/licenses',
              help: key == 'helpUrl' ? bad : 'https://una-app.dev/help',
            ),
          );
          expect(result.exitCode, 1, reason: out(result));
          expect(out(result), contains(key));
          expect(out(result), contains('reservado'));
        },
      );
    }

    test(
      'CA-015-13b: falla con dos direcciones iguales (también /x y /x/)',
      () {
        final result = run(
          id: identity(
            privacy: 'https://una-app.dev/web',
            licenses: 'https://una-app.dev/web/',
          ),
        );
        expect(result.exitCode, 1, reason: out(result));
        expect(out(result), contains('privacyPolicyUrl'));
        expect(out(result), contains('thirdPartyLicensesUrl'));
      },
    );

    test(
      'CA-015-13b: falla con una clave ausente, vacía o que no es texto',
      () {
        const head = 'displayName: "X"\nwordmark: "x"\n';
        for (final (raw, key) in <(String, String)>[
          (
            '${head}privacyPolicyUrl: "https://una-app.dev/p"\n'
                'thirdPartyLicensesUrl: "https://una-app.dev/l"\n',
            'helpUrl',
          ),
          (
            '${head}privacyPolicyUrl: "https://una-app.dev/p"\n'
                'thirdPartyLicensesUrl: ""\n'
                'helpUrl: "https://una-app.dev/h"\n',
            'thirdPartyLicensesUrl',
          ),
          (
            '${head}privacyPolicyUrl: 42\n'
                'thirdPartyLicensesUrl: "https://una-app.dev/l"\n'
                'helpUrl: "https://una-app.dev/h"\n',
            'privacyPolicyUrl',
          ),
          (
            '${head}privacyPolicyUrl: "https://una-app.dev/p"\n'
                'thirdPartyLicensesUrl: [a, b]\n'
                'helpUrl: "https://una-app.dev/h"\n',
            'thirdPartyLicensesUrl',
          ),
          (
            '${head}privacyPolicyUrl: "https://una-app.dev/p"\n'
                'thirdPartyLicensesUrl: "https://una-app.dev/l"\n'
                'helpUrl:\n',
            'helpUrl',
          ),
        ]) {
          final result = run(id: identity(raw: raw));
          expect(result.exitCode, 1, reason: '$key\n${out(result)}');
          expect(out(result), contains(key), reason: raw);
          expect(out(result), isNot(contains('TypeError')), reason: raw);
        }
      },
    );

    test('CA-015-13b: una raíz que no es un mapa o un yaml roto falla sin '
        'excepción', () {
      for (final raw in ['- a\n- b\n', 'solo texto\n', '', 'a: [\n']) {
        final result = run(id: identity(raw: raw));
        expect(result.exitCode, 1, reason: '"$raw"\n${out(result)}');
        expect(out(result), contains('identity.yaml'));
        expect(out(result), isNot(contains('Unhandled exception')));
      }
    });

    test('CA-012-05: falla con una política con huecos aunque las direcciones '
        'sean buenas', () {
      final result = run(
        pol: policy(
          _cleanPolicy.replaceFirst('30 de septiembre de 2026', '[FECHA]'),
        ),
      );
      expect(result.exitCode, 1);
      expect(out(result), contains('[FECHA]'));
    });

    test('CA-012-05: una política que no existe falla', () {
      final result = _runScript([
        '--identity',
        identity().path,
        '--policy',
        '${tmp.path}/no-existe.md',
      ]);
      expect(result.exitCode, 1);
    });

    test('CA-015-13b: un identity.yaml que no existe falla', () {
      final result = _runScript([
        '--identity',
        '${tmp.path}/no-existe.yaml',
        '--policy',
        policy(_cleanPolicy).path,
      ]);
      expect(result.exitCode, isNot(0));
    });

    group('CA-020-05: --json <archivo> (la lista de errores con su clase)', () {
      Map<String, Object?> readJson(File f) =>
          jsonDecode(f.readAsStringSync()) as Map<String, Object?>;

      List<Map<String, Object?>> issuesOf(Map<String, Object?> json) => [
        for (final i in json['issues']! as List) i as Map<String, Object?>,
      ];

      test(
        'CA-020-05: con todo en orden escribe complete y ninguna incidencia, '
        'y no deja temporales',
        () {
          final json = File('${tmp.path}/out/gate.json');
          json.parent.createSync();
          final result = run(extra: ['--json', json.path]);
          expect(result.exitCode, 0, reason: out(result));
          final data = readJson(json);
          expect(data['complete'], isTrue);
          expect(issuesOf(data), isEmpty);
          expect(data['checks'], isA<List<Object?>>());
          expect(json.parent.listSync().map((e) => e.path.split('/').last), [
            'gate.json',
          ], reason: 'sin archivo temporal');
        },
      );

      test(
        'CA-020-05: los marcadores de hoy, los huecos y las marcas salen como '
        'placeholderAddress, policyGap y fault (las marcas), y se conserva la salida ::error::',
        () {
          final json = File('${tmp.path}/gate.json');
          final result = _runScript(['--json', json.path]);
          expect(result.exitCode, 1, reason: out(result));
          expect(out(result), contains('::error::privacyPolicyUrl'));
          final data = readJson(json);
          expect(data['complete'], isTrue);
          final issues = issuesOf(data);
          final kinds = issues.map((i) => i['kind']).toSet();
          expect(kinds, {'placeholderAddress', 'policyGap', 'fault'});
          expect(
            issues
                .where((i) => i['kind'] == 'placeholderAddress')
                .map((i) => i['subject']),
            unorderedEquals(_keys),
          );
          for (final i in issues) {
            expect(i['message'], isA<String>());
            expect((i['message']! as String), isNotEmpty);
          }
        },
      );

      test('CA-020-05: una dirección con aviso y fallo a la vez '
          '(https://example.com/%2e) sale como fallo', () {
        final json = File('${tmp.path}/gate.json');
        final result = run(
          id: identity(privacy: 'https://example.com/%2e'),
          extra: ['--json', json.path],
        );
        expect(result.exitCode, 1, reason: out(result));
        final issues = issuesOf(readJson(json));
        expect(issues, isNotEmpty);
        expect(issues.map((i) => i['kind']), everyElement('fault'));
        expect(
          issues.map((i) => i['subject']),
          everyElement('privacyPolicyUrl'),
        );
      });

      test('CA-020-05: http://ejemplo-propio.es es un fallo en el JSON', () {
        final json = File('${tmp.path}/gate.json');
        final result = run(
          id: identity(help: 'http://ejemplo-propio.es'),
          extra: ['--json', json.path],
        );
        expect(result.exitCode, 1, reason: out(result));
        final issues = issuesOf(readJson(json));
        expect(issues.single['kind'], 'fault');
        expect(issues.single['subject'], 'helpUrl');
      });

      test(
        'CA-020-05: un identity.yaml roto es un fallo y el JSON se escribe',
        () {
          final json = File('${tmp.path}/gate.json');
          final result = run(
            id: identity(raw: 'a: [\n'),
            extra: ['--json', json.path],
          );
          expect(result.exitCode, 1, reason: out(result));
          final data = readJson(json);
          expect(data['complete'], isTrue);
          final issues = issuesOf(data);
          expect(issues.map((i) => i['kind']), everyElement('fault'));
          expect(
            issues.map((i) => i['subject']).join(),
            contains('identity.yaml'),
          );
        },
      );

      test('CA-020-05: una política que no existe es un fallo en el JSON', () {
        final json = File('${tmp.path}/gate.json');
        final result = _runScript([
          '--identity',
          identity().path,
          '--policy',
          '${tmp.path}/no-existe.md',
          '--json',
          json.path,
        ]);
        expect(result.exitCode, 1, reason: out(result));
        final issues = issuesOf(readJson(json));
        expect(issues.single['kind'], 'fault');
        expect(issues.single['subject'], contains('no-existe.md'));
      });

      test('CA-020-11: una marca en la política sale como fault (CA-023-01) con su '
          'línea y falla', () {
        final json = File('${tmp.path}/gate.json');
        final result = run(
          pol: policy(
            _cleanPolicy.replaceFirst(
              'Escribe a hola@ejemplo.org.',
              'Dato [Suposición, PD-9].',
            ),
          ),
          extra: ['--json', json.path],
        );
        expect(result.exitCode, 1, reason: out(result));
        final issues = issuesOf(readJson(json));
        expect(issues, hasLength(1));
        expect(issues.single['kind'], 'fault');
        expect(issues.single['subject'], 'política (ES)');
        expect(issues.single['message'], contains('[Suposición, PD-9]'));
        expect(out(result), contains('::error::política (ES)'));
      });

      test('CA-023-01: --web-text revisa strings.json y la Ayuda con las '
          'reglas de la política y lo declara en checks', () {
        final json = File('${tmp.path}/gate.json');
        final strings = File('${tmp.path}/strings.json')
          ..writeAsStringSync('{"es":{"webContact":"Contacto: [CONTACTO]"}}');
        final help = File('${tmp.path}/help.es.md')
          ..writeAsStringSync('# Ayuda\n\nMira [XYZ] y {appName}.\n');
        final result = run(
          extra: [
            '--json',
            json.path,
            '--web-text',
            strings.path,
            '--web-text',
            help.path,
          ],
        );
        expect(result.exitCode, 1, reason: out(result));
        final data = readJson(json);
        expect(
          data['checks'],
          containsAll(['addresses', 'policy', 'web-texts']),
        );
        final issues = issuesOf(data);
        expect(issues, hasLength(2));
        expect(
          issues.singleWhere((i) => i['subject'] == 'strings.json')['kind'],
          'policyGap',
        );
        expect(
          issues.singleWhere((i) => i['subject'] == 'help.es.md')['kind'],
          'fault',
        );
        expect(out(result), contains('::error::strings.json'));
      });

      test('CA-023-01: --web-text con archivos limpios pasa; uno ausente es un '
          'fallo aunque aún no sean obligatorios por defecto', () {
        final json = File('${tmp.path}/gate.json');
        final ok = File('${tmp.path}/help.en.md')
          ..writeAsStringSync('# Help\n\nAll good in {appName}.\n');
        final pass = run(extra: ['--json', json.path, '--web-text', ok.path]);
        expect(pass.exitCode, 0, reason: out(pass));
        expect(readJson(json)['checks'], contains('web-texts'));
        final fail = run(
          extra: ['--json', json.path, '--web-text', '${tmp.path}/falta.md'],
        );
        expect(fail.exitCode, 1, reason: out(fail));
        final issues = issuesOf(readJson(json));
        expect(issues.single['kind'], 'fault');
        expect(issues.single['subject'], 'falta.md');
      });

      test('CA-023-01: con --policy y sin --web-text la web no se revisa (los '
          'valores de prueba no mezclan archivos del repositorio)', () {
        final json = File('${tmp.path}/gate.json');
        final result = run(extra: ['--json', json.path]);
        expect(result.exitCode, 0, reason: out(result));
        expect(readJson(json)['checks'], isNot(contains('web-texts')));
      });

      test('CA-020-12: un identity.yaml que no existe es un fallo con JSON '
          '(no un error de uso) y la política se revisa igualmente', () {
        final json = File('${tmp.path}/gate.json');
        final result = _runScript([
          '--identity',
          '${tmp.path}/no-existe.yaml',
          '--policy',
          policy(
            _cleanPolicy.replaceFirst('30 de septiembre de 2026', '[FECHA]'),
          ).path,
          '--json',
          json.path,
        ]);
        expect(result.exitCode, 1, reason: out(result));
        final data = readJson(json);
        expect(data['complete'], isTrue);
        final issues = issuesOf(data);
        expect(
          issues.where((i) => i['kind'] == 'fault').map((i) => i['subject']),
          ['identity.yaml'],
        );
        expect(
          issues.firstWhere((i) => i['subject'] == 'identity.yaml')['message'],
          contains('no-existe.yaml'),
        );
        expect(issues.map((i) => i['kind']), contains('policyGap'));
      });

      test('CA-020-12: un identity.yaml en una carpeta que no existe es un '
          'fallo con JSON', () {
        final json = File('${tmp.path}/gate.json');
        final result = _runScript([
          '--identity',
          '${tmp.path}/otra/no-existe.yaml',
          '--policy',
          policy(_cleanPolicy).path,
          '--json',
          json.path,
        ]);
        expect(result.exitCode, 1, reason: out(result));
        final issues = issuesOf(readJson(json));
        expect(issues.single['kind'], 'fault');
        expect(issues.single['message'], contains('no-existe.yaml'));
      });

      test('CA-020-12: un identity.yaml vacío es un fallo con JSON', () {
        final json = File('${tmp.path}/gate.json');
        final result = run(
          id: identity(raw: ''),
          extra: ['--json', json.path],
        );
        expect(result.exitCode, 1, reason: out(result));
        final issues = issuesOf(readJson(json));
        expect(issues.single['kind'], 'fault');
        expect(issues.single['subject'], 'identity.yaml');
        expect(issues.single['message'], contains('vací'));
      });

      test(
        'CA-020-12: una política vacía es un fallo con JSON que la nombra',
        () {
          final json = File('${tmp.path}/gate.json');
          final empty = policy('');
          final result = run(pol: empty, extra: ['--json', json.path]);
          expect(result.exitCode, 1, reason: out(result));
          final issues = issuesOf(readJson(json));
          expect(issues.single['kind'], 'fault');
          expect(issues.single['subject'], contains('policy.md'));
          expect(out(result), contains('policy.md'));
        },
      );

      test('CA-020-12: lo generado desfasado es un fallo en el JSON', () {
        final root = Directory('${tmp.path}/app')..createSync();
        for (final p in _generatedFiles) {
          File('${root.path}/$p')
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(File(p).readAsStringSync());
        }
        File('${root.path}/lib/app/app_identity.g.dart')
            .writeAsStringSync('// viejo\n');
        final json = File('${tmp.path}/gate.json');
        final result = run(
          extra: ['--generated-root', root.path, '--json', json.path],
        );
        expect(result.exitCode, 1, reason: out(result));
        final issues = issuesOf(readJson(json));
        expect(issues, hasLength(1));
        expect(issues.single['kind'], 'fault');
        expect(issues.single['subject'], contains('gen_identity'));
        expect(issues.single['message'], contains('app_identity.g.dart'));
        expect(out(result), contains('::error::'));
      });

      test('CA-020-12: sin --generated-root la herramienta no lo da por '
          'comprobado en el JSON', () {
        final json = File('${tmp.path}/gate.json');
        final result = Process.runSync('dart', [
          'run',
          'tool/check_release_config.dart',
          '--identity',
          identity().path,
          '--policy',
          policy(_cleanPolicy).path,
          '--json',
          json.path,
        ]);
        expect(result.exitCode, 0, reason: out(result));
        expect(readJson(json)['checks'], isNot(contains('generated')));
      });

      test(
        'CA-020-12: con lo generado al día el JSON lo lista como comprobado',
        () {
          final json = File('${tmp.path}/gate.json');
          final result = run(extra: ['--json', json.path]);
          expect(result.exitCode, 0, reason: out(result));
          expect(readJson(json)['checks'], contains('generated'));
        },
      );

      test('CA-020-05: --json sin valor es un error de uso', () {
        final result = _runScript(['--json']);
        expect(result.exitCode, 2, reason: out(result));
      });

      test('CA-020-05: una ruta relativa de --json se resuelve donde está el '
          'que llama, no en app/', () {
        final dir = Directory('${tmp.path}/cwd')..createSync();
        final result = Process.runSync('bash', [
          File('../tools/check-release-config.sh').absolute.path,
          '--identity',
          identity().path,
          '--policy',
          policy(_cleanPolicy).path,
          '--json',
          'rel.json',
        ], workingDirectory: dir.path);
        expect(result.exitCode, 0, reason: out(result));
        expect(File('${dir.path}/rel.json').existsSync(), isTrue);
      });
    });

    test('CA-015-13b: --url ya no existe y un argumento desconocido falla '
        '(no se ignora)', () {
      for (final args in [
        ['--url', 'https://una-app.dev/privacy'],
        ['--nope'],
      ]) {
        final result = _runScript(args);
        expect(result.exitCode, 2, reason: args.join(' '));
      }
    });

    group('lo generado también cuenta (gen_identity.dart --check)', () {
      /// Copia en [tmp]/app los archivos que genera `gen_identity.dart`.
      Directory copyOfGenerated() {
        final root = Directory('${tmp.path}/app')..createSync();
        for (final path in _generatedFiles) {
          final to = File('${root.path}/$path')
            ..parent.createSync(recursive: true);
          to.writeAsStringSync(File(path).readAsStringSync());
        }
        return root;
      }

      test('CA-015-13b: con lo generado al día pasa (control)', () {
        final root = copyOfGenerated();
        final result = run(extra: ['--generated-root', root.path]);
        expect(result.exitCode, 0, reason: out(result));
      });

      test('CA-015-13b: con un app_identity.g.dart desfasado falla', () {
        final root = copyOfGenerated();
        final g = File('${root.path}/lib/app/app_identity.g.dart');
        g.writeAsStringSync(
          g.readAsStringSync().replaceFirst(
            RegExp(r"helpUrl = '[^']*'"),
            "helpUrl = 'https://otra.una-app.dev/help'",
          ),
        );
        final result = run(extra: ['--generated-root', root.path]);
        expect(result.exitCode, 1, reason: out(result));
        expect(out(result), contains('app_identity.g.dart'));
      });

      test('CA-015-13b: con un identity.yaml sin generar de nuevo falla', () {
        final root = copyOfGenerated();
        final y = File('${root.path}/identity.yaml');
        y.writeAsStringSync(
          y.readAsStringSync().replaceFirst(
            RegExp(r'helpUrl: "[^"]*"'),
            'helpUrl: "https://nueva.una-app.dev/help"',
          ),
        );
        final result = run(extra: ['--generated-root', root.path]);
        expect(result.exitCode, 1, reason: out(result));
        expect(out(result), contains('app_identity.g.dart'));
      });
    });
  }, skip: Platform.isWindows ? 'necesita bash' : null);
}
