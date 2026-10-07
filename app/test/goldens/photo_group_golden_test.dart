// Goldens de la spec 016 (T-016-11): la pila de fotos, "Foto no disponible" en
// la pila y "Preparando foto 2 de 5…". Se generan y comparan solo en Linux (CI,
// etiqueta `actualizar-goldens`): ver docs/testing.md, "Goldens". Los PNG no se
// suben desde el Mac. T-016-22 añade el aviso compuesto, el carrusel con puntos
// y "Foto no disponible" del carrusel, en ES y EN y a ×1,0 y ×2,0.
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/import_notice_banner.dart';
import 'package:app/features/attachments/photo_missing_box.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/sticky_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/fake_image_importer.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

const _w = 300;
const _h = 400;

/// Tres "fotos" distinguibles (fondo de un color y un número grande) para ver
/// cuál va arriba y cómo se recortan.
Future<List<ImageProvider>> _photos(WidgetTester tester, int n) async {
  final bytes = await tester.runAsync(() => _photoBytes(n));
  return [for (final b in bytes!) MemoryImage(b)];
}

Future<List<Uint8List>> _photoBytes(int n) async {
  final colors = [
    const Color(0xFFD9803A),
    const Color(0xFF3A8FB7),
    const Color(0xFF6BA368),
  ];
  final out = <Uint8List>[];
  for (var i = 0; i < n; i++) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.drawRect(
      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      Paint()..color = colors[i % colors.length],
    );
    c.drawRect(
      Rect.fromLTWH(30, 40, _w - 60.0, _h - 80.0),
      Paint()..color = const Color(0xFFFAFAF5),
    );
    final text = TextPainter(
      text: TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          fontFamily: UnaFonts.display,
          fontSize: 140,
          color: Color(0xFF2B2B2B),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(c, Offset((_w - text.width) / 2, (_h - text.height) / 2));
    final image = await recorder.endRecording().toImage(_w, _h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    out.add(data!.buffer.asUint8List());
  }
  return out;
}

void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpPreview(
    WidgetTester tester, {
    required int shown,
    required int count,
    Set<int> missing = const {},
    bool preparing = false,
    Locale locale = const Locale('es'),
    double textScale = 1.0,
  }) async {
    final photos = await _photos(tester, shown);
    await pumpWithApp(
      tester,
      Material(
        color: UnaColors.paper,
        child: StickyNote(
          colorKey: 1,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                UnaSpace.ml,
                UnaSizes.attachPreviewTop + 56,
                UnaSpace.l,
                UnaSpace.xxl * 3,
              ),
              child: AttachmentPreview(
                image: null,
                stack: PhotoStack(
                  photos: [
                    for (var i = 0; i < shown; i++)
                      StackPhoto(
                        image: missing.contains(i) ? null : photos[i],
                        aspectRatio: _w / _h,
                      ),
                  ],
                  count: count,
                ),
                semanticLabel: '',
                preparingLabel: locale.languageCode == 'es'
                    ? 'Preparando foto 2 de 5…'
                    : 'Preparing photo 2 of 5…',
                cancelLabel: locale.languageCode == 'es'
                    ? 'Cancelar'
                    : 'Cancel',
                onRemove: () {},
                preparing: preparing,
                onCancelPreparing: () {},
                focusSignal: 0,
                cancelFocusSignal: 0,
              ),
            ),
          ),
        ),
      ),
      locale: locale,
      textScale: textScale,
    );
    await tester.pump();
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    await tester.pump();
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('CA-016-06: pila de 3 fotos con "3 fotos" (texto ×$scale)', (
      tester,
    ) async {
      await pumpPreview(tester, shown: 3, count: 3, textScale: scale);
      await golden(tester, 'photo_stack_3_es_x$scale');
    }, skip: _skip);
  }

  testWidgets('CA-016-06: pila de 2 fotos con "2 fotos"', (tester) async {
    await pumpPreview(tester, shown: 2, count: 2);
    await golden(tester, 'photo_stack_2_es');
  }, skip: _skip);

  testWidgets('CA-016-06: pila de 10 fotos en inglés', (tester) async {
    await pumpPreview(tester, shown: 3, count: 10, locale: const Locale('en'));
    await golden(tester, 'photo_stack_10_en');
  }, skip: _skip);

  testWidgets('CA-016-18a: una foto de la pila no está disponible', (
    tester,
  ) async {
    await pumpPreview(tester, shown: 3, count: 3, missing: {1});
    await golden(tester, 'photo_stack_missing_es');
  }, skip: _skip);

  for (final scale in [1.0, 2.0]) {
    testWidgets('CA-016-04: "Preparando foto 2 de 5…" (texto ×$scale)', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        shown: 3,
        count: 3,
        preparing: true,
        textScale: scale,
      );
      await golden(tester, 'photo_preparing_es_x$scale');
    }, skip: _skip);
  }

  group('CA-016-21: el aviso compuesto del editor', () {
    late MemoryAttachmentStore store;
    late _DrawnImporter importer;

    setUp(() {
      store = MemoryAttachmentStore();
      importer = _DrawnImporter(store);
    });

    Future<void> pumpNotice(
      WidgetTester tester, {
      Locale locale = const Locale('es'),
      double textScale = 1.0,
    }) async {
      importer.photos = (await tester.runAsync(() => _photoBytes(3)))!;
      importer.manyTotal = 12;
      importer.copyErrorsByToken['content://many-0'] = const ImageImportFailure(
        ImageImportError.unsupportedType,
      );
      importer.copyErrorsByToken['content://many-3'] = const ImageImportFailure(
        ImageImportError.unsupportedType,
      );
      final english = locale.languageCode == 'en';
      await pumpWithApp(
        tester,
        const TaskEditorScreen(mode: EditorMode.first),
        repo: InMemoryTaskRepository(),
        locale: locale,
        textScale: textScale,
        overrides: [
          attachmentStoreProvider.overrideWithValue(store),
          imageImporterProvider.overrideWithValue(importer),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel(
          english
              ? 'Add a photo, image or file'
              : 'Añadir foto, imagen o archivo',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(english ? 'Upload images' : 'Subir imágenes'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ImportNoticeBanner), findsOneWidget);
      await _decode(tester);
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('CA-016-21: pila de 3 y el aviso "Solo se usarán las 10 '
          'primeras…" (ES, texto ×$scale)', (tester) async {
        await pumpNotice(tester, textScale: scale);
        await _golden(tester, 'photo_notice_es_x$scale');
      }, skip: _skip);
    }

    testWidgets('CA-016-21: el aviso compuesto en inglés', (tester) async {
      await pumpNotice(tester, locale: const Locale('en'));
      await _golden(tester, 'photo_notice_en_x1.0');
    }, skip: _skip);
  });

  group('CA-016-08/09/11/18a: el carrusel en la pantalla principal', () {
    late MemoryAttachmentStore store;
    late FakeImageImporter importer;
    late List<Uint8List> bytes;

    setUp(() {
      store = MemoryAttachmentStore();
      importer = FakeImageImporter(store);
    });

    /// [n] fotos de 300 × 400 con su número dibujado, ya guardadas.
    Future<Task> groupTask(WidgetTester tester, int n) async {
      bytes = (await tester.runAsync(() => _photoBytes(n)))!;
      final all = <Attachment>[];
      for (var i = 0; i < n; i++) {
        all.add(
          await store.commit(
            stageImage(store, 'g$i', width: _w, height: _h),
            DateTime.utc(2026, 9, 20),
          ),
        );
        for (final name in [
          ImageTiles.fileName(0, 0),
          'screen.jpg',
          'thumb.jpg',
        ]) {
          store.putStored('g$i', name, bytes[i]);
        }
      }
      final base = sampleTask(
        id: 't1',
        text: 'Horario del festival',
        colorKey: 3,
      );
      return base.withContent(
        'Horario del festival',
        null,
        base.updatedAt,
        attachments: all,
      );
    }

    Future<void> pumpScreen(
      WidgetTester tester,
      Task task, {
      Locale locale = const Locale('es'),
      double textScale = 1.0,
    }) async {
      await pumpWithApp(
        tester,
        CurrentTaskScreen(task: task),
        locale: locale,
        textScale: textScale,
        overrides: [
          attachmentStoreProvider.overrideWithValue(store),
          imageImporterProvider.overrideWithValue(importer),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await _decode(tester);
    }

    Future<void> swipeNext(WidgetTester tester) async {
      await tester.timedDragFrom(
        const Offset(330, 400),
        const Offset(-250, 0),
        const Duration(milliseconds: 320),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _decode(tester);
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('CA-016-09/11: carrusel de 3 fotos con los puntos bajo el '
          'pie (ES, texto ×$scale)', (tester) async {
        await pumpScreen(tester, await groupTask(tester, 3), textScale: scale);
        await _golden(tester, 'photo_carousel_es_x$scale');
      }, skip: _skip);
    }

    testWidgets('CA-016-09/11: carrusel en la segunda foto (EN)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        await groupTask(tester, 3),
        locale: const Locale('en'),
      );
      await swipeNext(tester);
      await _golden(tester, 'photo_carousel_second_en_x1.0');
    }, skip: _skip);

    for (final locale in ['es', 'en']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('CA-016-18a: "Foto no disponible" en el carrusel '
            '($locale, texto ×$scale)', (tester) async {
          final task = await groupTask(tester, 3);
          store.removeFile(task.attachments[1].id, 'full-0-0.jpg');
          await pumpScreen(
            tester,
            task,
            locale: Locale(locale),
            textScale: scale,
          );
          await swipeNext(tester);
          expect(find.byType(PhotoMissingBox), findsOneWidget);
          await _golden(tester, 'photo_carousel_missing_${locale}_x$scale');
        }, skip: _skip);
      }
    }
  });
}

/// Decodifica de verdad las imágenes en pantalla (fuera del reloj falso).
Future<void> _decode(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

/// El importador falso, con las "fotos" dibujadas en lugar del PNG de 1 px.
class _DrawnImporter extends FakeImageImporter {
  _DrawnImporter(this._store) : super(_store);

  final MemoryAttachmentStore _store;
  List<Uint8List> photos = const [];
  var _n = 0;

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) async {
    final staged = await super.sanitize(
      id,
      type,
      origin,
      maxPixels: maxPixels,
      storedMaxPixels: storedMaxPixels,
    );
    final bytes = photos[_n++ % photos.length];
    for (final name in ['screen.jpg', 'thumb.jpg']) {
      _store.putStaging(id, name, bytes);
    }
    return staged;
  }
}
