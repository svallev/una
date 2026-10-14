// Estática MASTG del paquete de release (spec 020, CA-020-22; plan §3.3): falla si el APK o el AAB
// compilado se aparta de lo que la app promete en privacidad y seguridad. Mira el paquete, no el
// código fuente: lo que se distribuye es lo que cuenta.
//
//   dart run tool/check_package.dart [--aapt2 <ruta>] [--allowlist <archivo>] <apk|aab>...
//   dart run tool/check_package.dart [--aapt2 <ruta>] --package-name [--json <archivo>] <apk|aab>...
//   dart run tool/check_package.dart [--aapt2 <ruta>] --manifest-xml <archivo> <apk|aab>
//
// Lo normal es llamarla con `tools/check-package.sh`, que pasa los APK de release y la lista de
// excepciones (`tools/release/secret-allowlist.txt`). Usa `aapt2` (manifiesto, recursos y
// configuración de red), `unzip` (los secretos) y, para un AAB, `zip`; no instala nada ni usa la red.
//
// Las reglas (cada fallo nombra la regla, el archivo del paquete y el motivo):
//   (a) ni `debuggable` ni `testOnly` en `<application>`;
//   (b) `usesCleartextTraffic="false"`; la configuración de red resuelta solo tiene una
//       `<base-config cleartextTrafficPermitted="false">` con, si acaso, `<trust-anchors>` del
//       sistema: ningún `<domain-config>`, `<debug-overrides>` ni `<certificates src="user">`;
//   (c) `fullBackupContent` y `dataExtractionRules` presentes y resueltos, sin `backupAgent`, con
//       `allowBackup` igual al esperado y con exactamente las reglas de copia esperadas (las
//       variantes de cada recurso también son una lista exacta);
//   (d) ningún `<provider>` sin `exported="false"`, y la unión de todos los
//       `android.support.FILE_PROVIDER_PATHS` (también los de los plugins) es exactamente
//       `<cache-path name="import" path="import/">`;
//   (e) `minSdkVersion` = 26 y `targetSdkVersion` >= [playMinTargetSdk];
//   (f) ningún secreto con forma de clave (ASCII y UTF-16LE, en zips y jars anidados y en lo
//       comprimido con gzip) ni archivo de firma o de claves, salvo la lista de excepciones;
//   (g) `MetricsOptOut` de la WebView a `true` y `MainActivity` con `taskAffinity=""`.
//
// Todo atributo que sea una referencia (`@bool/…`, `@xml/…`) se resuelve con `aapt2 dump resources`;
// si no se puede, la regla falla. Falla cerrada: un volcado que no se entiende o un archivo que no
// se puede leer es un hallazgo (`fault`), nunca un verde.
//
// **El AAB (T-020-06, P-020-1).** Guarda el manifiesto y los recursos en formato *proto*, que
// `aapt2 dump` no lee igual que el binario del APK. Se reempaqueta su módulo `base/`
// (`manifest/AndroidManifest.xml` a la raíz, `resources.pb` y `res/`) como un APK *proto* temporal y
// se convierte con `aapt2 convert --output-format binary`: el volcado sale con el mismo formato que
// el de un APK y valen las mismas reglas. Un AAB con otro módulo que `base/` es un fallo, y los
// secretos se buscan en el archivo entero (también en `BUNDLE-METADATA/`).
//
// `--package-name` comprueba el *package name* (CA-020-03 f): ni el provisional `invalid.pending.*`
// ni un dominio reservado (la lista de la puerta de la identidad) son un fallo, sino un **aviso**
// de clase `provisional` (CA-020-05 b); lo mal formado, un fallo. `--json` escribe la lista con su
// clase, de forma atómica y al final (`complete: true`). `--manifest-xml` escribe el manifiesto
// como XML para `tools/check-android-permissions.sh --manifest`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'check_release_config.dart' show reservedHostReasons;

/// El `targetSdk` mínimo que acepta Google Play para apps nuevas y actualizaciones (Android 16,
/// API 36, desde el 31-08-2026; Q-020-3). Si Play lo sube, se cambia aquí y en ningún sitio más
/// (CL-020-13).
const playMinTargetSdk = 36;

/// El `minSdk` de la app (D12, Android 8).
const expectedMinSdk = 26;

/// El valor de `allowBackup` en el manifiesto (ADR-0004: la copia la gobiernan las reglas).
const expectedAllowBackup = true;

/// Cuántos zips o gzips caben uno dentro de otro; más hondo no se da por bueno.
const maxNestingDepth = 4;

/// Lo máximo que puede ocupar una entrada de gzip descomprimida (contra las bombas).
const maxInflatedBytes = 256 * 1024 * 1024;

const _androidNs = 'http://schemas.android.com/apk/res/android';

/// Un hallazgo: la regla (`a` a `g`, o `fault` si la comprobación no pudo hacerse), el archivo del
/// paquete y el motivo.
class PackageIssue {
  const PackageIssue(this.rule, this.entry, this.message, {this.sha256});

  final String rule;
  final String entry;
  final String message;

  /// En un posible secreto: la suma SHA-256 del texto encontrado, para la lista de excepciones.
  final String? sha256;

  /// «regla (x) · archivo: motivo».
  String get line {
    final label = rule == 'fault'
        ? 'fallo de la comprobación'
        : 'regla ($rule)';
    return '$label · $entry: $message${sha256 == null ? '' : ' [sha256 $sha256]'}';
  }

  @override
  String toString() => line;
}

// ─── El volcado de `aapt2 dump xmltree` ─────────────────────────────────────────────────────────

/// Un elemento del volcado: su nombre, sus atributos (por nombre local; los de otro espacio de
/// nombres que `android`, con su prefijo) y sus hijos.
class _Node {
  _Node(this.name, this.indent);

  final String name;
  final int indent;
  final Map<String, String> attrs = {};

  /// Los atributos que van sin espacio de nombres (`package`…), para volver a escribir el XML.
  final Set<String> plain = {};
  final List<_Node> children = [];

  Iterable<_Node> child(String n) => children.where((c) => c.name == n);

  /// Este elemento y todos sus descendientes, en orden de documento.
  Iterable<_Node> get all sync* {
    yield this;
    for (final c in children) {
      yield* c.all;
    }
  }
}

final _elementLine = RegExp(r'^(\s*)E: ([\w.:-]+) \(line=\d+\)\s*$');
final _attrLine = RegExp(r'^\s*A: (.+)$');
final _idSuffix = RegExp(r'\(0x[0-9a-fA-F]+\)$');
final _rawSuffix = RegExp(r'^"(.*)" \(Raw: "(.*)"\)$');

/// Interpreta un volcado de `aapt2 dump xmltree`. Lanza [FormatException] si no se entiende.
_Node _parseXmlTree(String dump) {
  _Node? root;
  final stack = <_Node>[];
  var number = 0;
  for (final raw in const LineSplitter().convert(dump)) {
    number++;
    if (raw.trim().isEmpty) continue;
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('N: ')) continue;
    final e = _elementLine.firstMatch(raw);
    if (e != null) {
      final node = _Node(e.group(2)!, e.group(1)!.length);
      while (stack.isNotEmpty && stack.last.indent >= node.indent) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        if (root != null) {
          throw FormatException('línea $number: más de un elemento raíz');
        }
        root = node;
      } else {
        stack.last.children.add(node);
      }
      stack.add(node);
      continue;
    }
    final a = _attrLine.firstMatch(raw);
    if (a != null && stack.isNotEmpty) {
      final text = a.group(1)!;
      final eq = text.indexOf('=');
      if (eq <= 0) throw FormatException('línea $number: atributo sin «=»');
      final left = text.substring(0, eq).replaceFirst(_idSuffix, '');
      final colon = left.lastIndexOf(':');
      // Los atributos de `android` por su nombre local; los de otro espacio, con su prefijo.
      final name = colon >= 0 && left.substring(0, colon) == _androidNs
          ? left.substring(colon + 1)
          : left;
      if (name.isEmpty) {
        throw FormatException('línea $number: atributo sin nombre');
      }
      stack.last.attrs[name] = _attrValue(text.substring(eq + 1), number);
      if (colon < 0) stack.last.plain.add(name);
      continue;
    }
    throw FormatException('línea $number: no se entiende «${_clip(trimmed)}»');
  }
  if (root == null) {
    throw const FormatException('el volcado no tiene ningún elemento');
  }
  return root;
}

String _attrValue(String value, int number) {
  if (!value.startsWith('"')) return value.trim();
  final m = _rawSuffix.firstMatch(value);
  if (m != null) return m.group(2)!;
  if (value.length >= 2 && value.endsWith('"')) {
    return value.substring(1, value.length - 1);
  }
  throw FormatException('línea $number: valor sin cerrar');
}

String _clip(String s) => s.length <= 60 ? s : '${s.substring(0, 59)}…';

// ─── El volcado de `aapt2 dump resources` ───────────────────────────────────────────────────────

/// Un valor de un recurso para una configuración (`()` es la de por defecto).
class _Variant {
  const _Variant(this.value, {this.file});

  final String value;

  /// La ruta dentro del paquete si es un archivo (`(file) res/Qq.xml type=XML`).
  final String? file;
}

class _Resource {
  _Resource(this.id, this.type, this.name);

  final String id;
  final String type;
  final String name;
  final Map<String, _Variant> variants = {};
}

final _resourceLine = RegExp(r'^\s*resource (0x[0-9a-fA-F]+) (\w+)/(\S+)\s*$');
final _variantLine = RegExp(r'^\s+\(([^)]*)\) (.*)$');
final _fileValue = RegExp(r'^\(file\) (\S+) type=\w+$');

class _ResourceTable {
  _ResourceTable._(this._byId);

  /// Interpreta `aapt2 dump resources`. Lanza [FormatException] si no tiene el aspecto de uno.
  factory _ResourceTable.parse(String dump) {
    final byId = <String, _Resource>{};
    var header = false;
    _Resource? current;
    for (final raw in const LineSplitter().convert(dump)) {
      if (raw.startsWith('Package name=')) header = true;
      final r = _resourceLine.firstMatch(raw);
      if (r != null) {
        current = _Resource(
          r.group(1)!.toLowerCase(),
          r.group(2)!,
          r.group(3)!,
        );
        byId[current.id] = current;
        continue;
      }
      final v = _variantLine.firstMatch(raw);
      if (v != null && current != null) {
        final rest = v.group(2)!;
        // `(v28) (file) res/xo.xml type=XML` o, en un valor simple, `() true`.
        final file = _fileValue.firstMatch(rest);
        current.variants[v.group(1)!] = file != null
            ? _Variant(rest, file: file.group(1))
            : _Variant(_unquote(rest));
      }
    }
    if (!header) {
      throw const FormatException(
        'el volcado de recursos no empieza como «aapt2 dump resources»',
      );
    }
    return _ResourceTable._(byId);
  }

  final Map<String, _Resource> _byId;

  _Resource? byId(String id) => _byId[id.toLowerCase()];

  /// El valor de [raw]: si es una referencia (`@0x7f…`), el del recurso (solo con una variante
  /// por defecto y que no sea un archivo); si no, el propio texto. `null` si no se puede.
  String? resolve(String raw, [int depth = 0]) {
    if (!raw.startsWith('@')) return raw;
    if (depth > 4) return null;
    final res = byId(raw.substring(1));
    if (res == null || res.variants.length != 1) return null;
    final v = res.variants['']; // la configuración por defecto
    if (v == null || v.file != null) return null;
    return resolve(v.value, depth + 1);
  }
}

String _unquote(String s) =>
    s.length >= 2 && s.startsWith('"') && s.endsWith('"')
    ? s.substring(1, s.length - 1)
    : s;

// ─── Las reglas de copia esperadas ──────────────────────────────────────────────────────────────

String _rule(String path, [Map<String, String> attrs = const {}]) {
  final keys = attrs.keys.toList()..sort();
  return '$path[${[for (final k in keys) '$k=${attrs[k]}'].join(',')}]';
}

List<String> _backupV26() => [
  _rule('full-backup-content'),
  for (final d in [
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ])
    _rule('full-backup-content/exclude', {'domain': d, 'path': '.'}),
];

List<String> _webViewExcludes(String parent) => [
  for (final p in ['AwOriginVisitLoggerPrefs.xml', 'WebViewChromiumPrefs.xml'])
    _rule('$parent/exclude', {'domain': 'sharedpref', 'path': p}),
];

List<String> _backupV28() => [
  _rule('full-backup-content'),
  _rule('full-backup-content/include', {
    'domain': 'root',
    'path': 'app_flutter/',
    'requireFlags': 'clientSideEncryption',
  }),
  _rule('full-backup-content/include', {
    'domain': 'sharedpref',
    'path': '.',
    'requireFlags': 'clientSideEncryption',
  }),
  ..._webViewExcludes('full-backup-content'),
];

List<String> _extraction() => [
  _rule('data-extraction-rules'),
  _rule('data-extraction-rules/cloud-backup', {
    'disableIfNoEncryptionCapabilities': 'true',
  }),
  _rule('data-extraction-rules/cloud-backup/include', {
    'domain': 'root',
    'path': 'app_flutter/',
  }),
  _rule('data-extraction-rules/cloud-backup/include', {
    'domain': 'sharedpref',
    'path': '.',
  }),
  ..._webViewExcludes('data-extraction-rules/cloud-backup'),
  _rule('data-extraction-rules/device-transfer'),
  _rule('data-extraction-rules/device-transfer/include', {
    'domain': 'root',
    'path': 'app_flutter/',
  }),
  _rule('data-extraction-rules/device-transfer/include', {
    'domain': 'sharedpref',
    'path': '.',
  }),
  _rule('data-extraction-rules/device-transfer/include', {
    'domain': 'file',
    'path': '.',
  }),
  ..._webViewExcludes('data-extraction-rules/device-transfer'),
];

/// Las reglas de copia que debe llevar el paquete (CA-020-22 c), por recurso y variante, en el
/// formato «ruta[atributo=valor,…]» (una por elemento, atributos ordenados). Son las mismas que
/// fija `test/app/backup_rules_test.dart` sobre los XML de `res/`: un test comprueba que coinciden
/// con ellos. Una variante que no está aquí (`v31`…) es un fallo.
final Map<String, Map<String, List<String>>> expectedBackupRules = {
  'backup_rules': {'': _backupV26(), 'v28': _backupV28()},
  'data_extraction_rules': {'': _extraction()},
};

/// La única ruta que puede declarar un FileProvider (la cámara, spec 007).
final String _expectedProviderPath = _rule('paths/cache-path', {
  'name': 'import',
  'path': 'import/',
});

// ─── Las reglas (a), (b), (c), (d), (e) y (g) ───────────────────────────────────────────────────

const _manifestEntry = 'AndroidManifest.xml';

/// Comprueba el manifiesto y los recursos que referencia. [manifest] es la salida de
/// `aapt2 dump xmltree --file AndroidManifest.xml`, [resources] la de `aapt2 dump resources` y
/// [xmlFile] devuelve la de `aapt2 dump xmltree --file <entrada>` (lanza si no se puede).
List<PackageIssue> checkPackageXml({
  required String manifest,
  required String resources,
  required String Function(String entry) xmlFile,
}) {
  final issues = <PackageIssue>[];
  final _Node root;
  final _ResourceTable table;
  try {
    root = _parseXmlTree(manifest);
    if (root.name != 'manifest') {
      throw FormatException('la raíz es «${root.name}», no «manifest»');
    }
  } on FormatException catch (e) {
    return [
      PackageIssue('fault', _manifestEntry, 'volcado ilegible: ${e.message}'),
    ];
  }
  try {
    table = _ResourceTable.parse(resources);
  } on FormatException catch (e) {
    return [
      PackageIssue('fault', 'resources.arsc', 'volcado ilegible: ${e.message}'),
    ];
  }

  final ctx = _Context(issues, table, xmlFile);
  final application = root.child('application').firstOrNull;
  if (application == null) {
    issues.add(
      const PackageIssue('fault', _manifestEntry, 'no hay <application>'),
    );
    return issues;
  }
  _checkDebuggable(ctx, application);
  _checkNetwork(ctx, application);
  _checkBackup(ctx, application);
  _checkProviders(ctx, root, application);
  _checkSdk(ctx, root);
  _checkPrivacySettings(ctx, application);
  return issues;
}

class _Context {
  _Context(this.issues, this.table, this.xmlFile);

  final List<PackageIssue> issues;
  final _ResourceTable table;
  final String Function(String entry) xmlFile;

  void add(String rule, String entry, String message) =>
      issues.add(PackageIssue(rule, entry, message));

  /// El valor de un atributo ya resuelto: `null` si falta; lanza [_Unresolved] si es una
  /// referencia que no se puede resolver.
  String? value(_Node node, String name) {
    final raw = node.attrs[name];
    if (raw == null) return null;
    final v = table.resolve(raw);
    if (v == null) throw _Unresolved(name, raw);
    return v;
  }

  /// El XML de un recurso por variante: `{configuración: (ruta, raíz)}`. Si no se puede, anota el
  /// motivo en [entry] con la regla [rule] y devuelve `null`.
  Map<String, (String, _Node)>? xmlVariants(
    String rule,
    String entry,
    String attribute,
    String raw,
  ) {
    if (!raw.startsWith('@')) {
      add(
        rule,
        entry,
        '$attribute no es una referencia a un recurso xml («$raw»): no se puede resolver',
      );
      return null;
    }
    final res = table.byId(raw.substring(1));
    if (res == null || res.type != 'xml') {
      add(
        rule,
        entry,
        '$attribute apunta a $raw, que no se puede resolver a un recurso xml',
      );
      return null;
    }
    final out = <String, (String, _Node)>{};
    for (final MapEntry(key: config, value: v) in res.variants.entries) {
      final file = v.file;
      if (file == null) {
        add(
          rule,
          entry,
          '$attribute (${res.name}, «$config») no es un archivo xml',
        );
        return null;
      }
      try {
        out[config] = (file, _parseXmlTree(xmlFile(file)));
      } on Object catch (e) {
        issues.add(
          PackageIssue(
            'fault',
            file,
            'no se pudo leer ${res.name} para $attribute: '
                '${e is FormatException ? e.message : e}',
          ),
        );
        return null;
      }
    }
    if (out.isEmpty) {
      add(
        rule,
        entry,
        '$attribute (${res.name}) no tiene ningún archivo: no se puede resolver',
      );
      return null;
    }
    return out;
  }
}

class _Unresolved implements Exception {
  _Unresolved(this.attribute, this.raw);

  final String attribute;
  final String raw;

  String get message =>
      '$attribute = $raw no se puede resolver con aapt2 dump resources';
}

/// Ejecuta [body] y anota como hallazgo de [rule] lo que no se pudo resolver.
void _guard(_Context ctx, String rule, String entry, void Function() body) {
  try {
    body();
  } on _Unresolved catch (e) {
    ctx.add(rule, entry, e.message);
  }
}

void _checkDebuggable(_Context ctx, _Node application) {
  for (final name in ['debuggable', 'testOnly']) {
    _guard(ctx, 'a', _manifestEntry, () {
      final v = ctx.value(application, name);
      if (v != null && v != 'false') {
        ctx.add(
          'a',
          _manifestEntry,
          '<application> con $name="$v": la app tiene que ser de release',
        );
      }
    });
  }
}

void _checkNetwork(_Context ctx, _Node application) {
  _guard(ctx, 'b', _manifestEntry, () {
    final cleartext = ctx.value(application, 'usesCleartextTraffic');
    if (cleartext != 'false') {
      ctx.add(
        'b',
        _manifestEntry,
        cleartext == null
            ? 'falta usesCleartextTraffic="false" en <application>'
            : 'usesCleartextTraffic="$cleartext" (tiene que ser false)',
      );
    }
  });
  final raw = application.attrs['networkSecurityConfig'];
  if (raw == null) {
    ctx.add(
      'b',
      _manifestEntry,
      'falta networkSecurityConfig en <application>',
    );
    return;
  }
  final variants = ctx.xmlVariants(
    'b',
    _manifestEntry,
    'networkSecurityConfig',
    raw,
  );
  if (variants == null) return;
  for (final (file, tree) in variants.values) {
    _checkNetworkConfig(ctx, file, tree);
  }
}

void _checkNetworkConfig(_Context ctx, String file, _Node tree) {
  void bad(String message) => ctx.add('b', file, message);
  if (tree.name != 'network-security-config') {
    bad('la raíz es <${tree.name}>, no <network-security-config>');
    return;
  }
  if (tree.attrs.isNotEmpty) {
    bad('atributos inesperados en <network-security-config>');
  }
  var bases = 0;
  for (final c in tree.children) {
    switch (c.name) {
      case 'base-config':
        bases++;
        _checkBaseConfig(c, bad);
      case 'domain-config':
        bad(
          '<domain-config> no permitido: la app no tiene excepciones por dominio',
        );
      case 'debug-overrides':
        bad('<debug-overrides> no permitido en el paquete de release');
      default:
        bad('elemento inesperado <${c.name}>');
    }
  }
  if (bases != 1) {
    bad('tiene que haber exactamente una <base-config> (hay $bases)');
  }
}

void _checkBaseConfig(_Node base, void Function(String) bad) {
  final cleartext = base.attrs['cleartextTrafficPermitted'];
  if (cleartext != 'false') {
    bad(
      cleartext == null
          ? '<base-config> sin cleartextTrafficPermitted="false"'
          : '<base-config cleartextTrafficPermitted="$cleartext"> (tiene que ser false)',
    );
  }
  for (final key in base.attrs.keys) {
    if (key != 'cleartextTrafficPermitted') {
      bad('atributo $key inesperado en <base-config>');
    }
  }
  for (final c in base.children) {
    if (c.name != 'trust-anchors') {
      bad('elemento <${c.name}> inesperado en <base-config>');
      continue;
    }
    if (c.attrs.isNotEmpty) bad('atributos inesperados en <trust-anchors>');
    for (final cert in c.children) {
      if (cert.name != 'certificates') {
        bad('elemento <${cert.name}> inesperado en <trust-anchors>');
        continue;
      }
      final src = cert.attrs['src'];
      if (src == 'user') {
        bad('<certificates src="user"> no permitido: certificados del usuario');
      } else if (src != 'system') {
        bad('<certificates src="${src ?? ''}">: solo se admite src="system"');
      }
      for (final key in cert.attrs.keys) {
        if (key != 'src') bad('atributo $key inesperado en <certificates>');
      }
      if (cert.children.isNotEmpty) {
        bad('elementos inesperados en <certificates>');
      }
    }
  }
}

/// Todas las reglas de [tree] como «ruta[atributo=valor,…]», ordenadas.
List<String> _normalizedRules(_Node tree) {
  final out = <String>[];
  void walk(_Node n, String path) {
    final p = path.isEmpty ? n.name : '$path/${n.name}';
    out.add(_rule(p, n.attrs));
    for (final c in n.children) {
      walk(c, p);
    }
  }

  walk(tree, '');
  return out..sort();
}

void _checkBackup(_Context ctx, _Node application) {
  _guard(ctx, 'c', _manifestEntry, () {
    final allow = ctx.value(application, 'allowBackup');
    if (allow != '$expectedAllowBackup') {
      ctx.add(
        'c',
        _manifestEntry,
        'allowBackup="${allow ?? 'ausente'}" (se espera $expectedAllowBackup)',
      );
    }
  });
  if (application.attrs.containsKey('backupAgent')) {
    ctx.add(
      'c',
      _manifestEntry,
      'backupAgent presente: la copia la gobiernan solo las reglas',
    );
  }
  for (final (attribute, resource) in [
    ('fullBackupContent', 'backup_rules'),
    ('dataExtractionRules', 'data_extraction_rules'),
  ]) {
    final raw = application.attrs[attribute];
    if (raw == null) {
      ctx.add('c', _manifestEntry, 'falta $attribute en <application>');
      continue;
    }
    final variants = ctx.xmlVariants('c', _manifestEntry, attribute, raw);
    if (variants == null) continue;
    final expected = expectedBackupRules[resource]!;
    for (final config in variants.keys) {
      if (!expected.containsKey(config)) {
        ctx.add(
          'c',
          _manifestEntry,
          '$attribute tiene una variante que no se espera («$config»)',
        );
      }
    }
    for (final config in expected.keys) {
      if (!variants.containsKey(config)) {
        ctx.add(
          'c',
          _manifestEntry,
          '$attribute no tiene la variante «${config.isEmpty ? 'por defecto' : config}» esperada',
        );
      }
    }
    for (final MapEntry(key: config, value: (file, tree)) in variants.entries) {
      final want = expected[config];
      if (want == null) continue;
      _compareRules(ctx, file, (List.of(want)..sort()), _normalizedRules(tree));
    }
  }
}

/// Anota lo que sobra y lo que falta entre [want] y [got] (listas ordenadas, con repeticiones).
void _compareRules(
  _Context ctx,
  String file,
  List<String> want,
  List<String> got,
) {
  final missing = List.of(want);
  final extra = <String>[];
  for (final g in got) {
    if (!missing.remove(g)) extra.add(g);
  }
  for (final r in missing) {
    ctx.add('c', file, 'falta la regla esperada $r');
  }
  for (final r in extra) {
    ctx.add('c', file, 'regla inesperada $r');
  }
}

void _checkProviders(_Context ctx, _Node root, _Node application) {
  // Los <provider> de <application> (un <queries><provider> solo declara qué se quiere ver).
  for (final p in application.children.where((n) => n.name == 'provider')) {
    final name = p.attrs['name'] ?? '(sin nombre)';
    _guard(ctx, 'd', _manifestEntry, () {
      final exported = ctx.value(p, 'exported');
      if (exported != 'false') {
        ctx.add(
          'd',
          _manifestEntry,
          '<provider> $name ${exported == null ? 'sin android:exported' : 'con exported="$exported"'} (tiene que ser false)',
        );
      }
    });
  }
  var seen = 0;
  for (final m in root.all.where(
    (n) =>
        n.name == 'meta-data' &&
        n.attrs['name'] == 'android.support.FILE_PROVIDER_PATHS',
  )) {
    seen++;
    final raw = m.attrs['resource'];
    if (raw == null) {
      ctx.add(
        'd',
        _manifestEntry,
        'FILE_PROVIDER_PATHS sin android:resource: no se puede resolver',
      );
      continue;
    }
    final variants = ctx.xmlVariants(
      'd',
      _manifestEntry,
      'FILE_PROVIDER_PATHS',
      raw,
    );
    if (variants == null) continue;
    for (final (file, tree) in variants.values) {
      if (tree.name != 'paths') {
        ctx.add('d', file, 'la raíz es <${tree.name}>, no <paths>');
        continue;
      }
      if (tree.children.isEmpty) {
        ctx.add(
          'd',
          file,
          'sin ninguna ruta: se esperaba $_expectedProviderPath',
        );
      }
      for (final c in tree.children) {
        final got = _rule('paths/${c.name}', c.attrs);
        if (c.children.isNotEmpty || got != _expectedProviderPath) {
          ctx.add(
            'd',
            file,
            c.name == 'root-path'
                ? 'ruta <root-path> no permitida: da acceso a todo el sistema de archivos'
                : 'ruta <${c.name}> no esperada: $got (solo $_expectedProviderPath, la de la cámara)',
          );
        }
      }
    }
  }
  if (seen == 0) {
    ctx.add(
      'd',
      _manifestEntry,
      'no hay ningún android.support.FILE_PROVIDER_PATHS: se esperaba $_expectedProviderPath',
    );
  }
}

void _checkSdk(_Context ctx, _Node root) {
  final sdk = root.child('uses-sdk').firstOrNull;
  if (sdk == null) {
    ctx.add(
      'e',
      _manifestEntry,
      'no hay <uses-sdk>: no se puede comprobar minSdkVersion ni targetSdkVersion',
    );
    return;
  }
  for (final (name, ok, want) in [
    ('minSdkVersion', (int v) => v == expectedMinSdk, '= $expectedMinSdk'),
    (
      'targetSdkVersion',
      (int v) => v >= playMinTargetSdk,
      '>= $playMinTargetSdk (mínimo de Google Play)',
    ),
  ]) {
    _guard(ctx, 'e', _manifestEntry, () {
      final raw = ctx.value(sdk, name);
      final n = raw == null ? null : int.tryParse(raw);
      if (n == null) {
        ctx.add(
          'e',
          _manifestEntry,
          '$name ${raw == null ? 'ausente' : '«$raw» no es un número'} (se espera $want)',
        );
      } else if (!ok(n)) {
        ctx.add('e', _manifestEntry, '$name = $n (se espera $want)');
      }
    });
  }
}

void _checkPrivacySettings(_Context ctx, _Node application) {
  const metrics = 'android.webkit.WebView.MetricsOptOut';
  final metaValues = <String>[];
  for (final m in application.children.where(
    (n) => n.name == 'meta-data' && n.attrs['name'] == metrics,
  )) {
    _guard(ctx, 'g', _manifestEntry, () {
      metaValues.add(ctx.value(m, 'value') ?? '');
    });
  }
  if (metaValues.isEmpty) {
    if (!ctx.issues.any((i) => i.rule == 'g')) {
      ctx.add(
        'g',
        _manifestEntry,
        'falta <meta-data> $metrics = true (P4: la WebView no envía métricas)',
      );
    }
  } else if (metaValues.any((v) => v != 'true')) {
    ctx.add(
      'g',
      _manifestEntry,
      '$metrics = ${metaValues.join(', ')} (tiene que ser true)',
    );
  }

  final mains = application.children.where((n) {
    if (n.name != 'activity') return false;
    final name = n.attrs['name'] ?? '';
    return name == 'MainActivity' || name.endsWith('.MainActivity');
  }).toList();
  if (mains.isEmpty) {
    ctx.add('g', _manifestEntry, 'no hay ninguna <activity> MainActivity');
  }
  for (final a in mains) {
    _guard(ctx, 'g', _manifestEntry, () {
      final affinity = ctx.value(a, 'taskAffinity');
      if (affinity != '') {
        ctx.add(
          'g',
          _manifestEntry,
          affinity == null
              ? 'MainActivity sin taskAffinity="" (ADR-0019: «Recientes»)'
              : 'MainActivity con taskAffinity="$affinity" (tiene que ser vacía)',
        );
      }
    });
  }
}

// ─── La regla (f): secretos ─────────────────────────────────────────────────────────────────────

class _SecretPattern {
  const _SecretPattern(this.id, this.label, this.regex);

  final String id;
  final String label;
  final String regex;
}

const _secretPatterns = <_SecretPattern>[
  _SecretPattern(
    'pem-private-key',
    'clave privada PEM',
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----',
  ),
  _SecretPattern(
    'google-api-key',
    'clave de API de Google',
    r'AIza[0-9A-Za-z_\-]{35}',
  ),
  _SecretPattern(
    'aws-access-key',
    'clave de acceso de AWS',
    r'AKIA[0-9A-Z]{16}',
  ),
  _SecretPattern(
    'github-token',
    'token de GitHub',
    r'gh[pousr]_[0-9A-Za-z]{36}',
  ),
  _SecretPattern(
    'github-pat',
    'token fino de GitHub',
    r'github_pat_[0-9A-Za-z_]{22,}',
  ),
];

const _fileNamePatternId = 'secret-file-name';

final _compiledPatterns = [
  for (final p in _secretPatterns) (p, RegExp(p.regex)),
];

/// Nombres de archivo de firma o de claves (en minúsculas).
final _secretFileName = RegExp(
  r'(\.(jks|keystore|p12|pk8|pem|bks)$)|(^(key\.properties|google-services\.json)$)',
);

/// La lista de excepciones de la regla (f): `entrada<TAB>regla<TAB>sha256 del texto encontrado`,
/// sin comodines (un secreto distinto en la misma entrada no queda oculto; CL-020-12).
class SecretAllowlist {
  SecretAllowlist._(this._keys);

  /// Interpreta [text]. Lanza [FormatException] (con el número de línea) si una línea no es
  /// «entrada TAB regla TAB sha256»: una excepción mal escrita no se ignora.
  factory SecretAllowlist.parse(String text) {
    final keys = <String>{};
    final ids = {for (final p in _secretPatterns) p.id, _fileNamePatternId};
    final hex = RegExp(r'^[0123456789abcdef]{64}$');
    final lines = const LineSplitter().convert(text);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final where = 'línea ${i + 1}';
      final cols = line.split('\t');
      if (cols.length != 3) {
        throw FormatException(
          '$where: se esperan 3 columnas separadas por tabulador',
        );
      }
      final [entry, rule, sha] = cols;
      if (entry.isEmpty) throw FormatException('$where: entrada vacía');
      if (RegExp(r'[*?\[\]]').hasMatch(entry)) {
        throw FormatException('$where: la entrada no admite comodines');
      }
      if (!ids.contains(rule)) {
        throw FormatException(
          '$where: regla desconocida «$rule» (${ids.join(', ')})',
        );
      }
      if (!hex.hasMatch(sha)) {
        throw FormatException(
          '$where: el sha256 son 64 caracteres hexadecimales en minúsculas',
        );
      }
      keys.add('$entry\t$rule\t$sha');
    }
    return SecretAllowlist._(keys);
  }

  /// Sin ninguna excepción.
  static final SecretAllowlist empty = SecretAllowlist._({});

  final Set<String> _keys;

  bool allows(String entry, String rule, String sha) =>
      _keys.contains('$entry\t$rule\t$sha');
}

/// SHA-256 de [bytes] en hexadecimal (`package:crypto` no es dependencia directa).
String sha256Hex(List<int> bytes) {
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  const mask = 0xffffffff;
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & mask;

  final h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final length = bytes.length;
  final padded = Uint8List(((length + 9 + 63) ~/ 64) * 64)
    ..setRange(0, length, bytes);
  padded[length] = 0x80;
  final bits = length * 8;
  for (var i = 0; i < 8; i++) {
    padded[padded.length - 1 - i] = (bits >> (8 * i)) & 0xff;
  }
  final w = List<int>.filled(64, 0);
  for (var block = 0; block < padded.length; block += 64) {
    for (var t = 0; t < 16; t++) {
      final o = block + t * 4;
      w[t] =
          (padded[o] << 24) |
          (padded[o + 1] << 16) |
          (padded[o + 2] << 8) |
          padded[o + 3];
    }
    for (var t = 16; t < 64; t++) {
      final s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
      final s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & mask;
    }
    var [a, b, c, d, e, f, g, hh] = h;
    for (var t = 0; t < 64; t++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & mask) & g);
      final t1 = (hh + s1 + ch + k[t] + w[t]) & mask;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & mask;
    }
    final next = [a, b, c, d, e, f, g, hh];
    for (var i = 0; i < 8; i++) {
      h[i] = (h[i] + next[i]) & mask;
    }
  }
  return [for (final x in h) x.toRadixString(16).padLeft(8, '0')].join();
}

/// Las cuatro primeras letras de [text], para que el aviso no lleve el secreto entero.
String _teaser(String text) =>
    '${text.substring(0, text.length < 4 ? text.length : 4)}…';

/// Los hallazgos de secretos en [packagePath] (un zip: APK o, después, AAB): cada entrada, los zips
/// y jars anidados y lo comprimido con gzip, leídos con `unzip`. Lo que [allowlist] cubre
/// exactamente (entrada, regla y suma) no se informa. Si el paquete no se puede leer es un
/// hallazgo `fault`.
List<PackageIssue> scanSecrets(
  String packagePath, {
  SecretAllowlist? allowlist,
}) {
  final issues = <PackageIssue>[];
  _scanArchive(
    packagePath,
    '',
    0,
    allowlist ?? SecretAllowlist.empty,
    issues,
    packagePath,
  );
  return issues;
}

String _escapeUnzipPattern(String name) =>
    name.replaceAllMapped(RegExp(r'[\\*?\[\]]'), (m) => '\\${m[0]}');

Uint8List _bytes(Object? out) =>
    out is Uint8List ? out : Uint8List.fromList((out as List).cast<int>());

void _scanArchive(
  String path,
  String prefix,
  int depth,
  SecretAllowlist allowlist,
  List<PackageIssue> issues,
  String label,
) {
  final shown = prefix.isEmpty ? label : prefix.substring(0, prefix.length - 1);
  final ProcessResult list;
  try {
    list = Process.runSync('unzip', ['-Z1', path], stdoutEncoding: utf8);
  } on ProcessException catch (e) {
    issues.add(
      PackageIssue('fault', shown, 'no se pudo ejecutar unzip (${e.message})'),
    );
    return;
  }
  if (list.exitCode != 0) {
    issues.add(
      PackageIssue(
        'fault',
        shown,
        'unzip -Z1 falló (código ${list.exitCode}): no es un zip legible',
      ),
    );
    return;
  }
  final names = const LineSplitter()
      .convert(list.stdout as String)
      .where((n) => n.isNotEmpty && !n.endsWith('/'))
      .toList();
  for (final name in names) {
    final entry = '$prefix$name';
    final base = name.split('/').last.toLowerCase();
    if (_secretFileName.hasMatch(base)) {
      _report(
        issues,
        allowlist,
        entry,
        _fileNamePatternId,
        name,
        'archivo de firma o de claves',
      );
    }
    final ProcessResult data;
    try {
      data = Process.runSync('unzip', [
        '-p',
        path,
        _escapeUnzipPattern(name),
      ], stdoutEncoding: null);
    } on ProcessException catch (e) {
      issues.add(
        PackageIssue(
          'fault',
          entry,
          'no se pudo ejecutar unzip (${e.message})',
        ),
      );
      continue;
    }
    if (data.exitCode != 0) {
      issues.add(
        PackageIssue(
          'fault',
          entry,
          'unzip -p falló (código ${data.exitCode})',
        ),
      );
      continue;
    }
    _scanContent(entry, _bytes(data.stdout), depth, allowlist, issues);
  }
}

void _scanContent(
  String entry,
  Uint8List bytes,
  int depth,
  SecretAllowlist allowlist,
  List<PackageIssue> issues,
) {
  // Un zip o un jar dentro del paquete: se abre, con un límite de profundidad.
  if (bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04) {
    if (depth + 1 > maxNestingDepth) {
      issues.add(
        PackageIssue(
          'f',
          entry,
          'archivo anidado a más de $maxNestingDepth niveles: no se puede comprobar',
        ),
      );
      return;
    }
    final dir = Directory.systemTemp.createTempSync('check_package_');
    try {
      final inner = File('${dir.path}/inner')..writeAsBytesSync(bytes);
      _scanArchive(inner.path, '$entry!', depth + 1, allowlist, issues, entry);
    } finally {
      dir.deleteSync(recursive: true);
    }
    return;
  }
  // Un gzip (NOTICES.Z): se ve también descomprimido, con un tope de tamaño.
  if (bytes.length >= 3 &&
      bytes[0] == 0x1f &&
      bytes[1] == 0x8b &&
      bytes[2] == 0x08) {
    final inflated = _inflate(bytes);
    if (inflated == null) {
      issues.add(
        PackageIssue(
          'f',
          entry,
          'gzip que se descomprime a más de ${maxInflatedBytes ~/ (1024 * 1024)} MB '
              'o dañado: no se puede comprobar',
        ),
      );
    } else {
      _scanContent(entry, inflated, depth, allowlist, issues);
    }
  }
  _scanBytes(entry, bytes, allowlist, issues);
}

/// Descomprime un gzip hasta [maxInflatedBytes]; `null` si lo pasa o está dañado.
Uint8List? _inflate(Uint8List gz) {
  final out = BytesBuilder();
  var total = 0;
  final decoder = gzip.decoder.startChunkedConversion(
    _CollectSink((chunk) {
      total += chunk.length;
      if (total > maxInflatedBytes) throw const _InflateLimit();
      out.add(chunk);
    }),
  );
  try {
    decoder
      ..add(gz)
      ..close();
  } on Object {
    return null;
  }
  return out.takeBytes();
}

class _InflateLimit implements Exception {
  const _InflateLimit();
}

class _CollectSink implements Sink<List<int>> {
  _CollectSink(this._onChunk);

  final void Function(List<int>) _onChunk;

  @override
  void add(List<int> data) => _onChunk(data);

  @override
  void close() {}
}

void _scanBytes(
  String entry,
  Uint8List bytes,
  SecretAllowlist allowlist,
  List<PackageIssue> issues,
) {
  if (bytes.isEmpty) return;
  // Tres vistas del contenido: bytes tal cual (ASCII y UTF-8) y UTF-16LE en las dos alineaciones
  // (resources.arsc guarda así sus cadenas).
  final views = <String>[String.fromCharCodes(bytes)];
  for (var offset = 0; offset < 2; offset++) {
    final units = (bytes.length - offset) ~/ 2;
    if (units < 8) continue;
    final codes = Uint16List(units);
    for (var i = 0; i < units; i++) {
      final o = offset + i * 2;
      codes[i] = bytes[o] | (bytes[o + 1] << 8);
    }
    views.add(String.fromCharCodes(codes));
  }
  final seen = <String>{};
  for (final view in views) {
    for (final (pattern, regex) in _compiledPatterns) {
      for (final m in regex.allMatches(view)) {
        final text = m.group(0)!;
        if (!seen.add('${pattern.id}\t$text')) continue;
        _report(issues, allowlist, entry, pattern.id, text, pattern.label);
      }
    }
  }
}

void _report(
  List<PackageIssue> issues,
  SecretAllowlist allowlist,
  String entry,
  String patternId,
  String text,
  String label,
) {
  final sha = sha256Hex(utf8.encode(text));
  if (allowlist.allows(entry, patternId, sha)) return;
  final isName = patternId == _fileNamePatternId;
  issues.add(
    PackageIssue(
      'f',
      entry,
      isName
          ? '$label (regla $patternId)'
          : 'posible $label («${_teaser(text)}», regla $patternId)',
      sha256: sha,
    ),
  );
}

// ─── aapt2 y la línea de órdenes ────────────────────────────────────────────────────────────────

/// El `aapt2` de las `build-tools` más nuevas de `$ANDROID_HOME` (o `$ANDROID_SDK_ROOT`, o las
/// carpetas habituales del SDK); `null` si no hay ninguno.
String? findAapt2() {
  final env = Platform.environment;
  final home = env['HOME'];
  final roots = [
    env['ANDROID_HOME'],
    env['ANDROID_SDK_ROOT'],
    if (home != null) '$home/Library/Android/sdk',
    if (home != null) '$home/Android/Sdk',
  ].whereType<String>().where((r) => r.isNotEmpty);
  for (final root in roots) {
    final dir = Directory('$root/build-tools');
    if (!dir.existsSync()) continue;
    final versions =
        dir
            .listSync()
            .whereType<Directory>()
            .where((d) => File('${d.path}/aapt2').existsSync())
            .toList()
          ..sort(
            (a, b) => _compareVersions(_baseName(b.path), _baseName(a.path)),
          );
    if (versions.isNotEmpty) return '${versions.first.path}/aapt2';
  }
  return null;
}

String _baseName(String path) => path.split(Platform.pathSeparator).last;

int _compareVersions(String a, String b) {
  final pa = a
      .split(RegExp(r'[.\-]'))
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final pb = b
      .split(RegExp(r'[.\-]'))
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

String _aapt(String aapt2, List<String> args) {
  final ProcessResult r;
  try {
    r = Process.runSync(
      aapt2,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException catch (e) {
    throw StateError('no se pudo ejecutar aapt2 (${e.message})');
  }
  if (r.exitCode != 0) {
    final detail = '${r.stderr}'.trim().split('\n').first;
    throw StateError(
      'aapt2 ${args.take(2).join(' ')} falló (código ${r.exitCode}): ${_clip(detail)}',
    );
  }
  return r.stdout as String;
}

// ─── El AAB: su módulo base como APK ────────────────────────────────────────────────────────────

/// Si [path] es un AAB (por su extensión).
bool isAab(String path) => path.toLowerCase().endsWith('.aab');

/// Las carpetas de primer nivel de un AAB que se esperan: `base/` (el único módulo) y los metadatos.
const _aabDirs = {'base', 'BUNDLE-METADATA', 'META-INF'};
const _aabConfig = 'BundleConfig.pb';

const _aabManifest = 'base/manifest/AndroidManifest.xml';
const _aabResourceTable = 'base/resources.pb';

/// Un paquete que `aapt2 dump` puede leer: el propio APK o, para un AAB, su módulo base convertido
/// a un APK binario en una carpeta temporal ([dispose] la borra).
class ReadablePackage {
  ReadablePackage._(this.path, [this._temp]);

  /// El APK que se pasa a `aapt2 dump`.
  final String path;
  final Directory? _temp;

  void dispose() {
    final t = _temp;
    if (t != null && t.existsSync()) t.deleteSync(recursive: true);
  }
}

String _runTool(String tool, List<String> args, {String? cwd}) {
  final ProcessResult r;
  try {
    r = Process.runSync(
      tool,
      args,
      workingDirectory: cwd,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException catch (e) {
    throw StateError('no se pudo ejecutar $tool (${e.message})');
  }
  if (r.exitCode != 0 && r.exitCode != 1 && r.exitCode != 11) {
    final detail = '${r.stderr}'.trim().split('\n').first;
    throw StateError(
      '$tool falló (código ${r.exitCode}${detail.isEmpty ? '' : ': ${_clip(detail)}'})',
    );
  }
  return r.stdout as String;
}

/// Prepara [package] para `aapt2 dump`. Lanza [StateError] con el motivo si no se puede (un AAB con
/// otro módulo que `base/`, sin manifiesto o sin tabla de recursos, ilegible, o `aapt2 convert`
/// que falla).
ReadablePackage openPackage(String package, String aapt2) {
  if (!isAab(package)) return ReadablePackage._(package);

  final listing = Process.runSync('unzip', [
    '-Z1',
    package,
  ], stdoutEncoding: utf8);
  if (listing.exitCode != 0) {
    throw StateError(
      'unzip -Z1 falló (código ${listing.exitCode}): no es un zip legible',
    );
  }
  final names = const LineSplitter()
      .convert(listing.stdout as String)
      .where((n) => n.isNotEmpty)
      .toList();
  // Solo `base/` como módulo: otra carpeta de primer nivel es un módulo más; un archivo suelto que no
  // sea `BundleConfig.pb`, una entrada inesperada.
  final modules = <String>{};
  final loose = <String>{};
  for (final name in names) {
    final slash = name.indexOf('/');
    if (slash < 0) {
      if (name != _aabConfig) loose.add(name);
    } else if (!_aabDirs.contains(name.substring(0, slash))) {
      modules.add(name.substring(0, slash));
    }
  }
  if (modules.isNotEmpty || loose.isNotEmpty) {
    throw StateError(
      [
        if (modules.isNotEmpty)
          'el AAB lleva un módulo distinto de base/ (${(modules.toList()..sort()).join(', ')}): '
              'esta herramienta solo lee el módulo base',
        if (loose.isNotEmpty)
          'el AAB lleva entradas inesperadas en la raíz (${(loose.toList()..sort()).join(', ')})',
      ].join('; '),
    );
  }
  for (final required in [_aabManifest, _aabResourceTable]) {
    if (!names.contains(required)) {
      throw StateError('el AAB no tiene $required');
    }
  }

  final temp = Directory.systemTemp.createTempSync('una_aab_');
  try {
    final extracted = '${temp.path}/x';
    _runTool('unzip', [
      '-q',
      '-o',
      '-d',
      extracted,
      package,
      _aabManifest,
      _aabResourceTable,
      'base/res/*',
    ]);
    final proto = Directory('${temp.path}/proto')..createSync();
    File('$extracted/$_aabManifest')
        .renameSync('${proto.path}/AndroidManifest.xml');
    File('$extracted/$_aabResourceTable')
        .renameSync('${proto.path}/resources.pb');
    final res = Directory('$extracted/base/res');
    if (res.existsSync()) res.renameSync('${proto.path}/res');
    final protoApk = '${temp.path}/proto.apk';
    _runTool('zip', ['-q', '-r', '-X', protoApk, '.'], cwd: proto.path);
    final binary = '${temp.path}/base.apk';
    _aapt(aapt2, [
      'convert',
      '--output-format',
      'binary',
      '-o',
      binary,
      protoApk,
    ]);
    return ReadablePackage._(binary, temp);
  } on Object {
    temp.deleteSync(recursive: true);
    rethrow;
  }
}

/// Todas las reglas sobre [package]: los volcados de `aapt2` y el escaneo de secretos.
List<PackageIssue> checkPackage(
  String package, {
  required String aapt2,
  SecretAllowlist? allowlist,
}) {
  final issues = <PackageIssue>[];
  ReadablePackage? readable;
  try {
    readable = openPackage(package, aapt2);
    final apk = readable.path;
    issues.addAll(
      checkPackageXml(
        manifest: _aapt(aapt2, [
          'dump',
          'xmltree',
          '--file',
          _manifestEntry,
          apk,
        ]),
        resources: _aapt(aapt2, ['dump', 'resources', apk]),
        xmlFile: (entry) =>
            _aapt(aapt2, ['dump', 'xmltree', '--file', entry, apk]),
      ),
    );
  } on StateError catch (e) {
    issues.add(PackageIssue('fault', package, e.message));
  } finally {
    readable?.dispose();
  }
  issues.addAll(scanSecrets(package, allowlist: allowlist));
  return issues;
}

// ─── El manifiesto como XML ─────────────────────────────────────────────────────────────────────

String _xmlEscape(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// El volcado de `aapt2 dump xmltree` del manifiesto, como XML: lo que lee
/// `tools/check-android-permissions.sh --manifest`. Los atributos de `android` llevan su prefijo, los
/// que no tienen espacio de nombres (`package`…) no, y los de otro espacio se escriben con `ext:`.
/// Lanza [FormatException] si el volcado no se entiende.
String manifestDumpToXml(String dump) {
  final root = _parseXmlTree(dump);
  final out = StringBuffer('<?xml version="1.0" encoding="utf-8"?>\n');
  void write(_Node n, int depth) {
    final pad = '  ' * depth;
    out.write('$pad<${n.name}');
    if (depth == 0) out.write(' xmlns:android="$_androidNs"');
    n.attrs.forEach((name, value) {
      final String shown;
      if (n.plain.contains(name)) {
        shown = name;
      } else if (name.contains(':')) {
        shown = 'ext:${name.substring(name.lastIndexOf(':') + 1)}';
      } else {
        shown = 'android:$name';
      }
      out.write(' $shown="${_xmlEscape(value)}"');
    });
    out.write('>\n');
    for (final c in n.children) {
      write(c, depth + 1);
    }
    out.write('$pad</${n.name}>\n');
  }

  write(root, 0);
  return out.toString();
}

/// El manifiesto de [package] como XML. Lanza [StateError] si no se puede leer.
String manifestXmlOf(String package, {required String aapt2}) {
  final readable = openPackage(package, aapt2);
  try {
    final dump = _aapt(aapt2, [
      'dump',
      'xmltree',
      '--file',
      _manifestEntry,
      readable.path,
    ]);
    try {
      return manifestDumpToXml(dump);
    } on FormatException catch (e) {
      throw StateError('el manifiesto no se entiende: ${e.message}');
    }
  } finally {
    readable.dispose();
  }
}

// ─── El package name (CA-020-03 f, CA-020-05 b) ─────────────────────────────────────────────────

/// Un hallazgo con clase, para el resumen del trabajo de publicación: `kind` es `provisional` (un
/// aviso de identidad, CA-020-05 b) o `fault`; [subject] es el paquete y [message] el motivo.
class ClassedIssue {
  const ClassedIssue(this.kind, this.subject, this.message);

  final String kind;
  final String subject;
  final String message;

  String get line => '$subject: $message';

  Map<String, Object?> toJson() => {
    'kind': kind,
    'subject': subject,
    'message': message,
  };

  @override
  String toString() => '$kind: $line';
}

final _applicationId = RegExp(
  r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
);

/// El prefijo del *package name* provisional (PD-2).
const provisionalPackagePrefix = 'invalid.pending.';

/// Los hallazgos del *package name* [id]: `provisional` si es el provisional (`invalid.pending.*`) o
/// su dominio, al revés, está reservado (lista de la puerta de la identidad); `fault` si no es un
/// *package name* de Android. Un fallo y un aviso no se mezclan: si hay un fallo, todo es fallo.
List<ClassedIssue> checkApplicationId(
  String id, {
  String subject = 'applicationId',
}) {
  if (!_applicationId.hasMatch(id)) {
    return [
      ClassedIssue(
        'fault',
        subject,
        'el package name "${_clip(id.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '?'))}" '
            'no es válido: dos o más segmentos de letras, cifras y «_», cada uno empezando por letra',
      ),
    ];
  }
  // El provisional ya lo explica todo (su primer segmento, `invalid`, es un sufijo reservado): un
  // solo aviso por paquete.
  if ('$id.'.startsWith(provisionalPackagePrefix)) {
    return [
      ClassedIssue(
        'provisional',
        subject,
        'el package name "$id" es el provisional (invalid.pending.*): '
            'no se puede cambiar después de la primera subida a Play (PD-2)',
      ),
    ];
  }
  final reasons = <String>[];
  final host = id.split('.').reversed.join('.').toLowerCase();
  reasons.addAll(
    reservedHostReasons(host)
        .map((r) => 'el package name "$id" usa un dominio reservado: $r'),
  );
  return [for (final r in reasons) ClassedIssue('provisional', subject, r)];
}

/// El `package` del manifiesto compilado de [package]. Lanza [StateError] si no se puede leer.
String applicationIdOf(String package, {required String aapt2}) {
  final readable = openPackage(package, aapt2);
  try {
    final dump = _aapt(aapt2, [
      'dump',
      'xmltree',
      '--file',
      _manifestEntry,
      readable.path,
    ]);
    final _Node root;
    try {
      root = _parseXmlTree(dump);
    } on FormatException catch (e) {
      throw StateError('el manifiesto no se entiende: ${e.message}');
    }
    final id = root.attrs['package'];
    if (root.name != 'manifest' || id == null) {
      throw StateError('el manifiesto no tiene el atributo package');
    }
    return id;
  } finally {
    readable.dispose();
  }
}

/// Escribe [issues] en [path] de forma atómica (archivo temporal + renombrado), con `complete: true`
/// y la lista de comprobaciones hechas: el resumen solo da por bueno un JSON completo.
void writeClassJson(
  String path,
  List<ClassedIssue> issues,
  List<String> checks,
) {
  final temp = File('$path.tmp');
  temp.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'complete': true,
      'checks': checks,
      'issues': [for (final i in issues) i.toJson()],
    }),
  );
  temp.renameSync(path);
}

const _usage =
    'Uso: dart run tool/check_package.dart [--aapt2 <ruta>] [--allowlist <archivo>] <apk|aab>...\n'
    '     dart run tool/check_package.dart [--aapt2 <ruta>] --package-name [--json <archivo>] <apk|aab>...\n'
    '     dart run tool/check_package.dart [--aapt2 <ruta>] --manifest-xml <archivo> <apk|aab>';

/// Ejecuta la herramienta. Devuelve el código de salida: 0 bien, 1 hallazgos o comprobación que no
/// pudo hacerse, 2 uso incorrecto. [out] y [err] son donde escribe (por defecto, la consola).
int runCheckPackage(List<String> args, {StringSink? out, StringSink? err}) {
  final o = out ?? stdout;
  final e = err ?? stderr;
  String? aapt2;
  String? allowlistPath;
  String? jsonPath;
  String? manifestXmlPath;
  var packageName = false;
  final packages = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--aapt2' ||
        a == '--allowlist' ||
        a == '--json' ||
        a == '--manifest-xml') {
      if (i + 1 >= args.length) {
        e.writeln('::error::$a necesita un valor\n$_usage');
        return 2;
      }
      final value = args[++i];
      switch (a) {
        case '--aapt2':
          aapt2 = value;
        case '--allowlist':
          allowlistPath = value;
        case '--json':
          jsonPath = value;
        default:
          manifestXmlPath = value;
      }
    } else if (a == '--package-name') {
      packageName = true;
    } else if (a.startsWith('--')) {
      e.writeln('::error::argumento desconocido: $a\n$_usage');
      return 2;
    } else {
      packages.add(a);
    }
  }
  if (packages.isEmpty) {
    e.writeln(
      '::error::no hay ningún paquete que comprobar (0 entradas es un fallo)\n$_usage',
    );
    return 2;
  }
  if (jsonPath != null && !packageName) {
    e.writeln('::error::--json solo vale con --package-name\n$_usage');
    return 2;
  }
  if (packageName && (manifestXmlPath != null || allowlistPath != null)) {
    e.writeln(
      '::error::--package-name no se mezcla con --manifest-xml ni --allowlist\n$_usage',
    );
    return 2;
  }
  if (manifestXmlPath != null &&
      (packages.length != 1 || allowlistPath != null)) {
    e.writeln(
      '::error::--manifest-xml pide exactamente un paquete y no admite --allowlist\n$_usage',
    );
    return 2;
  }

  final tool = aapt2 ?? findAapt2();
  final toolOk = tool != null && File(tool).existsSync();
  if (!toolOk) {
    final message =
        'no se encuentra aapt2${tool == null ? '' : ' ($tool)'}: instala las build-tools del SDK '
        'de Android o pásalo con --aapt2';
    if (packageName) {
      return _packageNameRun(packages, null, jsonPath, o, failAll: message);
    }
    o.writeln('::error::$message');
    return 1;
  }

  if (manifestXmlPath != null) {
    final package = packages.single;
    if (!File(package).existsSync()) {
      o.writeln('::error::No existe el paquete: $package');
      return 1;
    }
    try {
      final xml = manifestXmlOf(package, aapt2: tool);
      File(manifestXmlPath).writeAsStringSync(xml);
    } on StateError catch (ex) {
      o.writeln('::error::$package: ${ex.message}');
      return 1;
    } on FileSystemException catch (ex) {
      o.writeln(
        '::error::no se puede escribir $manifestXmlPath (${ex.osError?.message ?? ex.message})',
      );
      return 1;
    }
    return 0;
  }

  if (packageName) return _packageNameRun(packages, tool, jsonPath, o);

  var allowlist = SecretAllowlist.empty;
  if (allowlistPath != null) {
    try {
      allowlist = SecretAllowlist.parse(File(allowlistPath).readAsStringSync());
    } on FormatException catch (ex) {
      o.writeln('::error::$allowlistPath: ${ex.message}');
      return 1;
    } on FileSystemException catch (ex) {
      o.writeln(
        '::error::no se puede leer $allowlistPath (${ex.osError?.message ?? ex.message})',
      );
      return 1;
    }
  }

  var status = 0;
  for (final package in packages) {
    if (!File(package).existsSync()) {
      o.writeln('::error::No existe el paquete: $package');
      status = 1;
      continue;
    }
    final issues = checkPackage(package, aapt2: tool, allowlist: allowlist);
    if (issues.isEmpty) {
      o.writeln('OK $package: reglas (a) a (g) sin hallazgos');
      continue;
    }
    status = 1;
    for (final i in issues) {
      o.writeln('::error::$package: ${i.line}');
    }
    o.writeln(
      'La estática del paquete falla en $package (${issues.length}) '
      '(spec 020, CA-020-22).',
    );
  }
  return status;
}

/// `--package-name`: el *package name* de cada paquete. [failAll] (sin `aapt2`) hace fallar todos.
int _packageNameRun(
  List<String> packages,
  String? aapt2,
  String? jsonPath,
  StringSink o, {
  String? failAll,
}) {
  final issues = <ClassedIssue>[];
  for (final package in packages) {
    final subject = _baseName(package);
    if (failAll != null) {
      issues.add(ClassedIssue('fault', subject, failAll));
      continue;
    }
    if (!File(package).existsSync()) {
      issues.add(ClassedIssue('fault', subject, 'no existe el paquete'));
      continue;
    }
    try {
      final id = applicationIdOf(package, aapt2: aapt2!);
      issues.addAll(checkApplicationId(id, subject: subject));
    } on StateError catch (ex) {
      issues.add(ClassedIssue('fault', subject, ex.message));
    }
  }
  if (jsonPath != null) {
    try {
      writeClassJson(jsonPath, issues, ['package-name']);
    } on FileSystemException catch (ex) {
      o.writeln(
        '::error::no se puede escribir $jsonPath (${ex.osError?.message ?? ex.message})',
      );
      return 1;
    }
  }
  if (issues.isEmpty) {
    o.writeln(
      'OK package name de ${packages.length} paquete(s): propio y no reservado',
    );
    return 0;
  }
  for (final i in issues) {
    o.writeln('::error::${i.line}');
  }
  o.writeln(
    'El package name no sirve para publicar (${issues.length}) (spec 020, CA-020-03 f).',
  );
  return 1;
}

void main(List<String> args) {
  exit(runCheckPackage(args));
}
