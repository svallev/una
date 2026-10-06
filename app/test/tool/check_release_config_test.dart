import 'dart:io';

import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/services/privacy_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

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
