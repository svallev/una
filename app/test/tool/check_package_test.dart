import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_package.dart';

/// Estática MASTG del paquete de release (spec 020, CA-020-22, plan §3.3): `tool/check_package.dart`
/// con las reglas (a) a (g) sobre `aapt2 dump` y `unzip`. Los negativos son volcados de `aapt2`
/// de prueba (`test/tool/fixtures/aapt2/good/`: los del APK de release real de la 020) modificados
/// con una sola diferencia, y paquetes `zip` pequeños creados aquí, en una carpeta temporal.
///
/// Los secretos de los casos se arman en tiempo de ejecución (no hay ningún literal con forma de
/// clave en el repositorio).
const _fixtures = 'test/tool/fixtures/aapt2/good';
const _manifestEntry = 'AndroidManifest.xml';

const _ns = 'http://schemas.android.com/apk/res/android';

bool _hasTool(String name) => Process.runSync('which', [name]).exitCode == 0;

/// Los volcados de `aapt2` de los que se parte; cada test cambia uno y mira lo que sale.
class _Dumps {
  _Dumps._(this.manifest, this.resources, this.files);

  factory _Dumps.good() {
    String read(String p) => File('$_fixtures/$p').readAsStringSync();
    return _Dumps._(read('manifest.txt'), read('resources.txt'), {
      for (final f in ['4j', '8G', 'Md', 'Qq', 'xo'])
        'res/$f.xml': read('res/$f.xml.txt'),
    });
  }

  String manifest;
  String resources;
  final Map<String, String> files;

  /// Cambia [from] por [to] en [text] y comprueba que hubo cambio (si no, el test no probaría nada).
  static String _swap(String text, String from, String to, {bool all = false}) {
    expect(
      text,
      contains(from),
      reason: 'el volcado de partida no tiene «$from»',
    );
    return all ? text.replaceAll(from, to) : text.replaceFirst(from, to);
  }

  /// Cambia todas las apariciones (el volcado repite el valor en el «Raw» de cada atributo).
  void manifestSwap(String from, String to) =>
      manifest = _swap(manifest, from, to, all: true);

  void resourcesSwap(String from, String to) =>
      resources = _swap(resources, from, to);

  void fileSwap(String file, String from, String to) =>
      files[file] = _swap(files[file]!, from, to);

  /// Quita la línea de [manifest] que contiene [fragment].
  void manifestRemoveLine(String fragment) {
    final lines = manifest.split('\n');
    final i = lines.indexWhere((l) => l.contains(fragment));
    expect(i, greaterThanOrEqualTo(0), reason: 'no hay línea con «$fragment»');
    lines.removeAt(i);
    manifest = lines.join('\n');
  }

  /// Añade [block] justo antes de la primera línea de [manifest] que contiene [marker].
  void manifestInsertBefore(String marker, String block) {
    final lines = manifest.split('\n');
    final i = lines.indexWhere((l) => l.contains(marker));
    expect(i, greaterThanOrEqualTo(0), reason: 'no hay línea con «$marker»');
    lines.insert(i, block);
    manifest = lines.join('\n');
  }

  /// Añade un atributo a `<application>` (tras `allowBackup`, que es suyo).
  void addApplicationAttr(String attr) {
    final lines = manifest.split('\n');
    final i = lines.indexWhere((l) => l.contains(':allowBackup('));
    lines.insert(i + 1, '        A: $attr');
    manifest = lines.join('\n');
  }

  void addFile(String entry, String dump) => files[entry] = dump;

  List<PackageIssue> check() => checkPackageXml(
    manifest: manifest,
    resources: resources,
    xmlFile: (entry) {
      final f = files[entry];
      if (f == null) throw StateError('sin volcado de $entry');
      return f;
    },
  );
}

Iterable<PackageIssue> _of(List<PackageIssue> all, String rule) =>
    all.where((i) => i.rule == rule);

/// Un único hallazgo de [rule]; los demás pueden no existir.
void _expectOnly(
  List<PackageIssue> issues,
  String rule, {
  required String entryContains,
  required String messageContains,
}) {
  final mine = _of(issues, rule).toList();
  expect(
    mine,
    isNotEmpty,
    reason: 'sin hallazgo de la regla ($rule): ${issues.map((i) => i.line)}',
  );
  expect(
    mine.any(
      (i) =>
          i.entry.contains(entryContains) &&
          i.message.contains(messageContains),
    ),
    isTrue,
    reason:
        'ningún hallazgo de ($rule) nombra «$entryContains» y «$messageContains»: '
        '${mine.map((i) => i.line).join(' | ')}',
  );
  expect(
    issues.where((i) => i.rule != rule),
    isEmpty,
    reason: 'solo debe fallar ($rule): ${issues.map((i) => i.line)}',
  );
}

String _attr(String name, String id, String value) =>
    '            A: $_ns:$name($id)=$value';

String _str(String s) => '"$s" (Raw: "$s")';

/// Un `<provider>` de un plugin con su `FILE_PROVIDER_PATHS` hacia [resourceId].
String _pluginProvider({String exported = 'false', String? resourceId}) => [
  '          E: provider (line=900)',
  _attr('name', '0x01010003', _str('x.PluginProvider')),
  if (exported.isNotEmpty) _attr('exported', '0x01010010', exported),
  if (resourceId != null) ...[
    '              E: meta-data (line=901)',
    '                A: $_ns:name(0x01010003)=${_str('android.support.FILE_PROVIDER_PATHS')}',
    '                A: $_ns:resource(0x01010025)=@$resourceId',
  ],
].join('\n');

String _pathsFile(List<String> children) =>
    ['E: paths (line=4)', for (final c in children) c].join('\n');

String _cachePath(String name, String path) =>
    '    E: cache-path (line=5)\n'
    '      A: name=${_str(name)}\n'
    '      A: path=${_str(path)}';

String _addXmlResource(_Dumps d, String id, String name, String file) {
  d.resources +=
      '\n    resource $id xml/$name\n      () (file) $file type=XML\n';
  return id;
}

// ─── Secretos en el paquete (f) ───────────────────────────────────────────────────────────────

/// Un zip con [entries] (ruta -> contenido) en [dir]; devuelve su ruta.
String _zip(Directory dir, String name, Map<String, List<int>> entries) {
  final staging = Directory('${dir.path}/staging_$name')..createSync();
  entries.forEach((path, bytes) {
    File('${staging.path}/$path')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  });
  final out = '${dir.path}/$name.zip';
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

String _googleKey() => 'AIza${'SyA-bcdefghijklmnopqrstuvwxyz012345'}';
String _awsKey() => 'AKIA${'IOSFODNN7EXAMPLE'}';
String _ghToken() => 'gh${'p'}_${'a1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8'}';
String _ghPat() => 'github_${'pat'}_${'11ABCDEFG0abcdefghij_klmnopqrstuvwx'}';
String _pem() => '-----BEGIN ${'RSA PRIVATE'} KEY-----';

List<int> _utf16le(String s) => [
  for (final u in s.codeUnits) ...[u & 0xff, u >> 8],
];

List<int> _text(String s) => utf8.encode(s);

String _findings(List<PackageIssue> issues) =>
    issues.map((i) => i.line).join('\n');

void main() {
  group('CA-020-22: la base (el APK de release de hoy)', () {
    test('CA-020-22: los volcados buenos no dan ningún hallazgo', () {
      expect(_Dumps.good().check(), isEmpty);
    });

    test('CA-020-22: el mínimo de Google Play es 36 en un único sitio', () {
      expect(playMinTargetSdk, 36);
    });
  });

  group('CA-020-22 (a): depurable o de solo pruebas', () {
    test('debuggable=true', () {
      final d = _Dumps.good()
        ..addApplicationAttr('$_ns:debuggable(0x0101000f)=true');
      _expectOnly(
        d.check(),
        'a',
        entryContains: _manifestEntry,
        messageContains: 'debuggable',
      );
    });

    test('testOnly=true', () {
      final d = _Dumps.good()
        ..addApplicationAttr('$_ns:testOnly(0x01010272)=true');
      _expectOnly(
        d.check(),
        'a',
        entryContains: _manifestEntry,
        messageContains: 'testOnly',
      );
    });

    test('debuggable=false explícito, no es un hallazgo', () {
      final d = _Dumps.good()
        ..addApplicationAttr('$_ns:debuggable(0x0101000f)=false');
      expect(d.check(), isEmpty);
    });

    test('debuggable por referencia a un bool true: se resuelve y falla', () {
      final d = _Dumps.good();
      d.resources += '\n  type bool id=01 entryCount=1\n    resource 0x7f010000 bool/dbg\n      () true\n';
      d.addApplicationAttr('$_ns:debuggable(0x0101000f)=@0x7f010000');
      _expectOnly(
        d.check(),
        'a',
        entryContains: _manifestEntry,
        messageContains: 'debuggable',
      );
    });

    test(
      'debuggable por referencia que no se puede resolver: falla cerrada',
      () {
        final d = _Dumps.good()
          ..addApplicationAttr('$_ns:debuggable(0x0101000f)=@0x01030007');
        _expectOnly(
          d.check(),
          'a',
          entryContains: _manifestEntry,
          messageContains: 'resolver',
        );
      },
    );
  });

  group('CA-020-22 (b): tráfico en claro y configuración de red', () {
    test('usesCleartextTraffic=true', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'usesCleartextTraffic(0x010104ec)=false',
          'usesCleartextTraffic(0x010104ec)=true',
        );
      _expectOnly(
        d.check(),
        'b',
        entryContains: _manifestEntry,
        messageContains: 'usesCleartextTraffic',
      );
    });

    test('usesCleartextTraffic ausente', () {
      final d = _Dumps.good()..manifestRemoveLine(':usesCleartextTraffic(');
      _expectOnly(
        d.check(),
        'b',
        entryContains: _manifestEntry,
        messageContains: 'usesCleartextTraffic',
      );
    });

    test('sin networkSecurityConfig', () {
      final d = _Dumps.good()..manifestRemoveLine(':networkSecurityConfig(');
      _expectOnly(
        d.check(),
        'b',
        entryContains: _manifestEntry,
        messageContains: 'networkSecurityConfig',
      );
    });

    test('cleartextTrafficPermitted=true en la base', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/8G.xml',
          'cleartextTrafficPermitted=false',
          'cleartextTrafficPermitted=true',
        );
      _expectOnly(
        d.check(),
        'b',
        entryContains: 'res/8G.xml',
        messageContains: 'cleartextTrafficPermitted',
      );
    });

    test('cualquier <domain-config>, aunque no permita tráfico en claro', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/8G.xml',
          '      A: cleartextTrafficPermitted=false',
          '      A: cleartextTrafficPermitted=false\n'
              '    E: domain-config (line=6)\n'
              '      A: cleartextTrafficPermitted=false\n'
              '      E: domain (line=7)\n'
              '        A: includeSubdomains=true',
        );
      _expectOnly(
        d.check(),
        'b',
        entryContains: 'res/8G.xml',
        messageContains: 'domain-config',
      );
    });

    test('certificados del usuario (<certificates src="user">)', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/8G.xml',
          '      A: cleartextTrafficPermitted=false',
          '      A: cleartextTrafficPermitted=false\n'
              '      E: trust-anchors (line=5)\n'
              '        E: certificates (line=6)\n'
              '          A: src="user" (Raw: "user")',
        );
      _expectOnly(
        d.check(),
        'b',
        entryContains: 'res/8G.xml',
        messageContains: 'certificados del usuario',
      );
    });

    test('trust-anchors solo del sistema: pasa', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/8G.xml',
          '      A: cleartextTrafficPermitted=false',
          '      A: cleartextTrafficPermitted=false\n'
              '      E: trust-anchors (line=5)\n'
              '        E: certificates (line=6)\n'
              '          A: src="system" (Raw: "system")',
        );
      expect(d.check(), isEmpty);
    });

    test('trust-anchors con un certificado propio de la app (@raw)', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/8G.xml',
          '      A: cleartextTrafficPermitted=false',
          '      A: cleartextTrafficPermitted=false\n'
              '      E: trust-anchors (line=5)\n'
              '        E: certificates (line=6)\n'
              '          A: src=@0x7f0f0000',
        );
      _expectOnly(
        d.check(),
        'b',
        entryContains: 'res/8G.xml',
        messageContains: 'src',
      );
    });

    test('anclas de depuración (<debug-overrides>)', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/8G.xml',
          '      A: cleartextTrafficPermitted=false',
          '      A: cleartextTrafficPermitted=false\n'
              '    E: debug-overrides (line=6)\n'
              '      E: trust-anchors (line=7)\n'
              '        E: certificates (line=8)\n'
              '          A: src="user" (Raw: "user")',
        );
      _expectOnly(
        d.check(),
        'b',
        entryContains: 'res/8G.xml',
        messageContains: 'debug-overrides',
      );
    });

    test('sin <base-config>', () {
      final d = _Dumps.good()
        ..addFile('res/8G.xml', 'E: network-security-config (line=3)');
      _expectOnly(
        d.check(),
        'b',
        entryContains: 'res/8G.xml',
        messageContains: 'base-config',
      );
    });
  });

  group('CA-020-22 (c): copia de seguridad y transferencia', () {
    test('sin fullBackupContent', () {
      final d = _Dumps.good()..manifestRemoveLine(':fullBackupContent(');
      _expectOnly(
        d.check(),
        'c',
        entryContains: _manifestEntry,
        messageContains: 'fullBackupContent',
      );
    });

    test('sin dataExtractionRules', () {
      final d = _Dumps.good()..manifestRemoveLine(':dataExtractionRules(');
      _expectOnly(
        d.check(),
        'c',
        entryContains: _manifestEntry,
        messageContains: 'dataExtractionRules',
      );
    });

    test('un backupAgent', () {
      final d = _Dumps.good()
        ..addApplicationAttr('$_ns:backupAgent(0x01010279)=${_str('x.Agent')}');
      _expectOnly(
        d.check(),
        'c',
        entryContains: _manifestEntry,
        messageContains: 'backupAgent',
      );
    });

    test('allowBackup distinto del esperado', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'allowBackup(0x01010280)=true',
          'allowBackup(0x01010280)=false',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: _manifestEntry,
        messageContains: 'allowBackup',
      );
    });

    test('una referencia que no apunta a ningún recurso', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'fullBackupContent(0x010104eb)=@0x7f0e0000',
          'fullBackupContent(0x010104eb)=@0x7f0e00aa',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: _manifestEntry,
        messageContains: 'resolver',
      );
    });

    test('Android 12+: falta una exclusión de la WebView en la nube', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/4j.xml',
          '        E: exclude (line=16)\n'
              '          A: domain="sharedpref" (Raw: "sharedpref")\n'
              '          A: path="WebViewChromiumPrefs.xml" (Raw: "WebViewChromiumPrefs.xml")\n',
          '',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: 'res/4j.xml',
        messageContains: 'WebViewChromiumPrefs.xml',
      );
    });

    test('Android 12+: la transferencia deja de llevar los adjuntos', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/4j.xml',
          'A: domain="file" (Raw: "file")',
          'A: domain="database" (Raw: "database")',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: 'res/4j.xml',
        messageContains: 'file',
      );
    });

    test('Android 12+: la nube deja de pedir copia cifrada', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/4j.xml',
          'A: disableIfNoEncryptionCapabilities=true',
          'A: disableIfNoEncryptionCapabilities=false',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: 'res/4j.xml',
        messageContains: 'disableIfNoEncryptionCapabilities',
      );
    });

    test('Android 9-11: una inclusión sin clientSideEncryption', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/xo.xml',
          '      A: requireFlags="clientSideEncryption" (Raw: "clientSideEncryption")\n',
          '',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: 'res/xo.xml',
        messageContains: 'requireFlags',
      );
    });

    test('Android 8: deja de excluir los dominios device_*', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/Qq.xml',
          'A: domain="device_sharedpref" (Raw: "device_sharedpref")',
          'A: domain="sharedpref" (Raw: "sharedpref")',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: 'res/Qq.xml',
        messageContains: 'device_sharedpref',
      );
    });

    test('una variante de recurso que no se espera (v31)', () {
      final d = _Dumps.good()
        ..resourcesSwap(
          '      (v28) (file) res/xo.xml type=XML',
          '      (v28) (file) res/xo.xml type=XML\n'
              '      (v31) (file) res/xo.xml type=XML',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: _manifestEntry,
        messageContains: 'v31',
      );
    });

    test('falta la variante v28', () {
      final d = _Dumps.good()
        ..resourcesSwap('      (v28) (file) res/xo.xml type=XML\n', '');
      _expectOnly(
        d.check(),
        'c',
        entryContains: _manifestEntry,
        messageContains: 'v28',
      );
    });

    test('un elemento que no es una regla dentro del archivo', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/Qq.xml',
          '    E: exclude (line=5)',
          '    E: backup-agent (line=4)\n    E: exclude (line=5)',
        );
      _expectOnly(
        d.check(),
        'c',
        entryContains: 'res/Qq.xml',
        messageContains: 'backup-agent',
      );
    });
  });

  group('CA-020-22 (d): proveedores y rutas del FileProvider', () {
    test('un <provider> exportado', () {
      final d = _Dumps.good()
        ..manifestInsertBefore(
          'E: uses-library',
          _pluginProvider(exported: 'true'),
        );
      _expectOnly(
        d.check(),
        'd',
        entryContains: _manifestEntry,
        messageContains: 'x.PluginProvider',
      );
    });

    test('un <provider> dentro de <queries> no es un proveedor de la app', () {
      final d = _Dumps.good()
        ..manifestInsertBefore(
          'E: intent (line=32)',
          '          E: provider (line=31)\n'
              '            A: $_ns:authorities(0x01010018)=${_str('x.otro')}',
        );
      expect(d.check(), isEmpty);
    });

    test('un <provider> sin exported', () {
      final d = _Dumps.good()
        ..manifestInsertBefore(
          'E: uses-library',
          _pluginProvider(exported: ''),
        );
      _expectOnly(
        d.check(),
        'd',
        entryContains: _manifestEntry,
        messageContains: 'x.PluginProvider',
      );
    });

    test('el FileProvider con una <root-path>', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/Md.xml',
          '    E: cache-path (line=5)',
          '    E: root-path (line=4)\n'
              '      A: name="r" (Raw: "r")\n'
              '      A: path="." (Raw: ".")\n'
              '    E: cache-path (line=5)',
        );
      _expectOnly(
        d.check(),
        'd',
        entryContains: 'res/Md.xml',
        messageContains: 'root-path',
      );
    });

    test('el FileProvider con una ruta más amplia (cache-path ".")', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/Md.xml',
          'A: path="import/" (Raw: "import/")',
          'A: path="." (Raw: ".")',
        );
      _expectOnly(
        d.check(),
        'd',
        entryContains: 'res/Md.xml',
        messageContains: 'cache-path',
      );
    });

    test('un external-path', () {
      final d = _Dumps.good()
        ..fileSwap(
          'res/Md.xml',
          'E: cache-path (line=5)',
          'E: external-path (line=5)',
        );
      _expectOnly(
        d.check(),
        'd',
        entryContains: 'res/Md.xml',
        messageContains: 'external-path',
      );
    });

    test(
      'un plugin con su propio FILE_PROVIDER_PATHS (otra ruta): se mira',
      () {
        final d = _Dumps.good();
        final id = _addXmlResource(
          d,
          '0x7f0e0009',
          'plugin_paths',
          'res/Pp.xml',
        );
        d
          ..addFile('res/Pp.xml', _pathsFile([_cachePath('docs', 'docs/')]))
          ..manifestInsertBefore(
            'E: uses-library',
            _pluginProvider(resourceId: id),
          );
        _expectOnly(
          d.check(),
          'd',
          entryContains: 'res/Pp.xml',
          messageContains: 'cache-path',
        );
      },
    );

    test('un plugin con la misma ruta de importación: la unión no cambia', () {
      final d = _Dumps.good();
      final id = _addXmlResource(d, '0x7f0e0009', 'plugin_paths', 'res/Pp.xml');
      d
        ..addFile('res/Pp.xml', _pathsFile([_cachePath('import', 'import/')]))
        ..manifestInsertBefore(
          'E: uses-library',
          _pluginProvider(resourceId: id),
        );
      expect(d.check(), isEmpty);
    });

    test('un FILE_PROVIDER_PATHS que no se puede resolver', () {
      final d = _Dumps.good()
        ..manifestInsertBefore(
          'E: uses-library',
          _pluginProvider(resourceId: '0x7f0e00bb'),
        );
      _expectOnly(
        d.check(),
        'd',
        entryContains: _manifestEntry,
        messageContains: 'resolver',
      );
    });

    test('ninguna ruta del FileProvider en todo el manifiesto', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'android.support.FILE_PROVIDER_PATHS',
          'android.support.OTHER',
        );
      _expectOnly(
        d.check(),
        'd',
        entryContains: _manifestEntry,
        messageContains: 'FILE_PROVIDER_PATHS',
      );
    });
  });

  group('CA-020-22 (e): minSdk y targetSdk', () {
    test('minSdk 24', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'minSdkVersion(0x0101020c)=26',
          'minSdkVersion(0x0101020c)=24',
        );
      _expectOnly(
        d.check(),
        'e',
        entryContains: _manifestEntry,
        messageContains: 'minSdkVersion',
      );
    });

    test('targetSdk 35 (por debajo del de Google Play)', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'targetSdkVersion(0x01010270)=36',
          'targetSdkVersion(0x01010270)=35',
        );
      _expectOnly(
        d.check(),
        'e',
        entryContains: _manifestEntry,
        messageContains: 'targetSdkVersion',
      );
    });

    test('targetSdk 37 pasa', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'targetSdkVersion(0x01010270)=36',
          'targetSdkVersion(0x01010270)=37',
        );
      expect(d.check(), isEmpty);
    });

    test('un targetSdk que no es un número', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'targetSdkVersion(0x01010270)=36',
          'targetSdkVersion(0x01010270)="VanillaIceCream" (Raw: "VanillaIceCream")',
        );
      _expectOnly(
        d.check(),
        'e',
        entryContains: _manifestEntry,
        messageContains: 'targetSdkVersion',
      );
    });

    test('sin <uses-sdk>', () {
      final d = _Dumps.good()..manifestSwap('E: uses-sdk', 'E: uses-sdk-fake');
      _expectOnly(
        d.check(),
        'e',
        entryContains: _manifestEntry,
        messageContains: 'uses-sdk',
      );
    });
  });

  group('CA-020-22 (g): ajustes de privacidad de hoy', () {
    test('MetricsOptOut a false', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'WebView.MetricsOptOut" (Raw: "android.webkit.WebView.MetricsOptOut")\n'
              '            A: $_ns:value(0x01010024)=true',
          'WebView.MetricsOptOut" (Raw: "android.webkit.WebView.MetricsOptOut")\n'
              '            A: $_ns:value(0x01010024)=false',
        );
      _expectOnly(
        d.check(),
        'g',
        entryContains: _manifestEntry,
        messageContains: 'MetricsOptOut',
      );
    });

    test('MetricsOptOut ausente', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'android.webkit.WebView.MetricsOptOut',
          'android.webkit.OtherThing',
        );
      expect(_of(d.check(), 'g'), isNotEmpty);
      _expectOnly(
        d.check(),
        'g',
        entryContains: _manifestEntry,
        messageContains: 'MetricsOptOut',
      );
    });

    test('MainActivity sin taskAffinity', () {
      final d = _Dumps.good()..manifestRemoveLine(':taskAffinity(');
      _expectOnly(
        d.check(),
        'g',
        entryContains: _manifestEntry,
        messageContains: 'taskAffinity',
      );
    });

    test('MainActivity con otra taskAffinity', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'taskAffinity(0x01010012)=""',
          'taskAffinity(0x01010012)="x.y" (Raw: "x.y")',
        );
      _expectOnly(
        d.check(),
        'g',
        entryContains: _manifestEntry,
        messageContains: 'taskAffinity',
      );
    });

    test('sin MainActivity', () {
      final d = _Dumps.good()
        ..manifestSwap(
          'invalid.pending.app.MainActivity',
          'invalid.pending.app.Other',
        );
      _expectOnly(
        d.check(),
        'g',
        entryContains: _manifestEntry,
        messageContains: 'MainActivity',
      );
    });
  });

  group('CA-020-22: falla cerrada con volcados que no se entienden', () {
    test('un manifiesto vacío o que no es un volcado', () {
      for (final text in ['', 'esto no es un volcado', 'Binary APK\n']) {
        final d = _Dumps.good()..manifest = text;
        final issues = d.check();
        expect(issues, isNotEmpty, reason: text);
        expect(issues.every((i) => i.rule == 'fault'), isTrue, reason: text);
        expect(issues.first.entry, _manifestEntry);
      }
    });

    test('una línea de atributo que no se entiende', () {
      final d = _Dumps.good()
        ..manifestSwap(
          '        A: $_ns:allowBackup(0x01010280)=true',
          '        A: sin-igual',
        );
      final issues = d.check();
      expect(issues, isNotEmpty);
      expect(issues.every((i) => i.rule == 'fault'), isTrue);
    });

    test('unos recursos que no se entienden', () {
      final d = _Dumps.good()..resources = '';
      final issues = d.check();
      expect(issues, isNotEmpty);
      expect(issues.every((i) => i.rule == 'fault'), isTrue);
    });

    test('un archivo de recursos sin volcado', () {
      final d = _Dumps.good()..files.remove('res/8G.xml');
      final issues = d.check();
      expect(_of(issues, 'fault'), isNotEmpty);
      expect(_of(issues, 'fault').first.entry, contains('res/8G.xml'));
    });

    test('un archivo de recursos con un volcado vacío', () {
      final d = _Dumps.good()..files['res/Qq.xml'] = '';
      final issues = d.check();
      expect(_of(issues, 'fault'), isNotEmpty);
      expect(_of(issues, 'fault').first.entry, contains('res/Qq.xml'));
    });
  });

  group(
    'CA-020-22 (c): el conjunto esperado es el de las reglas del código',
    () {
      // `test/app/backup_rules_test.dart` comprueba el comportamiento de estas reglas fuente (qué
      // entra en la copia y qué no); aquí se exige que lo que la herramienta espera del paquete
      // compilado sea exactamente lo que dicen esos mismos archivos.
      const res = 'android/app/src/main/res';

      /// Las reglas de un XML fuente, con el mismo formato que la herramienta: «ruta[atrib=valor,…]».
      List<String> normalize(String xml) {
        final body = xml
            .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
            .replaceAll(RegExp(r'<\?xml[^>]*\?>'), '');
        final out = <String>[];
        final stack = <String>[];
        for (final m in RegExp(
          r'<(/?)([A-Za-z][\w-]*)((?:\s+[\w:-]+="[^"]*")*)\s*(/?)>',
        ).allMatches(body)) {
          if (m.group(1) == '/') {
            stack.removeLast();
            continue;
          }
          final attrs = {
            for (final a in RegExp(
              r'([\w:-]+)="([^"]*)"',
            ).allMatches(m.group(3)!))
              a.group(1)!: a.group(2)!,
          };
          final path = [...stack, m.group(2)!].join('/');
          final sorted = attrs.keys.toList()..sort();
          out.add(
            '$path[${[for (final k in sorted) '$k=${attrs[k]}'].join(',')}]',
          );
          if (m.group(4) != '/') stack.add(m.group(2)!);
        }
        return out..sort();
      }

      String read(String p) => File('$res/$p').readAsStringSync();

      test(
        'CA-020-22: backup_rules (Android 8), v28 y data_extraction_rules',
        () {
          List<String> sorted(List<String> l) => [...l]..sort();
          expect(
            sorted(expectedBackupRules['backup_rules']![''] ?? []),
            normalize(read('xml/backup_rules.xml')),
          );
          expect(
            sorted(expectedBackupRules['backup_rules']!['v28'] ?? []),
            normalize(read('xml-v28/backup_rules.xml')),
          );
          expect(
            sorted(expectedBackupRules['data_extraction_rules']![''] ?? []),
            normalize(read('xml/data_extraction_rules.xml')),
          );
        },
      );

      test('CA-020-22: las variantes esperadas son exactamente estas', () {
        expect(expectedBackupRules.keys.toSet(), {
          'backup_rules',
          'data_extraction_rules',
        });
        expect(expectedBackupRules['backup_rules']!.keys.toSet(), {'', 'v28'});
        expect(expectedBackupRules['data_extraction_rules']!.keys.toSet(), {
          '',
        });
      });
    },
  );

  group('CA-020-22 (f): secretos en el paquete', () {
    final skip = !_hasTool('zip') || !_hasTool('unzip')
        ? 'zip/unzip no disponibles'
        : null;
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('check_package_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    /// Un paquete con un `classes.dex` y [entries].
    String pkg(Map<String, List<int>> entries) =>
        _zip(tmp, 'p', {'classes.dex': _text('dex\n035 sin nada'), ...entries});

    test('CA-020-22: un paquete limpio no da hallazgos', () {
      expect(scanSecrets(pkg({'a.txt': _text('hola')})), isEmpty);
    }, skip: skip);

    for (final (id, secret) in [
      ('clave privada PEM', _pem()),
      ('clave de API de Google', _googleKey()),
      ('clave de AWS', _awsKey()),
      ('token de GitHub', _ghToken()),
      ('token fino de GitHub', _ghPat()),
    ]) {
      test('CA-020-22: $id en un archivo (ASCII)', () {
        final issues = scanSecrets(
          pkg({'assets/x.bin': _text('antes $secret después')}),
        );
        expect(issues, hasLength(1), reason: _findings(issues));
        expect(issues.single.rule, 'f');
        expect(issues.single.entry, 'assets/x.bin');
        final line = issues.single.line;
        expect(line, contains('assets/x.bin'));
        expect(line, contains('(f)'));
        // Como mucho los 4 primeros caracteres del hallazgo.
        expect(line, isNot(contains(secret.substring(0, 9))), reason: line);
        expect(line, isNot(contains(secret.substring(secret.length - 6))));
      }, skip: skip);

      test('CA-020-22: $id en UTF-16LE (resources.arsc)', () {
        final issues = scanSecrets(
          pkg({
            'resources.arsc': [0, 1, ..._utf16le(secret), 7, 7],
          }),
        );
        expect(issues, hasLength(1), reason: _findings(issues));
        expect(issues.single.entry, 'resources.arsc');
        expect(issues.single.line, isNot(contains(secret.substring(0, 9))));
      }, skip: skip);

      test('CA-020-22: $id en UTF-16LE desalineado', () {
        final issues = scanSecrets(
          pkg({
            'resources.arsc': [9, ..._utf16le(secret)],
          }),
        );
        expect(issues, hasLength(1), reason: _findings(issues));
      }, skip: skip);

      test('CA-020-22: $id dentro de un jar anidado', () {
        final inner = File(
          _zip(tmp, 'inner', {'com/x/Y.class': _text('..$secret..')}),
        ).readAsBytesSync();
        final issues = scanSecrets(pkg({'lib/dep.jar': inner}));
        expect(issues, hasLength(1), reason: _findings(issues));
        expect(issues.single.entry, 'lib/dep.jar!com/x/Y.class');
        expect(issues.single.line, isNot(contains(secret.substring(0, 9))));
      }, skip: skip);
    }

    test(
      'CA-020-22: un secreto en un gzip (NOTICES.Z) se ve descomprimido',
      () {
        final gz = gzip.encode(_text('licencia ${_googleKey()} fin'));
        final issues = scanSecrets(pkg({'assets/NOTICES.Z': gz}));
        expect(issues, hasLength(1), reason: _findings(issues));
        expect(issues.single.entry, 'assets/NOTICES.Z');
      },
      skip: skip,
    );

    test('CA-020-22: dos secretos distintos en un archivo, dos hallazgos', () {
      final issues = scanSecrets(
        pkg({'a.bin': _text('${_googleKey()} ${_awsKey()}')}),
      );
      expect(issues, hasLength(2), reason: _findings(issues));
    }, skip: skip);

    test('CA-020-22: el mismo secreto repetido en un archivo, un hallazgo', () {
      final k = _awsKey();
      final issues = scanSecrets(pkg({'a.bin': _text('$k..$k..$k')}));
      expect(issues, hasLength(1), reason: _findings(issues));
    }, skip: skip);

    for (final name in [
      'release.jks',
      'x/y/upload.keystore',
      'cert.p12',
      'key.pk8',
      'chain.pem',
      'store.bks',
      'key.properties',
      'app/google-services.json',
      'UPPER.JKS',
    ]) {
      test('CA-020-22: un archivo de firma o de claves, «$name»', () {
        final issues = scanSecrets(pkg({name: _text('x')}));
        expect(issues, hasLength(1), reason: _findings(issues));
        expect(issues.single.rule, 'f');
        expect(issues.single.entry, name);
      }, skip: skip);
    }

    test('CA-020-22: un archivo de firma dentro de un zip anidado', () {
      final inner = File(_zip(tmp, 'inner', {'security/ca.pem': _text('x')}))
          .readAsBytesSync();
      final issues = scanSecrets(pkg({'lib/dep.jar': inner}));
      expect(issues, hasLength(1), reason: _findings(issues));
      expect(issues.single.entry, 'lib/dep.jar!security/ca.pem');
    }, skip: skip);

    test('CA-020-22: nombres parecidos que no son archivos de claves', () {
      final issues = scanSecrets(
        pkg({
          'a/jks.txt': _text('x'),
          'a/notakey.properties': _text('x'),
          'a/pem': _text('x'),
          'a/p12': _text('x'),
          'a/google-services.json.txt': _text('x'),
        }),
      );
      expect(issues, isEmpty, reason: _findings(issues));
    }, skip: skip);

    test('CA-020-22: una entrada con corchetes y asteriscos en el nombre', () {
      final issues = scanSecrets(
        pkg({'res/a[1]*?.txt': _text('x'), 'res/b.bin': _text(_awsKey())}),
      );
      expect(issues, hasLength(1), reason: _findings(issues));
      expect(issues.single.entry, 'res/b.bin');
    }, skip: skip);

    test('CA-020-22: un zip anidado demasiado hondo no se da por bueno', () {
      var inner = _text('nada');
      for (var i = 0; i < 8; i++) {
        inner = File(_zip(tmp, 'n$i', {'in.zip': inner})).readAsBytesSync();
      }
      final issues = scanSecrets(pkg({'deep.zip': inner}));
      expect(issues, isNotEmpty);
      expect(issues.first.line, contains('anidad'));
    }, skip: skip);

    test(
      'CA-020-22: un archivo que no es un zip es un fallo de la comprobación',
      () {
        final bad = File('${tmp.path}/bad.apk')
          ..writeAsStringSync('no soy un zip');
        final issues = scanSecrets(bad.path);
        expect(issues, hasLength(1));
        expect(issues.single.rule, 'fault');
        expect(issues.single.entry, contains('bad.apk'));
      },
      skip: skip,
    );

    group('lista de excepciones (tools/release/secret-allowlist.txt)', () {
      String allowLine(String entry, String rule, String text) =>
          '$entry\t$rule\t${sha256Hex(_text(text))}';

      test('CA-020-22: la excepción exacta (entrada, regla y suma) lo deja pasar', () {
        final k = _googleKey();
        final list = SecretAllowlist.parse(
          '# comentario\n\n${allowLine('assets/x.bin', 'google-api-key', k)}\n',
        );
        final issues = scanSecrets(
          pkg({'assets/x.bin': _text(k)}),
          allowlist: list,
        );
        expect(issues, isEmpty, reason: _findings(issues));
      }, skip: skip);

      test('CA-020-22: una excepción con otro sha256 no tapa el hallazgo', () {
        final k = _googleKey();
        final other = SecretAllowlist.parse(
          '${allowLine('assets/x.bin', 'google-api-key', '${k}x')}\n',
        );
        final issues = scanSecrets(
          pkg({'assets/x.bin': _text(k)}),
          allowlist: other,
        );
        expect(issues, hasLength(1), reason: _findings(issues));
        // Dice qué suma añadir para una excepción.
        expect(issues.single.sha256, sha256Hex(_text(k)));
      }, skip: skip);

      test(
        'CA-020-22: un secreto nuevo en la misma entrada no queda oculto',
        () {
          final k = _googleKey();
          final list = SecretAllowlist.parse(
            '${allowLine('assets/x.bin', 'google-api-key', k)}\n',
          );
          final issues = scanSecrets(
            pkg({'assets/x.bin': _text('$k ${_awsKey()}')}),
            allowlist: list,
          );
          expect(issues, hasLength(1), reason: _findings(issues));
          expect(issues.single.line, contains('AKIA'));
        },
        skip: skip,
      );

      test(
        'CA-020-22: la excepción de otra regla o de otra entrada no vale',
        () {
          final k = _googleKey();
          for (final line in [
            allowLine('assets/x.bin', 'aws-access-key', k),
            allowLine('assets/y.bin', 'google-api-key', k),
          ]) {
            final issues = scanSecrets(
              pkg({'assets/x.bin': _text(k)}),
              allowlist: SecretAllowlist.parse('$line\n'),
            );
            expect(issues, hasLength(1), reason: line);
          }
        },
        skip: skip,
      );

      test('CA-020-22: una excepción para un archivo de firma', () {
        final list = SecretAllowlist.parse(
          '${allowLine('certs/ca.pem', 'secret-file-name', 'certs/ca.pem')}\n',
        );
        expect(
          scanSecrets(pkg({'certs/ca.pem': _text('x')}), allowlist: list),
          isEmpty,
        );
      }, skip: skip);

      for (final bad in [
        'solo-una-columna',
        'a\tb',
        'a\tgoogle-api-key\tNOEShex',
        'a\tgoogle-api-key\t${'0' * 63}',
        'a\tgoogle-api-key\t${'A' * 64}',
        'a\tregla-inventada\t${'0' * 64}',
        '\tgoogle-api-key\t${'0' * 64}',
        'a\tgoogle-api-key\t${'0' * 64}\textra',
        '*\tgoogle-api-key\t${'0' * 64}',
        'a/*\tgoogle-api-key\t${'0' * 64}',
      ]) {
        test('CA-020-22: una línea mal formada no se acepta («$bad»)', () {
          expect(
            () => SecretAllowlist.parse('$bad\n'),
            throwsA(isA<FormatException>()),
          );
        });
      }
    });
  });

  group('sha256Hex', () {
    test('CA-020-22: vectores conocidos', () {
      expect(
        sha256Hex(<int>[]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex(_text('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        sha256Hex(
          _text('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
      // Más de un bloque (el relleno cae en el segundo).
      expect(
        sha256Hex(Uint8List.fromList(List.filled(1000, 0x61))),
        '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3',
      );
    });
  });

  group('CA-020-22: la herramienta entera (aapt2 de mentira y la real)', () {
    final skip = !_hasTool('zip') || !_hasTool('unzip') || !_hasTool('bash')
        ? 'zip/unzip/bash no disponibles'
        : null;
    late Directory tmp;
    setUp(
      () => tmp = Directory.systemTemp.createTempSync('check_package_cli_'),
    );
    tearDown(() => tmp.deleteSync(recursive: true));

    /// Un `aapt2` que sirve los volcados de [d] (escritos en una carpeta temporal).
    String fakeAapt2(_Dumps d) {
      final dir = Directory('${tmp.path}/dumps')..createSync();
      File('${dir.path}/manifest').writeAsStringSync(d.manifest);
      File('${dir.path}/resources').writeAsStringSync(d.resources);
      d.files.forEach((entry, text) {
        File('${dir.path}/${entry.replaceAll('/', '__')}')
            .writeAsStringSync(text);
      });
      final script = File('${tmp.path}/aapt2')
        ..writeAsStringSync('''#!/bin/sh
D="${dir.path}"
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

    ({int code, String out, String err}) run(List<String> args) {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runCheckPackage(args, out: out, err: err);
      return (code: code, out: '$out', err: '$err');
    }

    test('CA-020-22: volcados buenos y paquete limpio: código 0', () {
      final apk = _zip(tmp, 'ok', {'classes.dex': _text('dex')});
      final r = run(['--aapt2', fakeAapt2(_Dumps.good()), apk]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
      expect(r.out, contains('OK'));
    }, skip: skip);

    test(
      'CA-020-22: una regla rota: código 1 y el mensaje nombra regla y archivo',
      () {
        final d = _Dumps.good()
          ..fileSwap(
            'res/8G.xml',
            'cleartextTrafficPermitted=false',
            'cleartextTrafficPermitted=true',
          );
        final apk = _zip(tmp, 'bad', {'classes.dex': _text('dex')});
        final r = run(['--aapt2', fakeAapt2(d), apk]);
        expect(r.code, 1, reason: '${r.out}${r.err}');
        final text = '${r.out}${r.err}';
        expect(text, contains('::error::'));
        expect(text, contains('(b)'));
        expect(text, contains('res/8G.xml'));
        expect(text, contains(apk));
      },
      skip: skip,
    );

    test('CA-020-22: un secreto: código 1, sin imprimirlo entero', () {
      final secret = _googleKey();
      final apk = _zip(tmp, 'sec', {'assets/x.bin': _text(secret)});
      final r = run(['--aapt2', fakeAapt2(_Dumps.good()), apk]);
      expect(r.code, 1, reason: '${r.out}${r.err}');
      final text = '${r.out}${r.err}';
      expect(text, contains('(f)'));
      expect(text, contains('assets/x.bin'));
      expect(text, isNot(contains(secret.substring(0, 8))));
    }, skip: skip);

    test('CA-020-22: la lista de excepciones se lee del archivo dado', () {
      final secret = _googleKey();
      final apk = _zip(tmp, 'sec', {'assets/x.bin': _text(secret)});
      final allow = File('${tmp.path}/allow.txt')
        ..writeAsStringSync(
          'assets/x.bin\tgoogle-api-key\t${sha256Hex(_text(secret))}\n',
        );
      final r = run([
        '--aapt2',
        fakeAapt2(_Dumps.good()),
        '--allowlist',
        allow.path,
        apk,
      ]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
    }, skip: skip);

    test('CA-020-22: una lista de excepciones mal formada: código 1', () {
      final apk = _zip(tmp, 'ok', {'classes.dex': _text('dex')});
      final allow = File('${tmp.path}/allow.txt')..writeAsStringSync('mal\n');
      final r = run([
        '--aapt2',
        fakeAapt2(_Dumps.good()),
        '--allowlist',
        allow.path,
        apk,
      ]);
      expect(r.code, 1);
      expect('${r.out}${r.err}', contains('allow.txt'));
    }, skip: skip);

    test(
      'CA-020-22: sin paquetes, o uno que no existe: no se da por bueno',
      () {
        expect(run(['--aapt2', fakeAapt2(_Dumps.good())]).code, 2);
        final r = run([
          '--aapt2',
          fakeAapt2(_Dumps.good()),
          '${tmp.path}/no-existe.apk',
        ]);
        expect(r.code, 1);
        expect('${r.out}${r.err}', contains('no-existe.apk'));
      },
      skip: skip,
    );

    test('CA-020-22: un aapt2 que no existe: código 1', () {
      final apk = _zip(tmp, 'ok', {'classes.dex': _text('dex')});
      final r = run(['--aapt2', '${tmp.path}/nada/aapt2', apk]);
      expect(r.code, 1);
      expect('${r.out}${r.err}', contains('aapt2'));
    }, skip: skip);

    test('CA-020-22: un aapt2 que falla: es un fallo de la comprobación', () {
      final apk = _zip(tmp, 'ok', {'classes.dex': _text('dex')});
      final failing = File('${tmp.path}/aapt2')
        ..writeAsStringSync('#!/bin/sh\necho roto >&2\nexit 3\n');
      Process.runSync('chmod', ['+x', failing.path]);
      final r = run(['--aapt2', failing.path, apk]);
      expect(r.code, 1);
      expect('${r.out}${r.err}', contains('aapt2'));
    }, skip: skip);

    test('CA-020-22: argumentos desconocidos: código 2', () {
      expect(run(['--nada']).code, 2);
      expect(run(['--aapt2']).code, 2);
    });

    test('CA-020-22: el APK real de release (si está compilado) pasa', () {
      final aapt2 = findAapt2();
      final apks = Directory('build/app/outputs/flutter-apk').existsSync()
          ? Directory('build/app/outputs/flutter-apk')
                .listSync()
                .whereType<File>()
                .map((f) => f.path)
                .where((p) => RegExp(r'app-[\w-]+-release\.apk$').hasMatch(p))
                .toList()
          : <String>[];
      if (aapt2 == null || apks.isEmpty) {
        markTestSkipped('sin aapt2 o sin APK de release compilado');
        return;
      }
      final r = run([
        '--aapt2',
        aapt2,
        '--allowlist',
        '../tools/release/secret-allowlist.txt',
        apks.first,
      ]);
      expect(r.code, 0, reason: '${r.out}${r.err}');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('CA-020-22: la envoltura y la CI', () {
    test(
      'CA-020-22: tools/check-package.sh falla con un paquete inexistente',
      () {
        final r = Process.runSync('bash', [
          '../tools/check-package.sh',
          '/no/existe/app-x-release.apk',
        ]);
        expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
        expect('${r.stdout}${r.stderr}', contains('app-x-release.apk'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('CA-020-22: la lista de excepciones existe y empieza vacía', () {
      final lines = File('../tools/release/secret-allowlist.txt')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty && !l.startsWith('#'));
      expect(lines, isEmpty);
    });

    test('CA-020-22: ci.yml pasa la estática sobre el APK de release', () {
      final ci = File('../.github/workflows/ci.yml').readAsStringSync();
      expect(ci, contains('tools/check-package.sh'));
      // Después de compilar, en el trabajo de Android.
      expect(
        ci.indexOf('tools/check-package.sh'),
        greaterThan(ci.indexOf('flutter build apk --release --split-per-abi')),
      );
      expect(
        ci.indexOf('tools/check-package.sh'),
        lessThan(ci.indexOf('  ios:')),
      );
    });
  });
}
