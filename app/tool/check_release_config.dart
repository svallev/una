// Puerta de publicación (spec 012, CA-012-05; spec 015, CA-015-13b; spec 020, CA-020-05, 09 y 10):
// falla si alguna de las tres direcciones de `identity.yaml` (política de privacidad, licencias de
// terceros y ayuda) no sirve para publicar, si dos de ellas son la misma, o si el texto de la
// política sigue con huecos.
//
//   dart run tool/check_release_config.dart [--identity <archivo>] [--policy <archivo>]
//                                           [--json <archivo>]
//
// Sin argumentos lee `identity.yaml` y la política de `../docs/legal/privacy-policy.md` (se ejecuta
// desde `app/`; lo normal es llamarla con `tools/check-release-config.sh`, que además comprueba que
// lo generado desde el yaml está al día). Con una compilación de desarrollo o local NO se usa: los
// marcadores `https://example.com/…` son normales mientras se desarrolla.
//
// Cada dirección debe ser `https`, sin usuario, sin puerto, sin `?`, `#` ni `\`, con un dominio
// público solo ASCII (ni una IP ni `localhost`) que no sea un dominio reservado para ejemplos o
// pruebas ni un subdominio suyo, y con una ruta de letras ASCII, cifras, `.`, `_`, `~`, `-` y `/`
// (sin `%`, sin segmentos `.` o `..`, sin `//`). La regla de `https` + sin usuario es la de
// `privacyLink` (lib/domain/services/privacy_link.dart); no se importa porque arrastra
// `package:flutter` y `dart run` no tiene `dart:ui`: un test
// (`test/tool/check_release_config_test.dart`) comprueba que esta nunca es más permisiva, para las
// tres claves.
//
// Cada error lleva una clase ([GateIssueKind]) que usa el resumen del trabajo de publicación
// (CA-020-05): `placeholderAddress` y `policyGap` son avisos de identidad; `fault` (todo lo demás)
// falla en los dos modos. Si una misma clave tiene un aviso y un fallo, todos sus errores son
// `fault`. Con `--json <archivo>` se escribe además la lista de errores (de forma atómica y al
// final, con `complete: true`).
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// La clase de un error de la puerta (CA-020-05). Una lista cerrada: lo que no está aquí es `fault`.
enum GateIssueKind {
  /// Una dirección marcador o con un dominio reservado (aviso de identidad, CA-020-05 a).
  placeholderAddress,

  /// Un hueco sin rellenar en la política (aviso de identidad, CA-020-05 c).
  policyGap,

  /// Una marca de documento (`[Suposición]`…) en la política (aviso de identidad, CA-020-05 c).
  policyMark,

  /// Todo lo demás: falla en los dos modos.
  fault,
}

/// Un error de la puerta: su clase, de qué es (una clave de `identity.yaml`, un archivo…) y el motivo.
class GateIssue {
  const GateIssue(this.kind, this.subject, this.message);

  final GateIssueKind kind;

  /// La clave de `identity.yaml`, el archivo o la parte de la política a la que se refiere.
  final String subject;

  /// El motivo, sin el [subject] delante.
  final String message;

  /// El texto de una línea `::error::`: `<subject>: <message>`.
  String get line => '$subject: $message';

  GateIssue asFault() => kind == GateIssueKind.fault
      ? this
      : GateIssue(GateIssueKind.fault, subject, message);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'subject': subject,
    'message': message,
  };

  @override
  String toString() => '${kind.name}: $line';
}

/// Las claves de `identity.yaml` que son direcciones de una web.
const addressKeys = ['privacyPolicyUrl', 'thirdPartyLicensesUrl', 'helpUrl'];

/// Dominios reservados para ejemplos y plantillas (RFC 2606 / 6761 y la plantilla `yourdomain.com`),
/// con todos sus subdominios.
const _reservedDomains = [
  'example.com',
  'example.net',
  'example.org',
  'yourdomain.com',
  'home.arpa',
];

/// Sufijos reservados o de uso privado: cualquier dominio que termine en uno de ellos.
const _reservedTlds = [
  'example',
  'test',
  'invalid',
  'localhost',
  'local',
  'internal',
  'lan',
  'localdomain',
  'onion',
  // Usos privados habituales en redes internas, o infraestructura (`arpa`): ninguno sirve para una
  // web pública (CA-020-10).
  'alt',
  'home',
  'corp',
  'mail',
  'intranet',
  'private',
  'arpa',
];

/// TLD de prueba internacionalizados (IDN) de IANA, en *punycode*.
///
/// **[Hecho]** Contrastada con la tabla «Test IDN top-level domains» de
/// https://www.iana.org/domains/reserved el 2026-10-14: son exactamente estos 11 y ninguno está
/// delegado hoy en la raíz (https://data.iana.org/TLD/tlds-alpha-by-domain.txt, versión
/// 2026101400). Las equivalencias (T-020-01): `xn--kgbechtv` árabe, `xn--hgbk6aj7f53bba` persa,
/// `xn--0zwm56d` chino simplificado, `xn--g6w251d` chino tradicional, `xn--80akhbyknj4f` ruso,
/// `xn--11b5bs3a9aj6g` hindi, `xn--jxalpdlp` griego, `xn--9t4b11yi5a` coreano, `xn--deba0ad`
/// yidis, `xn--zckzah` japonés y `xn--hlcj6aya9esc7a` tamil.
const idnTestTldsSource = 'https://www.iana.org/domains/reserved';

/// La fecha en la que se contrastó [_idnTestTlds] con [idnTestTldsSource].
const idnTestTldsCheckedOn = '2026-10-14';

const _idnTestTlds = [
  'xn--0zwm56d',
  'xn--11b5bs3a9aj6g',
  'xn--80akhbyknj4f',
  'xn--9t4b11yi5a',
  'xn--deba0ad',
  'xn--g6w251d',
  'xn--hgbk6aj7f53bba',
  'xn--hlcj6aya9esc7a',
  'xn--jxalpdlp',
  'xn--kgbechtv',
  'xn--zckzah',
];

/// Huecos de la política sin rellenar, en la parte española y en la inglesa.
final _gap = RegExp(
  r'\[\s*(NOMBRE DE LA APP|FECHA|RESPONSABLE|CONTACTO|APP NAME|DATE|CONTROLLER|CONTACT)\s*\]',
  caseSensitive: false,
);

/// Los errores de [value] como dirección de la clave [key] (vacío = sirve para publicar). El
/// `subject` de cada uno es [key]. Una clave ausente, vacía o que no es texto es un `fault`. Si la
/// dirección tiene a la vez un aviso (dominio reservado) y un fallo, todos pasan a `fault`
/// (CA-020-05).
List<GateIssue> checkAddress(String key, Object? value) {
  if (value == null) {
    return [
      GateIssue(GateIssueKind.fault, key, 'la clave falta o no tiene valor'),
    ];
  }
  if (value is! String) {
    return [
      GateIssue(
        GateIssueKind.fault,
        key,
        'no es texto (es ${value.runtimeType})',
      ),
    ];
  }
  final issues = _addressIssues(key, value);
  return _escalate(issues);
}

/// Si algún error de [issues] es un `fault`, todos lo son: un aviso de identidad no puede
/// esconder un fallo de la misma dirección (CL-020-20).
List<GateIssue> _escalate(List<GateIssue> issues) =>
    issues.any((i) => i.kind == GateIssueKind.fault)
    ? [for (final i in issues) i.asFault()]
    : issues;

/// Los caracteres invisibles o de dirección que no pueden ir en una ruta (CA-020-09): U+200B,
/// U+200E/F, U+202A–E y U+2066–9.
bool _isInvisible(int c) =>
    c == 0x200B ||
    c == 0x200E ||
    c == 0x200F ||
    (c >= 0x202A && c <= 0x202E) ||
    (c >= 0x2066 && c <= 0x2069);

/// La ruta restringida de CA-020-09: vacía o `/` seguida de letras ASCII, cifras, `.`, `_`, `~`,
/// `-` y `/`.
final _allowedPath = RegExp(r'^(/[A-Za-z0-9._~\-/]*)?$');

/// Los motivos por los que [path] (el texto tal cual tras el dominio) no vale; vacío = vale. Se
/// mira el texto crudo, no `Uri`, que decodifica `%2e` y normaliza `..`.
List<String> _pathProblems(String path) {
  final problems = <String>[];
  if (path.codeUnits.any(_isInvisible)) {
    problems.add(
      'la ruta lleva caracteres invisibles o de dirección (U+200B, U+200E, U+202A…, U+2066…)',
    );
  }
  if (path.contains('%')) {
    problems.add(
      'la ruta lleva `%` (ni `%2e`, ni `%2f`, ni `%5c`, ni `%00`): la ruta no se codifica',
    );
  }
  if (path.split('/').any((s) => s == '.' || s == '..')) {
    problems.add('la ruta lleva un segmento `.` o `..`');
  }
  if (path.contains('//')) {
    problems.add('la ruta lleva una barra doble `//`');
  }
  if (problems.isEmpty && !_allowedPath.hasMatch(path)) {
    problems.add(
      'la ruta lleva caracteres que no son letras ASCII, cifras, `.`, `_`, `~`, `-` ni `/`',
    );
  }
  return problems;
}

List<GateIssue> _addressIssues(String key, String address) {
  GateIssue fault(String message) =>
      GateIssue(GateIssueKind.fault, key, message);
  GateIssue placeholder(String message) =>
      GateIssue(GateIssueKind.placeholderAddress, key, message);

  final trimmed = address.trim();
  if (trimmed.isEmpty) return [fault('la dirección está vacía')];
  if (trimmed.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
    return [
      fault('la dirección "$trimmed" lleva espacios o caracteres de control'),
    ];
  }
  final forbidden = [
    for (final c in ['?', '#', r'\'])
      if (trimmed.contains(c)) '`$c`',
  ];
  if (forbidden.isNotEmpty) {
    return [
      fault(
        'la dirección "$trimmed" lleva ${forbidden.join(', ')}: '
        'ni consulta, ni fragmento, ni barra invertida',
      ),
    ];
  }
  final scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):').firstMatch(trimmed);
  if (scheme == null || scheme.group(1)!.toLowerCase() != 'https') {
    return [fault('la dirección "$trimmed" no es https')];
  }
  // El dominio y la ruta se miran en el texto tal cual, no en `Uri`: `Uri.parse` decodifica `%6d`
  // a `m`, convierte un nombre no ASCII en `%C3%B1…` y normaliza un `:443` explícito.
  final parts = RegExp(r'^[^:]*://([^/]*)(.*)$').firstMatch(trimmed);
  final authority = parts?.group(1);
  if (authority == null || authority.isEmpty) {
    return [fault('la dirección "$trimmed" no tiene dominio')];
  }
  final issues = <GateIssue>[];
  if (authority.contains('@')) {
    issues.add(
      fault(
        'la dirección "$trimmed" lleva usuario (`usuario@`), que disfraza el dominio',
      ),
    );
  }
  final hostPort = authority.substring(authority.lastIndexOf('@') + 1);
  final hasPort = hostPort.startsWith('[')
      ? hostPort.contains(']:')
      : hostPort.contains(':');
  if (hasPort) {
    issues.add(
      fault('la dirección "$trimmed" lleva puerto: la web va en el 443'),
    );
  }
  if (authority.codeUnits.any((c) => c > 0x7f)) {
    issues.add(
      fault(
        'el dominio de "$trimmed" lleva caracteres que no son ASCII: un nombre '
        'internacional va en punycode (`xn--…`)',
      ),
    );
  }
  if (authority.contains('%')) {
    issues.add(
      fault('el dominio de "$trimmed" lleva `%`: un dominio no se codifica'),
    );
  }
  for (final problem in _pathProblems(parts!.group(2)!)) {
    issues.add(fault('la dirección "$trimmed": $problem'));
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return [...issues, fault('la dirección "$trimmed" no se puede leer')];
  }
  // Normaliza como el navegador: minúsculas y sin el punto final (`example.com.`).
  var host = uri.host.toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  if (host.isEmpty) {
    return [...issues, fault('la dirección "$trimmed" no tiene dominio')];
  }

  final labels = host.split('.');
  final last = labels.last;
  if (InternetAddress.tryParse(host) != null ||
      RegExp(r'^[0-9]+$').hasMatch(last) ||
      last.startsWith('0x')) {
    issues.add(fault('el dominio "$host" es una IP, no un dominio'));
  } else if (host == 'localhost' || host.endsWith('.localhost')) {
    issues.add(
      placeholder('el dominio "$host" es local (`localhost`), reservado'),
    );
  } else if (labels.length < 2) {
    issues.add(
      fault('el dominio "$host" no tiene punto: no es un dominio público'),
    );
  } else {
    for (final reserved in _reservedDomains) {
      if (host == reserved || host.endsWith('.$reserved')) {
        issues.add(
          placeholder(
            'el dominio "$host" está reservado para ejemplos ($reserved y sus subdominios): '
            'cámbialo por el definitivo',
          ),
        );
      }
    }
    if (_reservedTlds.contains(last)) {
      issues.add(
        placeholder(
          'el dominio "$host" termina en `.$last`, reservado para ejemplos, pruebas o uso privado',
        ),
      );
    }
    if (_idnTestTlds.contains(last)) {
      issues.add(
        placeholder(
          'el dominio "$host" termina en `.$last`, un dominio internacional de pruebas de IANA',
        ),
      );
    }
  }
  return issues;
}

/// La identidad de una dirección para compararlas: dominio (en minúsculas, sin el punto final) y
/// ruta (sin `..` ni la barra final, de modo que `/privacy` y `/privacy/` coinciden), o `null` si
/// no se puede leer.
String? _sameAddress(String address) {
  final uri = Uri.tryParse(address.trim());
  if (uri == null || uri.host.isEmpty) return null;
  var host = uri.host.toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  var path = uri.normalizePath().path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return '$host$path';
}

/// Los errores de las direcciones de [values] (clave → valor): los de cada una y las que coinciden
/// entre sí (CA-015-13b: tres webs distintas). Una repetida es un `fault`, y sus claves no
/// conservan ningún aviso suelto (CA-020-05).
List<GateIssue> checkAddresses(Map<String, Object?> values) {
  final issues = <GateIssue>[
    for (final e in values.entries) ...checkAddress(e.key, e.value),
  ];
  final byAddress = <String, List<String>>{};
  for (final e in values.entries) {
    final value = e.value;
    if (value is! String || value.trim().isEmpty) continue;
    final id = _sameAddress(value);
    if (id != null) (byAddress[id] ??= []).add(e.key);
  }
  final repeated = <String>{};
  for (final e in byAddress.entries) {
    if (e.value.length > 1) {
      repeated.addAll(e.value);
      issues.add(
        GateIssue(
          GateIssueKind.fault,
          e.value.join(' y '),
          'son la misma dirección (${e.key}); cada web tiene la suya',
        ),
      );
    }
  }
  return [
    for (final i in issues) repeated.contains(i.subject) ? i.asFault() : i,
  ];
}

/// Los errores del contenido de `identity.yaml` ([root] es lo que devuelve `loadYaml`): las tres
/// direcciones (ausentes, vacías o que no son texto incluidas) y que sean distintas.
List<GateIssue> checkIdentity(Object? root) {
  if (root is! Map) {
    return [
      GateIssue(
        GateIssueKind.fault,
        'identity.yaml',
        'la raíz no es un mapa de claves (clave: valor)',
      ),
    ];
  }
  return checkAddresses({for (final key in addressKeys) key: root[key]});
}

/// Los huecos que quedan en el texto publicado de la política ([text] es el archivo
/// entero). Solo cuentan la parte española (`# Política de privacidad (ES)`) y la
/// inglesa (`# Privacy policy (EN)`); la cabecera y las notas de revisión, que citan los
/// huecos, no. Vacío = sin huecos. Un hueco es `policyGap`; no encontrar las dos partes, `fault`.
List<GateIssue> checkPolicyText(String text) {
  final es = RegExp(
    r'^#\s+Política de privacidad \(ES\)',
    multiLine: true,
  ).firstMatch(text);
  final en = RegExp(
    r'^#\s+Privacy policy \(EN\)',
    multiLine: true,
  ).firstMatch(text);
  if (es == null || en == null || en.start < es.start) {
    return [
      GateIssue(
        GateIssueKind.fault,
        'política',
        'no se encuentran, en ese orden, "# Política de privacidad (ES)" y "# Privacy policy (EN)"',
      ),
    ];
  }
  final notes = RegExp(
    r'^##\s+Notas para la revisión',
    multiLine: true,
  ).firstMatch(text.substring(en.start));
  final end = notes == null ? text.length : en.start + notes.start;

  final issues = <GateIssue>[];
  for (final (label, start, stop) in [
    ('ES', es.start, en.start),
    ('EN', en.start, end),
  ]) {
    final found =
        <
          String,
          (String, int, int)
        >{}; // clave normalizada → (texto, veces, línea)
    for (final m in _gap.allMatches(text.substring(start, stop))) {
      final key = m.group(1)!.toUpperCase();
      final line =
          '\n'.allMatches(text.substring(0, start + m.start)).length + 1;
      final (shown, count, first) = found[key] ?? (m.group(0)!, 0, line);
      found[key] = (shown, count + 1, first);
    }
    for (final (shown, count, first) in found.values) {
      issues.add(
        GateIssue(
          GateIssueKind.policyGap,
          'política ($label)',
          'sigue con el hueco $shown ($count×, primera vez en la línea $first)',
        ),
      );
    }
  }
  return issues;
}

Never _usage(String message) {
  stderr.writeln('::error::$message');
  stderr.writeln(
    'Uso: dart run tool/check_release_config.dart [--identity <archivo>] '
    '[--policy <archivo>] [--json <archivo>]',
  );
  exit(2);
}

/// Escribe [issues] en [path] de forma atómica (archivo temporal en la misma carpeta + renombrado),
/// con `complete: true`: el resumen del trabajo de publicación solo da por bueno un JSON completo.
void _writeJson(String path, List<GateIssue> issues, List<String> checks) {
  final target = File(path);
  final temp = File('$path.tmp');
  temp.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'complete': true,
      'checks': checks,
      'issues': [for (final i in issues) i.toJson()],
    }),
  );
  temp.renameSync(target.path);
}

void main(List<String> args) {
  var identityPath = 'identity.yaml';
  var policyPath = '../docs/legal/privacy-policy.md';
  String? jsonPath;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--identity':
        if (++i >= args.length) _usage('--identity necesita un valor');
        identityPath = args[i];
      case '--policy':
        if (++i >= args.length) _usage('--policy necesita un valor');
        policyPath = args[i];
      case '--json':
        if (++i >= args.length) _usage('--json necesita un valor');
        jsonPath = args[i];
      default:
        _usage('argumento desconocido: ${args[i]}');
    }
  }

  final identity = File(identityPath);
  if (!identity.existsSync()) {
    _usage('no existe $identityPath (¿se ejecuta desde app/?); usa --identity');
  }
  final checks = ['addresses', 'policy'];
  final List<GateIssue> addressIssues;
  try {
    addressIssues = checkIdentity(loadYaml(identity.readAsStringSync()));
  } on YamlException catch (e) {
    final issue = GateIssue(
      GateIssueKind.fault,
      'identity.yaml',
      'no se puede leer (${e.message})',
    );
    stdout.writeln('::error::${issue.line}');
    if (jsonPath != null) _writeJson(jsonPath, [issue], checks);
    exit(1);
  }

  final policy = File(policyPath);
  final issues = <GateIssue>[
    ...addressIssues,
    if (policy.existsSync())
      ...checkPolicyText(policy.readAsStringSync())
    else
      GateIssue(GateIssueKind.fault, policyPath, 'no existe la política'),
  ];

  if (jsonPath != null) _writeJson(jsonPath, issues, checks);

  if (issues.isEmpty) {
    stdout.writeln(
      'OK las tres direcciones (${addressKeys.join(', ')}) y el texto de la '
      'política sin huecos',
    );
    return;
  }
  for (final i in issues) {
    stdout.writeln('::error::${i.line}');
  }
  stdout.writeln(
    'La puerta de publicación falla (${issues.length}): no publicar esta versión '
    '(spec 012, CA-012-05; spec 015, CA-015-13b; spec 020, CA-020-09 y 10).',
  );
  exit(1);
}
