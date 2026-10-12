// Genera los textos nativos de la notificación a partir de las ARB (spec 019, CA-019-21 y 27).
//
//   dart run tool/gen_android_strings.dart          → escribe los archivos
//   dart run tool/gen_android_strings.dart --check  → falla si alguno no está al día (CI)
//   --out <carpeta>  la carpeta de la app (por defecto `.`); así se prueba sin tocar el árbol
//
// La notificación sale con la app cerrada, así que Kotlin no puede leer los ARB de Flutter: este
// generador copia un **listado fijo** de claves (solo texto, sin placeholders) a recursos de
// Android, para que los textos de la bandeja sean los mismos que los de la app (P7, P-019-6).
//
//   values/notification_strings.xml     → app_en.arb (inglés: el idioma por defecto de los recursos)
//   values-es/notification_strings.xml  → app_es.arb
//
// El nativo elige el idioma pedido con `createConfigurationContext`, sin depender del idioma del
// sistema. Sin paquetes (P11): solo `dart:io` y `dart:convert`. No va en `lib/` ni se empaqueta.
import 'dart:convert';
import 'dart:io';

/// Las claves de los ARB que pasan a recursos de Android (CA-019-21): las cuatro `notification…` y
/// las tres etiquetas de tipo que ya existen (`attachmentPhoto`, `attachmentImage`,
/// `attachmentPdf`). El nombre del recurso es la clave en `snake_case`. Si se añade una, se
/// añade aquí y el `--check` de CI obliga a regenerar.
const androidStringKeys = <String>[
  'notificationChannelName',
  'notificationChannelDescription',
  'notificationTitle',
  'notificationPublic',
  'attachmentPhoto',
  'attachmentImage',
  'attachmentPdf',
];

const _resDir = 'android/app/src/main/res';
const _fileName = 'notification_strings.xml';

/// Qué ARB va a qué carpeta de recursos.
const _targets = <({String lang, String dir})>[
  (lang: 'en', dir: 'values'),
  (lang: 'es', dir: 'values-es'),
];

const _usage =
    'Uso: dart run tool/gen_android_strings.dart [--check] [--out <carpeta de la app>]';

void main(List<String> args) {
  exit(runGenAndroidStrings(args));
}

/// Ejecuta el generador. Devuelve el código de salida: 0 bien, 1 desactualizado o error de
/// lectura, 2 uso incorrecto. [out] y [err] son donde escribe los mensajes (por defecto, la
/// consola); así lo prueba un test sin lanzar un proceso.
int runGenAndroidStrings(
  List<String> args, {
  StringSink? out,
  StringSink? err,
}) {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;

  var check = false;
  var root = '.';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--check':
        check = true;
      case '--out':
        if (i + 1 >= args.length) {
          stderrSink.writeln('--out necesita un valor\n$_usage');
          return 2;
        }
        root = args[++i];
      default:
        stderrSink.writeln('Argumento desconocido: ${args[i]}\n$_usage');
        return 2;
    }
  }

  // Primero se lee y se valida todo; no se escribe nada si algo falla.
  final outputs = <String, String>{};
  try {
    for (final t in _targets) {
      final arb = _readArb('$root/lib/l10n/app_${t.lang}.arb');
      outputs['$_resDir/${t.dir}/$_fileName'] = _render(arb, t.lang);
    }
  } on FormatException catch (e) {
    stderrSink.writeln(e.message);
    return 1;
  }

  final stale = <String>[];
  outputs.forEach((path, next) {
    final file = File('$root/$path');
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current == next) return;
    stale.add(path);
    if (!check) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(next);
    }
  });

  if (check && stale.isNotEmpty) {
    stderrSink.writeln(
      'Textos nativos desactualizados. Ejecuta `dart run tool/gen_android_strings.dart`:\n'
      ' - ${stale.join('\n - ')}',
    );
    return 1;
  }
  stdoutSink.writeln(
    check
        ? 'Textos nativos al día.'
        : 'Textos nativos generados (${stale.length} archivos actualizados).',
  );
  return 0;
}

Map<String, dynamic> _readArb(String path) {
  final file = File(path);
  if (!file.existsSync()) throw FormatException('No existe $path');
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$path no es un objeto JSON');
  }
  return decoded;
}

String _render(Map<String, dynamic> arb, String lang) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln(
      '<!-- GENERADO por tool/gen_android_strings.dart desde app_$lang.arb. No editar a mano. -->',
    )
    ..writeln('<resources>');
  for (final key in androidStringKeys) {
    final value = arb[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'app_$lang.arb: la clave `$key` falta o no es texto.',
      );
    }
    if (value.contains('{') || value.contains('}')) {
      throw FormatException(
        'app_$lang.arb: la clave `$key` lleva placeholders o plurales; '
        'solo se copian textos fijos.',
      );
    }
    b.writeln('    <string name="${_snake(key)}">${_android(value)}</string>');
  }
  b.writeln('</resources>');
  return b.toString();
}

/// `notificationChannelName` → `notification_channel_name`.
String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// Escapa un texto para un recurso `<string>` de Android: XML (`&`, `<`, `>`), el apóstrofo y las
/// comillas (que `aapt` exige escapar) y un `@` o `?` inicial (que se tomaría por una referencia).
String _android(String s) {
  final escaped = s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"');
  return escaped.startsWith('@') || escaped.startsWith('?')
      ? '\\$escaped'
      : escaped;
}
