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
    'ios/Runner/Info.plist': (current) {
      var plist = current!
          .replaceAllMapped(
            RegExp(
              r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
            ),
            (m) => '${m[1]}\$(APP_DISPLAY_NAME)${m[2]}',
          )
          .replaceAllMapped(
            RegExp(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)'),
            (m) => '${m[1]}\$(APP_DISPLAY_NAME)${m[2]}',
          );
      // Idiomas del paquete (spec 028, CA-028-08) y la descripción base del permiso de cámara
      // (la única de uso, CA-028-10); su traducción va en `InfoPlist.strings`.
      plist = _setPlistEntry(
        plist,
        'CFBundleLocalizations',
        '<array>\n${[for (final l in _iosLanguages) '\t\t<string>$l</string>\n'].join()}\t</array>',
        before: 'CFBundleName',
      );
      return _setPlistEntry(
        plist,
        'NSCameraUsageDescription',
        '<string>${_xmlText(_iosCameraUsage['en']!)}</string>',
        before: 'UIApplicationSceneManifest',
      );
    },
    // Textos del sistema de iOS por idioma (spec 028, CA-028-08): el nombre bajo el icono y el
    // permiso de cámara. `ca` es una copia de `es` (como `values-ca`, CA-024-04).
    for (final lang in _iosLanguages)
      'ios/Runner/$lang.lproj/InfoPlist.strings': (_) =>
          _infoPlistStrings(displayName, lang),
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

/// Idiomas del paquete de iOS (`CFBundleLocalizations` y una `*.lproj` cada uno). `ca` abre en
/// español (CA-028-08).
const _iosLanguages = ['en', 'es', 'ca'];

/// Texto del permiso de cámara de iOS por idioma (spec 028 §7; no es un ARB: lo lee el sistema,
/// no Flutter). `ca` = `es`.
const _iosCameraUsage = {
  'en': 'To take the photo for a task.',
  'es': 'Para hacer la foto de una tarea.',
};

/// El contenido de `<lang>.lproj/InfoPlist.strings`. `ca` usa los textos de `es`.
String _infoPlistStrings(String displayName, String lang) {
  final camera = _iosCameraUsage[lang == 'en' ? 'en' : 'es']!;
  return '''
/* GENERADO por tool/gen_identity.dart desde identity.yaml. No editar a mano. */
"CFBundleDisplayName" = "${_stringsValue(displayName)}";
"NSCameraUsageDescription" = "${_stringsValue(camera)}";
''';
}

/// [s] como valor de un `.strings` (entre comillas dobles).
String _stringsValue(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n');

/// [s] como texto de un `<string>` de un plist.
String _xmlText(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Pone en [plist] la entrada `<key>[key]</key>` [valueXml] justo antes de la de [before]
/// (orden alfabético, como lo deja Xcode); si ya está, la deja en ese sitio con ese valor
/// (idempotente). Falla si no encuentra [before].
String _setPlistEntry(
  String plist,
  String key,
  String valueXml, {
  required String before,
}) {
  final existing = RegExp(
    '\t<key>$key</key>\n\t(?:<array>.*?</array>|<string>[^<]*</string>)\n',
    dotAll: true,
  );
  final clean = plist.replaceFirst(existing, '');
  final anchor = '\t<key>$before</key>';
  final at = clean.indexOf(anchor);
  if (at < 0) {
    stderr.writeln('Info.plist: falta la clave `$before` (ancla de `$key`).');
    exit(1);
  }
  return '${clean.substring(0, at)}\t<key>$key</key>\n\t$valueXml\n'
      '${clean.substring(at)}';
}

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
