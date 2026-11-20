import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/gen_identity.dart` en lo que añade la spec 028 (T-028-02, CA-028-08): los textos del
/// sistema de iOS por idioma (`{en,es,ca}.lproj/InfoPlist.strings`) y `CFBundleLocalizations`.
/// Se prueba con una copia de lo que lee el generador en un directorio temporal (`--root`), sin
/// tocar el repositorio.

/// Lo que lee el generador (relativo a `app/`) y no es una de las salidas nuevas.
const _inputs = [
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

const _lprojs = [
  'ios/Runner/en.lproj/InfoPlist.strings',
  'ios/Runner/es.lproj/InfoPlist.strings',
  'ios/Runner/ca.lproj/InfoPlist.strings',
];

/// Los textos de spec §7 (el del permiso de cámara no es un ARB).
const _cameraEs = 'Para hacer la foto de una tarea.';
const _cameraEn = 'To take the photo for a task.';

late Directory _root;

ProcessResult _gen(List<String> args) => Process.runSync('dart', [
  'run',
  'tool/gen_identity.dart',
  '--root',
  _root.path,
  ...args,
]);

String _read(String rel) => File('${_root.path}/$rel').readAsStringSync();

/// Una copia con lo generado ya al día (las `lproj` no existen en la copia de partida: el
/// generador las crea).
void _generate() {
  final r = _gen([]);
  expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
}

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('gen_identity_');
    addTearDown(() => _root.deleteSync(recursive: true));
    for (final rel in _inputs) {
      File('${_root.path}/$rel')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(File(rel).readAsStringSync());
    }
  });

  test('CA-028-08: genera las tres lproj de InfoPlist.strings', () {
    _generate();
    for (final rel in _lprojs) {
      expect(File('${_root.path}/$rel').existsSync(), isTrue, reason: rel);
    }
  });

  test('CA-028-08: CFBundleDisplayName sale de identity.yaml en los tres '
      'idiomas (P7)', () {
    File('${_root.path}/identity.yaml').writeAsStringSync(
      File('identity.yaml').readAsStringSync().replaceFirst(
        RegExp(r'^displayName: "[^"]*"', multiLine: true),
        'displayName: "Nombre de prueba"',
      ),
    );
    _generate();
    for (final rel in _lprojs) {
      expect(
        _read(rel),
        contains('"CFBundleDisplayName" = "Nombre de prueba";'),
        reason: rel,
      );
    }
  });

  test('CA-028-08: NSCameraUsageDescription en inglés y en español', () {
    _generate();
    expect(
      _read(_lprojs[0]),
      contains('"NSCameraUsageDescription" = "$_cameraEn";'),
    );
    expect(
      _read(_lprojs[1]),
      contains('"NSCameraUsageDescription" = "$_cameraEs";'),
    );
  });

  test('CA-028-08: ca es una copia exacta de es (como values-ca, '
      'CA-024-04)', () {
    _generate();
    expect(_read(_lprojs[2]), _read(_lprojs[1]));
    expect(_read(_lprojs[0]), isNot(_read(_lprojs[1])));
  });

  test('CA-028-08: las lproj llevan la marca de generado y solo las dos '
      'claves', () {
    _generate();
    for (final rel in _lprojs) {
      final text = _read(rel);
      expect(
        text,
        contains('GENERADO por tool/gen_identity.dart'),
        reason: rel,
      );
      final keys = RegExp(
        r'^"(\w+)" =',
        multiLine: true,
      ).allMatches(text).map((m) => m[1]).toList();
      expect(keys, ['CFBundleDisplayName', 'NSCameraUsageDescription']);
    }
  });

  test('CA-028-08: Info.plist declara CFBundleLocalizations en, es y ca '
      'y es idempotente', () {
    _generate();
    final plist = _read('ios/Runner/Info.plist');
    expect(
      plist,
      contains(
        RegExp(
          r'<key>CFBundleLocalizations</key>\s*<array>\s*'
          r'<string>en</string>\s*<string>es</string>\s*<string>ca</string>\s*'
          r'</array>',
        ),
      ),
    );
    expect('CFBundleLocalizations'.allMatches(plist), hasLength(1));
    _generate();
    expect(_read('ios/Runner/Info.plist'), plist);
  });

  test('CA-028-08, CA-028-10: Info.plist trae la descripción base de la cámara '
      '(la única de uso) con el texto en inglés', () {
    _generate();
    final plist = _read('ios/Runner/Info.plist');
    expect(
      plist,
      contains(
        RegExp(
          r'<key>NSCameraUsageDescription</key>\s*'
          '<string>$_cameraEn</string>',
        ),
      ),
    );
    expect(
      RegExp(r'<key>NS\w*UsageDescription</key>').allMatches(plist),
      hasLength(1),
    );
  });

  test('CA-028-08: --check pasa con todo al día', () {
    _generate();
    final r = _gen(['--check']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });

  test('CA-028-08: --check falla si falta una lproj y la nombra', () {
    for (final rel in _lprojs) {
      _generate();
      File('${_root.path}/$rel').deleteSync();
      final r = _gen(['--check']);
      expect(r.exitCode, 1, reason: rel);
      expect('${r.stderr}', contains(rel));
    }
  });

  test('CA-028-08: --check falla si una lproj está desfasada', () {
    _generate();
    File('${_root.path}/${_lprojs[2]}').writeAsStringSync('"x" = "y";\n');
    final r = _gen(['--check']);
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains(_lprojs[2]));
  });

  test('CA-028-08: --check falla si falta CFBundleLocalizations', () {
    _generate();
    final f = File('${_root.path}/ios/Runner/Info.plist');
    f.writeAsStringSync(
      f.readAsStringSync().replaceFirst(
        RegExp(
          r'\t<key>CFBundleLocalizations</key>.*?</array>\n',
          dotAll: true,
        ),
        '',
      ),
    );
    final r = _gen(['--check']);
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains('ios/Runner/Info.plist'));
  });

  test('CA-028-08: un nombre con comillas o barra invertida sale escapado '
      'como texto de .strings', () {
    File('${_root.path}/identity.yaml').writeAsStringSync(
      File('identity.yaml').readAsStringSync().replaceFirst(
        RegExp(r'^displayName: "[^"]*"', multiLine: true),
        r'displayName: "A \"B\" \\ C"',
      ),
    );
    _generate();
    expect(
      _read(_lprojs[0]),
      contains(r'"CFBundleDisplayName" = "A \"B\" \\ C";'),
    );
  });

  test('CA-028-08: el repositorio de verdad está al día (--check sobre '
      'app/)', () {
    final r = Process.runSync('dart', [
      'run',
      'tool/gen_identity.dart',
      '--check',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    for (final rel in _lprojs) {
      expect(File(rel).existsSync(), isTrue, reason: rel);
    }
  });

  test('CA-028-08: la sección l10n del script de paridad pasa con las lproj '
      'reales y es la que vigila el repositorio', () {
    final r = Process.runSync('bash', [
      '../tools/check-ios-parity.sh',
      '--section',
      'l10n',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    final sections = File('../tools/ios-parity.sections').readAsLinesSync();
    expect(sections.map((l) => l.split('#').first.trim()), contains('l10n'));
  });

  test('CA-028-08: el proyecto de Xcode incluye las tres lproj como recurso '
      'del Runner y declara las regiones', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    // Una vez como archivo de construcción y otra en la fase de recursos del Runner.
    expect(
      RegExp(r'InfoPlist\.strings in Resources').allMatches(pbx),
      hasLength(2),
    );
    final phase = RegExp(
      r'PBXResourcesBuildPhase section \*/(.*?)End PBXResourcesBuildPhase',
      dotAll: true,
    ).firstMatch(pbx)![1]!;
    expect(phase, contains('InfoPlist.strings in Resources'));
    for (final lang in ['en', 'es', 'ca']) {
      expect(pbx, contains('path = $lang.lproj/InfoPlist.strings;'));
    }
    final regions = RegExp(r'knownRegions = \(([^)]*)\)').firstMatch(pbx)![1]!;
    for (final lang in ['en', 'es', 'ca', 'Base']) {
      expect(regions, contains(RegExp('\\b$lang\\b')), reason: lang);
    }
  });
}
