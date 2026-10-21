import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Apoyo de las pruebas de las herramientas que leen el AAB (spec 020, T-020-06): un AAB de prueba
/// (un zip pequeño con las entradas de `base/` que usan las herramientas), un `aapt2` de mentira que
/// sirve los volcados de `test/tool/fixtures/aapt2/good/` (los del APK de release real de la 020) y
/// el AAB real si está compilado (`flutter build appbundle --release`).
const aapt2FixturesDir = 'test/tool/fixtures/aapt2/good';

/// El AAB de release que deja `flutter build appbundle --release` (desde `app/`).
const realAabPath = 'build/app/outputs/bundle/release/app-release.aab';

bool hasTool(String name) => Process.runSync('which', [name]).exitCode == 0;

/// Por qué se salta una prueba que arma paquetes con `zip` y los lee con `unzip` y `bash`.
String? get zipToolsSkip =>
    !hasTool('zip') || !hasTool('unzip') || !hasTool('bash')
    ? 'zip/unzip/bash no disponibles'
    : null;

/// Un zip con [entries] (ruta -> contenido) en [dir], con la extensión [ext].
String zipEntries(
  Directory dir,
  String name,
  Map<String, List<int>> entries, {
  String ext = 'aab',
}) {
  final staging = Directory('${dir.path}/staging_$name')..createSync();
  entries.forEach((path, bytes) {
    File('${staging.path}/$path')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  });
  final out = '${dir.path}/$name.$ext';
  final r = Process.runSync('zip', [
    '-q',
    '-r',
    '-X',
    out,
    '.',
  ], workingDirectory: staging.path);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  return out;
}

/// Las entradas mínimas de un AAB con un solo módulo.
Map<String, List<int>> aabEntries({
  Map<String, List<int>> extra = const {},
  Iterable<String> without = const [],
}) => {
  'BundleConfig.pb': utf8.encode('config'),
  'BUNDLE-METADATA/com.android.tools/r8.json': utf8.encode('{}'),
  'META-INF/MANIFEST.MF': utf8.encode('Manifest-Version: 1.0'),
  'base/manifest/AndroidManifest.xml': utf8.encode('proto-manifest'),
  'base/resources.pb': utf8.encode('proto-resources'),
  'base/res/xml/network_security_config.xml': utf8.encode('proto-xml'),
  'base/dex/classes.dex': utf8.encode('dex'),
  'base/lib/arm64-v8a/libpdfium.so': utf8.encode('pdfium'),
  ...extra,
}..removeWhere((k, _) => without.contains(k));

String _fixture(String p) => File('$aapt2FixturesDir/$p').readAsStringSync();

/// El volcado de `aapt2 dump xmltree` del manifiesto bueno.
String goodManifestDump() => _fixture('manifest.txt');

/// Escribe en [dir] un `aapt2` de mentira y devuelve su ruta. Sirve los volcados buenos (con
/// [manifest] y [resources] cambiados si se dan) y, ante `convert`, copia el paquete de entrada a la
/// salida (el AAB de prueba no es un APK proto de verdad: no hay nada que convertir). Anota cada
/// llamada en `calls.log` de [dir].
String writeFakeAapt2(
  Directory dir, {
  String? manifest,
  String? resources,
  int convertExit = 0,
}) {
  final dumps = Directory('${dir.path}/dumps')..createSync(recursive: true);
  File('${dumps.path}/manifest')
      .writeAsStringSync(manifest ?? goodManifestDump());
  File('${dumps.path}/resources')
      .writeAsStringSync(resources ?? _fixture('resources.txt'));
  for (final n in ['4j', '8G', 'Md', 'Qq', 'xo']) {
    File('${dumps.path}/res__$n.xml')
        .writeAsStringSync(_fixture('res/$n.xml.txt'));
  }
  final script = File('${dir.path}/aapt2')
    ..writeAsStringSync('''#!/bin/sh
D="${dumps.path}"
echo "\$*" >> "${dir.path}/calls.log"
if [ "\$1" = convert ]; then
  # aapt2 convert --output-format binary -o OUT IN
  [ "$convertExit" = 0 ] || { echo "convert roto" >&2; exit $convertExit; }
  cp "\$6" "\$5"
  exit 0
fi
if [ "\$1" = dump ] && [ "\$2" = resources ]; then cat "\$D/resources"; exit 0; fi
if [ "\$1" = dump ] && [ "\$2" = xmltree ] && [ "\$3" = --file ]; then
  if [ "\$4" = AndroidManifest.xml ]; then cat "\$D/manifest"; exit 0; fi
  f="\$D/\$(echo "\$4" | sed 's#/#__#g')"
  if [ -f "\$f" ]; then cat "\$f"; exit 0; fi
fi
echo "aapt2 de mentira: no sé hacer \$*" >&2
exit 1
''');
  Process.runSync('chmod', ['+x', script.path]);
  return script.path;
}

/// El resultado de la estática sobre un paquete **real** de release: 0 (CA-020-22). Con uno
/// compilado en un Mac, la ruta de la carpeta del proyecto (`/Users/<usuario>/…`) hace fallar solo
/// la regla `build-paths` (spec 023, CA-023-19, Q-023-3 a: se acepta en una entrega a testers); eso
/// se tolera fuera de la CI, y cualquier otro hallazgo, no. En la CI (`CI=true`, un runner de
/// GitHub) el resultado tiene que ser 0.
void expectPassesOrLocalBuildPaths(int code, String output) {
  if (code == 0) return;
  final ci = Platform.environment['CI'] == 'true';
  final errors = const LineSplitter()
      .convert(output)
      .where((l) => l.startsWith('::error::'))
      .toList();
  expect(
    !ci &&
        errors.isNotEmpty &&
        errors.every((l) => l.contains('(build-paths)')),
    isTrue,
    reason: 'código $code\n$output',
  );
}
