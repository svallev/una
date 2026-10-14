import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tools/release/check-ci-runs.sh` (CA-020-02 punto 0, P-020-3 a): la CI y Security del commit que
/// se entrega terminaron en verde. Lee las ejecuciones con `gh api` (se sustituye por un `gh` falso en
/// el PATH) y no espera nunca: lo que no ha terminado, no existe, se canceló o se saltó es un fallo.
const _script = '../tools/release/check-ci-runs.sh';
final _sha = 'a' * 40;
const _repo = 'dueno/una';

Map<String, Object?> _run(
  int number, {
  String status = 'completed',
  String? conclusion = 'success',
  String path = '.github/workflows/ci.yml',
  String event = 'push',
  String branch = 'main',
  String? sha,
}) => {
  'id': 1000 + number,
  'run_number': number,
  'run_attempt': 1,
  'path': path,
  'event': event,
  'head_branch': branch,
  'head_sha': sha ?? _sha,
  'status': status,
  'conclusion': conclusion,
  'created_at': '2026-10-14T10:${number.toString().padLeft(2, '0')}:00Z',
};

void main() {
  late Directory tmp;
  late Directory bin;
  late Directory data;
  late File log;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ci_runs_');
    bin = Directory('${tmp.path}/bin')..createSync();
    data = Directory('${tmp.path}/data')..createSync();
    log = File('${tmp.path}/gh.log');
    File('${bin.path}/gh').writeAsStringSync(r'''#!/usr/bin/env bash
echo "$@" >> "$FAKE_LOG"
ep=""
for a in "$@"; do case "$a" in */actions/workflows/*) ep="$a" ;; esac; done
wf="${ep#*/workflows/}"; wf="${wf%%/*}"
f="$FAKE_DIR/$wf.json"
[ -f "$f" ] || { echo "gh: HTTP 404" >&2; exit 1; }
cat "$f"
''');
    Process.runSync('chmod', ['+x', '${bin.path}/gh']);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  void runsFor(String workflow, Object? runs) {
    File('${data.path}/$workflow.json').writeAsStringSync(
      runs is String
          ? runs
          : jsonEncode({
              'total_count': (runs as List).length,
              'workflow_runs': runs,
            }),
    );
  }

  Map<String, Object?> sec(
    int n, {
    String status = 'completed',
    String? conclusion = 'success',
  }) => _run(
    n,
    status: status,
    conclusion: conclusion,
    path: '.github/workflows/security.yml',
  );

  ProcessResult run({
    String? sha,
    String? repo,
    List<String> extra = const [],
  }) {
    return Process.runSync(
      'bash',
      [_script, '--repo', repo ?? _repo, '--sha', sha ?? _sha, ...extra],
      environment: {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'FAKE_LOG': log.path,
        'FAKE_DIR': data.path,
      },
    );
  }

  String out(ProcessResult r) => '${r.stdout}${r.stderr}';

  test('CA-020-02: CI y Security en verde sobre el commit pasa', () {
    runsFor('ci.yml', [_run(5)]);
    runsFor('security.yml', [sec(5)]);
    final r = run();
    expect(r.exitCode, 0, reason: out(r));
  });

  test('CA-020-02: pide cada workflow por su archivo, push, main y el commit exacto', () {
    runsFor('ci.yml', [_run(5)]);
    runsFor('security.yml', [sec(5)]);
    run();
    final calls = log.readAsLinesSync();
    expect(calls, hasLength(2));
    for (final wf in ['ci.yml', 'security.yml']) {
      final call = calls.singleWhere((c) => c.contains('/workflows/$wf/runs'));
      expect(call, contains('repos/$_repo/actions/workflows/$wf/runs'));
      expect(call, contains('event=push'));
      expect(call, contains('branch=main'));
      expect(call, contains('head_sha=$_sha'));
    }
  });

  test(
    'CA-020-02: una ejecución que falló es un fallo que nombra el workflow',
    () {
      runsFor('ci.yml', [_run(5, conclusion: 'failure')]);
      runsFor('security.yml', [sec(5)]);
      final r = run();
      expect(r.exitCode, 1);
      expect(out(r), contains('ci.yml'));
      expect(out(r), contains('failure'));
    },
  );

  test(
    'CA-020-02: sin terminar (en curso, en cola) falla pidiendo esperar',
    () {
      runsFor('ci.yml', [_run(5)]);
      runsFor('security.yml', [
        sec(5, status: 'in_progress', conclusion: null),
      ]);
      final r = run();
      expect(r.exitCode, 1);
      expect(out(r), contains('security.yml'));
      expect(out(r), contains('espera'));
    },
  );

  test('CA-020-02: cancelada, saltada o neutral no cuentan como verde', () {
    for (final c in ['cancelled', 'skipped', 'neutral', 'timed_out', null]) {
      runsFor('ci.yml', [_run(5, conclusion: c)]);
      runsFor('security.yml', [sec(5)]);
      expect(run().exitCode, 1, reason: 'conclusión «$c»');
    }
  });

  test('CA-020-02: sin ninguna ejecución del commit falla', () {
    runsFor('ci.yml', <Object?>[]);
    runsFor('security.yml', [sec(5)]);
    final r = run();
    expect(r.exitCode, 1);
    expect(out(r), contains('ci.yml'));
    expect(out(r), contains('ninguna'));
  });

  test('CA-020-02: cuenta la última ejecución: un reintento en verde sí, uno cancelado después no', () {
    runsFor('ci.yml', [_run(4, conclusion: 'failure'), _run(6)]);
    runsFor('security.yml', [sec(5)]);
    expect(run().exitCode, 0, reason: 'la última es la buena');
    runsFor('ci.yml', [_run(4), _run(6, conclusion: 'cancelled')]);
    expect(run().exitCode, 1, reason: 'la última se canceló');
    // El orden en la respuesta no cuenta: manda run_number.
    runsFor('ci.yml', [_run(6, conclusion: 'failure'), _run(4)]);
    expect(run().exitCode, 1);
  });

  test(
    'CA-020-02: una ejecución de otro commit, evento, rama o archivo no vale',
    () {
      final other = [
        _run(9, sha: 'b' * 40),
        _run(9, event: 'pull_request'),
        _run(9, branch: 'feat/x'),
        _run(9, path: '.github/workflows/otro.yml'),
        // Un workflow que se llama «CI» pero está en otro archivo.
        _run(9, path: '.github/workflows/falso-ci.yml'),
      ];
      for (final o in other) {
        runsFor('ci.yml', [o]);
        runsFor('security.yml', [sec(5)]);
        final r = run();
        expect(r.exitCode, 1, reason: '$o');
      }
    },
  );

  test('CA-020-02: el commit tiene que ser el exacto (no un prefijo)', () {
    runsFor('ci.yml', [_run(5, sha: '${'a' * 39}b')]);
    runsFor('security.yml', [sec(5)]);
    expect(run().exitCode, 1);
  });

  test(
    'CA-020-02: gh que falla, una respuesta ilegible o sin lista, es un fallo',
    () {
      runsFor('security.yml', [sec(5)]);
      // Sin archivo para ci.yml el gh falso sale con 1.
      expect(run().exitCode, 1);
      for (final body in [
        'no es json',
        '[]',
        '{}',
        '{"workflow_runs": 3}',
        '',
      ]) {
        runsFor('ci.yml', body);
        expect(run().exitCode, 1, reason: 'respuesta «$body»');
      }
    },
  );

  test('CA-020-02: un elemento sin los campos esperados es un fallo', () {
    runsFor('security.yml', [sec(5)]);
    runsFor('ci.yml', [
      {'status': 'completed'},
    ]);
    expect(run().exitCode, 1);
  });

  test(
    'CA-020-02: argumentos mal formados son un error de uso y no llaman a gh',
    () {
      expect(run(sha: 'abc').exitCode, 2);
      expect(run(sha: 'A' * 40).exitCode, 2);
      expect(run(sha: '${'a' * 40};x').exitCode, 2);
      expect(run(repo: 'sin-barra').exitCode, 2);
      expect(run(repo: 'a/b/c').exitCode, 2);
      expect(run(repo: r'a/b$(x)').exitCode, 2);
      // The whole value is checked, not line by line.
      expect(run(sha: '${'a' * 40}\nx').exitCode, 2);
      expect(run(repo: 'a/b\nx y').exitCode, 2);
      expect(run(extra: ['--nada']).exitCode, 2);
      expect(log.existsSync(), isFalse);
      final r = Process.runSync('bash', [_script]);
      expect(r.exitCode, 2);
    },
  );

  test('CA-020-02: sin gh en el PATH es un fallo', () {
    final r = Process.runSync(
      '/bin/bash',
      [_script, '--repo', _repo, '--sha', _sha],
      environment: {'PATH': '/nonexistent:/bin'},
    );
    expect(r.exitCode, isNot(0));
  });
}
