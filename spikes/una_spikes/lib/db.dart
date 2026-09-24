// SPIKE S1 — código desechable. Base de datos drift sin generación de código,
// con el mismo motor (drift_flutter → sqlite3) que usará la app.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as imglib;
import 'package:path_provider/path_provider.dart';

class SpikeDb extends GeneratedDatabase {
  SpikeDb(super.e);

  /// Variante A (por defecto de drift_flutter): SQLite en un isolate aparte.
  factory SpikeDb.isolate() => SpikeDb(driftDatabase(name: 'una_spike'));

  /// Variante B: SQLite en el isolate principal (llamadas FFI síncronas, sin
  /// coste de crear un isolate). Mismo archivo que la variante A.
  factory SpikeDb.mainIsolate(String dir) => SpikeDb(NativeDatabase(File('$dir/una_spike.sqlite')));

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  Future<void> ensureSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS tasks(
        id TEXT PRIMARY KEY, text TEXT, status TEXT NOT NULL, rank TEXT NOT NULL,
        color_key INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        completed_at INTEGER, deleted_at INTEGER)''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS attachments(
        id TEXT PRIMARY KEY, task_id TEXT NOT NULL, kind TEXT NOT NULL,
        rel_path TEXT NOT NULL, display_rel_path TEXT, byte_size INTEGER NOT NULL)''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_current ON tasks(status, deleted_at, rank)',
    );
  }

  /// La consulta de arranque: solo la tarea actual y su adjunto.
  Future<CurrentTask?> currentTask() async {
    final rows = await customSelect('''
      SELECT t.id, t.text, t.color_key, a.kind, a.display_rel_path
      FROM tasks t LEFT JOIN attachments a ON a.task_id = t.id
      WHERE t.status = 'pending' AND t.deleted_at IS NULL
      ORDER BY t.rank LIMIT 1''').get();
    if (rows.isEmpty) return null;
    final r = rows.first;
    return CurrentTask(
      id: r.read<String>('id'),
      text: r.readNullable<String>('text'),
      colorKey: r.read<int>('color_key'),
      kind: r.readNullable<String>('kind'),
      displayRelPath: r.readNullable<String>('display_rel_path'),
    );
  }

  Future<int> countPending() async {
    final r = await customSelect(
      "SELECT COUNT(*) AS c FROM tasks WHERE status='pending' AND deleted_at IS NULL",
    ).getSingle();
    return r.read<int>('c');
  }

  /// Primera ejecución: 200 tareas de texto + 1 con una imagen de 12 MP (4000×3000).
  Future<void> seedIfEmpty(String baseDir) async {
    if (await countPending() > 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      for (var i = 0; i < 200; i++) {
        await customStatement(
          'INSERT INTO tasks VALUES(?,?,?,?,?,?,?,NULL,NULL)',
          ['t$i', 'Tarea de prueba número $i para medir el arranque', 'pending', 'b${i.toString().padLeft(4, '0')}', i % 5, now, now],
        );
      }
    });
    await _seedImageTask(baseDir, now);
  }

  Future<void> _seedImageTask(String baseDir, int now) async {
    final dir = Directory('$baseDir/attachments/img1')..createSync(recursive: true);
    final original = await _renderPng(4000, 3000);
    File('${dir.path}/original.png').writeAsBytesSync(original);
    // Versión de pantalla pregenerada al importar (≈ 2× el ancho lógico típico).
    final display = await _downscale(original, 1440);
    File('${dir.path}/display.png').writeAsBytesSync(display);
    await customStatement(
      'INSERT INTO tasks VALUES(?,?,?,?,?,?,?,NULL,NULL)',
      ['img1', 'Horario del festival', 'pending', 'c0000', 2, now, now],
    );
    await customStatement(
      'INSERT INTO attachments VALUES(?,?,?,?,?,?)',
      ['att1', 'img1', 'image', 'attachments/img1/original.png', 'attachments/img1/display.png', original.length],
    );
  }

  /// Variante JPEG: versión de pantalla al ancho exacto (1080 px), calidad 85.
  /// Se genera una sola vez (no se mide) y se apunta el adjunto a ella.
  Future<void> ensureJpegDisplay(String baseDir, int width) async {
    final jpg = File('$baseDir/attachments/img1/display_$width.jpg');
    if (!jpg.existsSync()) {
      final png = File('$baseDir/attachments/img1/original.png').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(png, targetWidth: width);
      final img = (await codec.getNextFrame()).image;
      final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final im = imglib.Image.fromBytes(width: img.width, height: img.height, bytes: rgba.buffer, numChannels: 4, order: imglib.ChannelOrder.rgba);
      jpg.writeAsBytesSync(imglib.encodeJpg(im, quality: 85));
    }
    await customStatement(
      "UPDATE attachments SET display_rel_path = ? WHERE id = 'att1'",
      ['attachments/img1/display_$width.jpg'],
    );
  }

  /// Alterna qué tarea es la actual (texto o imagen) para medir ambos casos.
  Future<void> setCurrent({required bool image}) async {
    await customStatement("UPDATE tasks SET rank = 'c0000' WHERE id = 'img1'");
    if (image) {
      await customStatement("UPDATE tasks SET rank = 'a0000' WHERE id = 'img1'");
    }
  }

  static Future<Uint8List> _renderPng(int w, int h) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rnd = Random(7);
    c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFFF4F1EA));
    for (var i = 0; i < 400; i++) {
      c.drawRect(
        Rect.fromLTWH(rnd.nextDouble() * w, rnd.nextDouble() * h, 60 + rnd.nextDouble() * 400, 20 + rnd.nextDouble() * 120),
        Paint()..color = Color(0xFF000000 | rnd.nextInt(0xFFFFFF)),
      );
    }
    final img = await rec.endRecording().toImage(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static Future<Uint8List> _downscale(Uint8List png, int targetWidth) async {
    final codec = await ui.instantiateImageCodec(png, targetWidth: targetWidth);
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}

class CurrentTask {
  CurrentTask({required this.id, this.text, required this.colorKey, this.kind, this.displayRelPath});
  final String id;
  final String? text;
  final int colorKey;
  final String? kind;
  final String? displayRelPath;
}

Future<String> attachmentsBase() async => (await getApplicationSupportDirectory()).path;

/// drift_flutter guarda `una_spike.sqlite` en getApplicationDocumentsDirectory().
Future<String> dbDir() async => (await getApplicationDocumentsDirectory()).path;
