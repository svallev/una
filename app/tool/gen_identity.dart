// Genera todo lo que depende del nombre de la app a partir de `identity.yaml` (fuente única, P7).
//
//   dart run tool/gen_identity.dart          → escribe los archivos
//   dart run tool/gen_identity.dart --check  → falla si alguno no está al día (CI)
//   --root <carpeta>  → la carpeta de la app (por defecto `.`); así se prueba con una copia
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final rootIndex = args.indexOf('--root');
  if (rootIndex >= 0 && rootIndex + 1 >= args.length) {
    stderr.writeln('--root necesita un valor');
    exit(2);
  }
  final root = rootIndex >= 0 ? args[rootIndex + 1] : '.';
  final yaml =
      loadYaml(File('$root/identity.yaml').readAsStringSync()) as YamlMap;
  final displayName = _required(yaml, 'displayName');
  final wordmark = _required(yaml, 'wordmark');
  final privacyPolicyUrl = _required(yaml, 'privacyPolicyUrl');
  final thirdPartyLicensesUrl = _required(yaml, 'thirdPartyLicensesUrl');
  final helpUrl = _required(yaml, 'helpUrl');

  final outputs = <String, String Function(String? current)>{
    'lib/app/app_identity.g.dart': (_) =>
        '''
// GENERADO por tool/gen_identity.dart desde identity.yaml. No editar a mano.

/// Identidad de la app. El nombre nunca se escribe literal en el código (constitución P7).
abstract final class AppIdentity {
  /// Nombre de la app en el sistema (bajo el icono).
  static const String displayName = ${_dartString(displayName)};

  /// Logotipo que se muestra dentro de la app.
  static const String wordmark = ${_dartString(wordmark)};

  /// Dirección de la política de privacidad (una sola para ES y EN). Solo `https`; se abre en el
  /// navegador del sistema. Es un marcador hasta que exista la web (spec 012, CA-012-05).
  static const String privacyPolicyUrl = ${_dartString(privacyPolicyUrl)};

  /// Dirección de la web de licencias de terceros (una sola para ES y EN; ADR-0026). Marcador
  /// hasta que exista la web (spec 015, CA-015-13a).
  static const String thirdPartyLicensesUrl = ${_dartString(thirdPartyLicensesUrl)};

  /// Dirección de la web de ayuda (una sola para ES y EN). Marcador hasta que exista la web
  /// (spec 015, CA-015-13a).
  static const String helpUrl = ${_dartString(helpUrl)};
}
''',
    'android/app/src/main/res/values/strings.xml': (_) =>
        '''
<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por tool/gen_identity.dart desde identity.yaml. No editar a mano. -->
<resources>
    <string name="app_name" translatable="false">${_xml(displayName)}</string>
</resources>
''',
    'ios/Flutter/Identity.xcconfig': (_) =>
        '''
// GENERADO por tool/gen_identity.dart desde identity.yaml. No editar a mano.
APP_DISPLAY_NAME = $displayName
''',
    'ios/Flutter/Debug.xcconfig': (current) => _ensureInclude(current!),
    'ios/Flutter/Release.xcconfig': (current) => _ensureInclude(current!),
    'ios/Runner/Info.plist': (current) => current!
        .replaceAllMapped(
          RegExp(
            r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
          ),
          (m) => '${m[1]}\$(APP_DISPLAY_NAME)${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)'),
          (m) => '${m[1]}\$(APP_DISPLAY_NAME)${m[2]}',
        ),
    'web/index.html': (current) => current!
        .replaceAllMapped(
          RegExp(r'<title>[^<]*</title>'),
          (_) => '<title>${_xml(displayName)}</title>',
        )
        .replaceAllMapped(
          RegExp(
            r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(">)',
          ),
          (m) => '${m[1]}${_xml(displayName)}${m[2]}',
        ),
    'web/manifest.json': (current) {
      final m = jsonDecode(current!) as Map<String, dynamic>;
      m['name'] = displayName;
      m['short_name'] = displayName;
      return '${const JsonEncoder.withIndent('    ').convert(m)}\n';
    },
  };

  final stale = <String>[];
  outputs.forEach((path, build) {
    final file = File('$root/$path');
    final current = file.existsSync() ? file.readAsStringSync() : null;
    final raw = build(current).trimLeft();
    final next = path.endsWith('.dart') ? _formatDart(raw) : raw;
    if (current == next) return;
    stale.add(path);
    if (!check) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(next);
    }
  });

  if (check && stale.isNotEmpty) {
    stderr.writeln(
      'Identidad desactualizada. Ejecuta `dart run tool/gen_identity.dart`:\n - ${stale.join('\n - ')}',
    );
    exit(1);
  }
  stdout.writeln(
    check
        ? 'Identidad al día.'
        : 'Identidad generada (${stale.length} archivos actualizados).',
  );
}

/// El valor de [key] como texto: si falta o no lo es, falla con un mensaje claro (no con un
/// `TypeError`). La validez de las direcciones la comprueba la puerta de publicación.
String _required(YamlMap yaml, String key) {
  final value = yaml[key];
  if (value is! String) {
    stderr.writeln('identity.yaml: la clave `$key` falta o no es texto.');
    exit(1);
  }
  return value;
}

String _ensureInclude(String xcconfig) =>
    xcconfig.contains('#include "Identity.xcconfig"')
    ? xcconfig
    : '${xcconfig.trimRight()}\n#include "Identity.xcconfig"\n';

String _dartString(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", r"\'");

/// Formatea código Dart con `dart format` para que coincida con lo que exige CI.
String _formatDart(String source) {
  final tmp = Directory.systemTemp.createTempSync('gen_');
  try {
    final f = File('${tmp.path}/gen.dart')..writeAsStringSync(source);
    final r = Process.runSync(Platform.resolvedExecutable, ['format', f.path]);
    if (r.exitCode != 0) throw StateError('dart format falló: ${r.stderr}');
    return f.readAsStringSync();
  } finally {
    tmp.deleteSync(recursive: true);
  }
}
