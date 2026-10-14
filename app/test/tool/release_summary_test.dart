import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_summary.dart';

/// `tool/release_summary.dart` (CA-020-02 a 05, 07; CL-020-20): lee `results.tsv` y los `outcome` de
/// GitHub, aplica la tabla cerrada de avisos de identidad y decide verde / verde con avisos / rojo.
/// Falla cerrada: lo que no aparece, no casa, no se lee o no se conoce es un fallo.

const _dir = '/r'; // carpeta ficticia de los JSON

/// Los `checks` que cada comprobación con clase tiene que declarar en su JSON.
const _requiredChecks = <String, List<String>>{
  'identity': ['addresses', 'policy', 'generated'],
  'package-name': ['package-name'],
  'signature': ['signature'],
  'tag': ['tag'],
};

String _json(
  String id,
  List<Map<String, String>> issues, {
  Object? version = 1,
  Object? complete = true,
  Object? checks,
}) {
  return jsonEncode({
    'version': ?version,
    'complete': ?complete,
    'checks': ?(checks ?? _requiredChecks[id]),
    'issues': issues,
  });
}

Map<String, String> _issue(
  String kind, [
  String subject = 's',
  String m = 'm',
]) => {'kind': kind, 'subject': subject, 'message': m};

/// Un mundo completo y en verde que cada test estropea en un sitio.
class _World {
  _World() {
    for (final id in releaseCheckIds) {
      codes[id] = 0;
    }
    for (final id in _requiredChecks.keys) {
      jsons[id] = _json(id, []);
    }
  }

  final codes = <String, int>{};
  final jsons = <String, String?>{};
  final outcomeOverrides = <String, String?>{};
  final extraRows = <String>[];
  final removedRows = <String>{};
  final pathOverrides = <String, String>{};
  Set<String> removedSteps = {};

  String path(String id) => pathOverrides[id] ?? '$_dir/$id.json';

  String get results {
    final lines = <String>[];
    for (final id in releaseCheckIds) {
      if (removedRows.contains(id)) continue;
      final p = _requiredChecks.containsKey(id) ? path(id) : '';
      lines.add('$id\t${codes[id]}\t$p');
    }
    lines.addAll(extraRows);
    return '${lines.join('\n')}\n';
  }

  Map<String, Object?> get steps {
    final m = <String, Object?>{};
    for (final id in [...releaseStepOnlyIds, ...releaseCheckIds]) {
      if (removedSteps.contains(id)) continue;
      final String? o = outcomeOverrides.containsKey(id)
          ? outcomeOverrides[id]
          : (releaseStepOnlyIds.contains(id) || codes[id] == 0)
          ? 'success'
          : 'failure';
      m[id] = {'outcome': o, 'conclusion': o};
    }
    return m;
  }

  String? read(String p) {
    for (final e in _requiredChecks.keys) {
      if (path(e) == p) return jsons[e];
    }
    return null;
  }

  SummaryReport build(ReleaseMode mode, {String? resultsText}) => buildSummary(
    mode: mode,
    resultsText: resultsText ?? results,
    steps: steps,
    readJson: read,
  );
}

Finding _only(SummaryReport r, String check, {Severity? severity}) {
  final f = r.findings.where((f) => f.check == check).toList();
  expect(f, hasLength(1), reason: '$check: ${r.findings.join('\n')}');
  if (severity != null) expect(f.single.severity, severity);
  return f.single;
}

void main() {
  group('lista de ids', () {
    test('CA-020-02: las comprobaciones esperadas son las del plan §3.2', () {
      expect(releaseCheckIds, [
        'ci-runs',
        'lockfile',
        'identity',
        'native-strings',
        'permissions',
        'test-classes',
        'pdfium',
        'licenses',
        'size',
        'mastg-static',
        'package-name',
        'signature',
        'tag',
      ]);
      expect(releaseStepOnlyIds, ['mode', 'build']);
    });

    test('CA-020-05: la tabla cerrada de avisos es la de la spec', () {
      expect(identityWarningTable.keys.toSet(), {
        'identity.placeholderAddress',
        'identity.policyGap',
        'identity.policyMark',
        'package-name.provisional',
        'signature.debug',
        'signature.unsigned',
        'signature.uploadCertMissing',
        'tag.missing',
      });
      // uploadCertMissing solo en estricto; tag.missing solo en testers (CA-020-05 e).
      expect(identityWarningTable['signature.uploadCertMissing'], {
        ReleaseMode.strict,
      });
      expect(identityWarningTable['tag.missing'], {ReleaseMode.testers});
      for (final k in identityWarningTable.keys.where(
        (k) => k != 'signature.uploadCertMissing' && k != 'tag.missing',
      )) {
        expect(identityWarningTable[k], {
          ReleaseMode.strict,
          ReleaseMode.testers,
        }, reason: k);
      }
    });
  });

  group('verde', () {
    for (final mode in ReleaseMode.values) {
      test(
        'CA-020-02: todo en verde (${mode.name}) lista todas las comprobaciones como ok',
        () {
          final r = _World().build(mode);
          expect(r.exitCode, 0, reason: r.findings.join('\n'));
          expect(r.findings, isEmpty);
          expect(r.results.keys, [...releaseStepOnlyIds, ...releaseCheckIds]);
          expect(r.results.values.toSet(), {Severity.ok});
          for (final id in releaseCheckIds) {
            expect(r.markdown, contains(id));
          }
        },
      );
    }
  });

  group('avisos de identidad', () {
    _World hoy() {
      final w = _World();
      w.codes
        ..['identity'] = 1
        ..['package-name'] = 1
        ..['signature'] = 1
        ..['tag'] = 1;
      w.jsons['identity'] = _json('identity', [
        _issue('placeholderAddress', 'privacyPolicyUrl', 'es un marcador'),
        _issue('policyGap', 'privacy-policy.md', 'hueco [CONTACTO]'),
        _issue('policyMark', 'privacy-policy.md', 'línea 12: [Pendiente]'),
      ]);
      w.jsons['package-name'] = _json('package-name', [
        _issue('provisional', 'app-release.aab', 'invalid.pending.app'),
      ]);
      w.jsons['signature'] = _json('signature', [
        _issue('debug', 'app-release.aab', 'CN=Android Debug'),
        _issue('unsigned', 'app-x86_64-release.apk', 'sin firmar'),
      ]);
      w.jsons['tag'] = _json('tag', [_issue('missing', 'tag', 'sin etiqueta')]);
      return w;
    }

    test('CA-020-04: en testers los avisos no paran el trabajo y se listan uno por línea', () {
      final r = hoy().build(ReleaseMode.testers);
      expect(r.exitCode, 0, reason: r.findings.join('\n'));
      expect(r.findings, hasLength(7));
      expect(r.findings.every((f) => f.severity == Severity.warning), isTrue);
      final lines = r.markdown
          .split('\n')
          .where((l) => l.startsWith('- aviso'));
      expect(lines, hasLength(7));
      expect(
        r.markdown,
        contains('aviso · identity · `privacyPolicyUrl` · `es un marcador`'),
      );
      expect(r.markdown, contains('aviso · signature · `app-release.aab`'));
      expect(r.markdown, contains('aviso · tag'));
      expect(
        r.markdown.trimRight(),
        endsWith('Esta versión no se puede publicar.'),
      );
      expect(r.results['identity'], Severity.warning);
      expect(r.results['permissions'], Severity.ok);
    });

    test(
      'CA-020-03: en estricto cada aviso cuenta como fallo y dice «fallo»',
      () {
        final w = hoy();
        // En estricto no hay «sin etiqueta» ni... pero sí los demás avisos.
        w.codes['tag'] = 0;
        w.jsons['tag'] = _json('tag', []);
        final r = w.build(ReleaseMode.strict);
        expect(r.exitCode, 1);
        expect(r.findings, hasLength(6));
        expect(r.findings.every((f) => f.severity == Severity.failure), isTrue);
        expect(r.markdown, isNot(contains('- aviso')));
        expect(r.markdown, contains('- fallo · identity · `privacyPolicyUrl`'));
        expect(
          r.markdown,
          contains('aviso de identidad no admitido en el modo estricto'),
        );
        expect(
          r.markdown,
          isNot(contains('Esta versión no se puede publicar.')),
        );
        expect(r.results['identity'], Severity.failure);
      },
    );

    test('CA-020-05: el aviso de la huella de subida solo existe en estricto (fallo allí, fallo en testers)', () {
      for (final mode in ReleaseMode.values) {
        final w = _World();
        w.codes['signature'] = 1;
        w.jsons['signature'] = _json('signature', [
          _issue('uploadCertMissing', 'app-release.aab', 'sin huella'),
        ]);
        final r = w.build(mode);
        expect(r.exitCode, 1, reason: mode.name);
        _only(r, 'signature', severity: Severity.failure);
      }
    });

    test('CA-020-05 e: «sin etiqueta» es un aviso en testers y un fallo en estricto', () {
      for (final mode in ReleaseMode.values) {
        final w = _World();
        w.codes['tag'] = 1;
        w.jsons['tag'] = _json('tag', [
          _issue('missing', 'tag', 'sin etiqueta'),
        ]);
        final r = w.build(mode);
        expect(
          _only(r, 'tag').severity,
          mode == ReleaseMode.testers ? Severity.warning : Severity.failure,
        );
        expect(r.exitCode, mode == ReleaseMode.testers ? 0 : 1);
      }
    });

    test('CA-020-05: una dirección con ruta no válida (fault) falla también en testers', () {
      final w = _World();
      w.codes['identity'] = 1;
      w.jsons['identity'] = _json('identity', [
        _issue(
          'fault',
          'privacyPolicyUrl',
          'https://example.com/%2e: la ruta lleva «%»',
        ),
      ]);
      final r = w.build(ReleaseMode.testers);
      expect(r.exitCode, 1);
      _only(r, 'identity', severity: Severity.failure);
      expect(r.markdown, contains('- fallo · identity · `privacyPolicyUrl`'));
    });

    test('CA-020-05: avisos y un fallo juntos: el fallo hace fallar y los avisos siguen listados como avisos', () {
      final w = _World();
      w.codes['identity'] = 1;
      w.jsons['identity'] = _json('identity', [
        _issue('placeholderAddress', 'helpUrl', 'marcador'),
        _issue('fault', 'identity.yaml', 'falta la clave'),
      ]);
      final r = w.build(ReleaseMode.testers);
      expect(r.exitCode, 1);
      expect(r.findings.map((f) => f.severity), [
        Severity.warning,
        Severity.failure,
      ]);
      expect(r.results['identity'], Severity.failure);
    });

    test('CA-020-05: una clase que no está en la tabla es un fallo en los dos modos', () {
      for (final (check, kind) in [
        ('identity', 'nueva'),
        ('identity', 'missing'), // de otra comprobación
        ('package-name', 'placeholderAddress'),
        ('signature', 'provisional'),
        ('tag', 'debug'),
        ('tag', ''),
      ]) {
        for (final mode in ReleaseMode.values) {
          final w = _World();
          w.codes[check] = 1;
          w.jsons[check] = _json(check, [_issue(kind)]);
          final r = w.build(mode);
          expect(r.exitCode, 1, reason: '$check.$kind ${mode.name}');
          expect(
            _only(r, check).severity,
            Severity.failure,
            reason: '$check.$kind ${mode.name}',
          );
        }
      }
    });
  });

  group('fallos de las demás comprobaciones', () {
    test('CA-020-04: un permiso de más (permissions con código 1) es rojo también en testers', () {
      for (final mode in ReleaseMode.values) {
        final w = _World();
        w.codes['permissions'] = 1;
        final r = w.build(mode);
        expect(r.exitCode, 1);
        expect(_only(r, 'permissions').severity, Severity.failure);
        expect(r.markdown, contains('permissions'));
        expect(r.markdown, contains('código 1'));
      }
    });

    test('CA-020-02: cada comprobación que falla (código 1) hace fallar el trabajo', () {
      for (final id in releaseCheckIds.where(
        (i) => !_requiredChecks.containsKey(i),
      )) {
        final w = _World();
        w.codes[id] = 1;
        final r = w.build(ReleaseMode.testers);
        expect(r.exitCode, 1, reason: id);
        expect(_only(r, id).severity, Severity.failure, reason: id);
      }
    });

    test('CA-020-02: un código inesperado (2, 126, 127, 137, 255) en cualquiera es fallo', () {
      for (final id in releaseCheckIds) {
        for (final code in [2, 126, 127, 137, 255]) {
          final w = _World();
          w.codes[id] = code;
          final r = w.build(ReleaseMode.testers);
          expect(r.exitCode, 1, reason: '$id $code');
          expect(_only(r, id).severity, Severity.failure, reason: '$id $code');
        }
      }
    });

    test('CA-020-05: un código distinto de 0 y 1 no es un aviso aunque el JSON sea válido', () {
      for (final code in [2, 126, 127, 137]) {
        for (final id in classedChecks.keys) {
          final kind = switch (id) {
            'identity' => 'policyGap',
            'package-name' => 'provisional',
            'signature' => 'debug',
            _ => 'missing',
          };
          final w = _World();
          w.codes[id] = code;
          w.jsons[id] = _json(id, [_issue(kind)]);
          final r = w.build(ReleaseMode.testers);
          expect(r.exitCode, 1, reason: '$id $code');
          expect(
            r.findings.where((f) => f.severity == Severity.warning),
            isEmpty,
            reason: '$id $code',
          );
          expect(_only(r, id).message, contains('inesperado'), reason: id);
        }
      }
    });

    test('CA-020-05: un aviso con línea falsificada (el paso se saltó o se canceló) no cuenta como aviso', () {
      for (final o in ['skipped', 'cancelled', 'weird', null]) {
        final w = _World();
        w.codes['tag'] = 1;
        w.jsons['tag'] = _json('tag', [
          _issue('missing', 'tag', 'sin etiqueta'),
        ]);
        w.outcomeOverrides['tag'] = o;
        final r = w.build(ReleaseMode.testers);
        expect(r.exitCode, 1, reason: '$o');
        expect(
          r.findings.where((f) => f.severity == Severity.warning),
          isEmpty,
          reason: '$o',
        );
      }
    });

    test('CA-020-02: una comprobación sin clase que sale con 1 dice que falló con ese código', () {
      final w = _World()..codes['pdfium'] = 1;
      expect(
        _only(w.build(ReleaseMode.testers), 'pdfium').message,
        'falló (código 1)',
      );
    });

    test('CA-020-05: un fault del JSON se muestra tal cual, sin notas de clase desconocida', () {
      final w = _World();
      w.codes['identity'] = 1;
      w.jsons['identity'] = _json('identity', [
        _issue('fault', 'helpUrl', 'sin https'),
      ]);
      final f = _only(w.build(ReleaseMode.testers), 'identity');
      expect(f.message, 'sin https');
      expect(f.subject, 'helpUrl');
    });

    test('CA-020-02: cero paquetes de entrada (la comprobación sale con 2 sin JSON) es un fallo', () {
      final w = _World();
      w.codes['signature'] = 2;
      w.jsons['signature'] = null;
      expect(w.build(ReleaseMode.testers).exitCode, 1);
    });

    test(
      'CA-020-02: «build» o «mode» que no terminan en success son un fallo',
      () {
        for (final id in releaseStepOnlyIds) {
          for (final o in ['failure', 'skipped', 'cancelled', null]) {
            final w = _World();
            w.outcomeOverrides[id] = o;
            final r = w.build(ReleaseMode.testers);
            expect(r.exitCode, 1, reason: '$id $o');
            expect(_only(r, id).severity, Severity.failure, reason: '$id $o');
          }
          final w = _World()..removedSteps = {id};
          expect(
            w.build(ReleaseMode.testers).exitCode,
            1,
            reason: '$id ausente',
          );
        }
      },
    );
  });

  group('falla cerrada: lo que falta o no casa', () {
    test('CA-020-02: cada id ausente de results.tsv es «no ejecutada»', () {
      for (final id in releaseCheckIds) {
        final w = _World()
          ..removedRows.add(id)
          ..outcomeOverrides[id] = 'skipped';
        final r = w.build(ReleaseMode.testers);
        expect(r.exitCode, 1, reason: id);
        final f = _only(r, id, severity: Severity.failure);
        expect(f.message, contains('no ejecutada'), reason: id);
      }
    });

    test(
      'CA-020-02: results.tsv vacío o ausente: todas las comprobaciones fallan',
      () {
        for (final text in ['', '\n', null]) {
          final r = buildSummary(
            mode: ReleaseMode.testers,
            resultsText: text,
            steps: _World().steps,
            readJson: (_) => null,
          );
          expect(r.exitCode, 1);
          expect(
            r.findings.where((f) => releaseCheckIds.contains(f.check)),
            hasLength(releaseCheckIds.length),
          );
        }
      },
    );

    test('CA-020-02: un id repetido en results.tsv es un fallo', () {
      final w = _World()..extraRows.add('permissions\t0\t');
      final r = w.build(ReleaseMode.testers);
      expect(r.exitCode, 1);
      expect(_only(r, 'permissions').message, contains('2 veces'));
    });

    test('CA-020-02: un id que no está en la lista es un fallo', () {
      final w = _World()..extraRows.add('otra-cosa\t0\t');
      final r = w.build(ReleaseMode.testers);
      expect(r.exitCode, 1);
      expect(_only(r, 'results.tsv').message, contains('otra-cosa'));
    });

    test('CA-020-02: una línea mal formada es un fallo (aunque todas las demás estén bien)', () {
      for (final line in [
        'size\t0',
        'size',
        'size\tx\t',
        'size\t-1\t',
        'size\t0\t\textra',
        '\t0\t',
        ' \t0\t',
        'size\t 0\t',
        'size\t00x\t',
      ]) {
        final w = _World()..extraRows.add(line);
        final r = w.build(ReleaseMode.testers);
        expect(r.exitCode, 1, reason: 'línea «$line»');
        expect(
          r.findings.any((f) => f.check == 'results.tsv'),
          isTrue,
          reason: 'línea «$line»: ${r.findings.join('\n')}',
        );
      }
    });

    test('CA-020-02: el outcome de GitHub tiene que casar con la línea', () {
      void expectMismatch(String name, void Function(_World) mutate) {
        final w = _World();
        mutate(w);
        final r = w.build(ReleaseMode.testers);
        expect(r.exitCode, 1, reason: name);
        expect(_only(r, 'size').severity, Severity.failure, reason: name);
      }

      // código 0 en la línea, pero el paso falló
      expectMismatch(
        '0/failure',
        (w) => w.outcomeOverrides['size'] = 'failure',
      );
      // código 1 en la línea, pero el paso salió bien
      expectMismatch('1/success', (w) {
        w.codes['size'] = 1;
        w.outcomeOverrides['size'] = 'success';
      });
      // una línea sin que el paso se haya ejecutado, cancelado o desconocido
      for (final o in ['skipped', 'cancelled', 'weird', null]) {
        expectMismatch('0/$o', (w) => w.outcomeOverrides['size'] = o);
      }
      // código 1 en la línea con el paso saltado, cancelado o desconocido (un aviso falsificado)
      for (final o in ['skipped', 'cancelled', 'weird', null]) {
        expectMismatch('1/$o', (w) {
          w.codes['size'] = 1;
          w.outcomeOverrides['size'] = o;
        });
      }
      // sin el paso en `steps`
      expectMismatch('0/sin paso', (w) => w.removedSteps = {'size'});
      // paso ejecutado (success) sin su línea
      expectMismatch('sin línea/success', (w) => w.removedRows.add('size'));
      // paso que falló sin su línea
      expectMismatch('sin línea/failure', (w) {
        w.removedRows.add('size');
        w.outcomeOverrides['size'] = 'failure';
      });
    });

    test('CA-020-02: steps que no es un mapa de mapas es un fallo de todas las comprobaciones', () {
      for (final steps in <Object?>[
        null,
        [],
        'x',
        {'size': 3},
      ]) {
        final r = buildSummary(
          mode: ReleaseMode.testers,
          resultsText: _World().results,
          steps: steps,
          readJson: _World().read,
        );
        expect(r.exitCode, 1, reason: '$steps');
      }
    });
  });

  group('JSON con clase', () {
    SummaryReport withJson(
      String id,
      String? json, {
      int code = 1,
      ReleaseMode mode = ReleaseMode.testers,
    }) {
      final w = _World();
      w.codes[id] = code;
      w.jsons[id] = json;
      return w.build(mode);
    }

    test(
      'CA-020-07: JSON ausente, vacío o ilegible con código 1 es un fallo',
      () {
        for (final json in [
          null,
          '',
          '   ',
          'no es json',
          '{',
          '[]',
          '3',
          'null',
        ]) {
          final r = withJson('identity', json);
          expect(r.exitCode, 1, reason: 'json «$json»');
          _only(r, 'identity', severity: Severity.failure);
        }
      },
    );

    test(
      'CA-020-07: una ruta de JSON vacía o que no se puede leer es un fallo',
      () {
        final w = _World();
        w.codes['identity'] = 1;
        w.pathOverrides['identity'] = '';
        expect(w.build(ReleaseMode.testers).exitCode, 1);

        final lanzador = buildSummary(
          mode: ReleaseMode.testers,
          resultsText: (_World()..codes['identity'] = 1).results,
          steps: (_World()..codes['identity'] = 1).steps,
          readJson: (p) => throw const FileSystemException('sin permiso'),
        );
        expect(lanzador.exitCode, 1);
      },
    );

    test('CA-020-07: JSON incompleto (sin complete, complete falso, sin version, otra version) es un fallo', () {
      final issues = [_issue('placeholderAddress')];
      for (final json in [
        _json('identity', issues, complete: false),
        _json('identity', issues, complete: null),
        _json('identity', issues, complete: 'true'),
        _json('identity', issues, version: null),
        _json('identity', issues, version: 2),
        _json('identity', issues, version: '1'),
      ]) {
        final r = withJson('identity', json);
        expect(r.exitCode, 1, reason: json);
        expect(r.findings.every((f) => f.severity == Severity.failure), isTrue);
      }
    });

    test(
      'CA-020-07: JSON que no declara las subcomprobaciones hechas es un fallo',
      () {
        final issues = [_issue('placeholderAddress')];
        for (final checks in [
          null,
          <String>[],
          ['addresses'],
          ['addresses', 'policy'], // falta «generated»
          'addresses',
          [1, 2, 3],
        ]) {
          final json = jsonEncode({
            'version': 1,
            'complete': true,
            'checks': ?checks,
            'issues': issues,
          });
          final r = withJson('identity', json);
          expect(r.exitCode, 1, reason: json);
          expect(
            r.findings.every((f) => f.severity == Severity.failure),
            isTrue,
            reason: json,
          );
        }
      },
    );

    test(
      'CA-020-07: issues ausente, no lista o vacía con código 1 es un fallo',
      () {
        for (final body in [
          '{"version":1,"complete":true,"checks":["tag"]}',
          '{"version":1,"complete":true,"checks":["tag"],"issues":3}',
          '{"version":1,"complete":true,"checks":["tag"],"issues":{}}',
          '{"version":1,"complete":true,"checks":["tag"],"issues":[]}',
        ]) {
          final r = withJson('tag', body);
          expect(r.exitCode, 1, reason: body);
          _only(r, 'tag', severity: Severity.failure);
        }
      },
    );

    test(
      'CA-020-07: un elemento sin kind, subject o message de texto es un fallo',
      () {
        for (final bad in <Object?>[
          3,
          'x',
          <String, Object?>{'subject': 's', 'message': 'm'},
          <String, Object?>{'kind': 3, 'subject': 's', 'message': 'm'},
          <String, Object?>{'kind': 'missing', 'message': 'm'},
          <String, Object?>{'kind': 'missing', 'subject': 's'},
          <String, Object?>{'kind': 'missing', 'subject': null, 'message': 'm'},
        ]) {
          final json = jsonEncode({
            'version': 1,
            'complete': true,
            'checks': ['tag'],
            'issues': [bad],
          });
          final r = withJson('tag', json);
          expect(r.exitCode, 1, reason: '$bad');
          expect(
            r.findings.every((f) => f.severity == Severity.failure),
            isTrue,
          );
        }
      },
    );

    test('CA-020-07: un kind desconocido entre avisos válidos falla sin ocultar los avisos', () {
      final r = withJson(
        'identity',
        _json('identity', [
          _issue('policyGap', 'p', 'hueco'),
          _issue('inventada', 'p', 'rara'),
        ]),
      );
      expect(r.exitCode, 1);
      expect(r.findings.map((f) => f.severity), [
        Severity.warning,
        Severity.failure,
      ]);
    });

    test('CA-020-07: código 0 con errores en el JSON es un fallo', () {
      final r = withJson(
        'identity',
        _json('identity', [
          _issue('placeholderAddress', 'helpUrl', 'marcador'),
        ]),
        code: 0,
      );
      expect(r.exitCode, 1);
      expect(_only(r, 'identity').severity, Severity.failure);
      expect(_only(r, 'identity').message, contains('código 0'));
    });

    test('CA-020-07: código 0 sin JSON (o incompleto) en una comprobación con clase es un fallo', () {
      for (final json in [null, '', _json('identity', [], complete: false)]) {
        final r = withJson('identity', json, code: 0);
        expect(r.exitCode, 1, reason: '$json');
      }
    });

    test('CA-020-07: código 1 con un JSON sin errores no se da por bueno', () {
      final r = withJson('identity', _json('identity', []));
      expect(r.exitCode, 1);
    });

    test('CA-020-05: https://example.com/%2e y http://ejemplo-propio.es (fault) fallan en testers', () {
      for (final addr in [
        'https://example.com/%2e',
        'http://ejemplo-propio.es',
      ]) {
        final r = withJson(
          'identity',
          _json('identity', [_issue('fault', 'privacyPolicyUrl', addr)]),
        );
        expect(r.exitCode, 1, reason: addr);
      }
    });
  });

  group('texto del resumen', () {
    test('CA-020-04: lleva el modo, la tabla con todas las comprobaciones y dice aviso/fallo en texto', () {
      final w = _World();
      w.codes['size'] = 1;
      final r = w.build(ReleaseMode.testers);
      expect(r.markdown, contains('testers'));
      expect(r.markdown, contains('| size | fallo |'));
      expect(r.markdown, contains('| ci-runs | ok |'));
      for (final id in [...releaseStepOnlyIds, ...releaseCheckIds]) {
        expect(r.markdown, contains('| $id |'));
      }
    });

    test('CA-020-04: lo que viene de las herramientas se limpia (saltos, control, bidi, comillas inversas, longitud)', () {
      final w = _World();
      w.codes['identity'] = 1;
      w.jsons['identity'] = _json('identity', [
        _issue(
          'fault',
          'a\nb',
          'uno\r\ndos\u0007 `tres` \u202Ecuatro\u200E ${'x' * 1000}',
        ),
      ]);
      final r = w.build(ReleaseMode.testers);
      final line = r.markdown.split('\n').singleWhere((l) => l.contains('uno'));
      expect(line, contains('uno dos'));
      expect(line, isNot(contains('`tres`')));
      expect(
        line.contains(
          RegExp(
            '[\u0000-\u0008\u000B-\u001F\u200E\u202A-\u202E\u2066-\u2069]',
          ),
        ),
        isFalse,
      );
      expect(line.length, lessThan(500));
      expect(line, contains('…'));
      // El motivo no abre una orden de workflow.
      expect(r.markdown.split('\n').where((l) => l.startsWith('::')), isEmpty);
    });
  });

  group('runReleaseSummary (los archivos y el entorno)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('release_summary_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    ({int code, String out, String err}) run(
      List<String> args, {
      Map<String, String> env = const {},
    }) {
      final o = StringBuffer();
      final e = StringBuffer();
      final code = runReleaseSummary(args, env: env, out: o, err: e);
      return (code: code, out: o.toString(), err: e.toString());
    }

    /// Escribe results.tsv, los JSON y steps.json de un mundo.
    Map<String, String> files(_World w) {
      final dir = Directory('${tmp.path}/release')..createSync();
      for (final id in _requiredChecks.keys) {
        w.pathOverrides[id] = '${dir.path}/$id.json';
        final j = w.jsons[id];
        if (j != null) File(w.path(id)).writeAsStringSync(j);
      }
      File('${dir.path}/results.tsv').writeAsStringSync(w.results);
      File('${tmp.path}/steps.json').writeAsStringSync(jsonEncode(w.steps));
      return {
        'results': '${dir.path}/results.tsv',
        'steps': '${tmp.path}/steps.json',
      };
    }

    test('CA-020-04: lee los archivos, escribe summary.md y añade a GITHUB_STEP_SUMMARY', () {
      final f = files(_World());
      final out = '${tmp.path}/build/release/summary.md';
      final gh = File('${tmp.path}/step-summary.md')
        ..writeAsStringSync('antes\n');
      final r = run(
        [
          '--mode',
          'testers',
          '--results',
          f['results']!,
          '--steps-file',
          f['steps']!,
          '--out',
          out,
        ],
        env: {'GITHUB_STEP_SUMMARY': gh.path},
      );
      expect(r.code, 0, reason: r.out + r.err);
      expect(File(out).readAsStringSync(), contains('| ci-runs | ok |'));
      final summary = gh.readAsStringSync();
      expect(summary, startsWith('antes\n'));
      expect(summary, contains('| ci-runs | ok |'));
      expect(r.out, contains('ci-runs'));
    });

    test('CA-020-02: sale con 1 si hay algún fallo y lo dice', () {
      final w = _World()..codes['pdfium'] = 1;
      final f = files(w);
      final r = run([
        '--mode',
        'strict',
        '--results',
        f['results']!,
        '--steps-file',
        f['steps']!,
        '--out',
        '${tmp.path}/s.md',
      ]);
      expect(r.code, 1);
      expect(
        File('${tmp.path}/s.md').readAsStringSync(),
        contains('| pdfium | fallo |'),
      );
    });

    test('CA-020-02: los outcome de GitHub pueden llegar por el entorno (toJSON(steps))', () {
      final w = _World();
      final f = files(w);
      final r = run(
        [
          '--mode',
          'testers',
          '--results',
          f['results']!,
          '--out',
          '${tmp.path}/s.md',
        ],
        env: {'RELEASE_STEPS_JSON': jsonEncode(w.steps)},
      );
      expect(r.code, 0, reason: r.out + r.err);
    });

    test('CA-020-02: sin steps (ni archivo ni entorno) o con steps ilegibles no se da nada por bueno', () {
      final f = files(_World());
      expect(
        run([
          '--mode',
          'testers',
          '--results',
          f['results']!,
          '--out',
          '${tmp.path}/s.md',
        ]).code,
        1,
      );
      expect(
        run(
          [
            '--mode',
            'testers',
            '--results',
            f['results']!,
            '--out',
            '${tmp.path}/s.md',
          ],
          env: {'RELEASE_STEPS_JSON': 'no es json'},
        ).code,
        1,
      );
    });

    test(
      'CA-020-02: results.tsv que no existe: todas las comprobaciones fallan',
      () {
        final f = files(_World());
        File(f['results']!).deleteSync();
        final r = run([
          '--mode',
          'testers',
          '--results',
          f['results']!,
          '--steps-file',
          f['steps']!,
          '--out',
          '${tmp.path}/s.md',
        ]);
        expect(r.code, 1);
        expect(
          File('${tmp.path}/s.md').readAsStringSync(),
          contains('| size | fallo |'),
        );
      },
    );

    test('CA-020-07: un JSON ilegible en disco es un fallo', () {
      final w = _World()..codes['tag'] = 1;
      w.jsons['tag'] = '{ roto';
      final f = files(w);
      final r = run([
        '--mode',
        'testers',
        '--results',
        f['results']!,
        '--steps-file',
        f['steps']!,
        '--out',
        '${tmp.path}/s.md',
      ]);
      expect(r.code, 1);
    });

    test('CA-020-02: argumentos incorrectos son un error de uso (2)', () {
      expect(run([]).code, 2);
      expect(run(['--mode', 'otro', '--results', 'x']).code, 2);
      expect(run(['--mode', 'strict']).code, 2);
      expect(run(['--mode', 'strict', '--results', 'x', '--nada']).code, 2);
    });

    test('CA-020-04: si no puede escribir el resumen, falla', () {
      final f = files(_World());
      final blocked = '${tmp.path}/archivo';
      File(blocked).writeAsStringSync('x');
      final r = run([
        '--mode',
        'testers',
        '--results',
        f['results']!,
        '--steps-file',
        f['steps']!,
        '--out',
        '$blocked/summary.md',
      ]);
      expect(r.code, 1);
    });
  });
}
