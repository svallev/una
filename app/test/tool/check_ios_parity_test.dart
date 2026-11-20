import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// `tools/check-ios-parity.sh` (spec 028, T-028-01, CA-028-04 a 08, 17 y 20): cada sección pasa con un
/// árbol bueno y falla con su rotura. Se prueba con un árbol de mentira en un directorio temporal
/// (`--root`) y una copia del script con sus propias sumas de iconos (así el test no depende de que
/// existan los iconos de la plantilla de Flutter, que la T-028-04 retira). Solo necesita `bash` y
/// `python3`, como el trabajo `flutter` de la CI (Linux).
const _script = '../tools/check-ios-parity.sh';
const _realFixture = '../tools/fixtures/ios-template-icons.sha256';
const _kotlinReal = '../app/android/app/src/main/kotlin';

const _channels = <String, (String kt, String swift, List<String> methods)>{
  'una/images': (
    'ImageImport.kt',
    'Images.swift',
    [
      'capabilities',
      'pick',
      'pickMany',
      'debugPickManyDocuments',
      'freeSpace',
      'copy',
      'sanitize',
      'cancel',
      'encodeJpeg',
      'regenerate',
      'debugCopyFile',
    ],
  ),
  'una/webview': (
    'WebViewHardening.kt',
    'WebViewHardening.swift',
    ['harden', 'state', 'destroy', 'clearData'],
  ),
  'una/notifications': (
    'notifications/NotificationsChannel.kt',
    'Notifications.swift',
    [
      'canNotify',
      'requestPermission',
      'configure',
      'cancelDelivered',
      'setForeground',
      'openSystemSettings',
    ],
  ),
  'una/screen': (
    'MainActivity.kt',
    'Screen.swift',
    ['rotateWithAttachment', 'keepOn'],
  ),
  'una/links': ('LinkOpener.kt', 'Links.swift', ['open', 'canOpen']),
  'una/a11y': ('AccessibilityTimeouts.kt', 'A11y.swift', ['timeouts']),
};

// ─── generadores de archivos ────────────────────────────────────────────

String _plist(Map<String, Object> entries) {
  final b = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
    '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0">\n<dict>\n',
  );
  void value(Object v) {
    if (v is bool) {
      b.writeln(v ? '<true/>' : '<false/>');
    } else if (v is String) {
      b.writeln('<string>$v</string>');
    } else if (v is List) {
      b.writeln('<array>');
      for (final e in v) {
        value(e as Object);
      }
      b.writeln('</array>');
    } else if (v is Map) {
      b.writeln('<dict>');
      for (final e in v.entries) {
        b.writeln('<key>${e.key}</key>');
        value(e.value as Object);
      }
      b.writeln('</dict>');
    } else {
      throw ArgumentError('$v');
    }
  }

  for (final e in entries.entries) {
    b.writeln('<key>${e.key}</key>');
    value(e.value);
  }
  b.writeln('</dict>\n</plist>');
  return b.toString();
}

Map<String, Object> _goodInfo() => {
  'CFBundleName': r'$(APP_DISPLAY_NAME)',
  'UIUserInterfaceStyle': 'Light',
  'NSCameraUsageDescription': 'Camera',
  'CFBundleLocalizations': ['en', 'es', 'ca'],
  'UISupportedInterfaceOrientations': [
    'UIInterfaceOrientationPortrait',
    'UIInterfaceOrientationLandscapeLeft',
    'UIInterfaceOrientationLandscapeRight',
  ],
};

String _pbx({
  String family = '"1"',
  String target = '16.0',
  bool profileHasFamily = true,
}) {
  String config(String id, String name, {bool family_ = true}) =>
      '''
		$id /* $name */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = $target;
				SDKROOT = iphoneos;
${family_ ? '\t\t\t\tTARGETED_DEVICE_FAMILY = $family;\n' : ''}			};
			name = $name;
		};
''';
  return '''
/* Begin XCBuildConfiguration section */
${config('AA01', 'Profile', family_: profileHasFamily)}${config('AA02', 'Debug')}${config('AA03', 'Release')}		BB01 /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = CC01 /* Debug.xcconfig */;
			buildSettings = {
				PRODUCT_NAME = "\$(TARGET_NAME)";
			};
			name = Debug;
		};
/* End XCBuildConfiguration section */
''';
}

const _strings =
    '/* Name */\n"CFBundleDisplayName" = "Una";\n'
    '"NSCameraUsageDescription" = "Para hacer una foto.";\n';

const _paperColorset = '''
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.918", "green" : "0.945", "red" : "0.957" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
''';

const _storyboard = '''
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0">
  <scenes><scene sceneID="EHf-IW-A2E"><objects>
    <viewController id="01J-lp-oVM" sceneMemberID="viewController">
      <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
        <color key="backgroundColor" name="LaunchBackground"/>
      </view>
    </viewController>
  </objects></scene></scenes>
  <resources><namedColor name="LaunchBackground"><color red="0.957" green="0.945" blue="0.918" alpha="1" colorSpace="custom" customColorSpace="sRGB"/></namedColor></resources>
</document>
''';

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Un PNG válido liso (`colorType` 2 = RGB, 6 = RGBA), con `tRNS` opcional.
Uint8List _png(int size, {int colorType = 2, bool trns = false}) {
  final bpp = const {0: 1, 2: 3, 4: 2, 6: 4}[colorType]!;
  final raw = Uint8List(size * (1 + size * bpp));
  final out = BytesBuilder();
  void chunk(String type, List<int> data) {
    final head = ByteData(4)..setUint32(0, data.length);
    final body = [...type.codeUnits, ...data];
    final crc = ByteData(4)..setUint32(0, _crc32(body));
    out
      ..add(head.buffer.asUint8List())
      ..add(body)
      ..add(crc.buffer.asUint8List());
  }

  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ihdr = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8)
    ..setUint8(9, colorType);
  chunk('IHDR', ihdr.buffer.asUint8List());
  if (trns) chunk('tRNS', [0, 0, 0, 0, 0, 0]);
  chunk('IDAT', ZLibCodec().encode(raw));
  chunk('IEND', const []);
  return out.toBytes();
}

String _sha256(File f) {
  final r = Process.runSync('python3', [
    '-c',
    'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',
    f.path,
  ]);
  return '${r.stdout}'.trim();
}

String _kotlinWhen(List<String> methods) {
  final b = StringBuffer(
    'class C {\n  fun onMethodCall(call: Call, result: R) {\n',
  );
  b.writeln('    // "commentedOut" -> result.success(1)');
  b.writeln('    when (call.method) {');
  for (var i = 0; i < methods.length; i++) {
    final m = methods[i];
    if (i == 0) {
      b.writeln('      "$m" -> result.success(mapOf("x" to "\${y}"))');
    } else if (i == 1) {
      b.writeln('      "$m" -> {');
      b.writeln('        when (kind) {');
      b.writeln('          "web" -> a()');
      b.writeln('          "mail" -> b()');
      b.writeln('        }');
      b.writeln('      }');
    } else {
      b.writeln('      "$m" -> if (x) f(result) else result.notImplemented()');
    }
  }
  b.writeln('      else -> result.notImplemented()');
  b.writeln('    }\n  }\n}');
  return b.toString();
}

String _swiftSwitch(List<String> methods, {String? commentOnly}) {
  final b = StringBuffer(
    'import Flutter\nfinal class X {\n  func handle(_ call: FlutterMethodCall, result: FlutterResult) {\n    switch call.method {\n',
  );
  for (final m in methods) {
    b.writeln('    case "$m":\n      result(nil)');
  }
  if (commentOnly != null) {
    b.writeln('    // case "$commentOnly":');
    b.writeln('    /* case "$commentOnly": */');
  }
  b.writeln('    default: result(FlutterMethodNotImplemented)\n    }\n  }\n}');
  return b.toString();
}

// ─── el mundo de la prueba ──────────────────────────────────────────────

class ParityWorld {
  ParityWorld() : root = Directory.systemTemp.createTempSync('ios_parity_') {
    toolsDir = Directory('${root.path}/_tools/tools')
      ..createSync(recursive: true);
    Directory('${toolsDir.path}/fixtures').createSync();
    File(_script).copySync('${toolsDir.path}/check-ios-parity.sh');
    _useFixture(templateSums: const []);
    _writeGoodTree();
  }

  final Directory root;
  late final Directory toolsDir;

  String get scriptPath => '${toolsDir.path}/check-ios-parity.sh';

  File file(String rel) => File('${root.path}/$rel');

  void write(String rel, String content) {
    file(rel)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  void writeBytes(String rel, List<int> bytes) {
    file(rel)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  void delete(String rel) => file(rel).deleteSync();

  String read(String rel) => file(rel).readAsStringSync();

  /// Sustituye el texto de un archivo (y comprueba que había algo que sustituir).
  void replace(String rel, Pattern from, String to) {
    final before = read(rel);
    final after = before.replaceAll(from, to);
    expect(after, isNot(before), reason: 'la mutación de $rel no cambió nada');
    write(rel, after);
  }

  /// Las sumas del script: las reales del repositorio más las que pida la prueba.
  void _useFixture({required List<String> templateSums}) {
    final real = File(_realFixture).readAsStringSync();
    File('${toolsDir.path}/fixtures/ios-template-icons.sha256')
        .writeAsStringSync(
          '$real${templateSums.map((s) => '$s  Fake.png\n').join()}',
        );
  }

  void declareTemplateIcon(File icon) =>
      _useFixture(templateSums: [_sha256(icon)]);

  void _writeGoodTree() {
    const ios = 'app/ios';
    write('$ios/Runner.xcodeproj/project.pbxproj', _pbx());
    write('$ios/Runner/Info.plist', _plist(_goodInfo()));
    for (final lang in ['en', 'es', 'ca']) {
      write('$ios/Runner/$lang.lproj/InfoPlist.strings', _strings);
    }
    write(
      'design/tokens.json',
      jsonEncode({
        'color': {
          'paper': {r'$value': '#F4F1EA'},
        },
      }),
    );
    write(
      '$ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
      _paperColorset,
    );
    write('$ios/Runner/Base.lproj/LaunchScreen.storyboard', _storyboard);
    writeBytes(
      '$ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-1024.png',
      _png(1024),
    );
    writeBytes(
      '$ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-20.png',
      _png(20),
    );
    write(
      '$ios/Runner/PrivacyInfo.xcprivacy',
      _plist({
        'NSPrivacyTracking': false,
        'NSPrivacyTrackingDomains': <String>[],
        'NSPrivacyCollectedDataTypes': <String>[],
        'NSPrivacyAccessedAPITypes': [
          {
            'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryDiskSpace',
            'NSPrivacyAccessedAPITypeReasons': ['E174.1'],
          },
        ],
      }),
    );
    write(
      '$ios/Runner/AppDelegate.swift',
      'import Flutter\n// print("nada") y URLSession solo en un comentario\n'
          '/* NSLog("x") */\nclass AppDelegate: FlutterAppDelegate {}\n',
    );
    for (final c in _channels.values) {
      final kt = c.$1;
      write('app/android/app/src/main/kotlin/dev/x/app/$kt', _kotlinWhen(c.$3));
      write('$ios/Runner/${c.$2}', _swiftSwitch(c.$3));
    }
    write(
      'tools/ios-parity.sections',
      '# secciones activas\nnetwork\n\nproject # el proyecto\n',
    );
  }

  ProcessResult run([List<String> args = const []]) =>
      Process.runSync('bash', [scriptPath, '--root', root.path, ...args]);

  ProcessResult section(String name) => run(['--section', name]);

  void dispose() {
    root.deleteSync(recursive: true);
  }
}

late ParityWorld w;

void _passes(ProcessResult r) {
  expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
}

/// Falla (salida 1) y el mensaje de error contiene `needle`.
void _fails(ProcessResult r, Pattern needle) {
  expect(r.exitCode, 1, reason: '${r.stdout}\n${r.stderr}');
  expect('${r.stderr}', contains(needle));
  expect('${r.stdout}', contains('FALLO'));
}

void main() {
  setUp(() {
    w = ParityWorld();
    addTearDown(w.dispose);
  });

  group('CA-028-20: interfaz', () {
    test('CA-028-20: sin --section corre las activas y lista las demás como PENDIENTE', () {
      final r = w.run();
      _passes(r);
      final out = '${r.stdout}';
      expect(out, contains(RegExp(r'^OK +network$', multiLine: true)));
      expect(out, contains(RegExp(r'^OK +project$', multiLine: true)));
      expect(out, contains(RegExp(r'^PENDIENTE +plist$', multiLine: true)));
      expect(
        out,
        contains(RegExp(r'^PENDIENTE +channel:una/images$', multiLine: true)),
      );
      expect(out, isNot(contains('FALLO')));
    });

    test('CA-028-20: con --section corre esa aunque no esté activa', () {
      w.replace('app/ios/Runner/Info.plist', 'Light', 'Dark');
      // `plist` no está en la lista de activas: sin --section no se mira.
      _passes(w.run());
      _fails(w.section('plist'), 'UIUserInterfaceStyle');
    });

    test('CA-028-20: --section se puede repetir y todas corren', () {
      w.replace('app/ios/Runner/Info.plist', 'Light', 'Dark');
      w.write('app/ios/Runner/Bad.swift', 'func f() { NSLog("x") }\n');
      final r = w.run(['--section', 'plist', '--section', 'network']);
      expect(r.exitCode, 1);
      expect('${r.stderr}', contains('plist:'));
      expect('${r.stderr}', contains('network:'));
    });

    test('CA-028-20: una sección que no existe es un error de uso (2)', () {
      final r = w.section('nada');
      expect(r.exitCode, 2);
      expect('${r.stderr}', contains('nada'));
    });

    test('CA-028-20: un argumento desconocido es un error de uso (2)', () {
      expect(w.run(['--otra']).exitCode, 2);
    });

    test('CA-028-20: una sección desconocida en la lista de activas falla', () {
      w.write('tools/ios-parity.sections', 'network\nlpist\n');
      final r = w.run();
      expect(r.exitCode, 1);
      expect('${r.stderr}', contains('sección desconocida «lpist»'));
    });

    test('CA-028-20: sin tools/ios-parity.sections falla cerrado', () {
      w.delete('tools/ios-parity.sections');
      final r = w.run();
      expect(r.exitCode, 1);
      expect('${r.stderr}', contains('ios-parity.sections'));
    });

    test('CA-028-20: --root que no existe es un error de uso (2)', () {
      final r = Process.runSync('bash', [
        w.scriptPath,
        '--root',
        '${w.root.path}/no-existe',
      ]);
      expect(r.exitCode, 2);
    });
  });

  group('CA-028-04: project', () {
    test('CA-028-04: un proyecto de solo iPhone con iOS 16 pasa', () {
      _passes(w.section('project'));
    });

    test('CA-028-04: la familia "1,2" (iPad) falla', () {
      w.write(
        'app/ios/Runner.xcodeproj/project.pbxproj',
        _pbx(family: '"1,2"'),
      );
      _fails(w.section('project'), 'TARGETED_DEVICE_FAMILY');
    });

    test('CA-028-04: iOS 15 de versión mínima falla', () {
      w.write('app/ios/Runner.xcodeproj/project.pbxproj', _pbx(target: '15.0'));
      _fails(w.section('project'), 'IPHONEOS_DEPLOYMENT_TARGET');
    });

    test('CA-028-04: iOS 13 (la plantilla) falla', () {
      w.write('app/ios/Runner.xcodeproj/project.pbxproj', _pbx(target: '13.0'));
      _fails(w.section('project'), '13.0');
    });

    test('CA-028-04: una configuración sin familia de dispositivos falla', () {
      w.write(
        'app/ios/Runner.xcodeproj/project.pbxproj',
        _pbx(profileHasFamily: false),
      );
      _fails(w.section('project'), 'Profile no fija TARGETED_DEVICE_FAMILY');
    });

    test('CA-028-04: sin el proyecto falla cerrado', () {
      w.delete('app/ios/Runner.xcodeproj/project.pbxproj');
      _fails(w.section('project'), 'project.pbxproj');
    });

    test('CA-028-04: un proyecto vacío falla cerrado', () {
      w.write('app/ios/Runner.xcodeproj/project.pbxproj', '');
      _fails(w.section('project'), 'vacío');
    });
  });

  group('CA-028-05, 08, 10, 13: plist', () {
    const info = 'app/ios/Runner/Info.plist';

    test('CA-028-05: un Info.plist bueno pasa', () {
      _passes(w.section('plist'));
    });

    test('CA-028-05: UIUserInterfaceStyle = Dark falla', () {
      w.replace(info, '<string>Light</string>', '<string>Dark</string>');
      _fails(w.section('plist'), 'UIUserInterfaceStyle');
    });

    test('CA-028-05: sin UIUserInterfaceStyle falla', () {
      w.replace(
        info,
        RegExp(r'<key>UIUserInterfaceStyle</key>\s*<string>Light</string>'),
        '',
      );
      _fails(w.section('plist'), 'UIUserInterfaceStyle');
    });

    test('CA-028-10: una segunda descripción de uso falla', () {
      w.replace(
        info,
        '<key>CFBundleName</key>',
        '<key>NSPhotoLibraryUsageDescription</key><string>x</string><key>CFBundleName</key>',
      );
      _fails(w.section('plist'), 'NSPhotoLibraryUsageDescription');
    });

    test('CA-028-10: sin la descripción de la cámara falla', () {
      w.replace(
        info,
        RegExp(
          r'<key>NSCameraUsageDescription</key>\s*<string>Camera</string>',
        ),
        '',
      );
      _fails(w.section('plist'), 'NSCameraUsageDescription');
    });

    test('CA-028-08: CFBundleLocalizations sin ca falla', () {
      w.replace(info, '<string>ca</string>', '');
      _fails(w.section('plist'), 'CFBundleLocalizations');
    });

    test('CA-028-08: CFBundleLocalizations con un idioma de más falla', () {
      w.replace(
        info,
        '<string>ca</string>',
        '<string>ca</string><string>gl</string>',
      );
      _fails(w.section('plist'), 'CFBundleLocalizations');
    });

    test('CA-028-13: sin una horizontal falla', () {
      w.replace(
        info,
        '<string>UIInterfaceOrientationLandscapeRight</string>',
        '',
      );
      _fails(w.section('plist'), 'LandscapeRight');
    });

    test('CA-028-13: solo vertical (la plantilla) falla', () {
      w.replace(
        info,
        RegExp(r'<string>UIInterfaceOrientationLandscape(Left|Right)</string>'),
        '',
      );
      _fails(w.section('plist'), 'LandscapeLeft');
    });

    test('CA-028-05: un Info.plist que no es plist falla', () {
      w.write(info, 'esto no es un plist');
      _fails(w.section('plist'), 'no es un plist válido');
    });

    test('CA-028-05: sin Info.plist falla cerrado', () {
      w.delete(info);
      _fails(w.section('plist'), 'Info.plist');
    });
  });

  group('CA-028-08: l10n', () {
    const ca = 'app/ios/Runner/ca.lproj/InfoPlist.strings';

    test('CA-028-08: tres InfoPlist.strings iguales pasan', () {
      _passes(w.section('l10n'));
    });

    test('CA-028-08: una clave menos en ca falla', () {
      w.write(ca, '"CFBundleDisplayName" = "Una";\n');
      _fails(w.section('l10n'), 'falta la clave NSCameraUsageDescription');
    });

    test('CA-028-08: una clave de más en en falla', () {
      w.write(
        'app/ios/Runner/en.lproj/InfoPlist.strings',
        '$_strings"NSFaceIDUsageDescription" = "x";\n',
      );
      _fails(w.section('l10n'), 'NSFaceIDUsageDescription');
    });

    test(
      'CA-028-08: ca distinto de es falla aunque tengan las mismas claves',
      () {
        w.replace(ca, 'Para hacer una foto.', 'Per fer una foto.');
        _fails(w.section('l10n'), 'ca = es');
      },
    );

    test('CA-028-08: falta un idioma entero', () {
      w.delete(ca);
      _fails(w.section('l10n'), 'ca.lproj');
    });

    test('CA-028-08: un archivo vacío falla', () {
      w.write(ca, '');
      _fails(w.section('l10n'), 'ca.lproj');
    });

    test('CA-028-08: una línea mal formada falla', () {
      w.write(
        'app/ios/Runner/es.lproj/InfoPlist.strings',
        '$_strings"Rota" = sin comillas\n',
      );
      _fails(w.section('l10n'), 'es.lproj');
    });

    test('CA-028-08: una clave repetida falla', () {
      w.write(
        'app/ios/Runner/en.lproj/InfoPlist.strings',
        '$_strings"CFBundleDisplayName" = "Otra";\n',
      );
      _fails(w.section('l10n'), 'repetida');
    });

    test(
      'CA-028-08: claves sin comillas (formato antiguo) también se leen',
      () {
        final plain = _strings.replaceAll(
          '"CFBundleDisplayName"',
          'CFBundleDisplayName',
        );
        for (final l in ['en', 'es', 'ca']) {
          w.write('app/ios/Runner/$l.lproj/InfoPlist.strings', plain);
        }
        _passes(w.section('l10n'));
      },
    );
  });

  group('CA-028-06: launch', () {
    const colorset =
        'app/ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json';
    const story = 'app/ios/Runner/Base.lproj/LaunchScreen.storyboard';

    test('CA-028-06: el color de paper y un storyboard sin imagen pasan', () {
      _passes(w.section('launch'));
    });

    test('CA-028-06: un color distinto de paper falla', () {
      w.replace(colorset, '"red" : "0.957"', '"red" : "1.000"');
      _fails(w.section('launch'), 'paper');
    });

    test('CA-028-06: los componentes en hexadecimal (0xF4) también valen', () {
      w.write(
        colorset,
        '{"colors":[{"color":{"color-space":"srgb","components":'
        '{"alpha":"1.000","blue":"0xEA","green":"0xF1","red":"0xF4"}},"idiom":"universal"}]}',
      );
      _passes(w.section('launch'));
    });

    test('CA-028-06: los componentes en entero (244) también valen', () {
      w.write(
        colorset,
        '{"colors":[{"color":{"color-space":"srgb","components":'
        '{"alpha":"1.000","blue":"234","green":"241","red":"244"}},"idiom":"universal"}]}',
      );
      _passes(w.section('launch'));
    });

    test('CA-028-06: una variante oscura falla', () {
      w.replace(
        colorset,
        '"idiom" : "universal"',
        '"idiom" : "universal" },\n { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "idiom" : "universal"',
      );
      _fails(w.section('launch'), 'appearances');
    });

    test('CA-028-06: un color con transparencia falla', () {
      w.replace(colorset, '"alpha" : "1.000"', '"alpha" : "0.500"');
      _fails(w.section('launch'), 'opaco');
    });

    test('CA-028-06: un storyboard con imagen falla', () {
      w.replace(
        story,
        '</view>',
        '<subviews><imageView image="LaunchImage" id="a"/></subviews></view>',
      );
      _fails(w.section('launch'), 'imagen');
    });

    test(
      'CA-028-06: un storyboard con fondo blanco fijo (la plantilla) falla',
      () {
        w.replace(
          story,
          '<color key="backgroundColor" name="LaunchBackground"/>',
          '<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
        );
        _fails(w.section('launch'), 'LaunchBackground');
      },
    );

    test('CA-028-06: sin el colorset falla cerrado', () {
      w.delete(colorset);
      _fails(w.section('launch'), 'LaunchBackground.colorset');
    });

    test('CA-028-06: sin tokens.json falla cerrado', () {
      w.delete('design/tokens.json');
      _fails(w.section('launch'), 'tokens.json');
    });

    test(
      'CA-028-06: se compara con paper de tokens.json, no con un valor fijo',
      () {
        w.write(
          'design/tokens.json',
          jsonEncode({
            'color': {
              'paper': {r'$value': '#FFFFFF'},
            },
          }),
        );
        _fails(w.section('launch'), 'paper');
      },
    );
  });

  group('CA-028-07: icon', () {
    const dir = 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset';

    test('CA-028-07: iconos propios sin alfa pasan', () {
      _passes(w.section('icon'));
    });

    test('CA-028-07: un icono con canal alfa (RGBA) falla', () {
      w.writeBytes('$dir/Icon-20.png', _png(20, colorType: 6));
      _fails(w.section('icon'), 'alfa');
    });

    test('CA-028-07: un icono en gris con alfa (tipo 4) falla', () {
      w.writeBytes('$dir/Icon-20.png', _png(20, colorType: 4));
      _fails(w.section('icon'), 'alfa');
    });

    test('CA-028-07: un icono con transparencia tRNS falla', () {
      w.writeBytes('$dir/Icon-20.png', _png(20, trns: true));
      _fails(w.section('icon'), 'transparencia');
    });

    test('CA-028-07: un icono idéntico a uno de la plantilla falla', () {
      w.declareTemplateIcon(w.file('$dir/Icon-20.png'));
      _fails(w.section('icon'), 'plantilla de Flutter');
    });

    test('CA-028-07: sin el icono de 1024 falla', () {
      w.delete('$dir/Icon-1024.png');
      _fails(w.section('icon'), '1024');
    });

    test('CA-028-07: sin ningún PNG falla', () {
      w.delete('$dir/Icon-1024.png');
      w.delete('$dir/Icon-20.png');
      _fails(w.section('icon'), 'ningún PNG');
    });

    test('CA-028-07: un archivo .png que no es PNG falla', () {
      w.write('$dir/Icon-20.png', 'no soy un png');
      _fails(w.section('icon'), 'no es un PNG');
    });

    test(
      'CA-028-07: las sumas de la plantilla reales cubren los 15 iconos',
      () {
        final sums = RegExp(
          r'^[0-9a-f]{64} ',
          multiLine: true,
        ).allMatches(File(_realFixture).readAsStringSync());
        expect(sums.length, 15);
        // El de 1024 de la plantilla, tal como salió de `flutter create`.
        expect(
          File(_realFixture).readAsStringSync(),
          contains(
            '7770183009e914112de7d8ef1d235a6a30c5834424858e0d2f8253f6b8d31926',
          ),
        );
      },
    );
  });

  group('CA-028-17: privacy', () {
    const xcprivacy = 'app/ios/Runner/PrivacyInfo.xcprivacy';

    test('CA-028-17: un manifiesto sin rastreo ni datos pasa', () {
      _passes(w.section('privacy'));
    });

    test('CA-028-17: NSPrivacyTracking = true falla', () {
      w.replace(xcprivacy, '<false/>', '<true/>');
      _fails(w.section('privacy'), 'NSPrivacyTracking');
    });

    test('CA-028-17: con un dominio de rastreo falla', () {
      w.replace(
        xcprivacy,
        RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array>\s*</array>'),
        '<key>NSPrivacyTrackingDomains</key><array><string>x.example</string></array>',
      );
      _fails(w.section('privacy'), 'NSPrivacyTrackingDomains');
    });

    test('CA-028-17: con un tipo de dato recogido falla', () {
      w.replace(
        xcprivacy,
        RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array>\s*</array>'),
        '<key>NSPrivacyCollectedDataTypes</key><array><dict><key>a</key><string>b</string></dict></array>',
      );
      _fails(w.section('privacy'), 'NSPrivacyCollectedDataTypes');
    });

    test('CA-028-17: una API declarada sin razón falla', () {
      w.replace(
        xcprivacy,
        RegExp(r'<array>\s*<string>E174.1</string>\s*</array>'),
        '<array></array>',
      );
      _fails(w.section('privacy'), 'sin razón');
    });

    test('CA-028-17: sin manifiesto falla cerrado', () {
      w.delete(xcprivacy);
      _fails(w.section('privacy'), 'PrivacyInfo.xcprivacy');
    });

    test('CA-028-17: un manifiesto que no es plist falla', () {
      w.write(xcprivacy, '{}');
      _fails(w.section('privacy'), 'plist válido');
    });

    final apis = <String, (String code, String category)>{
      'espacio libre (volumeAvailableCapacityForImportantUsageKey)': (
        'let k = URLResourceKey.volumeAvailableCapacityForImportantUsageKey',
        'DiskSpace',
      ),
      'espacio libre (systemFreeSize)': (
        'let k = attrs[.systemFreeSize]',
        'DiskSpace',
      ),
      'fechas (creationDate)': ('let d = values.creationDate', 'FileTimestamp'),
      'fechas (modificationDate)': (
        'let d = attrs.modificationDate',
        'FileTimestamp',
      ),
      'fechas (contentModificationDate)': (
        'let d = v.contentModificationDate',
        'FileTimestamp',
      ),
      'arranque (systemUptime)': (
        'let t = ProcessInfo.processInfo.systemUptime',
        'SystemBootTime',
      ),
      'arranque (mach_absolute_time)': (
        'let t = mach_absolute_time()',
        'SystemBootTime',
      ),
      'UserDefaults': ('let u = UserDefaults.standard', 'UserDefaults'),
    };
    for (final e in apis.entries) {
      test('CA-028-17: ${e.key} sin declarar falla y declarado pasa', () {
        w.write('app/ios/Runner/Uses.swift', '${e.value.$1}\n');
        // DiskSpace ya está declarado en el árbol bueno: el resto no.
        if (e.value.$2 == 'DiskSpace') {
          _passes(w.section('privacy'));
          w.replace(
            xcprivacy,
            'NSPrivacyAccessedAPICategoryDiskSpace',
            'NSPrivacyAccessedAPICategoryOtra',
          );
        }
        _fails(
          w.section('privacy'),
          'NSPrivacyAccessedAPICategory${e.value.$2}',
        );
        w.replace(
          xcprivacy,
          RegExp(r'</array>\s*</dict>\s*</plist>'),
          '<dict><key>NSPrivacyAccessedAPIType</key>'
          '<string>NSPrivacyAccessedAPICategory${e.value.$2}</string>'
          '<key>NSPrivacyAccessedAPITypeReasons</key><array><string>X.1</string></array></dict>'
          '</array></dict></plist>',
        );
        _passes(w.section('privacy'));
      });
    }

    test('CA-028-17: la API solo nombrada en un comentario no cuenta', () {
      w.write(
        'app/ios/Runner/Uses.swift',
        '// UserDefaults.standard\n/* mach_absolute_time() */\n',
      );
      _passes(w.section('privacy'));
    });

    test('CA-028-17: el aviso lleva el archivo y la línea', () {
      w.write(
        'app/ios/Runner/Uses.swift',
        'let a = 1\nlet u = UserDefaults.standard\n',
      );
      _fails(w.section('privacy'), 'Uses.swift:2');
    });
  });

  group('CA-028-17: network', () {
    test('CA-028-17: un Swift sin red ni registros pasa', () {
      _passes(w.section('network'));
    });

    const banned = {
      'URLSession': 'let s = URLSession.shared',
      'URLSessionConfiguration': 'let c = URLSessionConfiguration.default',
      'NWConnection': 'let c = NWConnection(host: h, port: p, using: .tcp)',
      'CFNetwork': 'import CFNetwork',
      'print': 'print("x")',
      'print con espacio': 'print ("x")',
      'debugPrint': 'debugPrint(x)',
      'NSLog': 'NSLog("x")',
      'os_log': 'os_log("x")',
      'Logger': 'let l = Logger(subsystem: "a", category: "b")',
    };
    for (final e in banned.entries) {
      test('CA-028-17: «${e.key}» en el Swift falla', () {
        w.write('app/ios/Runner/Bad.swift', '${e.value}\n');
        _fails(w.section('network'), 'Bad.swift:1');
      });
    }

    test(
      'CA-028-17: lo prohibido en una subcarpeta de Runner también falla',
      () {
        w.write('app/ios/Runner/Sub/Deep.swift', 'let s = URLSession.shared\n');
        _fails(w.section('network'), 'Deep.swift');
      },
    );

    test('CA-028-17: lo prohibido en un comentario no cuenta', () {
      w.write(
        'app/ios/Runner/Ok.swift',
        '// URLSession\n/* print("x")\n NSLog */\nlet a = 1\n',
      );
      _passes(w.section('network'));
    });

    test('CA-028-17: una palabra parecida (blueprint, Loggers) no cuenta', () {
      w.write(
        'app/ios/Runner/Ok.swift',
        'let blueprint = 1\nlet x = "a"\nlet fingerprint = 2\n',
      );
      _passes(w.section('network'));
    });

    test('CA-028-17: RunnerTests queda fuera (puede usar print)', () {
      w.write('app/ios/RunnerTests/T.swift', 'print("x")\n');
      _passes(w.section('network'));
    });

    test('CA-028-17: sin ningún Swift falla cerrado', () {
      for (final f in Directory(
        '${w.root.path}/app/ios/Runner',
      ).listSync(recursive: true)) {
        if (f is File && f.path.endsWith('.swift')) f.deleteSync();
      }
      _fails(w.section('network'), 'ningún .swift');
    });
  });

  group('CA-028-20: channel', () {
    for (final entry in _channels.entries) {
      final name = entry.key;
      final (kt, swift, methods) = entry.value;
      final swiftRel = 'app/ios/Runner/$swift';

      test('CA-028-20: $name con todos sus métodos pasa', () {
        _passes(w.section('channel:$name'));
      });

      for (final m in methods) {
        test('CA-028-20: $name sin `case "$m"` falla y lo nombra', () {
          w.replace(swiftRel, 'case "$m":', 'case "otro_$m":');
          _fails(w.section('channel:$name'), 'case "$m"');
        });
      }

      test(
        'CA-028-20: $name con un método nuevo en Kotlin sin su caso falla',
        () {
          w.replace(
            'app/android/app/src/main/kotlin/dev/x/app/$kt',
            '      else ->',
            '      "metodoNuevo" -> result.success(null)\n      else ->',
          );
          _fails(w.section('channel:$name'), 'metodoNuevo');
        },
      );

      test('CA-028-20: $name sin su archivo Swift falla cerrado', () {
        w.delete(swiftRel);
        _fails(w.section('channel:$name'), swift);
      });

      test('CA-028-20: $name sin su archivo Kotlin falla cerrado', () {
        w.delete('app/android/app/src/main/kotlin/dev/x/app/$kt');
        _fails(w.section('channel:$name'), kt);
      });
    }

    test('CA-028-20: un `case` solo en un comentario no cuenta', () {
      w.write(
        'app/ios/Runner/Links.swift',
        _swiftSwitch(['open'], commentOnly: 'canOpen'),
      );
      _fails(w.section('channel:una/links'), 'canOpen');
    });

    test('CA-028-20: varias etiquetas en un `case` valen', () {
      w.write(
        'app/ios/Runner/Links.swift',
        'switch call.method {\n case "open", "canOpen":\n  break\n default: break\n}\n',
      );
      _passes(w.section('channel:una/links'));
    });

    test('CA-028-20: un método solo de iOS en Swift no afecta (la comprobación va de Kotlin a Swift)', () {
      w.replace(
        'app/ios/Runner/Images.swift',
        '    default:',
        '    case "openAppSettings":\n      result(nil)\n    default:',
      );
      _passes(w.section('channel:una/images'));
    });

    test('CA-028-20: un método que iOS no implementa lleva su case y responde no implementado', () {
      // Es el caso de `debugPickManyDocuments`: el `case` tiene que estar aunque no haga nada.
      w.replace(
        'app/ios/Runner/Images.swift',
        'case "debugPickManyDocuments":\n      result(nil)',
        'case "debugPickManyDocuments":\n      result(FlutterMethodNotImplemented)',
      );
      _passes(w.section('channel:una/images'));
      w.replace(
        'app/ios/Runner/Images.swift',
        'case "debugPickManyDocuments":',
        '// case "debugPickManyDocuments":',
      );
      _fails(w.section('channel:una/images'), 'debugPickManyDocuments');
    });

    test('CA-028-20: un `when` anidado (web, mail) no cuenta como método', () {
      // El Kotlin de prueba trae `when (kind) { "web" -> …; "mail" -> … }` dentro de una rama.
      for (final m in ['web', 'mail', 'commentedOut']) {
        w.replace(
          'app/ios/Runner/Links.swift',
          'case "open":',
          'case "open":\n      break\n    case "$m":',
        );
      }
      // Solo cuentan los métodos del `when (call.method)`: los casos de más no molestan y nada falla.
      _passes(w.section('channel:una/links'));
      // Y al revés: si se quitaran los de verdad, falla.
      w.replace(
        'app/ios/Runner/Links.swift',
        'case "canOpen":',
        'case "xcanOpen":',
      );
      _fails(w.section('channel:una/links'), 'canOpen');
    });

    test('CA-028-20: un Kotlin sin `when (call.method)` falla cerrado', () {
      w.write(
        'app/android/app/src/main/kotlin/dev/x/app/LinkOpener.kt',
        'class LinkOpener {}\n',
      );
      _fails(w.section('channel:una/links'), 'when (call.method)');
    });

    test(
      'CA-028-20: dos archivos Kotlin con el mismo nombre fallan (ambiguo)',
      () {
        w.write(
          'app/android/app/src/main/kotlin/dev/otro/LinkOpener.kt',
          _kotlinWhen(['open', 'canOpen']),
        );
        _fails(w.section('channel:una/links'), 'exactamente un archivo');
      },
    );

    test('CA-028-20: el Swift se lee aunque el Kotlin tenga el paquete en otra carpeta', () {
      final from = Directory(
        '${w.root.path}/app/android/app/src/main/kotlin/dev',
      );
      from.renameSync('${w.root.path}/app/android/app/src/main/kotlin/otro');
      _passes(w.section('channel:una/links'));
    });
  });

  group('CA-028-20: contra el Kotlin real', () {
    // Los métodos que hoy tiene cada canal de Kotlin: si el lector del script se rompe con el código
    // de verdad (llaves en cadenas, `when` anidados, ramas de varias líneas), este test lo ve.
    test(
      'CA-028-20: el script lee todos los métodos de los seis canales reales',
      () {
        final real = Directory(_kotlinReal);
        expect(real.existsSync(), isTrue);
        final tree = Directory.systemTemp.createTempSync('ios_parity_real_');
        addTearDown(() => tree.deleteSync(recursive: true));
        for (final f in real.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.kt')) continue;
          final rel = f.path.substring(real.path.length);
          File('${tree.path}/app/android/app/src/main/kotlin$rel')
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(f.readAsStringSync());
        }
        for (final c in _channels.values) {
          File('${tree.path}/app/ios/Runner/${c.$2}')
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(_swiftSwitch(c.$3));
        }
        for (final name in _channels.keys) {
          final r = Process.runSync('bash', [
            w.scriptPath,
            '--root',
            tree.path,
            '--section',
            'channel:$name',
          ]);
          expect(r.exitCode, 0, reason: '$name: ${r.stdout}\n${r.stderr}');
        }
        // Y si a un canal real le falta un método, falla (el Swift de prueba sin `capabilities`).
        File('${tree.path}/app/ios/Runner/Images.swift').writeAsStringSync(
          _swiftSwitch(
            _channels['una/images']!.$3
                .where((m) => m != 'capabilities')
                .toList(),
          ),
        );
        final r = Process.runSync('bash', [
          w.scriptPath,
          '--root',
          tree.path,
          '--section',
          'channel:una/images',
        ]);
        expect(r.exitCode, 1);
        expect('${r.stderr}', contains('capabilities'));
      },
    );
  });

  group('CA-028-20: el repositorio de verdad', () {
    test('CA-028-20: las secciones activas del repositorio pasan', () {
      final r = Process.runSync('bash', [_script]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(
        '${r.stdout}',
        contains(RegExp(r'^OK +network$', multiLine: true)),
      );
    });

    test(
      'CA-028-20: tools/ios-parity.sections solo nombra secciones que existen',
      () {
        final names = File('../tools/ios-parity.sections')
            .readAsLinesSync()
            .map((l) => l.split('#').first.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        expect(names, isNotEmpty);
        for (final n in names) {
          // Una sección desconocida haría fallar la ejecución sin argumentos.
          final r = Process.runSync('bash', [_script, '--section', n]);
          expect(r.exitCode, anyOf(0, 1), reason: 'sección $n: ${r.stderr}');
        }
      },
    );
  });
}
