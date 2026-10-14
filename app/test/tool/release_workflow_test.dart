import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/release_summary.dart';

/// El *lint* de `.github/workflows/release.yml` (CA-020-01, 02, 06, 07 y 08; plan §3.2): disparadores,
/// permisos, acciones fijadas por SHA, sin secretos, sin expresiones dentro de `run:`, cada
/// comprobación con su paso y su `id`, y nada de subir un APK o un AAB.
const _path = '../.github/workflows/release.yml';
final _sha = RegExp(r'^[0-9a-f]{40}$');

void main() {
  final text = File(_path).readAsStringSync();
  final doc = loadYaml(text) as YamlMap;
  final job = (doc['jobs'] as YamlMap).values.single as YamlMap;
  final steps = [for (final s in job['steps'] as YamlList) s as YamlMap];
  final byId = {
    for (final s in steps)
      if (s['id'] != null) s['id'] as String: s,
  };
  String run(YamlMap s) => (s['run'] ?? '') as String;
  String cond(YamlMap s) => (s['if'] ?? '').toString();

  test(
    'CA-020-01: se lanza solo con una etiqueta v* o a mano (sin entradas)',
    () {
      final on = doc['on'] as YamlMap;
      expect(on.keys.toSet(), {'push', 'workflow_dispatch'});
      final push = on['push'] as YamlMap;
      expect(push.keys.toSet(), {'tags'}, reason: 'sin branches ni paths');
      expect(push['tags'], ['v*']);
      final dispatch = on['workflow_dispatch'];
      expect(dispatch == null || (dispatch as YamlMap).isEmpty, isTrue);
    },
  );

  test('CA-020-01: nunca con una PR, un fork ni un pull_request_target', () {
    expect(text, isNot(contains('pull_request')));
    expect(text, isNot(contains('workflow_run')));
    expect(text, isNot(contains('issue_comment')));
  });

  test(
    'CA-020-01: permisos mínimos (contenido y lectura de las ejecuciones)',
    () {
      expect(doc['permissions'], {'contents': 'read', 'actions': 'read'});
      final jobPerms = job['permissions'];
      expect(
        jobPerms == null ||
            jobPerms.toString() == doc['permissions'].toString(),
        isTrue,
      );
    },
  );

  test('CA-020-01: ninguna acción sin fijar por SHA, y solo las de ci.yml con los mismos SHA', () {
    final ci = File('../.github/workflows/ci.yml').readAsStringSync();
    final used = <String>{};
    for (final s in steps) {
      final uses = s['uses'] as String?;
      if (uses == null) continue;
      final at = uses.indexOf('@');
      expect(at, greaterThan(0), reason: uses);
      final sha = uses.substring(at + 1);
      expect(
        _sha.hasMatch(sha),
        isTrue,
        reason: 'no está fijada por SHA: $uses',
      );
      expect(ci, contains(uses), reason: '$uses no es la misma que usa ci.yml');
      used.add(uses.substring(0, at));
    }
    expect(used, {
      'actions/checkout',
      'actions/setup-java',
      'actions/upload-artifact',
    });
  });

  test('CA-020-01: ningún secreto, ni en comentarios', () {
    expect(text, isNot(contains('secrets.')));
    expect(text, isNot(contains('secrets[')));
    expect(text, isNot(contains('GITHUB_TOKEN')));
  });

  test(
    'CA-020-01: el checkout no persiste credenciales y trae toda la historia',
    () {
      final checkout = steps.firstWhere(
        (s) => (s['uses'] as String?)?.startsWith('actions/checkout@') ?? false,
      );
      expect(checkout['with'], {
        'persist-credentials': false,
        'fetch-depth': 0,
      });
      expect(steps.first, same(checkout));
    },
  );

  test('CA-020-01: ningún «\${{» dentro de un run:', () {
    for (final s in steps) {
      expect(run(s), isNot(contains(r'${{')), reason: '${s['name']}');
    }
  });

  test('CA-020-01: GH_TOKEN solo en el paso ci-runs', () {
    expect(RegExp('GH_TOKEN').allMatches(text), hasLength(1));
    expect((byId['ci-runs']!['env'] as YamlMap).keys, contains('GH_TOKEN'));
    expect(
      (byId['ci-runs']!['env'] as YamlMap)['GH_TOKEN'],
      r'${{ github.token }}',
    );
    expect(doc['env'], isNull);
    expect((job['env'] as YamlMap).keys, isNot(contains('GH_TOKEN')));
  });

  test('CA-020-01: un solo trabajo, sin cancelar el que está en curso, y con límite de tiempo', () {
    expect((doc['jobs'] as YamlMap), hasLength(1));
    expect(job['runs-on'], 'ubuntu-latest');
    expect(job['timeout-minutes'], isA<int>());
    final c = doc['concurrency'] as YamlMap;
    expect(c['cancel-in-progress'], false);
    expect(c['group'], contains('github.sha'));
    expect(c['group'], contains('github.event_name'));
  });

  test('CA-020-03: el modo sale del evento (etiqueta = estricto, a mano = testers)', () {
    final mode = (job['env'] as YamlMap)['MODE'] as String;
    expect(mode, contains("github.event_name == 'push'"));
    expect(mode, contains("'strict'"));
    expect(mode, contains("'testers'"));
  });

  test('CA-020-02: todos los pasos menos el checkout corren aunque falle uno anterior (!cancelled())', () {
    for (final s in steps.skip(1)) {
      expect(cond(s), contains('!cancelled()'), reason: '${s['name']}');
    }
  });

  test(
    'CA-020-02: «rojo al empezar»: el paso mode va primero, antes de compilar',
    () {
      final mode = byId['mode']!;
      expect(run(mode), contains('check-tag.sh --early'));
      expect(run(mode), contains(r'--mode "$MODE"'));
      expect(
        run(mode),
        isNot(contains('run-check.sh')),
        reason: 'su resultado va por outcome',
      );
      expect(mode['continue-on-error'], isNull);
      expect(steps.indexOf(mode), 1);
      expect(steps.indexOf(mode), lessThan(steps.indexOf(byId['build']!)));
    },
  );

  test('CA-020-02: build sin envoltorio, con su código real y solo si el modo y el lockfile salieron bien', () {
    final build = byId['build']!;
    expect(run(build), isNot(contains('run-check.sh')));
    expect(build['continue-on-error'], isNull);
    expect(run(build), contains('flutter build apk --release --split-per-abi'));
    expect(run(build), contains('flutter build appbundle --release'));
    expect(cond(build), contains("steps.mode.outcome == 'success'"));
    expect(cond(build), contains("steps.lockfile.outcome == 'success'"));
  });

  const afterBuild = [
    'permissions',
    'test-classes',
    'pdfium',
    'licenses',
    'size',
    'mastg-static',
    'package-name',
    'signature',
  ];

  test('CA-020-02: lo que depende del paquete solo corre si la compilación salió bien', () {
    for (final id in afterBuild) {
      expect(
        cond(byId[id]!),
        contains("steps.build.outcome == 'success'"),
        reason: id,
      );
      expect(
        steps.indexOf(byId[id]!),
        greaterThan(steps.indexOf(byId['build']!)),
        reason: id,
      );
    }
    for (final id in [
      'ci-runs',
      'lockfile',
      'identity',
      'native-strings',
      'tag',
    ]) {
      expect(cond(byId[id]!), isNot(contains('steps.build')), reason: id);
    }
  });

  test('CA-020-02: cada comprobación esperada por el resumen tiene su paso, por el envoltorio', () {
    for (final id in releaseCheckIds) {
      final s = byId[id];
      expect(s, isNotNull, reason: 'falta el paso con id: $id');
      expect(
        run(s!),
        contains('tools/release/run-check.sh $id --'),
        reason: id,
      );
      // continue-on-error: su outcome es el verdadero y el resumen lo cruza con results.tsv.
      expect(s['continue-on-error'], true, reason: id);
    }
    final used = RegExp(r'run-check\.sh ([a-z-]+) --')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toList();
    expect(used.toSet(), releaseCheckIds.toSet());
    expect(
      used,
      hasLength(releaseCheckIds.length),
      reason: 'ningún id repetido',
    );
    for (final id in releaseStepOnlyIds) {
      expect(byId[id], isNotNull, reason: id);
    }
  });

  test('CA-020-02: las comprobaciones con clase piden su JSON con {json}', () {
    for (final id in classedChecks.keys) {
      expect(run(byId[id]!), contains("'{json}'"), reason: id);
    }
    for (final id in releaseCheckIds.where(
      (i) => !classedChecks.containsKey(i),
    )) {
      expect(run(byId[id]!), isNot(contains('{json}')), reason: id);
    }
  });

  test('CA-020-02: las comprobaciones sobre paquetes reciben la lista explícita (APK y AAB), nunca un glob', () {
    final env = job['env'] as YamlMap;
    final apks = (env['APKS'] as String)
        .replaceAll(RegExp(r'\$\{\{[^}]*\}\}'), 'W')
        .split(' ');
    expect(apks, hasLength(3));
    for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
      expect(
        apks.where((a) => a.endsWith('app-$abi-release.apk')),
        hasLength(1),
      );
    }
    expect(env['AAB'], endsWith('/bundle/release/app-release.aab'));
    for (final id in [
      'test-classes',
      'pdfium',
      'mastg-static',
      'package-name',
      'signature',
    ]) {
      expect(run(byId[id]!), contains(r'$APKS "$AAB"'), reason: id);
    }
    expect(run(byId['size']!), contains(r'$APKS'));
    expect(run(byId['permissions']!), contains(r'--aab "$AAB"'));
    for (final id in afterBuild) {
      expect(
        run(byId[id]!),
        isNot(contains('*')),
        reason: '$id: un glob puede quedar vacío',
      );
    }
  });

  test(
    'CA-020-02: cada comprobación llama a la herramienta que dice la spec',
    () {
      final expected = {
        'ci-runs': 'tools/release/check-ci-runs.sh',
        'lockfile': 'flutter pub get --enforce-lockfile',
        'identity': 'tools/check-release-config.sh',
        'native-strings': 'gen_android_strings.dart --check',
        'permissions': 'tools/check-android-permissions.sh release',
        'test-classes': 'tools/check-apk-no-test-classes.sh',
        'pdfium': 'tools/check-pdfium.sh',
        'licenses': 'tools/check-licenses.sh',
        'size': 'tools/check-size.sh',
        'mastg-static': 'tools/check-package.sh',
        'package-name': 'tools/check-package.sh --package-name',
        'signature': 'tools/release/check-signature.sh --mode "\$MODE"',
        'tag': 'tools/release/check-tag.sh --mode "\$MODE"',
      };
      expect(expected.keys.toSet(), releaseCheckIds.toSet());
      expected.forEach((id, call) {
        expect(run(byId[id]!), contains(call), reason: id);
      });
      expect(run(byId['licenses']!), contains('check-licenses.sh --negative'));
      expect(run(byId['ci-runs']!), contains(r'--sha "$GITHUB_SHA"'));
      expect(run(byId['tag']!), contains(r'--ref "$GITHUB_REF"'));
    },
  );

  test('CA-020-02: el resumen es el último paso de comprobación y recibe los outcome de GitHub', () {
    final summary = byId['summary']!;
    expect(run(summary), contains('tool/release_summary.dart'));
    expect(run(summary), contains(r'--mode "$MODE"'));
    expect(run(summary), contains('results.tsv'));
    expect(
      (summary['env'] as YamlMap)['RELEASE_STEPS_JSON'],
      r'${{ toJSON(steps) }}',
    );
    expect(summary['continue-on-error'], isNull);
    for (final id in [...releaseStepOnlyIds, ...releaseCheckIds]) {
      expect(
        steps.indexOf(summary),
        greaterThan(steps.indexOf(byId[id]!)),
        reason: id,
      );
    }
    expect(cond(summary), contains('!cancelled()'));
  });

  test('CA-020-06: deja solo el archivo de avisos de terceros y el resumen, a 90 días; nunca un APK ni un AAB', () {
    final uploads = [
      for (final s in steps)
        if ((s['uses'] as String?)?.startsWith('actions/upload-artifact@') ??
            false)
          s,
    ];
    expect(uploads.map((s) => (s['with'] as YamlMap)['name']).toSet(), {
      'third-party-notices',
      'release-summary',
    });
    for (final s in uploads) {
      final w = s['with'] as YamlMap;
      expect(w['retention-days'], 90);
      final path = (w['path'] as String);
      expect(
        RegExp(r'\.(apk|aab)\b|\*\*|\*').hasMatch(path),
        isFalse,
        reason: path,
      );
      expect(
        path,
        anyOf(endsWith('third-party-notices.txt'), endsWith('summary.md')),
      );
    }
    // Nada más que suba: ni gh release, ni cp a otro sitio, ni ningún otro verbo de publicación.
    expect(text, isNot(contains('gh release')));
    expect(text, isNot(contains('actions/upload-release-asset')));
    // El archivo de avisos solo si las licencias pasaron.
    final notices = uploads.firstWhere(
      (s) => (s['with'] as YamlMap)['name'] == 'third-party-notices',
    );
    expect(cond(notices), contains("steps.licenses.outcome == 'success'"));
  });

  test('CA-020-07: todo lo que invoca el workflow existe', () {
    final scripts = RegExp(r'(?:tools/[\w/.-]+\.sh|tool/[\w.]+\.dart)')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet();
    expect(scripts, isNotEmpty);
    for (final s in scripts) {
      final path = s.startsWith('tool/') ? s : '../$s';
      expect(File(path).existsSync(), isTrue, reason: s);
    }
  });

  test('CA-020-08: la CI de las PR no pasa la puerta de la identidad ni el resumen', () {
    final ci = File('../.github/workflows/ci.yml').readAsStringSync();
    expect(ci, isNot(contains('check-release-config')));
    expect(ci, isNot(contains('release_summary')));
    expect(ci, isNot(contains('check-tag')));
    expect(ci, isNot(contains('check-ci-runs')));
    expect(ci, isNot(contains('check-signature')));
  });

  test('CA-020-01: actionlint, si está instalado', () {
    ProcessResult r;
    try {
      r = Process.runSync('actionlint', [File(_path).absolute.path]);
    } on ProcessException {
      markTestSkipped('actionlint no está instalado (se anota en tasks.md)');
      return;
    }
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });
}
