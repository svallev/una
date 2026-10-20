// El resumen del trabajo de publicación (spec 020, T-020-07; plan §3.2; CA-020-02 a 05, 07):
//
//   dart run tool/release_summary.dart --mode strict|testers --results <results.tsv>
//       [--steps-file <steps.json>] [--out <summary.md>]
//
// Lee lo que dejó `tools/release/run-check.sh` en `results.tsv` (una línea `id<TAB>código<TAB>ruta del
// JSON` por comprobación), los `outcome` que pone GitHub de cada paso (`toJSON(steps)`, por el entorno
// `RELEASE_STEPS_JSON` o con `--steps-file`) y los JSON de errores con clase, y decide si el trabajo
// acaba en verde, en verde con avisos (solo en `testers`) o en rojo. Escribe el resumen en
// `$GITHUB_STEP_SUMMARY` (si existe) y en `--out`, y sale con 1 si hay algún fallo (2: uso incorrecto).
//
// **Falla cerrada** (CA-020-02): la lista de comprobaciones esperadas está escrita aquí; una que no
// aparece ("no ejecutada"), que aparece dos veces, cuyo código no casa con el `outcome` que GitHub
// puso a su paso (contra una línea falsificada de `results.tsv`), que sale con un código inesperado,
// o cuyo JSON falta, está incompleto, no se lee o trae un `kind` desconocido, es un fallo. Un código 0
// con errores en el JSON, también. Solo un **código 1 con un JSON completo** cuyos errores están en la
// tabla cerrada [identityWarningTable] cuenta como aviso de identidad (CA-020-05); en `strict` todo
// aviso cuenta como fallo. Lo que viene de las herramientas se limpia antes de mostrarlo.
import 'dart:convert';
import 'dart:io';

/// El modo del trabajo de publicación (CA-020-03 y 04).
enum ReleaseMode { strict, testers }

/// La gravedad de un hallazgo o de una comprobación.
enum Severity { ok, warning, failure }

/// Los pasos que no pasan por `run-check.sh` (no dejan línea en `results.tsv`): tienen que terminar en
/// `success`. `mode` es el «rojo al empezar» y `build` la compilación (plan §3.2).
const releaseStepOnlyIds = ['mode', 'build'];

/// Las comprobaciones esperadas, con el `id` de su paso y de su línea en `results.tsv` (plan §3.2).
const releaseCheckIds = [
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
];

/// Las comprobaciones que dejan un JSON con clase, y las subcomprobaciones que ese JSON tiene que
/// declarar haber hecho (`checks`): sin ellas, el JSON está incompleto.
const classedChecks = <String, List<String>>{
  'identity': ['addresses', 'policy', 'generated'],
  'package-name': ['package-name'],
  'signature': ['signature'],
  'tag': ['tag'],
};

const _both = {ReleaseMode.strict, ReleaseMode.testers};

/// La lista **cerrada** de avisos de identidad (CA-020-05): `comprobación.clase` → los modos en los
/// que existe. Cualquier otra combinación es un fallo. En `strict` un aviso cuenta como fallo.
const identityWarningTable = <String, Set<ReleaseMode>>{
  // (a) una dirección marcador o con un dominio reservado.
  'identity.placeholderAddress': _both,
  // (c) un hueco de identidad en la política o en los textos de la web. Una marca de documento o un
  // texto entre corchetes ya no es un aviso sino un fallo (spec 023, CA-023-01).
  'identity.policyGap': _both,
  // (b) el package name provisional.
  'package-name.provisional': _both,
  // (d) la firma de depuración o un paquete sin firmar, y, solo en estricto, que aún no haya huella
  // del certificado de subida (CA-020-03 e, F6).
  'signature.debug': _both,
  'signature.unsigned': _both,
  'signature.uploadCertMissing': {ReleaseMode.strict},
  // (e) en modo testers, que no haya etiqueta.
  'tag.missing': {ReleaseMode.testers},
};

/// Un hallazgo del resumen. [subject] es la clave, el archivo o el paquete a los que se refiere (si lo
/// hay); [strictWarning] marca un aviso de identidad que en `strict` cuenta como fallo.
class Finding {
  const Finding(
    this.severity,
    this.check,
    this.subject,
    this.message, {
    this.strictWarning = false,
  });

  final Severity severity;
  final String check;
  final String? subject;
  final String message;
  final bool strictWarning;

  @override
  String toString() =>
      '${severity.name} · $check · ${subject ?? '-'} · $message';
}

/// El resultado de [buildSummary].
class SummaryReport {
  SummaryReport(this.mode, this.results, this.findings);

  final ReleaseMode mode;

  /// La gravedad de cada paso o comprobación, en orden (y `results.tsv` si su contenido falla).
  final Map<String, Severity> results;
  final List<Finding> findings;

  int get failures => results.values.where((s) => s == Severity.failure).length;
  int get warnings =>
      findings.where((f) => f.severity == Severity.warning).length;

  /// 1 si algo falla; los avisos (solo en `testers`) no lo hacen fallar.
  int get exitCode => failures > 0 ? 1 : 0;

  /// El resumen en Markdown. Cada línea dice «aviso» o «fallo» en texto: no depende del color (§6).
  String get markdown {
    final b = StringBuffer()
      ..writeln(
        '# Trabajo de publicación · modo ${mode == ReleaseMode.strict ? 'estricto' : 'testers'}',
      )
      ..writeln()
      ..writeln('| Comprobación | Resultado |')
      ..writeln('|---|---|');
    for (final e in results.entries) {
      b.writeln(
        '| ${e.key} | ${switch (e.value) {
          Severity.ok => 'ok',
          Severity.warning => 'aviso',
          Severity.failure => 'fallo',
        }} |',
      );
    }
    if (findings.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Avisos y fallos')
        ..writeln();
      for (final f in findings) {
        final word = f.severity == Severity.warning ? 'aviso' : 'fallo';
        final message = f.strictWarning
            ? '${f.message} (aviso de identidad no admitido en el modo estricto)'
            : f.message;
        final subject = f.subject == null ? '' : ' · `${f.subject}`';
        b.writeln('- $word · ${f.check}$subject · `$message`');
      }
    }
    b.writeln();
    if (failures > 0) {
      b.writeln('Resultado: fallo ($failures).');
    } else if (warnings > 0) {
      b.writeln('Resultado: verde con avisos.');
    } else {
      b.writeln('Resultado: verde.');
    }
    if (mode == ReleaseMode.testers && warnings > 0) {
      b
        ..writeln()
        ..writeln('Esta versión no se puede publicar.');
    }
    return b.toString();
  }
}

/// Lee el JSON de [path]: `null` si no existe. Puede lanzar si no se puede leer.
typedef JsonReader = String? Function(String path);

/// Quita de [s] lo que no debe llegar a un resumen: caracteres de control, de dirección y separadores
/// de línea (se cambian por un espacio), comillas inversas (rompen el código en línea); colapsa los
/// espacios y acorta a [max] caracteres.
String cleanText(String s, {int max = 300}) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final bad =
        r < 0x20 ||
        (r >= 0x7F && r <= 0x9F) ||
        r == 0x200B ||
        r == 0x200E ||
        r == 0x200F ||
        r == 0x2028 ||
        r == 0x2029 ||
        (r >= 0x202A && r <= 0x202E) ||
        (r >= 0x2066 && r <= 0x2069) ||
        r == 0xFEFF;
    if (bad) {
      b.write(' ');
    } else if (r == 0x60) {
      b.write("'");
    } else {
      b.writeCharCode(r);
    }
  }
  final text = b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = text.runes.toList();
  if (runes.length <= max) return text;
  return '${String.fromCharCodes(runes.take(max - 1))}…';
}

class _Row {
  const _Row(this.code, this.json);
  final int code;
  final String json;
}

class _Issue {
  const _Issue(this.kind, this.subject, this.message);
  final String kind;
  final String subject;
  final String message;
}

/// El JSON de una comprobación con clase, ya validado: o [error], o sus [issues].
class _ClassJson {
  const _ClassJson.error(String this.error) : issues = const [];
  const _ClassJson.ok(this.issues) : error = null;
  final String? error;
  final List<_Issue> issues;
}

_ClassJson _readClassJson(String id, String path, JsonReader readJson) {
  if (path.isEmpty) {
    return const _ClassJson.error('no dejó la ruta de su JSON de errores');
  }
  String? text;
  try {
    text = readJson(path);
  } on Object {
    return const _ClassJson.error('su JSON de errores no se puede leer');
  }
  if (text == null) {
    return const _ClassJson.error('su JSON de errores no existe');
  }
  if (text.trim().isEmpty) {
    return const _ClassJson.error('su JSON de errores está vacío');
  }
  Object? data;
  try {
    data = jsonDecode(text);
  } on FormatException {
    return const _ClassJson.error('su JSON de errores no es JSON válido');
  }
  if (data is! Map) {
    return const _ClassJson.error('su JSON de errores no es un objeto');
  }
  if (data['version'] != 1) {
    return const _ClassJson.error('su JSON de errores no es de la versión 1');
  }
  if (data['complete'] != true) {
    return const _ClassJson.error(
      'su JSON de errores está incompleto (complete no es true)',
    );
  }
  final checks = data['checks'];
  final required = classedChecks[id] ?? const <String>[];
  if (checks is! List || !required.every(checks.contains)) {
    return _ClassJson.error(
      'su JSON de errores no declara todas las subcomprobaciones hechas (${required.join(', ')})',
    );
  }
  final raw = data['issues'];
  if (raw is! List) {
    return const _ClassJson.error('su JSON de errores no trae la lista issues');
  }
  final issues = <_Issue>[];
  for (final item in raw) {
    if (item is! Map ||
        item['kind'] is! String ||
        item['subject'] is! String ||
        item['message'] is! String) {
      return const _ClassJson.error(
        'su JSON de errores trae un elemento sin kind, subject y message de texto',
      );
    }
    issues.add(
      _Issue(
        item['kind'] as String,
        item['subject'] as String,
        item['message'] as String,
      ),
    );
  }
  return _ClassJson.ok(issues);
}

/// Construye el resumen. [resultsText] es el contenido de `results.tsv` (`null`: no existe), [steps] el
/// `toJSON(steps)` de GitHub ya decodificado y [readJson] lee los JSON de errores.
SummaryReport buildSummary({
  required ReleaseMode mode,
  required String? resultsText,
  required Object? steps,
  required JsonReader readJson,
}) {
  final findings = <Finding>[];
  void fail(String check, String message, {String? subject}) =>
      findings.add(Finding(Severity.failure, check, subject, message));

  String? outcomeOf(String id) {
    if (steps is Map) {
      final step = steps[id];
      if (step is Map && step['outcome'] is String) {
        return step['outcome'] as String;
      }
    }
    return null;
  }

  // results.tsv: cada línea bien formada y de un id esperado.
  final rows = <String, List<_Row>>{};
  var lineNo = 0;
  for (final line in (resultsText ?? '').split('\n')) {
    lineNo++;
    if (line.isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length != 3) {
      fail(
        'results.tsv',
        'línea $lineNo mal formada: no tiene tres campos separados por tabulador',
      );
      continue;
    }
    if (!releaseCheckIds.contains(parts[0])) {
      fail(
        'results.tsv',
        'línea $lineNo con un id inesperado «${cleanText(parts[0], max: 40)}»',
      );
      continue;
    }
    if (!RegExp(r'^[0-9]{1,3}$').hasMatch(parts[1])) {
      fail(
        'results.tsv',
        'línea $lineNo mal formada: el código de salida de ${parts[0]} no es un número',
      );
      continue;
    }
    (rows[parts[0]] ??= []).add(_Row(int.parse(parts[1]), parts[2]));
  }

  // Los pasos que no dejan línea: tienen que haber terminado en success.
  for (final id in releaseStepOnlyIds) {
    final o = outcomeOf(id);
    if (o != 'success') {
      fail(
        id,
        o == null
            ? 'el paso no aparece en los resultados de GitHub'
            : o == 'skipped'
            ? 'no ejecutada: el paso se saltó'
            : 'el paso terminó con «${cleanText(o, max: 30)}», no con success',
      );
    }
  }

  for (final id in releaseCheckIds) {
    final outcome = outcomeOf(id);
    final mine = rows[id] ?? const <_Row>[];
    if (mine.isEmpty) {
      fail(id, switch (outcome) {
        'success' ||
        'failure' => 'el paso se ejecutó pero no dejó su línea en results.tsv',
        'cancelled' => 'no ejecutada: el paso se canceló',
        null => 'no ejecutada: el paso no aparece en los resultados de GitHub',
        _ => 'no ejecutada',
      });
      continue;
    }
    if (mine.length > 1) {
      fail(id, 'su resultado aparece ${mine.length} veces en results.tsv');
      continue;
    }
    final row = mine.single;
    // Contra una línea falsificada: el código tiene que casar con el outcome de GitHub.
    if (outcome != 'success' && outcome != 'failure') {
      fail(
        id,
        'tiene línea en results.tsv pero GitHub dice que su paso terminó con '
        '«${cleanText(outcome ?? 'nada', max: 30)}»',
      );
      continue;
    }
    if ((row.code == 0) != (outcome == 'success')) {
      fail(
        id,
        'results.tsv dice código ${row.code} y GitHub dice outcome $outcome: no casan',
      );
      continue;
    }

    final classed = classedChecks.containsKey(id);
    if (row.code == 0) {
      if (!classed) continue;
      final json = _readClassJson(id, row.json, readJson);
      if (json.error != null) {
        fail(id, 'terminó con código 0 pero ${json.error}');
      } else if (json.issues.isNotEmpty) {
        fail(
          id,
          'terminó con código 0 pero su JSON de errores lista ${json.issues.length}',
        );
      }
      continue;
    }
    if (!classed) {
      fail(id, 'falló (código ${row.code})');
      continue;
    }
    if (row.code != 1) {
      fail(
        id,
        'terminó con el código inesperado ${row.code} (solo 0 y 1 son resultados válidos)',
      );
      continue;
    }
    final json = _readClassJson(id, row.json, readJson);
    if (json.error != null) {
      fail(id, 'terminó con código 1 pero ${json.error}');
      continue;
    }
    if (json.issues.isEmpty) {
      fail(id, 'terminó con código 1 pero su JSON de errores no lista ninguno');
      continue;
    }
    for (final issue in json.issues) {
      final subject = cleanText(issue.subject, max: 120);
      final message = cleanText(issue.message);
      if (issue.kind == 'fault') {
        findings.add(Finding(Severity.failure, id, subject, message));
        continue;
      }
      final modes = identityWarningTable['$id.${issue.kind}'];
      if (modes == null || !modes.contains(mode)) {
        findings.add(
          Finding(
            Severity.failure,
            id,
            subject,
            '$message (la clase «${cleanText(issue.kind, max: 40)}» no es un aviso de '
            'identidad en este modo: es un fallo)',
          ),
        );
      } else if (mode == ReleaseMode.strict) {
        findings.add(
          Finding(Severity.failure, id, subject, message, strictWarning: true),
        );
      } else {
        findings.add(Finding(Severity.warning, id, subject, message));
      }
    }
  }

  // Ordena por comprobación (el orden de la lista) y conserva el de cada JSON. Un hallazgo idéntico
  // (comprobación, gravedad, paquete y motivo) sale una sola vez; los distintos se conservan todos.
  final order = ['results.tsv', ...releaseStepOnlyIds, ...releaseCheckIds];
  final seen = <String>{};
  final sorted = <Finding>[
    for (final c in order)
      for (final f in findings.where((f) => f.check == c))
        if (seen.add(
          '${f.check}\n${f.severity.name}\n${f.strictWarning}\n'
          '${f.subject}\n${f.message}',
        ))
          f,
  ];

  final results = <String, Severity>{};
  for (final id in [...releaseStepOnlyIds, ...releaseCheckIds]) {
    final mine = sorted.where((f) => f.check == id);
    results[id] = mine.any((f) => f.severity == Severity.failure)
        ? Severity.failure
        : mine.isNotEmpty
        ? Severity.warning
        : Severity.ok;
  }
  if (sorted.any((f) => f.check == 'results.tsv')) {
    results['results.tsv'] = Severity.failure;
  }
  return SummaryReport(mode, results, sorted);
}

const _usage =
    'Uso: dart run tool/release_summary.dart --mode strict|testers --results <results.tsv> '
    '[--steps-file <steps.json>] [--out <summary.md>]\n'
    '(sin --steps-file, los outcome de GitHub se leen del entorno RELEASE_STEPS_JSON)';

/// El programa; [env], [out] y [err] se pueden sustituir en las pruebas. Devuelve el código de salida.
int runReleaseSummary(
  List<String> args, {
  Map<String, String>? env,
  StringSink? out,
  StringSink? err,
}) {
  final environment = env ?? Platform.environment;
  final o = out ?? stdout;
  final e = err ?? stderr;

  String? modeArg;
  String? resultsPath;
  String? stepsFile;
  String? outPath;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a != '--mode' &&
        a != '--results' &&
        a != '--steps-file' &&
        a != '--out') {
      e.writeln(
        '::error::argumento desconocido: ${cleanText(a, max: 60)}\n$_usage',
      );
      return 2;
    }
    if (++i >= args.length) {
      e.writeln('::error::$a necesita un valor\n$_usage');
      return 2;
    }
    switch (a) {
      case '--mode':
        modeArg = args[i];
      case '--results':
        resultsPath = args[i];
      case '--steps-file':
        stepsFile = args[i];
      case '--out':
        outPath = args[i];
    }
  }
  final mode = switch (modeArg) {
    'strict' => ReleaseMode.strict,
    'testers' => ReleaseMode.testers,
    _ => null,
  };
  if (mode == null || resultsPath == null) {
    e.writeln('::error::faltan --mode strict|testers o --results\n$_usage');
    return 2;
  }

  String? resultsText;
  try {
    final f = File(resultsPath);
    if (f.existsSync()) resultsText = f.readAsStringSync();
  } on Object catch (ex) {
    e.writeln('::error::no se puede leer $resultsPath ($ex)');
  }

  Object? steps;
  try {
    final text = stepsFile != null
        ? File(stepsFile).readAsStringSync()
        : environment['RELEASE_STEPS_JSON'];
    if (text == null || text.trim().isEmpty) {
      e.writeln(
        '::error::no hay outcome de los pasos de GitHub (--steps-file o RELEASE_STEPS_JSON): '
        'no se da nada por bueno',
      );
    } else {
      steps = jsonDecode(text);
    }
  } on Object catch (ex) {
    e.writeln('::error::los outcome de los pasos no se pueden leer ($ex)');
  }

  final report = buildSummary(
    mode: mode,
    resultsText: resultsText,
    steps: steps,
    readJson: (path) {
      final f = File(path);
      return f.existsSync() ? f.readAsStringSync() : null;
    },
  );

  final markdown = report.markdown;
  var code = report.exitCode;
  try {
    if (outPath != null) {
      final f = File(outPath);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(markdown);
    }
    final gh = environment['GITHUB_STEP_SUMMARY'];
    if (gh != null && gh.isNotEmpty) {
      File(gh).writeAsStringSync(markdown, mode: FileMode.append);
    }
  } on FileSystemException catch (ex) {
    e.writeln(
      '::error::no se puede escribir el resumen (${ex.osError?.message ?? ex.message})',
    );
    code = 1;
  }
  o.write(markdown);
  return code;
}

void main(List<String> args) {
  exit(runReleaseSummary(args));
}
