// Puerta de publicación (spec 012, CA-012-05): falla si la dirección de la política
// de privacidad no sirve para publicar o si el texto de la política sigue con huecos.
//
//   dart run tool/check_release_config.dart [--url <dirección>] [--policy <archivo>]
//
// Sin argumentos lee `privacyPolicyUrl` de `identity.yaml` y la política de
// `../docs/legal/privacy-policy.md` (se ejecuta desde `app/`; lo normal es llamarla con
// `tools/check-release-config.sh`). Con una compilación de desarrollo o local NO se usa:
// el marcador `https://example.com/privacy` es normal mientras se desarrolla.
//
// La dirección debe ser `https`, sin usuario, sin puerto, con un dominio público (no una
// IP ni `localhost`) y que no sea un dominio reservado para ejemplos ni un subdominio suyo.
// La regla de `https` + sin usuario es la de `privacyLink` (lib/domain/services/privacy_link.dart);
// no se importa porque arrastra `package:flutter` y `dart run` no tiene `dart:ui`: un test
// (`test/tool/check_release_config_test.dart`) comprueba que esta nunca es más permisiva.
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Dominios reservados para ejemplos (RFC 2606 / 6761), con todos sus subdominios.
const _reservedDomains = ['example.com', 'example.net', 'example.org'];

/// Sufijos reservados: cualquier dominio que termine en uno de ellos.
const _reservedTlds = ['example', 'test', 'invalid', 'localhost'];

/// Huecos de la política sin rellenar, en la parte española y en la inglesa.
final _gap = RegExp(
  r'\[\s*(NOMBRE DE LA APP|FECHA|RESPONSABLE|CONTACTO|APP NAME|DATE|CONTROLLER|CONTACT)\s*\]',
  caseSensitive: false,
);

/// Los errores de [address] como dirección de la política (vacío = sirve para publicar).
List<String> checkPrivacyUrl(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return ['la dirección de la política está vacía'];
  if (trimmed.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) {
    return ['la dirección "$trimmed" lleva espacios o caracteres de control'];
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return ['la dirección "$trimmed" no se puede leer'];
  if (uri.scheme.toLowerCase() != 'https') {
    return ['la dirección "$trimmed" no es https'];
  }
  // Normaliza como el navegador: minúsculas y sin el punto final (`example.com.`).
  var host = uri.host.toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  if (host.isEmpty) return ['la dirección "$trimmed" no tiene dominio'];

  final errors = <String>[];
  if (uri.userInfo.isNotEmpty) {
    errors.add(
      'la dirección "$trimmed" lleva usuario (`usuario@`), que disfraza el dominio',
    );
  }
  if (uri.hasPort) {
    errors.add(
      'la dirección "$trimmed" lleva puerto (${uri.port}): la política va en el 443',
    );
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
        'el dominio "$host" termina en `.$last`, reservado para ejemplos y pruebas',
      );
    }
  }
  return errors;
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
    'Uso: dart run tool/check_release_config.dart [--url <dirección>] [--policy <archivo>]',
  );
  exit(2);
}

void main(List<String> args) {
  String? url;
  String policyPath = '../docs/legal/privacy-policy.md';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--url':
        if (++i >= args.length) _usage('--url necesita un valor');
        url = args[i];
      case '--policy':
        if (++i >= args.length) _usage('--policy necesita un valor');
        policyPath = args[i];
      default:
        _usage('argumento desconocido: ${args[i]}');
    }
  }

  if (url == null) {
    final identity = File('identity.yaml');
    if (!identity.existsSync()) {
      _usage('no existe identity.yaml (¿se ejecuta desde app/?); usa --url');
    }
    final yaml = loadYaml(identity.readAsStringSync()) as YamlMap;
    url = (yaml['privacyPolicyUrl'] as String?) ?? '';
  }

  final policy = File(policyPath);
  final errors = <String>[
    ...checkPrivacyUrl(url).map((e) => 'privacyPolicyUrl: $e'),
    if (policy.existsSync())
      ...checkPolicyText(policy.readAsStringSync())
    else
      'no existe la política ($policyPath)',
  ];

  if (errors.isEmpty) {
    stdout.writeln(
      'OK dirección de la política ($url) y texto de la política sin huecos',
    );
    return;
  }
  for (final e in errors) {
    stdout.writeln('::error::$e');
  }
  stdout.writeln(
    'La puerta de publicación falla (${errors.length}): no publicar esta versión '
    '(spec 012, CA-012-05).',
  );
  exit(1);
}
