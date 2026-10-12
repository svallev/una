import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_android_strings.dart';

/// Spec 019, T-019-01: el generador de los textos nativos de la notificación
/// (`tool/gen_android_strings.dart`). Las rutas son relativas a `app/` (el
/// directorio de `flutter test`). Se prueba en una copia temporal con `--out`,
/// sin tocar el árbol.
const _resEn = 'android/app/src/main/res/values/notification_strings.xml';
const _resEs = 'android/app/src/main/res/values-es/notification_strings.xml';

Map<String, dynamic> _arb(String l, [String root = '.']) =>
    jsonDecode(File('$root/lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Los pares `nombre → texto` de un XML de recursos (sin desescapar).
Map<String, String> _strings(String xml) => {
  for (final m in RegExp(
    r'<string name="([a-z_]+)">(.*)</string>',
  ).allMatches(xml))
    m[1]!: m[2]!,
};

/// Una carpeta de app mínima: solo los dos ARB.
Directory _appCopy() {
  final dir = Directory.systemTemp.createTempSync('gen_android_strings_');
  addTearDown(() => dir.deleteSync(recursive: true));
  Directory('${dir.path}/lib/l10n').createSync(recursive: true);
  for (final l in ['es', 'en']) {
    File('lib/l10n/app_$l.arb').copySync('${dir.path}/lib/l10n/app_$l.arb');
  }
  return dir;
}

int _run(List<String> args, {StringBuffer? out, StringBuffer? err}) =>
    runGenAndroidStrings(args, out: out ?? StringBuffer(), err: err);

void _editArb(Directory dir, String lang, String key, String value) {
  final file = File('${dir.path}/lib/l10n/app_$lang.arb');
  final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  arb[key] = value;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(arb));
}

void main() {
  test('CA-019-27, CA-019-21: el listado fijo son las 7 claves de la spec '
      '(4 notification… y attachmentPhoto/Image/Pdf)', () {
    expect(androidStringKeys, [
      'notificationChannelName',
      'notificationChannelDescription',
      'notificationTitle',
      'notificationPublic',
      'attachmentPhoto',
      'attachmentImage',
      'attachmentPdf',
    ]);
  });

  test('CA-019-27: los recursos del repositorio están al día con los ARB '
      '(--check)', () {
    final err = StringBuffer();
    expect(_run(['--check'], err: err), 0, reason: '$err');
  });

  test('CA-019-21: values/ va en inglés y values-es/ en español, con las 7 '
      'claves y el texto de los ARB (cabecera GENERADO)', () {
    final en = _arb('en'), es = _arb('es');
    final xmlEn = File(_resEn).readAsStringSync();
    final xmlEs = File(_resEs).readAsStringSync();
    expect(xmlEn, contains('GENERADO'));
    expect(xmlEs, contains('GENERADO'));
    expect(xmlEn, contains('tool/gen_android_strings.dart'));
    expect(_strings(xmlEn).keys, [
      'notification_channel_name',
      'notification_channel_description',
      'notification_title',
      'notification_public',
      'attachment_photo',
      'attachment_image',
      'attachment_pdf',
    ]);
    final stringsEn = _strings(xmlEn), stringsEs = _strings(xmlEs);
    expect(stringsEn.keys, stringsEs.keys);
    expect(stringsEn['notification_title'], en['notificationTitle']);
    expect(stringsEs['notification_title'], es['notificationTitle']);
    expect(stringsEn['notification_public'], en['notificationPublic']);
    expect(stringsEs['notification_public'], es['notificationPublic']);
    expect(stringsEn['notification_channel_name'], 'Current task');
    expect(stringsEs['notification_channel_name'], 'Tarea actual');
    expect(stringsEn['attachment_photo'], en['attachmentPhoto']);
    expect(stringsEs['attachment_image'], es['attachmentImage']);
    expect(stringsEs['attachment_pdf'], es['attachmentPdf']);
  });

  test('CA-019-27: generar en una carpeta vacía escribe los dos XML y '
      '--check pasa después; --check no escribe nada', () {
    final dir = _appCopy();
    final err = StringBuffer();
    expect(_run(['--check', '--out', dir.path], err: err), 1);
    expect('$err', contains('notification_strings.xml'));
    expect(File('${dir.path}/$_resEn').existsSync(), isFalse);
    expect(_run(['--out', dir.path]), 0);
    expect(
      File('${dir.path}/$_resEn').readAsStringSync(),
      File(_resEn).readAsStringSync(),
    );
    expect(
      File('${dir.path}/$_resEs').readAsStringSync(),
      File(_resEs).readAsStringSync(),
    );
    expect(_run(['--check', '--out', dir.path]), 0);
  });

  test('CA-019-27: --check falla si el XML difiere de los ARB, en cualquiera '
      'de los dos idiomas', () {
    final dir = _appCopy();
    expect(_run(['--out', dir.path]), 0);
    _editArb(dir, 'es', 'notificationPublic', 'Otro texto distinto.');
    final err = StringBuffer();
    expect(_run(['--check', '--out', dir.path], err: err), 1);
    expect('$err', contains('values-es'));
    expect('$err', isNot(contains('values/')));
    expect(_run(['--out', dir.path]), 0);
    expect(_run(['--check', '--out', dir.path]), 0);
    _editArb(dir, 'en', 'attachmentPdf', 'Document');
    expect(_run(['--check', '--out', dir.path]), 1);
    // Y a mano en el XML.
    expect(_run(['--out', dir.path]), 0);
    final xml = File('${dir.path}/$_resEn');
    xml.writeAsStringSync('${xml.readAsStringSync()}\n<!-- a mano -->\n');
    expect(_run(['--check', '--out', dir.path]), 1);
  });

  test('CA-019-27: un texto con apóstrofo, comillas, & o < se escapa para '
      'Android (el XML sigue siendo válido)', () {
    final dir = _appCopy();
    _editArb(dir, 'en', 'notificationPublic', 'You\'ve "a" <task> & more');
    expect(_run(['--out', dir.path]), 0);
    final xml = File('${dir.path}/$_resEn').readAsStringSync();
    expect(
      _strings(xml)['notification_public'],
      r'''You\'ve \"a\" &lt;task&gt; &amp; more''',
    );
  });

  test('CA-019-27: un texto que empieza por @ o ? se escapa (Android lo '
      'tomaría por una referencia)', () {
    final dir = _appCopy();
    _editArb(dir, 'es', 'notificationTitle', '@Tarea');
    expect(_run(['--out', dir.path]), 0);
    final xml = File('${dir.path}/$_resEs').readAsStringSync();
    expect(_strings(xml)['notification_title'], r'\@Tarea');
  });

  test('CA-019-27: falla (1) si falta una clave del listado en un ARB o si '
      'lleva placeholders (no son texto fijo)', () {
    final dir = _appCopy();
    final file = File('${dir.path}/lib/l10n/app_en.arb');
    final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      ..remove('attachmentImage');
    file.writeAsStringSync(jsonEncode(arb));
    final err = StringBuffer();
    expect(_run(['--out', dir.path], err: err), 1);
    expect('$err', contains('attachmentImage'));
    expect(Directory('${dir.path}/android').existsSync(), isFalse);

    final dir2 = _appCopy();
    _editArb(dir2, 'es', 'notificationTitle', 'Tarea {count}');
    final err2 = StringBuffer();
    expect(_run(['--out', dir2.path], err: err2), 1);
    expect('$err2', contains('notificationTitle'));
  });

  test('CA-019-27: un argumento desconocido o --out sin valor es un error '
      'de uso (2)', () {
    expect(_run(['--nope']), 2);
    expect(_run(['--out']), 2);
  });
}
