import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_tokens.dart';

/// Spec 028, T-028-04: `tool/gen_tokens.dart` escribe, además de `tokens.g.dart`, el color de
/// arranque de iOS (`LaunchBackground.colorset`, CA-028-06). Las rutas son relativas a `app/`
/// (el directorio de `flutter test`).
const _colorset =
    'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json';
const _generated = 'lib/app/theme/tokens.g.dart';

void main() {
  group('gen_tokens', () {
    late Directory tmp;
    late String appDir;
    late String tokensPath;
    late StringBuffer stdoutBuf;
    late StringBuffer stderrBuf;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('gen_tokens_test_');
      appDir = '${tmp.path}/app';
      Directory(appDir).createSync();
      tokensPath = '${tmp.path}/tokens.json';
      File(tokensPath)
          .writeAsStringSync(File('../design/tokens.json').readAsStringSync());
      stdoutBuf = StringBuffer();
      stderrBuf = StringBuffer();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    // Dentro de `flutter test` el ejecutable del proceso es `flutter_tester`: se formatea con `dart`.
    int run(List<String> args) => runGenTokens(
      args,
      tokensPath: tokensPath,
      appDir: appDir,
      out: stdoutBuf,
      err: stderrBuf,
      dart: 'dart',
    );

    Map<String, dynamic> colorsetJson() =>
        jsonDecode(File('$appDir/$_colorset').readAsStringSync())
            as Map<String, dynamic>;

    void setPaper(String value) {
      final tokens = jsonDecode(
        File(tokensPath).readAsStringSync(),
      ) as Map<String, dynamic>;
      ((tokens['color'] as Map)['paper'] as Map)[r'$value'] = value;
      File(tokensPath).writeAsStringSync(jsonEncode(tokens));
    }

    test('CA-028-06: escribe el color de arranque con paper, sin variante '
        'oscura y opaco', () {
      expect(run([]), 0, reason: stderrBuf.toString());
      final colors = colorsetJson()['colors'] as List;
      // Un solo color: sin entrada «dark» ni `appearances`.
      expect(colors, hasLength(1));
      final entry = colors.single as Map<String, dynamic>;
      expect(entry.containsKey('appearances'), isFalse);
      expect(entry['idiom'], 'universal');
      final color = entry['color'] as Map<String, dynamic>;
      expect(color['color-space'], 'srgb');
      // `paper` = #F4F1EA en design/tokens.json.
      expect(color['components'], {
        'alpha': '1.000',
        'red': '0xF4',
        'green': '0xF1',
        'blue': '0xEA',
      });
    });

    test('CA-028-06: el color sale del token, no de un valor fijo '
        '(otro paper, otro color)', () {
      setPaper('#102030');
      expect(run([]), 0, reason: stderrBuf.toString());
      final entry = (colorsetJson()['colors'] as List).single as Map;
      final components = (entry['color'] as Map)['components'] as Map;
      expect(
        [components['red'], components['green'], components['blue']],
        ['0x10', '0x20', '0x30'],
      );
    });

    test('CA-028-06: sigue escribiendo tokens.g.dart', () {
      expect(run([]), 0, reason: stderrBuf.toString());
      expect(
        File('$appDir/$_generated').readAsStringSync(),
        File(_generated).readAsStringSync(),
      );
    });

    test('CA-028-06: un paper que no es #RRGGBB falla con un mensaje y no '
        'escribe nada', () {
      setPaper('rgba(244, 241, 234, 0.5)');
      expect(run([]), 1);
      expect(stderrBuf.toString(), contains('color.paper'));
      expect(Directory(appDir).listSync(), isEmpty);
    });

    test('CA-028-06: --check sobre un árbol sin generar falla, nombra el '
        'color de arranque y no escribe nada', () {
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('LaunchBackground.colorset'));
      expect(Directory(appDir).listSync(), isEmpty);
    });

    test('CA-028-06: --check pasa justo después de generar', () {
      expect(run([]), 0);
      stdoutBuf.clear();
      expect(run(['--check']), 0, reason: stderrBuf.toString());
      expect(stdoutBuf.toString(), contains('al día'));
    });

    test('CA-028-06: --check falla si el color no es el de paper (por ejemplo '
        'el blanco de la plantilla) y no lo corrige', () {
      expect(run([]), 0);
      final file = File('$appDir/$_colorset');
      final white = file.readAsStringSync().replaceAll('0xF4', '0xFF');
      file.writeAsStringSync(white);
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('LaunchBackground.colorset'));
      expect(file.readAsStringSync(), white);
    });

    test('CA-028-06: --check falla si cambia el token y no el color', () {
      expect(run([]), 0);
      setPaper('#102030');
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('LaunchBackground.colorset'));
    });

    test('CA-028-06: --check falla si tokens.g.dart no está al día', () {
      expect(run([]), 0);
      File('$appDir/$_generated').writeAsStringSync('// viejo\n');
      expect(run(['--check']), 1);
      expect(stderrBuf.toString(), contains('tokens.g.dart'));
    });

    test(
      'CA-028-06: regenerar repone un color de arranque que se ha tocado',
      () {
        expect(run([]), 0);
        final file = File('$appDir/$_colorset');
        final good = file.readAsStringSync();
        file.writeAsStringSync(good.replaceAll('0xEA', '0x00'));
        expect(run([]), 0);
        expect(file.readAsStringSync(), good);
      },
    );
  });

  test('CA-028-06: el color de arranque del árbol y tokens.g.dart están al '
      'día con design/tokens.json (--check)', () {
    // Vigila que el árbol no se desvíe del generador sin depender de CI.
    final out = StringBuffer();
    final err = StringBuffer();
    expect(
      runGenTokens(['--check'], out: out, err: err, dart: 'dart'),
      0,
      reason: err.toString(),
    );
  });
}
