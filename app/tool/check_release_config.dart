// Puerta de publicación (spec 012, CA-012-05; spec 015, CA-015-13b): falla si alguna de las
// tres direcciones de `identity.yaml` (política de privacidad, licencias de terceros y ayuda)
// no sirve para publicar, si dos de ellas son la misma, o si el texto de la política sigue con huecos.
//
//   dart run tool/check_release_config.dart [--identity <archivo>] [--policy <archivo>]
//
// Sin argumentos lee `identity.yaml` y la política de `../docs/legal/privacy-policy.md` (se ejecuta
// desde `app/`; lo normal es llamarla con `tools/check-release-config.sh`, que además comprueba que
// lo generado desde el yaml está al día). Con una compilación de desarrollo o local NO se usa: los
// marcadores `https://example.com/…` son normales mientras se desarrolla.
//
// Cada dirección debe ser `https`, sin usuario, sin puerto, sin `?`, `#` ni `\`, con un dominio
// público solo ASCII (ni una IP ni `localhost`) y que no sea un dominio reservado para ejemplos o
// pruebas ni un subdominio suyo. La regla de `https` + sin usuario es la de `privacyLink`
// (lib/domain/services/privacy_link.dart); no se importa porque arrastra `package:flutter` y `dart run`
// no tiene `dart:ui`: un test (`test/tool/check_release_config_test.dart`) comprueba que esta nunca
// es más permisiva, para las tres claves.
import 'dart:io';

import 'package:yaml/yaml.dart';

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
];

/// TLD de prueba internacionalizados (IDN) de IANA, en *punycode*.
/// **[Suposición]** lista escrita de memoria, pendiente de contrastar con la de IANA.
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

/// Los errores de [value] como dirección de la clave [key] (vacío = sirve para publicar). Cada
/// mensaje empieza por `key:`. Una clave ausente, vacía o que no es texto es un error.
List<String> checkAddress(String key, Object? value) {
  if (value == null) return ['$key: la clave falta o no tiene valor'];
  if (value is! String) {
    return ['$key: no es texto (es ${value.runtimeType})'];
  }
  return [for (final e in _addressErrors(value)) '$key: $e'];
}

List<String> _addressErrors(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return ['la dirección está vacía'];
  if (trimmed.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
    return ['la dirección "$trimmed" lleva espacios o caracteres de control'];
  }
  final forbidden = [
    for (final c in ['?', '#', r'\'])
      if (trimmed.contains(c)) '`$c`',
  ];
  if (forbidden.isNotEmpty) {
    return [
      'la dirección "$trimmed" lleva ${forbidden.join(', ')}: '
          'ni consulta, ni fragmento, ni barra invertida',
    ];
  }
  final scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):').firstMatch(trimmed);
  if (scheme == null || scheme.group(1)!.toLowerCase() != 'https') {
    return ['la dirección "$trimmed" no es https'];
  }
  // El dominio se mira en el texto tal cual, no en `Uri`: `Uri.parse` decodifica `%6d` a `m`,
  // convierte un nombre no ASCII en `%C3%B1…` y normaliza un `:443` explícito.
  final authority = RegExp(r'^[^:]*://([^/]*)').firstMatch(trimmed)?.group(1);
  if (authority == null || authority.isEmpty) {
    return ['la dirección "$trimmed" no tiene dominio'];
  }
  final errors = <String>[];
  if (authority.contains('@')) {
    errors.add(
      'la dirección "$trimmed" lleva usuario (`usuario@`), que disfraza el dominio',
    );
  }
  final hostPort = authority.substring(authority.lastIndexOf('@') + 1);
  final hasPort = hostPort.startsWith('[')
      ? hostPort.contains(']:')
      : hostPort.contains(':');
  if (hasPort) {
    errors.add('la dirección "$trimmed" lleva puerto: la web va en el 443');
  }
  if (authority.codeUnits.any((c) => c > 0x7f)) {
    errors.add(
      'el dominio de "$trimmed" lleva caracteres que no son ASCII: un nombre '
      'internacional va en punycode (`xn--…`)',
    );
  }
  if (authority.contains('%')) {
    errors.add('el dominio de "$trimmed" lleva `%`: un dominio no se codifica');
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return [...errors, 'la dirección "$trimmed" no se puede leer'];
  }
  // Normaliza como el navegador: minúsculas y sin el punto final (`example.com.`).
  var host = uri.host.toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  if (host.isEmpty) {
    return [...errors, 'la dirección "$trimmed" no tiene dominio'];
  }

  final labels = host.split('.');
  final last = labels.last;
  if (InternetAddress.tryParse(host) != null ||
      RegExp(r'^[0-9]+$').hasMatch(last) ||
      last.startsWith('0x')) {
    errors.add('el dominio "$host" es una IP, no un dominio');
  } else if (host == 'localhost' || host.endsWith('.localhost')) {
    errors.add('el dominio "$host" es local (`localhost`), reservado');
  } else if (labels.length < 2) {
    errors.add('el dominio "$host" no tiene punto: no es un dominio público');
  } else {
    for (final reserved in _reservedDomains) {
      if (host == reserved || host.endsWith('.$reserved')) {
        errors.add(
          'el dominio "$host" está reservado para ejemplos ($reserved y sus subdominios): '
          'cámbialo por el definitivo',
        );
      }
    }
    if (_reservedTlds.contains(last)) {
      errors.add(
        'el dominio "$host" termina en `.$last`, reservado para ejemplos, pruebas o uso privado',
      );
    }
    if (_idnTestTlds.contains(last)) {
      errors.add(
        'el dominio "$host" termina en `.$last`, un dominio internacional de pruebas de IANA',
      );
    }
  }
  return errors;
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
/// entre sí (CA-015-13b: tres webs distintas).
List<String> checkAddresses(Map<String, Object?> values) {
  final errors = <String>[
    for (final e in values.entries) ...checkAddress(e.key, e.value),
  ];
  final byAddress = <String, List<String>>{};
  for (final e in values.entries) {
    final value = e.value;
    if (value is! String || value.trim().isEmpty) continue;
    final id = _sameAddress(value);
    if (id != null) (byAddress[id] ??= []).add(e.key);
  }
  for (final e in byAddress.entries) {
    if (e.value.length > 1) {
      errors.add(
        '${e.value.join(' y ')}: son la misma dirección (${e.key}); cada web tiene la suya',
      );
    }
  }
  return errors;
}

/// Los errores del contenido de `identity.yaml` ([root] es lo que devuelve `loadYaml`): las tres
/// direcciones (ausentes, vacías o que no son texto incluidas) y que sean distintas.
List<String> checkIdentity(Object? root) {
  if (root is! Map) {
    return ['identity.yaml: la raíz no es un mapa de claves (clave: valor)'];
  }
  return checkAddresses({for (final key in addressKeys) key: root[key]});
}

/// Los huecos que quedan en el texto publicado de la política ([text] es el archivo
/// entero). Solo cuentan la parte española (`# Política de privacidad (ES)`) y la
/// inglesa (`# Privacy policy (EN)`); la cabecera y las notas de revisión, que citan los
/// huecos, no. Vacío = sin huecos.
List<String> checkPolicyText(String text) {
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
      'no se encuentran, en ese orden, "# Política de privacidad (ES)" y "# Privacy policy (EN)"',
    ];
  }
  final notes = RegExp(
    r'^##\s+Notas para la revisión',
    multiLine: true,
  ).firstMatch(text.substring(en.start));
  final end = notes == null ? text.length : en.start + notes.start;

  final errors = <String>[];
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
      errors.add(
        'la política ($label) sigue con el hueco $shown ($count×, primera vez en la línea $first)',
      );
    }
  }
  return errors;
}

Never _usage(String message) {
  stderr.writeln('::error::$message');
  stderr.writeln(
    'Uso: dart run tool/check_release_config.dart [--identity <archivo>] [--policy <archivo>]',
  );
  exit(2);
}

void main(List<String> args) {
  var identityPath = 'identity.yaml';
  var policyPath = '../docs/legal/privacy-policy.md';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--identity':
        if (++i >= args.length) _usage('--identity necesita un valor');
        identityPath = args[i];
      case '--policy':
        if (++i >= args.length) _usage('--policy necesita un valor');
        policyPath = args[i];
      default:
        _usage('argumento desconocido: ${args[i]}');
    }
  }

  final identity = File(identityPath);
  if (!identity.existsSync()) {
    _usage('no existe $identityPath (¿se ejecuta desde app/?); usa --identity');
  }
  final List<String> addressErrors;
  try {
    addressErrors = checkIdentity(loadYaml(identity.readAsStringSync()));
  } on YamlException catch (e) {
    stdout.writeln('::error::identity.yaml: no se puede leer (${e.message})');
    exit(1);
  }

  final policy = File(policyPath);
  final errors = <String>[
    ...addressErrors,
    if (policy.existsSync())
      ...checkPolicyText(policy.readAsStringSync())
    else
      'no existe la política ($policyPath)',
  ];

  if (errors.isEmpty) {
    stdout.writeln(
      'OK las tres direcciones (${addressKeys.join(', ')}) y el texto de la '
      'política sin huecos',
    );
    return;
  }
  for (final e in errors) {
    stdout.writeln('::error::$e');
  }
  stdout.writeln(
    'La puerta de publicación falla (${errors.length}): no publicar esta versión '
    '(spec 012, CA-012-05; spec 015, CA-015-13b).',
  );
  exit(1);
}
