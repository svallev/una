import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// `tools/ci-detect.sh` (CA-023-18, plan §1.4): decide, a partir de los archivos que cambia una PR,
/// si hay que compilar la app (`build`) y si hay que comprobar la ficha de tienda (`store`; la web vive
/// en su propio repositorio, svallev/una-web, ADR-0029). Recibe los nombres separados por NUL en la
/// entrada estándar (la salida de `git diff --name-only -z`) y escribe `build=…` y `store=…`. Falla cerrado: una lista vacía en una PR lo da todo, y lo que no
/// entiende es un fallo, nunca un «no hace falta».
const _script = '../tools/ci-detect.sh';
const _ci = '../.github/workflows/ci.yml';

typedef _Result = ({int code, Map<String, String> out, String err});

/// Lanza el script con `files` por la entrada estándar (separados por NUL, con NUL final salvo que
/// `terminated` sea falso). `script` permite probar una copia en otra carpeta.
Future<_Result> _detect(
  List<String> files, {
  String event = 'pull_request',
  bool terminated = true,
  String script = _script,
  List<String>? args,
}) async {
  final p = await Process.start('bash', [
    script,
    ...args ?? ['--event', event],
  ]);
  final input =
      files.join('\u0000') + (terminated && files.isNotEmpty ? '\u0000' : '');
  p.stdin.add(utf8.encode(input));
  await p.stdin.close();
  final out = utf8.decodeStream(p.stdout);
  final err = utf8.decodeStream(p.stderr);
  final code = await p.exitCode;
  final lines = (await out).split('\n').where((l) => l.isNotEmpty);
  return (
    code: code,
    out: {
      for (final l in lines)
        if (l.contains('='))
          l.substring(0, l.indexOf('=')): l.substring(l.indexOf('=') + 1),
    },
    err: await err,
  );
}

Future<void> _expectFlags(
  List<String> files, {
  required bool build,
  required bool store,
  String event = 'pull_request',
}) async {
  final r = await _detect(files, event: event);
  expect(r.code, 0, reason: '${files.join(' ')}: ${r.err}');
  expect(r.out, {
    'build': '$build',
    'store': '$store',
  }, reason: files.join(' '));
}

void main() {
  group('CA-023-18: la ficha', () {
    const triggers = [
      'store/google-play/check.mjs',
      'store/google-play/lib.mjs',
      'store/google-play/data-safety.md',
      'store/google-play/play-console.md',
      'store/google-play/listing/es-ES/title.txt',
      'store/google-play/feature-graphic.png',
      'store/google-play/screenshots/es-ES/1-tarea.png',
      'docs/legal/privacy-policy.md',
      'app/identity.yaml',
      'tools/check-android-permissions.sh',
      'tools/ci-detect.sh',
      '.github/workflows/ci.yml',
    ];
    for (final f in triggers) {
      test('CA-023-18: $f comprueba la ficha', () async {
        final r = await _detect([f]);
        expect(r.code, 0, reason: r.err);
        expect(r.out['store'], 'true', reason: f);
      });
    }

    const noStore = [
      'app/lib/main.dart',
      'app/lib/ui/home/home_screen.dart',
      'app/lib/l10n/l10n.dart',
      'app/lib/l10n/app_es.arb',
      'app/assets/fonts/archivo/Archivo-Variable.ttf',
      'app/pubspec.yaml',
      'app/assets/images/x.png',
      'app/android/app/build.gradle.kts',
      'design/tokens.json',
      'store/google-play/icon-512.png',
      'docs/glossary.md',
      'docs/security/threat-model.md',
      'docs/adr/0001-x.md',
      'specs/023-x/tasks.md',
      'README.md',
      'tools/check-size.sh',
      'tools/check-licenses.sh',
      'tools/validate-tokens.mjs',
      '.github/workflows/release.yml',
      '.github/workflows/security.yml',
    ];
    for (final f in noStore) {
      test('CA-023-18: $f no comprueba la ficha', () async {
        final r = await _detect([f]);
        expect(r.code, 0, reason: r.err);
        expect(r.out['store'], 'false', reason: f);
      });
    }

    test('CA-023-18: una sola ruta de la lista entre muchas basta', () async {
      await _expectFlags(
        [
          'app/lib/main.dart',
          'docs/adr/x.md',
          'store/google-play/check.mjs',
          'README.md',
        ],
        build: true,
        store: true,
      );
    });
  });

  group('CA-023-18: la app', () {
    test('CA-023-18: un cambio en app/ compila la app y no la ficha', () async {
      await _expectFlags(['app/lib/x.dart'], build: true, store: false);
    });

    test('CA-023-18: store/ no compila la app', () async {
      for (final f in [
        'store/google-play/check.mjs',
        'store/google-play/listing/en-US/short.txt',
        'store/google-play/play-console.md',
      ]) {
        await _expectFlags([f], build: false, store: true);
      }
    });

    test('CA-023-18: el icono y el gráfico de funciones los leen los tests de la app', () async {
      await _expectFlags(
        ['store/google-play/icon-512.png'],
        build: true,
        store: false,
      );
      await _expectFlags(
        ['store/google-play/feature-graphic.png'],
        build: true,
        store: true,
      );
    });

    test('CA-023-18: lo que leen los tests de la app dentro de store/ la sigue compilando', () async {
      await _expectFlags(
        ['store/google-play/data-safety.md'],
        build: true,
        store: true,
      );
    });

    test('CA-023-18: lo que ya compilaba la app la sigue compilando', () async {
      for (final f in [
        'docs/glossary.md',
        'docs/security/threat-model.md',
        'docs/legal/privacy-policy.md',
        'app/identity.yaml',
        'design/tokens.json',
        'tools/ci-detect.sh',
        'tools/check-size.sh',
        '.github/workflows/ci.yml',
        '.github/workflows/release.yml',
        'pubspec.lock',
        'Makefile',
        'app/README.md',
      ]) {
        final r = await _detect([f]);
        expect(r.out['build'], 'true', reason: f);
      }
    });

    test('CA-023-18: documentación y raíz con .md no compilan nada', () async {
      for (final f in [
        'docs/adr/0001-x.md',
        'docs/PLAN.md',
        'specs/023-x/spec.md',
        'README.md',
        'CLAUDE.md',
      ]) {
        await _expectFlags([f], build: false, store: false);
      }
    });

    test(
      'CA-023-18: un documento que no se compila junto a uno que sí',
      () async {
        await _expectFlags(
          ['docs/PLAN.md', 'app/lib/x.dart'],
          build: true,
          store: false,
        );
        await _expectFlags(
          ['app/lib/x.dart', 'docs/PLAN.md'],
          build: true,
          store: false,
        );
      },
    );

    test('CA-023-18: un nombre con espacios, saltos de línea o no ASCII no despista', () async {
      await _expectFlags(['docs/mi nota.md'], build: false, store: false);
      await _expectFlags(['docs/a\nstore/x.md'], build: false, store: false);
      await _expectFlags(
        ['docs/a\napp/lib/x.dart'],
        build: false,
        store: false,
      );
      await _expectFlags(['docs/año/ñ.md'], build: false, store: false);
      // Una barra invertida no se interpreta: `store\/x` no es `store/x` y, ante la duda, compila.
      await _expectFlags([r'store\/x'], build: true, store: false);
      await _expectFlags(
        ['store/google-play/p\nágina.html'],
        build: false,
        store: true,
      );
    });

    test('CA-023-18: un nombre sin NUL final también se lee', () async {
      final r = await _detect([
        'store/google-play/x',
        'docs/a.md',
      ], terminated: false);
      expect(r.code, 0, reason: r.err);
      expect(r.out, {'build': 'false', 'store': 'true'});
      final r2 = await _detect([
        'docs/a.md',
        'app/lib/x.dart',
      ], terminated: false);
      expect(r2.out, {'build': 'true', 'store': 'false'});
    });
  });

  group('CA-023-18: falla cerrada', () {
    test('CA-023-18: una lista vacía en una PR lo da todo', () async {
      await _expectFlags([], build: true, store: true);
    });

    test(
      'CA-023-18: una lista de nombres vacíos en una PR lo da todo',
      () async {
        final r = await _detect(['', '', '']);
        expect(r.code, 0, reason: r.err);
        expect(r.out, {'build': 'true', 'store': 'true'});
      },
    );

    test(
      'CA-023-18: fuera de una PR (main) se compila y se construye todo',
      () async {
        await _expectFlags([], build: true, store: true, event: 'push');
        await _expectFlags(
          ['docs/PLAN.md'],
          build: true,
          store: true,
          event: 'push',
        );
        await _expectFlags(
          ['README.md'],
          build: true,
          store: true,
          event: 'workflow_dispatch',
        );
      },
    );

    test('CA-023-18: sin --event, con un evento vacío o con argumentos de más, falla (2)', () async {
      for (final args in [
        <String>[],
        ['--event'],
        ['--event', ''],
        ['--event', 'push', 'extra'],
        ['--evento', 'push'],
        ['push'],
      ]) {
        final r = await _detect(['docs/PLAN.md'], args: args);
        expect(r.code, 2, reason: args.join(' '));
        expect(
          r.out,
          isEmpty,
          reason: 'no escribe resultado: ${args.join(' ')}',
        );
      }
    });

    test('CA-023-18: sin app/pubspec.yaml no se compila la app (como antes), pero la ficha sí se decide', () async {
      final tmp = Directory.systemTemp.createTempSync('ci_detect_');
      try {
        Directory('${tmp.path}/tools').createSync();
        File(_script).copySync('${tmp.path}/tools/ci-detect.sh');
        final script = '${tmp.path}/tools/ci-detect.sh';
        var r = await _detect(['app/lib/x.dart'], script: script);
        expect(r.code, 0, reason: r.err);
        expect(r.out, {'build': 'false', 'store': 'false'});
        r = await _detect(['store/google-play/x'], script: script);
        expect(r.out, {'build': 'false', 'store': 'true'});
        r = await _detect([], event: 'push', script: script);
        expect(r.out, {'build': 'false', 'store': 'true'});
        // Con la app, lo mismo da en el repositorio real.
        Directory('${tmp.path}/app').createSync();
        File('${tmp.path}/app/pubspec.yaml').writeAsStringSync('name: x\n');
        r = await _detect(['app/lib/x.dart'], script: script);
        expect(r.out, {'build': 'true', 'store': 'false'});
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test(
      'CA-023-18: escribe solo build= y store=, sin nada más en la salida',
      () async {
        final p = await Process.start('bash', [
          _script,
          '--event',
          'pull_request',
        ]);
        p.stdin.add(utf8.encode('store/google-play/x\u0000'));
        await p.stdin.close();
        final out = await utf8.decodeStream(p.stdout);
        await p.stderr.drain<void>();
        expect(await p.exitCode, 0);
        expect(out.trimRight().split('\n'), ['build=false', 'store=true']);
      },
    );

    test(
      'CA-023-18: el script usa set -euo pipefail y no sustituye procesos',
      () {
        final text = File(_script).readAsStringSync();
        expect(text, contains('set -euo pipefail'));
        // `< <(git diff …)` esconde el fallo de git: la lista llega por la entrada estándar.
        final code = text
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('#'))
            .join('\n');
        expect(code, isNot(contains('<(')));
        expect(code, isNot(contains('git diff')));
      },
    );
  });

  group('CA-023-18: ci.yml', () {
    final text = File(_ci).readAsStringSync();
    final doc = loadYaml(text) as YamlMap;
    final jobs = doc['jobs'] as YamlMap;
    final detect = jobs['detect'] as YamlMap;
    final store = jobs['store'] as YamlMap;
    List<YamlMap> stepsOf(YamlMap job) => [
      for (final s in job['steps'] as YamlList) s as YamlMap,
    ];
    String run(YamlMap s) => (s['run'] ?? '') as String;

    test(
      'CA-023-18: detect saca build y store, y los dos vienen del script',
      () {
        final outputs = detect['outputs'] as YamlMap;
        expect(outputs.keys.toSet(), {'build', 'store'});
        expect(outputs['build'], r'${{ steps.check.outputs.build }}');
        expect(outputs['store'], r'${{ steps.check.outputs.store }}');
        final check = stepsOf(detect).firstWhere((s) => s['id'] == 'check');
        expect(run(check), contains('tools/ci-detect.sh'));
        expect(run(check), contains('--event'));
        // Ya no repite la lista de rutas en el workflow.
        expect(run(check), isNot(contains('glossary.md')));
        expect(run(check), isNot(contains('case ')));
      },
    );

    test('CA-023-18: detect falla cerrado si git diff falla', () {
      final check = stepsOf(detect).firstWhere((s) => s['id'] == 'check');
      final r = run(check);
      expect(r, contains('set -euo pipefail'));
      // `git diff` va a un archivo en su propio comando (con `set -e` un fallo detiene el paso)…
      expect(r, contains('git diff --name-only -z HEAD^1 HEAD >'));
      // …y no dentro de una sustitución de proceso, que se traga su código de salida.
      expect(r, isNot(contains('<(')));
      expect(r, isNot(contains('|| true')));
      expect(r, isNot(contains('set +e')));
      // El resultado se guarda antes de escribirlo en GITHUB_OUTPUT: un script que falla no deja medio.
      expect(r, contains(r'>> "$GITHUB_OUTPUT"'));
    });

    test('CA-023-18: el evento llega por una variable de entorno, no dentro de run', () {
      final check = stepsOf(detect).firstWhere((s) => s['id'] == 'check');
      expect((check['env'] as YamlMap)['EVENT'], r'${{ github.event_name }}');
      expect(run(check), isNot(contains(r'${{')));
    });

    test('CA-023-18: el checkout de detect trae dos commits y no guarda credenciales', () {
      final co = stepsOf(detect)
          .firstWhere((s) => '${s['uses']}'.startsWith('actions/checkout@'));
      final w = co['with'] as YamlMap;
      expect(w['fetch-depth'], 2);
      expect(w['persist-credentials'], false);
    });

    test('CA-023-18: los trabajos de la app siguen dependiendo de build', () {
      for (final name in ['flutter', 'android', 'ios']) {
        final job = jobs[name] as YamlMap;
        expect(job['needs'], 'detect', reason: name);
        expect(job['if'], "needs.detect.outputs.build == 'true'", reason: name);
      }
    });

    test('CA-023-18: el trabajo «Ficha» existe, depende de detect y solo con store', () {
      expect(store['name'], 'Ficha');
      expect(store['needs'], 'detect');
      expect(store['if'], "needs.detect.outputs.store == 'true'");
      expect(store['runs-on'], 'ubuntu-latest');
      expect(store['permissions'], {'contents': 'read'});
    });

    test('CA-023-18: «Ficha» no despliega, no usa secretos, ni npm, ni acciones de más', () {
      final body = [
        for (final s in stepsOf(store)) '${s['uses'] ?? ''}${run(s)}',
      ].join('\n');
      expect(text, isNot(contains('secrets.')));
      expect(text, isNot(contains('vercel')));
      expect(body, isNot(contains('deploy')));
      expect(body, isNot(contains('npm')));
      expect(body, isNot(contains('npx')));
      for (final s in stepsOf(store)) {
        final uses = s['uses'] as String?;
        if (uses == null) continue;
        expect(uses, startsWith('actions/checkout@'));
        expect(
          RegExp(r'@[0-9a-f]{40}( |$)').hasMatch(uses),
          isTrue,
          reason: uses,
        );
        expect((s['with'] as YamlMap)['persist-credentials'], false);
      }
    });

    test('CA-023-18: «Ficha» prueba y comprueba la ficha, en este orden', () {
      final runs = [for (final s in stepsOf(store)) run(s)]
          .where((r) => r.isNotEmpty)
          .join('\n');
      final tests = runs.indexOf('node --test');
      final checkStore = runs.indexOf('node store/google-play/check.mjs');
      expect(tests, greaterThanOrEqualTo(0));
      expect(checkStore, greaterThan(tests));
      expect(runs, contains('store/google-play/test/*.test.mjs'));
      // `node --test <carpeta>` falla en Node 24: se pasa el glob de la shell.
      expect(runs, isNot(contains('node --test store/google-play/test ')));
    });

    test('CA-023-18: «Ficha» exige un mínimo de tests ejecutados', () {
      final step = stepsOf(store)
          .firstWhere((s) => run(s).contains('node --test'));
      final r = run(step);
      expect(r, contains('set -euo pipefail'));
      expect(r, contains('--test-reporter=tap'));
      expect(r, contains('# tests'));
      expect(r, contains('min='));
      // Sin salida de recuento, o con menos del mínimo, el paso falla (no es un «0 tests, bien»).
      expect(r, contains('exit 1'));
    });

    test(
      'CA-023-18: el recuento mínimo del trabajo lo cumplen los tests de hoy',
      () async {
        final step = stepsOf(store)
            .firstWhere((s) => run(s).contains('node --test'));
        final min = int.parse(
          RegExp(r'min=(\d+)').firstMatch(run(step))!.group(1)!,
        );
        expect(min, greaterThanOrEqualTo(100));
        final r = await Process.run('node', [
          '--test',
          '--test-reporter=tap',
          ...Directory('../store/google-play/test')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.test.mjs'))
              .map((f) => f.path.substring(3)),
        ], workingDirectory: '..');
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
        final n = int.parse(
          RegExp(
            r'^# tests (\d+)$',
            multiLine: true,
          ).firstMatch(r.stdout as String)!.group(1)!,
        );
        expect(n, greaterThanOrEqualTo(min));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('CA-023-18: el trabajo no corre nada de la app', () {
      final body = [for (final s in stepsOf(store)) run(s)].join('\n');
      expect(body, isNot(contains('flutter')));
      expect(body, isNot(contains('dart ')));
      expect(body, isNot(contains('gradlew')));
    });
  });
}
