// Goldens de la spec 007 (T-007-22). Se generan y comparan solo en Linux (CI):
// ver docs/testing.md, "Goldens".
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_image_importer.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

const _w = 600;
const _h = 800;

/// "Foto" determinista: un horario impreso sobre una mesa. Se dibuja en el
/// test para que el golden muestre de verdad el recorte, el pie y el borde.
Future<Uint8List> _photo() async {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  final size = Size(_w.toDouble(), _h.toDouble());
  c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF8A5A3C));
  final sheet = Rect.fromLTWH(70, 90, _w - 140.0, _h - 180.0);
  c.drawRect(sheet, Paint()..color = const Color(0xFFFAFAF5));
  c.drawRect(
    Rect.fromLTWH(sheet.left, sheet.top, sheet.width, 70),
    Paint()..color = const Color(0xFFE2463A),
  );
  final line = Paint()..color = const Color(0xFF2B2B2B);
  for (var i = 0; i < 9; i++) {
    final y = sheet.top + 110 + i * 60.0;
    c
      ..drawRect(Rect.fromLTWH(sheet.left + 30, y, 70, 14), line)
      ..drawRect(
        Rect.fromLTWH(sheet.left + 130, y, sheet.width - 170 - i * 12, 14),
        line,
      );
  }
  c.drawCircle(
    Offset(sheet.right - 40, sheet.bottom - 40),
    60,
    Paint()..color = const Color(0xFF2E7D5B),
  );
  final image = await recorder.endRecording().toImage(_w, _h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late InMemoryTaskRepository repo;
  late Uint8List photo;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    repo = InMemoryTaskRepository();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
  ];

  Future<void> loadPhoto(WidgetTester tester) async {
    photo = (await tester.runAsync(_photo))!;
  }

  Future<Task> imageTask(
    String id, {
    String? text,
    String rank = 'M',
    int color = 1,
    AttachmentOrigin origin = AttachmentOrigin.camera,
  }) async {
    for (final name in [ImageTiles.fileName(0, 0), 'screen.jpg', 'thumb.jpg']) {
      store.putStaging('a-$id', name, photo);
    }
    final attachment = await store.commit((
      id: 'a-$id',
      origin: origin,
      width: _w,
      height: _h,
      byteSize: photo.length,
    ), DateTime.utc(2026, 9, 20));
    final base = sampleTask(
      id: id,
      text: text ?? 'x',
      rank: rank,
      colorKey: color,
    );
    return base.withContent(text, attachment, base.updatedAt);
  }

  /// Decodifica de verdad las imágenes en pantalla (fuera del reloj falso).
  Future<void> decodeImages(WidgetTester tester) async {
    for (var round = 0; round < 3; round++) {
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
    }
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  Future<void> pumpEditor(
    WidgetTester tester, {
    Task? task,
    double textScale = 1.0,
  }) async {
    await pumpWithApp(
      tester,
      TaskEditorScreen(
        mode: task == null ? EditorMode.first : EditorMode.edit,
        task: task,
      ),
      repo: repo,
      textScale: textScale,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, {double textScale = 1.0}) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpUnaApp(tester, repo: repo, overrides: overrides());
    await tester.pumpAndSettle();
    await decodeImages(tester);
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('CA-007-01: hoja "Añadir a la tarea" (texto ×$scale)', (
      tester,
    ) async {
      await pumpEditor(tester, textScale: scale);
      final plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pumpAndSettle();
      await golden(tester, 'attach_sheet_es_x$scale');
    }, skip: _skip);
  }

  testWidgets('CA-007-04: editor con imagen y texto', (tester) async {
    await loadPhoto(tester);
    await pumpEditor(
      tester,
      task: await imageTask('t1', text: 'Horario del festival'),
    );
    await decodeImages(tester);
    await golden(tester, 'editor_image_es');
  }, skip: _skip);

  testWidgets('CA-007-15: "Preparando imagen…"', (tester) async {
    await pumpEditor(tester);
    importer.sanitizeDelay = const Duration(seconds: 5);
    await tester.tap(find.bySemanticsLabel('Añadir foto, imagen o archivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir imagen'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    await golden(tester, 'editor_preparing_es');
    await tester.pump(const Duration(seconds: 5));
  }, skip: _skip);

  for (final scale in [1.0, 2.0]) {
    testWidgets('CA-007-08: tarea actual con imagen y pie (texto ×$scale)', (
      tester,
    ) async {
      await loadPhoto(tester);
      await repo.insert(
        await imageTask(
          't1',
          text: 'Llevar el horario del festival impreso a la reunión',
        ),
      );
      await pumpApp(tester, textScale: scale);
      expect(find.byType(TaskImage), findsOneWidget);
      await golden(tester, 'current_task_image_es_x$scale');
    }, skip: _skip);
  }

  testWidgets('CA-007-08: foto sin texto (sin pie)', (tester) async {
    await loadPhoto(tester);
    await repo.insert(await imageTask('t1'));
    await pumpApp(tester);
    await golden(tester, 'current_task_photo_es');
  }, skip: _skip);

  testWidgets('CA-007-19: "Adjunto no disponible"', (tester) async {
    await loadPhoto(tester);
    await repo.insert(await imageTask('t1', text: 'Horario del festival'));
    store.removeFile('a-t1', ImageTiles.fileName(0, 0));
    await pumpApp(tester);
    await golden(tester, 'missing_attachment_es');
  }, skip: _skip);

  testWidgets('CA-007-20: listado con miniaturas e insignia', (tester) async {
    await loadPhoto(tester);
    await repo.insert(await imageTask('t1', text: 'Horario', rank: 'A'));
    await repo.insert(sampleTask(id: 't2', text: 'Comprar pan', rank: 'B'));
    await repo.insert(
      await imageTask(
        't3',
        rank: 'C',
        color: 3,
        origin: AttachmentOrigin.gallery,
      ),
    );
    await repo.insert(await imageTask('t4', text: 'Mapa', rank: 'D', color: 4));
    store.removeFile('a-t4', ImageTiles.fileName(0, 0));
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    await decodeImages(tester);
    await golden(tester, 'task_list_images_es');
  }, skip: _skip);
}
