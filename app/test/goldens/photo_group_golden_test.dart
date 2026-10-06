// Goldens de la spec 016 (T-016-11): la pila de fotos, "Foto no disponible" en
// la pila y "Preparando foto 2 de 5…". Se generan y comparan solo en Linux (CI,
// etiqueta `actualizar-goldens`): ver docs/testing.md, "Goldens". Los PNG no se
// suben desde el Mac. T-016-22 añade el aviso compuesto y el carrusel.
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/ui/sticky_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

const _w = 300;
const _h = 400;

/// Tres "fotos" distinguibles (fondo de un color y un número grande) para ver
/// cuál va arriba y cómo se recortan.
Future<List<ImageProvider>> _photos(WidgetTester tester, int n) async {
  final colors = [
    const Color(0xFFD9803A),
    const Color(0xFF3A8FB7),
    const Color(0xFF6BA368),
  ];
  final bytes = await tester.runAsync(() async {
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
  });
  return [for (final b in bytes!) MemoryImage(b)];
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
}
