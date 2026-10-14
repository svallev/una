import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tools/release/check-tag.sh` (CA-020-03 c y d, CA-020-05 e; CL-020-1, 2, 3, 17 y 19): la etiqueta
/// del modo estricto y la referencia del modo testers. Se prueba con repositorios `git` temporales.
const _script = '../tools/release/check-tag.sh';

void main() {
  late Directory tmp;
  late String repo;
  late String json;

  String git(List<String> args) {
    final r = Process.runSync('git', ['-C', repo, ...args]);
    if (r.exitCode != 0) fail('git $args: ${r.stderr}');
    return (r.stdout as String).trim();
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('check_tag_');
    repo = '${tmp.path}/repo';
    json = '${tmp.path}/tag.json';
    Directory(repo).createSync();
    git(['init', '-q', '-b', 'main']);
    git(['config', 'user.email', 't@example.invalid']);
    git(['config', 'user.name', 'Test']);
    git(['config', 'commit.gpgsign', 'false']);
    git(['config', 'tag.gpgsign', 'false']);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Un commit que pone `version:` en `app/pubspec.yaml` (o lo quita con null).
  void commit(String? version, {String note = 'x'}) {
    final f = File('$repo/app/pubspec.yaml')..createSync(recursive: true);
    f.writeAsStringSync(
      'name: una\n${version == null ? '' : 'version: $version\n'}# $note\n',
    );
    git(['add', '-A']);
    git(['commit', '-q', '-m', note]);
  }

  ProcessResult run(List<String> args) {
    return Process.runSync('bash', [_script, '--repo', repo, ...args]);
  }

  List<Map<String, dynamic>> issues() {
    final j = jsonDecode(File(json).readAsStringSync()) as Map<String, dynamic>;
    expect(j['version'], 1);
    expect(j['complete'], isTrue);
    expect(j['checks'], contains('tag'));
    return (j['issues'] as List).cast<Map<String, dynamic>>();
  }

  ProcessResult strict(String tag, {List<String> extra = const []}) => run([
    '--mode',
    'strict',
    '--ref',
    'refs/tags/$tag',
    '--main-ref',
    'refs/heads/main',
    '--json',
    json,
    ...extra,
  ]);

  String text(ProcessResult r) => '${r.stdout}${r.stderr}';

  group('modo estricto', () {
    test('CA-020-03: etiqueta vX.Y.Z = pubspec, en main, sin etiquetas previas: sin hallazgos', () {
      commit('1.2.3+5');
      git(['tag', 'v1.2.3']);
      final r = strict('v1.2.3');
      expect(r.exitCode, 0, reason: text(r));
      expect(issues(), isEmpty);
    });

    test('CA-020-03 c: una etiqueta anotada también vale', () {
      commit('1.2.3+5');
      git(['tag', '-a', 'v1.2.3', '-m', 'versión']);
      final r = strict('v1.2.3');
      expect(r.exitCode, 0, reason: text(r));
    });

    test(
      'CA-020-03 c, CL-020-1: una etiqueta que no es vX.Y.Z falla nombrándola',
      () {
        commit('0.0.0+1');
        for (final tag in [
          'v0.0.0-gate',
          'v1.2',
          'v1.2.3.4',
          '1.2.3',
          'v1.2.3-rc1',
          'vfoo',
          'v1.2.x',
          'V1.2.3',
          'v1.2.3+4',
        ]) {
          git(['tag', tag]);
          final r = strict(tag);
          expect(r.exitCode, 1, reason: tag);
          expect(text(r), contains(tag), reason: tag);
          final is_ = issues();
          expect(is_, isNotEmpty);
          expect(is_.every((i) => i['kind'] == 'fault'), isTrue, reason: tag);
          git(['tag', '-d', tag]);
        }
      },
    );

    test('CA-020-03 c: una referencia que no es una etiqueta falla', () {
      commit('1.2.3+5');
      for (final ref in ['refs/heads/main', 'refs/pull/3/merge', 'main', '']) {
        final r = run([
          '--mode',
          'strict',
          '--ref',
          ref,
          '--main-ref',
          'refs/heads/main',
          '--json',
          json,
        ]);
        expect(r.exitCode, 1, reason: 'ref «$ref»');
      }
    });

    test('CA-020-03 c: no coincide con la versión de pubspec.yaml', () {
      commit('1.2.3+5');
      git(['tag', 'v1.2.4']);
      final r = strict('v1.2.4');
      expect(r.exitCode, 1);
      expect(text(r), contains('1.2.3'));
      expect(text(r), contains('v1.2.4'));
      expect(issues().single['kind'], 'fault');
    });

    test(
      'CA-020-03 c: un pubspec sin version, sin +build o con otra forma falla',
      () {
        for (final version in [
          null,
          '1.2.3',
          '1.2.3+',
          '1.2.3+x',
          '1.2.3-beta+1',
          'x',
        ]) {
          commit(version, note: 'v $version');
          git(['tag', 'v1.2.3']);
          final r = strict('v1.2.3');
          expect(r.exitCode, 1, reason: 'version «$version»');
          git(['tag', '-d', 'v1.2.3']);
        }
      },
    );

    test('CA-020-03 d, CL-020-2: un commit que no está en main falla', () {
      commit('1.2.3+5');
      git(['checkout', '-q', '-b', 'feat/x']);
      commit('1.2.3+5', note: 'fuera de main');
      git(['tag', 'v1.2.3']);
      final r = strict('v1.2.3');
      expect(r.exitCode, 1);
      expect(text(r), contains('main'));
      expect(issues().single['kind'], 'fault');
    });

    test(
      'CA-020-03 d: un commit antecesor de main sí vale (main avanzó después)',
      () {
        commit('1.2.3+5');
        git(['tag', 'v1.2.3']);
        final tagged = git(['rev-parse', 'HEAD']);
        commit('1.2.4+6', note: 'más tarde');
        git(['checkout', '-q', tagged]);
        final r = strict('v1.2.3');
        expect(r.exitCode, 0, reason: text(r));
      },
    );

    test('CA-020-03 d: sin la referencia de main no se da nada por bueno', () {
      commit('1.2.3+5');
      git(['tag', 'v1.2.3']);
      final r = strict('v1.2.3', extra: ['--main-ref', 'refs/heads/no-existe']);
      expect(r.exitCode, 1);
      expect(text(r), contains('no-existe'));
    });

    test(
      'CL-020-19: el commit que se comprueba tiene que ser el de la etiqueta',
      () {
        commit('1.2.3+5');
        git(['tag', 'v1.2.3']);
        commit('1.2.3+5', note: 'después de la etiqueta');
        final r = strict('v1.2.3');
        expect(r.exitCode, 1);
        expect(text(r), contains('etiqueta'));
      },
    );

    test('CL-020-17: el versionCode tiene que superar al de la etiqueta anterior más alta', () {
      commit('1.2.2+5');
      git(['tag', 'v1.2.2']);
      for (final (build, ok) in [
        (5, false),
        (4, false),
        (6, true),
        (50, true),
      ]) {
        commit('1.2.3+$build', note: 'b$build');
        git(['tag', 'v1.2.3']);
        final r = strict('v1.2.3');
        expect(r.exitCode, ok ? 0 : 1, reason: '+$build: ${text(r)}');
        if (!ok) {
          expect(text(r), contains('v1.2.2'));
          expect(text(r), contains('versionCode'));
        }
        git(['tag', '-d', 'v1.2.3']);
      }
    });

    test('CL-020-17: se compara con la más alta, no con la última creada', () {
      commit('1.10.0+10');
      git(['tag', 'v1.10.0']);
      commit('1.9.0+4', note: 'antigua creada después');
      git(['tag', 'v1.9.0']);
      commit('1.11.0+10', note: 'actual');
      git(['tag', 'v1.11.0']);
      // v1.10.0 (+10) es la más alta (orden de versión, no de creación; 1.10 > 1.9).
      expect(strict('v1.11.0').exitCode, 1);
      git(['tag', '-d', 'v1.11.0']);
      commit('1.11.0+11', note: 'actual bien');
      git(['tag', 'v1.11.0']);
      expect(strict('v1.11.0').exitCode, 0);
    });

    test('CL-020-17: solo cuentan las etiquetas con forma vX.Y.Z y nunca la propia', () {
      commit('0.9.0+99');
      git(['tag', 'v0.9.0-gate']); // no cuenta: no tiene la forma
      git(['tag', 'prueba']);
      commit('1.2.3+5', note: 'actual');
      git(['tag', 'v1.2.3']);
      final r = strict('v1.2.3');
      expect(r.exitCode, 0, reason: text(r));
    });

    test('CL-020-17: la etiqueta anterior se lee de su propio commit; si no se puede leer, falla', () {
      commit(null, note: 'sin version');
      git(['tag', 'v1.0.0']);
      commit('1.2.3+5', note: 'actual');
      git(['tag', 'v1.2.3']);
      final r = strict('v1.2.3');
      expect(r.exitCode, 1);
      expect(text(r), contains('v1.0.0'));
    });

    test(
      'CA-020-05: todos los hallazgos del modo estricto son fallo, nunca aviso',
      () {
        commit('1.2.3+5');
        git(['tag', 'v1.2.4']);
        strict('v1.2.4');
        expect(issues().map((i) => i['kind']).toSet(), {'fault'});
        expect(issues().every((i) => i['subject'] == 'tag'), isTrue);
      },
    );

    test('CA-020-03: un nombre de etiqueta con comillas o saltos no rompe el JSON ni inyecta comandos', () {
      commit('1.2.3+5');
      const nasty = r'v1.2.3"x$(echo)`id`;y|z&w';
      git(['tag', nasty]);
      final r = strict(nasty);
      expect(r.exitCode, 1);
      final lines = (r.stdout as String).split('\n');
      // Nada de lo que viene de la etiqueta puede abrir una orden de workflow.
      expect(
        lines.where(
          (l) => l.startsWith('::') && !l.startsWith('::error::tag:'),
        ),
        isEmpty,
      );
      expect(text(r), isNot(contains(nasty)));
      expect(issues(), isNotEmpty); // el JSON se puede leer
    });

    test('CA-020-03: sin repositorio de git es un fallo, no un verde', () {
      final r = Process.runSync('bash', [
        _script,
        '--repo',
        tmp.path,
        '--mode',
        'strict',
        '--ref',
        'refs/tags/v1.2.3',
        '--main-ref',
        'refs/heads/main',
        '--json',
        json,
      ]);
      expect(r.exitCode, 1);
      expect(issues().single['kind'], 'fault');
    });
  });

  group('modo testers', () {
    ProcessResult testers(String ref) =>
        run(['--mode', 'testers', '--ref', ref, '--json', json]);

    test('CA-020-05 e: lanzado desde main avisa de que no hay etiqueta (y nada más)', () {
      commit('1.2.3+5');
      final r = testers('refs/heads/main');
      expect(r.exitCode, 1, reason: text(r));
      final is_ = issues();
      expect(is_.single['kind'], 'missing');
      expect(is_.single['subject'], 'tag');
    });

    test(
      'CL-020-3: desde otra rama es un fallo, también el aviso pasa a fallo',
      () {
        commit('1.2.3+5');
        for (final ref in [
          'refs/heads/feat/x',
          'refs/heads/mainx',
          'refs/tags/v1.2.3',
          'main',
          '',
        ]) {
          final r = testers(ref);
          expect(r.exitCode, 1, reason: 'ref «$ref»');
          expect(issues().map((i) => i['kind']).toSet(), {
            'fault',
          }, reason: ref);
          expect(text(r), contains('main'), reason: ref);
        }
      },
    );
  });

  group('--early (rojo al empezar, antes de compilar)', () {
    ProcessResult early(String mode, String ref) =>
        run(['--early', '--mode', mode, '--ref', ref]);

    test(
      'CL-020-1: estricto con una etiqueta bien formada pasa; mal formada, no',
      () {
        expect(early('strict', 'refs/tags/v1.2.3').exitCode, 0);
        for (final ref in [
          'refs/tags/v0.0.0-gate',
          'refs/tags/v1.2',
          'refs/heads/main',
          'refs/tags/v1.2.3/extra',
        ]) {
          final r = early('strict', ref);
          expect(r.exitCode, 1, reason: ref);
          expect(text(r), contains('vX.Y.Z'), reason: ref);
        }
      },
    );

    test('CL-020-3: testers solo desde refs/heads/main', () {
      expect(early('testers', 'refs/heads/main').exitCode, 0);
      for (final ref in ['refs/heads/feat/x', 'refs/tags/v1.2.3', '']) {
        final r = early('testers', ref);
        expect(r.exitCode, 1, reason: ref);
        expect(text(r), contains('main'), reason: ref);
      }
    });

    test('--early no necesita repositorio ni escribe JSON', () {
      final r = Process.runSync('bash', [
        File(_script).absolute.path,
        '--early',
        '--mode',
        'testers',
        '--ref',
        'refs/heads/main',
      ], workingDirectory: tmp.path);
      expect(r.exitCode, 0, reason: text(r));
      expect(File(json).existsSync(), isFalse);
    });
  });

  group('uso', () {
    test(
      'CA-020-03: argumentos que faltan o no válidos son un error de uso',
      () {
        expect(run([]).exitCode, 2);
        expect(run(['--mode', 'otro', '--ref', 'refs/heads/main']).exitCode, 2);
        expect(run(['--mode', 'strict']).exitCode, 2);
        expect(run(['--ref', 'refs/heads/main']).exitCode, 2);
        expect(
          run(['--mode', 'strict', '--ref', 'refs/tags/v1.2.3', '--nada'])
              .exitCode,
          2,
        );
        // Sin --json en el modo completo tampoco hay dónde dejar la clase.
        expect(
          run(['--mode', 'strict', '--ref', 'refs/tags/v1.2.3']).exitCode,
          2,
        );
      },
    );
  });
}
