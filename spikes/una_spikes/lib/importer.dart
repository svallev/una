// SPIKE S3/S5 — canal de importación: tipo por contenido, límites, imagen sin
// metadatos (EXIF/GPS/XMP), miniaturas y copia al sandbox. Código desechable.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

enum Kind { image, pdf, document, rejected }

class Detection {
  Detection(this.kind, this.mime, [this.reason = '']);
  final Kind kind;
  final String mime;
  final String reason;
}

const mb = 1024 * 1024;
const limits = {Kind.image: 30 * mb, Kind.pdf: 10 * mb, Kind.document: 25 * mb};
const maxPixels = 50 * 1000 * 1000;

bool _starts(Uint8List b, List<int> sig, [int off = 0]) {
  if (b.length < off + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[off + i] != sig[i]) return false;
  }
  return true;
}

String _ext(String name) => name.contains('.') ? name.split('.').last.toLowerCase() : '';

/// Detección por **contenido** (bytes mágicos); la extensión solo se usa para
/// comprobar coherencia y para distinguir texto plano y formatos OLE antiguos.
Detection detect(Uint8List b, String name) {
  final ext = _ext(name);
  Detection? d;
  if (_starts(b, [0xFF, 0xD8, 0xFF])) {
    d = Detection(Kind.image, 'image/jpeg');
  } else if (_starts(b, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    d = Detection(Kind.image, 'image/png');
  } else if (_starts(b, ascii.encode('GIF87a')) || _starts(b, ascii.encode('GIF89a'))) {
    d = Detection(Kind.image, 'image/gif');
  } else if (_starts(b, ascii.encode('RIFF')) && _starts(b, ascii.encode('WEBP'), 8)) {
    d = Detection(Kind.image, 'image/webp');
  } else if (_starts(b, ascii.encode('ftyp'), 4) &&
      ['heic', 'heix', 'mif1', 'msf1', 'hevc', 'heim', 'heis'].contains(ascii.decode(b.sublist(8, 12), allowInvalid: true))) {
    d = Detection(Kind.image, 'image/heic');
  } else if (_starts(b, ascii.encode('%PDF-'))) {
    d = Detection(Kind.pdf, 'application/pdf');
  } else if (_starts(b, [0x50, 0x4B, 0x03, 0x04])) {
    d = _zipKind(b, ext);
  } else if (_starts(b, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])) {
    const ole = {'doc': 'application/msword', 'xls': 'application/vnd.ms-excel', 'ppt': 'application/vnd.ms-powerpoint'};
    d = ole.containsKey(ext) ? Detection(Kind.document, ole[ext]!) : Detection(Kind.rejected, '', 'OLE sin extensión Office conocida');
  } else if (_starts(b, ascii.encode(r'{\rtf'))) {
    d = Detection(Kind.document, 'application/rtf');
  } else if (_starts(b, ascii.encode('MZ')) || _starts(b, [0x7F, 0x45, 0x4C, 0x46]) || _starts(b, ascii.encode('#!'))) {
    d = Detection(Kind.rejected, '', 'ejecutable o script');
  } else {
    d = _textKind(b, ext);
  }
  if (d.kind == Kind.rejected) return d;
  // Coherencia extensión ↔ contenido (CL-008-5): una extensión conocida de otro tipo se rechaza.
  const extKind = {
    'jpg': Kind.image, 'jpeg': Kind.image, 'png': Kind.image, 'gif': Kind.image, 'webp': Kind.image, 'heic': Kind.image, 'heif': Kind.image,
    'pdf': Kind.pdf,
  };
  final expected = extKind[ext];
  if (expected != null && expected != d.kind) {
    return Detection(Kind.rejected, d.mime, 'extensión .$ext incoherente con el contenido (${d.mime})');
  }
  return d;
}

Detection _zipKind(Uint8List b, String ext) {
  try {
    final z = ZipDecoder().decodeBytes(b, verify: false);
    final names = z.files.map((f) => f.name).toSet();
    if (names.contains('[Content_Types].xml')) {
      if (names.any((n) => n.startsWith('word/'))) return Detection(Kind.document, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      if (names.any((n) => n.startsWith('xl/'))) return Detection(Kind.document, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      if (names.any((n) => n.startsWith('ppt/'))) return Detection(Kind.document, 'application/vnd.openxmlformats-officedocument.presentationml.presentation');
    }
    final mt = z.findFile('mimetype');
    if (mt != null) {
      final m = utf8.decode(mt.content as List<int>).trim();
      if (m.startsWith('application/vnd.oasis.opendocument.')) return Detection(Kind.document, m);
    }
    if (['pages', 'numbers', 'key'].contains(ext) && names.any((n) => n.startsWith('Index/'))) {
      return Detection(Kind.document, 'application/x-iwork-$ext');
    }
    return Detection(Kind.rejected, 'application/zip', 'ZIP genérico no admitido');
  } catch (_) {
    return Detection(Kind.rejected, 'application/zip', 'ZIP ilegible');
  }
}

Detection _textKind(Uint8List b, String ext) {
  const textExt = {'txt': 'text/plain', 'csv': 'text/csv', 'md': 'text/markdown'};
  if (!textExt.containsKey(ext)) return Detection(Kind.rejected, '', 'tipo desconocido');
  if (b.contains(0)) return Detection(Kind.rejected, '', 'binario con extensión de texto');
  try {
    final s = utf8.decode(b).trimLeft().replaceFirst('﻿', '');
    if (s.startsWith('<')) return Detection(Kind.rejected, '', 'marcado (HTML/SVG/XML) no admitido');
  } on FormatException {
    return Detection(Kind.rejected, '', 'texto no UTF-8');
  }
  return Detection(Kind.document, textExt[ext]!);
}

class ImportResult {
  ImportResult(this.name, this.detection, {this.id, this.dir, this.files = const {}, this.info = const {}, this.ms = const {}});
  final String name;
  final Detection detection;
  final String? id;
  final String? dir;
  final Map<String, String> files; // original / display / thumb
  final Map<String, Object?> info;
  final Map<String, int> ms;
  bool get accepted => detection.kind != Kind.rejected;

  Map<String, Object?> toJson() => {
        'name': name, 'kind': detection.kind.name, 'mime': detection.mime,
        if (!accepted) 'reason': detection.reason, ...info, 'ms': ms,
      };
}

int _seq = 0;

/// Canal completo. [screenPx] = ancho físico de la pantalla (versión de pantalla, I-2).
Future<ImportResult> importFile(File src, {required int screenPx}) async {
  final sw = Stopwatch()..start();
  final ms = <String, int>{};
  final name = src.uri.pathSegments.last;
  final size = await src.length();
  final head = Uint8List.fromList(await src.openRead(0, 64).expand((e) => e).toList());
  var det = detect(head, name);
  // ZIP y texto necesitan el contenido completo (pequeño por el límite de 25 MB).
  if (det.kind != Kind.rejected || _starts(head, [0x50, 0x4B, 0x03, 0x04]) || ['txt', 'csv', 'md'].contains(_ext(name))) {
    if (_starts(head, [0x50, 0x4B, 0x03, 0x04]) || det.mime.startsWith('text/') || det.kind == Kind.rejected) {
      if (size <= 25 * mb) det = detect(await src.readAsBytes(), name);
    }
  }
  ms['detect'] = sw.elapsedMilliseconds;
  if (det.kind == Kind.rejected) return ImportResult(name, det, ms: ms);
  final limit = limits[det.kind]!;
  if (size > limit) {
    return ImportResult(name, Detection(Kind.rejected, det.mime, 'demasiado grande: ${(size / mb).toStringAsFixed(1)} MB > ${limit ~/ mb} MB'), ms: ms);
  }

  final id = 'a${DateTime.now().millisecondsSinceEpoch}_${_seq++}';
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/attachments/$id')..createSync(recursive: true);
  final files = <String, String>{};
  final info = <String, Object?>{'bytesIn': size};
  try {
    if (det.kind == Kind.image && const String.fromEnvironment('SANITIZER', defaultValue: 'native') == 'native') {
      await _processImageNative(src, dir.path, screenPx, files, info, ms, sw);
    } else if (det.kind == Kind.image) {
      await _processImage(await src.readAsBytes(), dir.path, screenPx, files, info, ms, sw);
    } else if (det.kind == Kind.pdf) {
      final out = '${dir.path}/original.pdf';
      await src.copy(out);
      files['original'] = out;
      ms['copy'] = sw.elapsedMilliseconds;
      await _processPdf(out, dir.path, screenPx, files, info, ms, sw);
    } else {
      final out = '${dir.path}/original.${_ext(name).isEmpty ? 'bin' : _ext(name)}';
      await src.copy(out);
      files['original'] = out;
      ms['copy'] = sw.elapsedMilliseconds;
    }
  } catch (e) {
    dir.deleteSync(recursive: true); // nada a medias en el sandbox
    return ImportResult(name, Detection(Kind.rejected, det.mime, 'ilegible: $e'), ms: ms);
  }
  ms['total'] = sw.elapsedMilliseconds;
  return ImportResult(name, det, id: id, dir: dir.path, files: files, info: info, ms: ms);
}

const _native = MethodChannel('spike/native');

/// Variante nativa (puerto ImageSanitizer): cabecera y límite de píxeles en Dart, el resto en Kotlin.
Future<void> _processImageNative(File src, String dir, int screenPx, Map<String, String> files, Map<String, Object?> info, Map<String, int> ms, Stopwatch sw) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(src.path);
  final desc = await ui.ImageDescriptor.encoded(buffer);
  info['srcW'] = desc.width;
  info['srcH'] = desc.height;
  final px = desc.width * desc.height;
  desc.dispose();
  buffer.dispose();
  if (px > maxPixels) throw 'demasiados píxeles: ${(px / 1e6).toStringAsFixed(1)} MP > 50 MP';
  ms['header'] = sw.elapsedMilliseconds;
  final r = (await _native.invokeMapMethod<String, Object?>('sanitizeImage', {'in': src.path, 'outDir': dir, 'screenPx': screenPx}))!;
  for (final k in ['original', 'display', 'thumb']) {
    files[k] = r[k]! as String;
    info['${k}WxH'] = r['${k}WxH'];
    info['${k}Bytes'] = r['${k}Bytes'];
  }
  (r['ms']! as Map).forEach((k, v) => ms['native_$k'] = v as int);
  ms['native_roundtrip'] = sw.elapsedMilliseconds;
  info['sanitizer'] = 'native';
  info['metadataFound'] = files.values.any((p) => _hasMetadata(File(p).readAsBytesSync()));
}

Future<void> _processImage(Uint8List bytes, String dir, int screenPx, Map<String, String> files, Map<String, Object?> info, Map<String, int> ms, Stopwatch sw) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final desc = await ui.ImageDescriptor.encoded(buffer);
  info['srcW'] = desc.width;
  info['srcH'] = desc.height;
  if (desc.width * desc.height > maxPixels) {
    desc.dispose();
    throw 'demasiados píxeles: ${(desc.width * desc.height / 1e6).toStringAsFixed(1)} MP > 50 MP';
  }
  ms['header'] = sw.elapsedMilliseconds;
  // Decodificación nativa (Skia/Android) a cada tamaño; la orientación EXIF la aplica el decodificador.
  Future<(Uint8List, int, int)> rgba(int? targetW) async {
    final codec = await desc.instantiateCodec(targetWidth: targetW);
    final img = (await codec.getNextFrame()).image;
    final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final r = (data.buffer.asUint8List(), img.width, img.height);
    img.dispose();
    codec.dispose();
    return r;
  }

  final longSide = desc.width > desc.height ? desc.width : desc.height;
  final origW = longSide > 4096 ? (desc.width * 4096 / longSide).round() : null;
  final targets = {'original': origW, 'display': desc.width > screenPx ? screenPx : null, 'thumb': 256};
  for (final e in targets.entries) {
    final (px, w, h) = await rgba(e.value);
    ms['decode_${e.key}'] = sw.elapsedMilliseconds;
    // Recodificar en otro isolate: la imagen nueva NO lleva EXIF/GPS/XMP.
    final jpg = await encodeJpgInIsolate(px, w, h, e.key == 'thumb' ? 80 : 88);
    final path = '$dir/${e.key}.jpg';
    File(path).writeAsBytesSync(jpg);
    files[e.key] = path;
    info['${e.key}WxH'] = '${w}x$h';
    info['${e.key}Bytes'] = jpg.length;
    ms['encode_${e.key}'] = sw.elapsedMilliseconds;
  }
  desc.dispose();
  // Verificación: ningún archivo de salida contiene EXIF, GPS ni XMP.
  info['metadataFound'] = files.values.any((p) => _hasMetadata(File(p).readAsBytesSync()));
}

bool _hasMetadata(Uint8List b) {
  bool has(String s) {
    final pat = ascii.encode(s);
    outer:
    for (var i = 0; i + pat.length <= b.length; i++) {
      for (var j = 0; j < pat.length; j++) {
        if (b[i + j] != pat[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  return has('Exif\u0000\u0000') || has('http://ns.adobe.com/xap/') || has('SpikeCam');
}

Future<void> _processPdf(String path, String dir, int screenPx, Map<String, String> files, Map<String, Object?> info, Map<String, int> ms, Stopwatch sw) async {
  await pdfrxFlutterInitialize();
  PdfDocument doc;
  try {
    doc = await PdfDocument.openFile(path, passwordProvider: null, firstAttemptByEmptyPassword: true);
  } on PdfPasswordException {
    info['protected'] = true;
    ms['open'] = sw.elapsedMilliseconds;
    return;
  }
  ms['open'] = sw.elapsedMilliseconds;
  info['pages'] = doc.pages.length;
  final page = doc.pages.first;
  final w = screenPx;
  final h = (page.height * w / page.width).round();
  final img = await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), width: w, height: h, backgroundColor: 0xFFFFFFFF);
  ms['render_p1'] = sw.elapsedMilliseconds;
  if (img != null) {
    final px = Uint8List.fromList(img.pixels);
    final iw = img.width, ih = img.height;
    img.dispose();
    final jpg = await encodeJpgInIsolate(px, iw, ih, 85, bgra: true);
    final p = '$dir/p1_display.jpg';
    File(p).writeAsBytesSync(jpg);
    files['display'] = p;
    ms['encode_p1'] = sw.elapsedMilliseconds;
  }
  await doc.dispose();
}

/// Codifica a JPEG en otro isolate. Función aparte para que el cierre solo
/// capture datos enviables (bytes y enteros), nunca objetos nativos del decodificador.
Future<Uint8List> encodeJpgInIsolate(Uint8List px, int w, int h, int quality, {bool bgra = false}) {
  final bytes = Uint8List.fromList(px); // copia compacta (no una vista de un buffer mayor)
  return Isolate.run(() => Uint8List.fromList(imglib.encodeJpg(
        imglib.Image.fromBytes(width: w, height: h, bytes: bytes.buffer, numChannels: 4, order: bgra ? imglib.ChannelOrder.bgra : imglib.ChannelOrder.rgba),
        quality: quality,
      )));
}
