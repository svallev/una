// Pila de fotos del editor, "Foto no disponible" y la vista previa que las
// acepta (T-016-11; CA-016-06, 18a, 22, CL-016-18). Los widgets aún no están
// conectados al editor (T-016-12a): aquí se prueban con un anfitrión de test.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/photo_missing_box.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Móvil pequeño de CL-016-18.
const _phone = Size(360, 780);

/// Una foto de un solo color (PNG de verdad, decodificada fuera del reloj
/// falso): sirve para ver la etiqueta sobre blanco y sobre negro.
Future<MemoryImage> _solid(WidgetTester tester, Color color) async {
  final bytes = (await tester.runAsync<Uint8List>(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
        .drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = color);
    final image = await recorder.endRecording().toImage(8, 8);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  return MemoryImage(bytes);
}

Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
  await tester.pump();
}

/// Giro (grados) y desplazamiento de la tarjeta [index] de la pila.
({double degrees, Offset offset}) _pose(WidgetTester tester, int index) {
  final t = tester.widget<Transform>(find.byKey(PhotoStack.cardKey(index)));
  final m = t.transform.storage;
  return (
    degrees: math.atan2(m[1], m[0]) * 180 / math.pi,
    offset: Offset(m[12], m[13]),
  );
}

/// Los índices de las tarjetas en el orden en que se pintan (la última, arriba).
List<int> _paintOrder(WidgetTester tester) => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'photo-stack-card-',
                ),
          )
          .evaluate())
    int.parse((e.widget.key! as ValueKey<String>).value.split('-').last),
];

List<StackPhoto> _photos(int n, {Set<int> missing = const {}}) => [
  for (var i = 0; i < n; i++)
    StackPhoto(
      image: missing.contains(i) ? null : MemoryImage(tinyImage),
      aspectRatio: 3 / 4,
    ),
];

void main() {
  setUpAll(loadAppFonts);

  /// El anfitrión: la pila en su recuadro, a la altura del hueco del editor.
  Future<void> pumpStack(
    WidgetTester tester, {
    required List<StackPhoto> photos,
    int? count,
    Locale locale = const Locale('es'),
    double textScale = 1.0,
    bool disableAnimations = false,
    Size size = const Size(390, 844),
  }) async {
    await pumpWithApp(
      tester,
      Scaffold(
        backgroundColor: UnaColors.paper,
        body: Center(
          child: SizedBox(
            width: size.width - 2 * UnaSpace.l,
            height: 420,
            child: PhotoStack(photos: photos, count: count ?? photos.length),
          ),
        ),
      ),
      locale: locale,
      textScale: textScale,
      disableAnimations: disableAnimations,
      size: size,
    );
    await tester.pump();
  }

  group('CA-016-06: la pila del editor', () {
    testWidgets('con 3 fotos: giros -5°, 4° y -1° (como el prototipo) y la '
        'primera arriba', (tester) async {
      await pumpStack(tester, photos: _photos(3));
      // Se pinta de atrás hacia delante: la tercera, la segunda y la primera.
      expect(_paintOrder(tester), [2, 1, 0]);
      final top = _pose(tester, 0);
      final middle = _pose(tester, 1);
      final back = _pose(tester, 2);
      expect(top.degrees, closeTo(UnaMotion.photoStackTiltTop, 0.001));
      expect(top.offset, Offset.zero);
      expect(middle.degrees, closeTo(UnaMotion.photoStackTiltMiddle, 0.001));
      expect(
        middle.offset,
        const Offset(UnaSizes.photoStackMiddleDx, UnaSizes.photoStackMiddleDy),
      );
      expect(back.degrees, closeTo(UnaMotion.photoStackTiltBack, 0.001));
      expect(
        back.offset,
        const Offset(UnaSizes.photoStackBackDx, UnaSizes.photoStackBackDy),
      );
    });

    testWidgets('con 2 fotos: la segunda a 4° detrás de la primera a -1°', (
      tester,
    ) async {
      await pumpStack(tester, photos: _photos(2));
      expect(_paintOrder(tester), [1, 0]);
      expect(_pose(tester, 0).degrees, closeTo(-1, 0.001));
      expect(_pose(tester, 1).degrees, closeTo(4, 0.001));
      expect(
        _pose(tester, 1).offset,
        const Offset(UnaSizes.photoStackMiddleDx, UnaSizes.photoStackMiddleDy),
      );
    });

    testWidgets('con 10 fotos solo se ven las 3 primeras y la etiqueta cuenta '
        'todas', (tester) async {
      await pumpStack(tester, photos: _photos(10).take(3).toList(), count: 10);
      expect(_paintOrder(tester), [2, 1, 0]);
      expect(find.text('10 fotos'), findsOneWidget);
      // Aunque le lleguen más, solo pinta 3.
      await pumpStack(tester, photos: _photos(7), count: 7);
      expect(_paintOrder(tester), [2, 1, 0]);
      expect(find.text('7 fotos'), findsOneWidget);
    });

    testWidgets('cada foto: ancho del 86 %, borde de 3 y sombra dura', (
      tester,
    ) async {
      await pumpStack(tester, photos: _photos(3));
      final box = tester.getSize(find.byType(PhotoStack));
      final card = tester.getSize(
        find
            .descendant(
              of: find.byKey(PhotoStack.cardKey(0)),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        card.width,
        closeTo(box.width * UnaMotion.photoStackWidthFactor, 0.01),
      );
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byKey(PhotoStack.cardKey(0)),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.border!.top.width, UnaBorders.photoStackWidth);
      expect(deco.border!.top.color, UnaColors.ink);
      expect(deco.boxShadow, [UnaShadows.photoStack]);
    });

    testWidgets('la etiqueta "{n} fotos" va abajo a la izquierda, blanco '
        'sobre tinta opaca (≥ 4,5:1), en español e inglés', (tester) async {
      await pumpStack(tester, photos: _photos(3));
      final label = find.text('3 fotos');
      expect(label, findsOneWidget);
      final style = tester.widget<Text>(label).style!;
      expect(style.color, UnaColors.photoCountText);
      expect(style.fontSize, UnaFontSizes.photoCount);
      expect(style.fontWeight, UnaFontWeights.bold);
      final fill = tester
          .widget<ColoredBox>(
            find.ancestor(of: label, matching: find.byType(ColoredBox)).first,
          )
          .color;
      expect(fill, UnaColors.photoCountFill);
      expect(fill.a, 1.0, reason: 'opaca: no depende de la foto');
      final l1 = UnaColors.photoCountText.computeLuminance();
      final l2 = fill.computeLuminance();
      expect((l1 + 0.05) / (l2 + 0.05), greaterThanOrEqualTo(4.5));
      // Abajo a la izquierda de la caja.
      final box = tester.getRect(find.byType(PhotoStack));
      final rect = tester.getRect(
        find.ancestor(of: label, matching: find.byType(ColoredBox)).first,
      );
      expect(rect.left, box.left);
      expect(rect.bottom, box.bottom);

      await pumpStack(tester, photos: _photos(3), locale: const Locale('en'));
      expect(find.text('3 photos'), findsOneWidget);
    });

    for (final (name, color) in [
      ('blanca', const Color(0xFFFFFFFF)),
      ('negra', const Color(0xFF000000)),
    ]) {
      testWidgets('contraste del texto con una foto $name '
          '(textContrastGuideline)', (tester) async {
        final photo = await _solid(tester, color);
        await pumpStack(
          tester,
          photos: [
            for (var i = 0; i < 3; i++)
              StackPhoto(image: photo, aspectRatio: 3 / 4),
          ],
        );
        await _decode(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }

    testWidgets('la pila entera es UN nodo: "Vista previa: 3 fotos", sin '
        'hijos (ni la etiqueta ni las fotos)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpStack(tester, photos: _photos(3, missing: {1}));
      final node = tester.getSemantics(find.byType(PhotoStack));
      expect(node.getSemanticsData().label, 'Vista previa: 3 fotos');
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      expect(find.bySemanticsLabel('3 fotos'), findsNothing);
      expect(find.bySemanticsLabel('Foto no disponible'), findsNothing);

      await pumpStack(tester, photos: _photos(2), locale: const Locale('en'));
      expect(
        tester.getSemantics(find.byType(PhotoStack)).getSemanticsData().label,
        'Preview: 2 photos',
      );
      handle.dispose();
    });

    testWidgets('sin animación: fija con reducir movimiento (y sin él)', (
      tester,
    ) async {
      for (final reduce in [true, false]) {
        await pumpStack(tester, photos: _photos(3), disableAnimations: reduce);
        final before = _pose(tester, 1);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(_pose(tester, 1).degrees, before.degrees);
      }
    });
  });

  group('CA-016-18a: una foto que falta se ve como "Foto no disponible"', () {
    testWidgets('en su sitio de la pila y las demás se ven normales', (
      tester,
    ) async {
      await pumpStack(tester, photos: _photos(3, missing: {1}));
      expect(find.byType(PhotoMissingBox), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(PhotoStack.cardKey(1)),
          matching: find.byType(PhotoMissingBox),
        ),
        findsOneWidget,
      );
      for (final i in [0, 2]) {
        expect(
          find.descendant(
            of: find.byKey(PhotoStack.cardKey(i)),
            matching: find.byType(Image),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Foto no disponible'), findsOneWidget);
      // Con la misma pose que una foto: gira como la segunda de la pila.
      expect(_pose(tester, 1).degrees, closeTo(4, 0.001));
    });

    testWidgets('el recuadro: blanco con borde y sombra, aviso en rojo con el '
        'icono de imagen y sin acción alguna', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWithApp(
        tester,
        const Scaffold(
          body: Center(
            child: SizedBox(width: 240, height: 300, child: PhotoMissingBox()),
          ),
        ),
      );
      final box = find.byType(PhotoMissingBox);
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: box,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.color, UnaColors.surface);
      expect(deco.border!.top.width, UnaBorders.strongWidth);
      expect(deco.border!.top.color, UnaColors.ink);
      expect(deco.boxShadow, [UnaShadows.button]);
      final text = tester.widget<Text>(find.text('Foto no disponible'));
      expect(text.style!.color, UnaColors.error);
      final icon = tester.widget<UnaIcon>(
        find.descendant(of: box, matching: find.byType(UnaIcon)),
      );
      expect(icon.icon, UnaIcons.image);
      expect(icon.color, UnaColors.error);
      // Sin acción: nada que tocar ni enfocar.
      expect(
        find.descendant(of: box, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: box, matching: find.byType(GestureDetector)),
        findsNothing,
      );
      final data = tester
          .getSemantics(find.text('Foto no disponible'))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('en inglés: "Photo unavailable"', (tester) async {
      await pumpWithApp(
        tester,
        const Scaffold(
          body: SizedBox(width: 240, height: 300, child: PhotoMissingBox()),
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Photo unavailable'), findsOneWidget);
    });
  });

  group('CA-016-06 y 04: la vista previa con la pila', () {
    var removed = 0;
    var cancelled = 0;

    Future<void> pumpPreview(
      WidgetTester tester, {
      bool preparing = false,
      int count = 3,
      Locale locale = const Locale('es'),
      double textScale = 1.0,
      Size size = const Size(390, 844),
      bool disableAnimations = false,
      Set<int> missing = const {},
    }) async {
      removed = 0;
      cancelled = 0;
      await pumpWithApp(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(
              UnaSpace.ml,
              UnaSizes.attachPreviewTop,
              UnaSpace.l,
              UnaSpace.l,
            ),
            child: AttachmentPreview(
              image: null,
              stack: PhotoStack(
                photos: _photos(math.min(count, 3), missing: missing),
                count: count,
              ),
              semanticLabel: 'no se usa con la pila',
              preparingLabel: locale.languageCode == 'es'
                  ? 'Preparando foto 2 de 5…'
                  : 'Preparing photo 2 of 5…',
              cancelLabel: locale.languageCode == 'es' ? 'Cancelar' : 'Cancel',
              onRemove: () => removed++,
              preparing: preparing,
              onCancelPreparing: () => cancelled++,
              focusSignal: 0,
              cancelFocusSignal: 0,
            ),
          ),
        ),
        locale: locale,
        textScale: textScale,
        size: size,
        disableAnimations: disableAnimations,
      );
      await tester.pump();
    }

    testWidgets('"Quitar adjunto" (≥ 48 dp) quita el grupo entero de una vez', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPreview(tester);
      final remove = find.bySemanticsLabel('Quitar adjunto');
      expect(remove, findsOneWidget);
      final size = tester.getSize(remove);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(remove);
      expect(removed, 1);
      handle.dispose();
    });

    testWidgets('la pila se lee como un solo nodo, no "Foto"/"Imagen"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPreview(tester);
      expect(find.bySemanticsLabel('Vista previa: 3 fotos'), findsOneWidget);
      expect(find.bySemanticsLabel('no se usa con la pila'), findsNothing);
      handle.dispose();
    });

    testWidgets('"Preparando foto 2 de 5…" con "Cancelar" (≥ 48 dp), sin '
        '"Quitar adjunto" y con la pila fuera de la lectura', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPreview(tester, preparing: true);
      expect(find.text('Preparando foto 2 de 5…'), findsOneWidget);
      expect(find.bySemanticsLabel('Quitar adjunto'), findsNothing);
      expect(find.bySemanticsLabel('Vista previa: 3 fotos'), findsNothing);
      final cancel = find.bySemanticsLabel('Cancelar');
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
      await tester.tap(cancel);
      expect(cancelled, 1);
      handle.dispose();
    });

    testWidgets('en inglés: "Preparing photo 2 of 5…" y "Preview: 3 photos"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPreview(tester, locale: const Locale('en'));
      expect(find.bySemanticsLabel('Preview: 3 photos'), findsOneWidget);
      await pumpPreview(tester, preparing: true, locale: const Locale('en'));
      expect(find.text('Preparing photo 2 of 5…'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('CL-016-18: texto al 200 % en 360 dp, nada se corta', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        size: _phone,
        textScale: 2,
        count: 10,
        missing: {1},
      );
      expect(tester.takeException(), isNull);
      final preview = tester.getRect(find.byType(AttachmentPreview));
      // La etiqueta, entera y dentro del recuadro.
      final label = tester.getRect(find.text('10 fotos'));
      expect(preview.inflate(0.5).contains(label.topLeft), isTrue);
      expect(preview.inflate(0.5).contains(label.bottomRight), isTrue);
      // "Foto no disponible" entero y dentro de su recuadro.
      final missing = tester.getRect(find.text('Foto no disponible'));
      expect(preview.inflate(0.5).contains(missing.topLeft), isTrue);
      expect(preview.inflate(0.5).contains(missing.bottomRight), isTrue);
      // "Preparando foto 2 de 5…" también.
      await pumpPreview(tester, size: _phone, textScale: 2, preparing: true);
      expect(tester.takeException(), isNull);
      final prep = tester.getRect(find.text('Preparando foto 2 de 5…'));
      final box = tester.getRect(find.byType(AttachmentPreview));
      expect(box.inflate(0.5).contains(prep.topLeft), isTrue);
      expect(box.inflate(0.5).contains(prep.bottomRight), isTrue);
      expect(
        tester.getSize(find.bySemanticsLabel('Cancelar')).height,
        greaterThanOrEqualTo(48),
      );
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('guías de tamaño de toque, etiquetas y contraste (×$scale)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpPreview(tester, size: _phone, textScale: scale);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await pumpPreview(
          tester,
          size: _phone,
          textScale: scale,
          preparing: true,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('con reducir movimiento: pila fija y barra sin animar', (
      tester,
    ) async {
      await pumpPreview(tester, preparing: true, disableAnimations: true);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
