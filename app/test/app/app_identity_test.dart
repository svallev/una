import 'dart:convert';
import 'dart:io';

import 'package:app/app/app_identity.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/services/privacy_link.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/app_harness.dart';

/// Archivo generado desde `identity.yaml`: el único de `lib/` que puede
/// llevar el nombre escrito.
const _generated = 'lib/app/app_identity.g.dart';

/// El nombre escrito tal cual como palabra suelta (distingue mayúsculas).
/// No cuenta dentro de otra palabra ("ninguna." contiene "una.") ni como
/// parte de un identificador técnico ("una.sqlite", el archivo de la BD, que
/// no debe cambiar con el nombre para no perder los datos).
RegExp _literal(String name) => RegExp(
  '(?<![\\p{L}\\p{N}_])${RegExp.escape(name)}(?![\\p{L}\\p{N}_])',
  unicode: true,
);

/// Lo que va delante de una palabra que abre frase: nada, o el final de otra
/// (`. ! ? ¿ ¡ : …`, un salto de línea o un `\n` escrito), con comillas o
/// guiones de apertura.
final _beforeSentenceStart = RegExp(
  r'(^|[.!?¿¡:…\n]|\\n)\s*["'
  "'"
  r'«(\-—]*\s*$',
  unicode: true,
);

/// Lo que va detrás cuando la palabra sigue con más texto: otra palabra o un
/// marcador de ICU (`{count}`).
final _followedByMoreText = RegExp(r'^\s+[\p{L}{]', unicode: true);

/// Un trozo de texto de un literal de cadena y la línea (1) donde empieza.
typedef _Piece = ({String text, int line});

/// Saca los literales de cadena de un archivo de Dart: sin comentarios (`//`,
/// `///`, `/* */` anidados) y sin el código. Entiende comillas simples y
/// dobles, triples, `r'…'`, escapes e interpolaciones (`${…}`, con cadenas
/// dentro); un `//` dentro de una cadena (una URL) no abre un comentario.
List<_Piece> _dartLiterals(String source) => _DartLexer(source).run();

class _DartLexer {
  _DartLexer(this._s);

  final String _s;
  int _i = 0;
  int _line = 1;
  final _pieces = <_Piece>[];

  List<_Piece> run() {
    _code(inInterpolation: false);
    return _pieces;
  }

  bool _isIdentChar(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

  /// Recorre código hasta el final o, dentro de una interpolación, hasta su
  /// `}` de cierre (sin consumirlo).
  void _code({required bool inInterpolation}) {
    var depth = 0;
    while (_i < _s.length) {
      final c = _s[_i];
      if (c == '\n') {
        _line++;
        _i++;
      } else if (_s.startsWith('//', _i)) {
        while (_i < _s.length && _s[_i] != '\n') {
          _i++;
        }
      } else if (_s.startsWith('/*', _i)) {
        _blockComment();
      } else if (c == "'" || c == '"') {
        _string(raw: false);
      } else if ((c == 'r') &&
          _i + 1 < _s.length &&
          (_s[_i + 1] == "'" || _s[_i + 1] == '"') &&
          (_i == 0 || !_isIdentChar(_s[_i - 1]))) {
        _i++;
        _string(raw: true);
      } else if (c == '{') {
        depth++;
        _i++;
      } else if (c == '}') {
        if (inInterpolation && depth == 0) return;
        depth--;
        _i++;
      } else {
        _i++;
      }
    }
  }

  void _blockComment() {
    var depth = 0;
    do {
      if (_s.startsWith('/*', _i)) {
        depth++;
        _i += 2;
      } else if (_s.startsWith('*/', _i)) {
        depth--;
        _i += 2;
      } else {
        if (_s[_i] == '\n') _line++;
        _i++;
      }
    } while (depth > 0 && _i < _s.length);
  }

  void _string({required bool raw}) {
    final quote = _s[_i];
    final triple = _s.startsWith(quote * 3, _i);
    final delimiter = triple ? quote * 3 : quote;
    _i += delimiter.length;
    final buffer = StringBuffer();
    var startLine = _line;
    void flush() {
      if (buffer.isNotEmpty) {
        _pieces.add((text: buffer.toString(), line: startLine));
        buffer.clear();
      }
      startLine = _line;
    }

    while (_i < _s.length) {
      if (_s.startsWith(delimiter, _i)) {
        _i += delimiter.length;
        break;
      }
      final c = _s[_i];
      if (!raw && c == r'\') {
        buffer.write(_s.substring(_i, (_i + 2).clamp(0, _s.length)));
        if (_i + 1 < _s.length && _s[_i + 1] == '\n') _line++;
        _i += 2;
      } else if (!raw && c == r'$' && _s.startsWith(r'${', _i)) {
        flush();
        _i += 2;
        _code(inInterpolation: true);
        _i++; // la llave de cierre
        startLine = _line;
      } else {
        if (c == '\n') {
          // Una cadena simple no cruza líneas: está sin cerrar, no la sigas.
          if (!triple) break;
          _line++;
        }
        buffer.write(c);
        _i++;
      }
    }
    flush();
  }
}

/// Posición de [name] como palabra suelta en [text], o -1. Un nombre que es
/// una palabra del español ("Una", el artículo) no cuenta al abrir frase y
/// seguido de más texto ("Una foto", "Una o varias · …"); en cualquier otro
/// sitio sí, porque el artículo va en minúscula y la mayúscula a mitad de
/// frase es el nombre.
int _mentionAt(String text, String name) {
  final bareWord = RegExp(r'\p{L}$', unicode: true).hasMatch(name);
  for (final m in _literal(name).allMatches(text)) {
    final article =
        bareWord &&
        _beforeSentenceStart.hasMatch(text.substring(0, m.start)) &&
        _followedByMoreText.hasMatch(text.substring(m.end));
    if (!article) return m.start;
  }
  return -1;
}

bool _mentions(String text, String name) => _mentionAt(text, name) >= 0;

/// Archivos de `lib/`: todos, también los ARB (`lib/l10n/`) y los generados
/// de l10n.
List<File> _scannedFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        // Solo texto: fuera los archivos del sistema (`.DS_Store`).
        .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb'))
        .where((f) => f.path.replaceAll(r'\', '/') != _generated)
        .toList();

/// Devuelve `archivo:línea` de cada aparición de [names] en un literal de
/// cadena de un `.dart` o en el valor de una clave de un `.arb` (no en
/// comentarios, ni en las claves ni en las descripciones `@clave`).
List<String> _findLiterals(Iterable<File> files, List<String> names) {
  final hits = <String>{};
  for (final file in files) {
    if (file.path.endsWith('.arb')) {
      final lines = file.readAsLinesSync();
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in arb.entries) {
        if (key.startsWith('@') || value is! String) continue;
        if (names.any((n) => _mentions(value, n))) {
          final at = lines.indexWhere((l) => l.contains('"$key"'));
          hits.add('${file.path}:${at + 1}');
        }
      }
    } else {
      for (final piece in _dartLiterals(file.readAsStringSync())) {
        for (final name in names) {
          final at = _mentionAt(piece.text, name);
          if (at >= 0) {
            final breaks = '\n'.allMatches(piece.text.substring(0, at));
            hits.add('${file.path}:${piece.line + breaks.length}');
          }
        }
      }
    }
  }
  return hits.toList()..sort();
}

void main() {
  final identity =
      loadYaml(File('identity.yaml').readAsStringSync()) as YamlMap;
  final names = [
    identity['displayName'] as String,
    identity['wordmark'] as String,
  ];

  test('CA-010-05: AppIdentity coincide con identity.yaml (fuente única)', () {
    expect(AppIdentity.displayName, identity['displayName']);
    expect(AppIdentity.wordmark, identity['wordmark']);
  });

  test('CA-012-05: privacyPolicyUrl sale de identity.yaml, es https y es una '
      'sola dirección para los dos idiomas', () {
    expect(identity['privacyPolicyUrl'], isA<String>());
    expect(AppIdentity.privacyPolicyUrl, identity['privacyPolicyUrl']);
    final uri = Uri.parse(AppIdentity.privacyPolicyUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, isNotEmpty);
    expect(uri.userInfo, isEmpty);
  });

  test('CA-012-05: la dirección de la política no está escrita en lib/ '
      'fuera de lo generado', () {
    final url = identity['privacyPolicyUrl'] as String;
    final hits = [
      for (final f in _scannedFiles())
        if (f.readAsStringSync().contains(url)) f.path,
    ];
    expect(hits, isEmpty);
  });

  group('CA-015-13a: las tres direcciones de las webs', () {
    const keys = ['privacyPolicyUrl', 'thirdPartyLicensesUrl', 'helpUrl'];
    final generated = {
      'privacyPolicyUrl': AppIdentity.privacyPolicyUrl,
      'thirdPartyLicensesUrl': AppIdentity.thirdPartyLicensesUrl,
      'helpUrl': AppIdentity.helpUrl,
    };

    test(
      'CA-015-13a: AppIdentity las toma de identity.yaml (fuente única)',
      () {
        for (final key in keys) {
          expect(identity[key], isA<String>(), reason: key);
          expect(generated[key], identity[key], reason: key);
        }
      },
    );

    test('CA-015-13a: cada una pasa privacyLink y no lleva consulta ni '
        'fragmento', () {
      for (final (key, address) in generated.entries.map(
        (e) => (e.key, e.value),
      )) {
        expect(privacyLink(address), isA<WebLink>(), reason: key);
        final uri = Uri.parse(address);
        expect(uri.scheme, 'https', reason: key);
        expect(uri.hasQuery, isFalse, reason: key);
        expect(uri.hasFragment, isFalse, reason: key);
        expect(address, isNot(contains('?')), reason: key);
        expect(address, isNot(contains('#')), reason: key);
      }
    });

    test('CA-015-13a: los marcadores son tres y distintos entre sí', () {
      expect(generated.values.toSet(), hasLength(3));
    });

    test('CA-015-13a: ninguna está escrita en lib/ fuera de lo generado '
        '(no salen de los ajustes ni del idioma)', () {
      for (final key in keys) {
        final url = identity[key] as String;
        final hits = [
          for (final f in _scannedFiles())
            if (f.readAsStringSync().contains(url)) f.path,
        ];
        expect(hits, isEmpty, reason: key);
      }
    });
  });

  test('CA-012-05: CI ya comprueba lo generado y la marca del marcador '
      'está documentada en identity.yaml', () {
    final yaml = File('identity.yaml').readAsStringSync();
    expect(yaml, contains('privacyPolicyUrl'));
    expect(yaml, contains('PD-2'));
  });

  test(
    'CA-010-05: el nombre no está escrito tal cual en lib/ ni en los ARB',
    () {
      final files = _scannedFiles();
      expect(files.where((f) => f.path.endsWith('.arb')), hasLength(2));
      expect(_findLiterals(files, names), isEmpty);
    },
  );

  group('CA-010-05: la búsqueda del nombre', () {
    late Directory tmp;
    var counter = 0;

    setUp(() => tmp = Directory.systemTemp.createTempSync('identity_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    // En las plantillas, NAME es el nombre y WORD el logotipo.
    String fill(String template) =>
        template.replaceAll('NAME', names.first).replaceAll('WORD', names.last);

    File dart(String template) =>
        File('${tmp.path}/f${counter++}.dart')
          ..writeAsStringSync(fill(template));

    File arb(Map<String, Object> entries) => File(
      '${tmp.path}/f${counter++}.arb',
    )..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(entries));

    /// Las líneas con hallazgos de un archivo.
    List<String> lines(File f, [List<String>? searched]) => _findLiterals([
      f,
    ], searched ?? names).map((hit) => hit.split(':').last).toList();

    test('CA-010-05: detecta el nombre suelto en un literal, con su línea', () {
      final hit = dart("const a = 1;\nconst title = 'NAME';\n");
      expect(_findLiterals([hit], names), ['${hit.path}:2']);
      expect(lines(dart('const t = "WORD";')), ['1']);
      // Una cadena de varias líneas da la línea donde está el nombre.
      expect(lines(dart("const t = '''\nabre\nahora NAME\n''';")), ['3']);
      // Y las líneas siguientes cuentan los saltos de esa cadena.
      expect(lines(dart("const t = '''\nabre\n''';\nconst u = 'NAME';")), [
        '4',
      ]);
    });

    test('CA-010-05: no mira comentarios (el artículo "Una" es español)', () {
      final f = dart(r'''
/// Una tarea cada vez: NAME y WORD
// Una foto, NAME
/* NAME /* anidado WORD */ aún comentario */
const ok = 1; // NAME
''');
      expect(_findLiterals([f], names), isEmpty);
      // Código comentado y apóstrofos de la prosa: sus comillas no abren una
      // cadena que se coma lo de alrededor.
      final quoted = dart(r'''
// const t = 'NAME';
/* const u = "WORD"; */
// it's NAME and it's
/* it's NAME, it's */
const ok = 1;
''');
      expect(_findLiterals([quoted], names), isEmpty);
    });

    test('CA-010-05: un comentario no esconde el literal que va detrás, ni un '
        '// dentro de una cadena abre un comentario', () {
      expect(lines(dart("// nota\nconst t = 'NAME';")), ['2']);
      expect(lines(dart("const u = 'https://x.dev/'; const t = 'NAME';")), [
        '1',
      ]);
      // La comilla dentro de un comentario no abre una cadena.
      expect(lines(dart("// no es una cadena '\nconst t = 'NAME';")), ['2']);
    });

    test('CA-010-05: entiende escapes, cadenas crudas e interpolaciones', () {
      expect(lines(dart(r"const t = 'it\'s NAME';")), ['1']);
      expect(lines(dart("const t = r'x NAME';")), ['1']);
      // En una cadena cruda la barra no escapa: la comilla la cierra.
      expect(lines(dart(r"const a = r'\'; const t = 'NAME';")), ['1']);
      expect(lines(dart(r"final t = 'a ${f('NAME')} b';")), ['1']);
      expect(lines(dart(r"final t = 'a ${f({1: 2})} b NAME';")), ['1']);
      // Lo que va tras una interpolación sigue siendo cadena, no comentario.
      expect(lines(dart(r"final t = 'a ${f(1)} // NAME';")), ['1']);
      // Un comentario tras una interpolación sí es un comentario.
      expect(lines(dart("final t = 'a \${f(1)} b'; // NAME\n")), isEmpty);
      // Un nombre entre dos literales contiguos no se junta con el vecino.
      expect(lines(dart("const t = 'a' 'b' 'NAME';")), ['1']);
    });

    test('CA-010-05: no marca palabras que lo contienen ni "una.sqlite"', () {
      final f = dart(
        "const db = 'una.sqlite';\nconst a = 'ninguna.';\n"
        "const b = 'Unas fotos'; const c = 'Una_foto';\n",
      );
      expect(_findLiterals([f], names), isEmpty);
    });

    test('CA-010-05: en un ARB solo miran los valores, no las claves ni las '
        'descripciones', () {
      final f = arb({
        '@@locale': 'es',
        names.first: 'otro texto',
        'a': 'Bienvenido a ${names.first}',
        '@a': {'description': 'Muestra ${names.first}'},
        '@@nota': 'Muestra ${names.first}',
        'b': 'Texto sin nombre',
      });
      expect(_findLiterals([f], names), ['${f.path}:4']);
    });

    test('CA-010-05: "Una" como artículo (abre frase y sigue con texto) no es '
        'el nombre', () {
      final n = names.first;
      final articles = arb({
        'a': 'Una o varias · van arriba',
        'b': 'Elige. Una foto basta',
        'c': 'Primera\nUna segunda línea',
        'd': '"Una foto"',
        'e': 'Una {count} foto',
        'f': '¿Quieres añadir más? ¡Una página web!',
      });
      expect(_findLiterals([articles], [n]), isEmpty);
      // El mismo texto en un literal de Dart (con el \n escrito).
      final inDart = dart(
        r"const a = 'Una o varias'; const b = 'Primera\nUna segunda línea';",
      );
      expect(_findLiterals([inDart], [n]), isEmpty);
    });

    test('CA-010-05: "Una" como nombre sí se marca: suelto, con signo detrás, '
        'a mitad de frase o tras otra palabra', () {
      final n = names.first;
      for (final value in [
        n,
        '$n.',
        '$n, ya',
        '$n: ayuda',
        'Bienvenido a $n',
        'Abre $n para empezar',
        'Elige. Abre $n',
        'Sobre $n.',
        'Hola, $n',
      ]) {
        expect(
          _findLiterals(
            [
              arb({'k': value}),
            ],
            [n],
          ),
          hasLength(1),
          reason: value,
        );
      }
    });
  });

  test('CA-010-05: strings.xml lleva el displayName generado', () {
    final xml = File('android/app/src/main/res/values/strings.xml')
        .readAsStringSync();
    expect(xml, contains('GENERADO por tool/gen_identity.dart'));
    expect(
      xml,
      contains(
        '<string name="app_name" translatable="false">'
        '${AppIdentity.displayName}</string>',
      ),
    );
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:label="@string/app_name"'));
  });

  test('CA-010-05: CI comprueba que la identidad generada está al día', () {
    final ci = File('../.github/workflows/ci.yml').readAsStringSync();
    expect(ci, contains('dart run tool/gen_identity.dart --check'));
  });

  testWidgets(
    'CA-010-05: el título de la app (Recientes) es displayName en ES y EN',
    (tester) async {
      await pumpUnaApp(tester, repo: InMemoryTaskRepository(), tasks: ['A']);
      expect(find.byType(UnaApp), findsOneWidget);
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        AppIdentity.displayName,
      );

      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.pumpAndSettle();
      expect(
        tester.widget<Title>(find.byType(Title)).title,
        AppIdentity.displayName,
      );
    },
  );

  testWidgets('CA-010-05: la pantalla de error de almacenamiento también '
      'lleva displayName de título', (tester) async {
    await tester.pumpWidget(StorageErrorApp(noSpace: false, onRetry: () {}));
    expect(
      tester.widget<Title>(find.byType(Title)).title,
      AppIdentity.displayName,
    );
  });
}
