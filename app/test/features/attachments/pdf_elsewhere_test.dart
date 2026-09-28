import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/attachments/task_thumbnail.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../task_list/list_harness.dart';

const _frame = Duration(milliseconds: 16);

/// Lo que "se ve" en el visor falso: un color que no sale en ninguna otra
/// parte de la pantalla (hace de la página visible).
const _visiblePage = Color(0xFF12AB34);

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late InMemoryTaskRepository repo;

  setUp(() {
    store = MemoryAttachmentStore();
    repo = InMemoryTaskRepository();
    taskPdfCalls.clear();
  });

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    pdfImporterProvider.overrideWithValue(FakePdfImporter(store)),
    // El visor pinta "la página visible".
    taskPdfBuilderProvider.overrideWithValue((args) {
      taskPdfCalls.add(args);
      return const ColoredBox(key: Key('fake-task-pdf'), color: _visiblePage);
    }),
  ];

  Future<Task> pdfTask(
    String id, {
    String? text,
    required String rank,
    String? name = 'Programa.pdf',
    int color = 1,
  }) async {
    final attachmentId = 'p-$id';
    store
      ..putStaging(attachmentId, 'document.pdf', Uint8List.fromList(pdfHead))
      ..putStaging(attachmentId, 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      StagedPdf(
        id: attachmentId,
        byteSize: 2400000,
        pageCount: 12,
        width: 595,
        height: 842,
        originalName: name,
      ),
      DateTime.utc(2026, 9, 27),
    );
    final base = sampleTask(
      id: id,
      text: text ?? 'x',
      rank: rank,
      colorKey: color,
    );
    return base.withContent(text, attachment, base.updatedAt);
  }

  Future<void> openListWith(WidgetTester tester, List<Task> tasks) async {
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(tester, repo: repo, overrides: overrides());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
  }

  TaskListRow rowFor(WidgetTester tester, String id) => tester
      .widgetList<TaskListRow>(find.byType(TaskListRow))
      .firstWhere((r) => r.task.id == id);

  Finder thumbOf(WidgetTester tester, String id) => find.descendant(
    of: find.byWidget(rowFor(tester, id)),
    matching: find.byType(TaskThumbnail),
  );

  group('CA-008-19: listado', () {
    testWidgets('insignia negra de 44 px con "PDF" entre el asa y el texto', (
      tester,
    ) async {
      await openListWith(tester, [
        await pdfTask('t1', text: 'Congreso', rank: 'A'),
        await pdfTask('t2', text: 'Billetes', rank: 'B'),
      ]);

      for (final id in ['t1', 't2']) {
        expect(tester.getSize(thumbOf(tester, id)), const Size(44, 44));
        expect(
          find.descendant(of: thumbOf(tester, id), matching: find.text('PDF')),
          findsOneWidget,
        );
      }
      // Negra, con el texto en el tamaño de la insignia.
      final badge = find.descendant(
        of: thumbOf(tester, 't2'),
        matching: find.byType(ColoredBox),
      );
      expect(tester.widget<ColoredBox>(badge.first).color, UnaColors.ink);
      final label = tester.widget<Text>(
        find.descendant(of: thumbOf(tester, 't2'), matching: find.text('PDF')),
      );
      expect(label.style!.fontSize, UnaFontSizes.badge);
      expect(label.style!.color, UnaColors.onInk);
      // Entre el asa y el texto.
      final thumb = tester.getRect(thumbOf(tester, 't2'));
      final text = tester.getRect(find.text('Billetes'));
      expect(thumb.right, lessThan(text.left));
      final row = tester.getRect(find.byWidget(rowFor(tester, 't2')));
      expect(thumb.left - row.left, greaterThan(34));
    });

    testWidgets('también con "Adjunto no disponible"', (tester) async {
      final t1 = await pdfTask('t1', text: 'Congreso', rank: 'A');
      final t2 = await pdfTask('t2', text: 'Billetes', rank: 'B');
      store.removeFile('p-t2', 'document.pdf');
      await openListWith(tester, [t1, t2]);
      expect(
        find.descendant(of: thumbOf(tester, 't2'), matching: find.text('PDF')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin texto, la fila dice el nombre del archivo (o "PDF")', (
      tester,
    ) async {
      await openListWith(tester, [
        sampleTask(id: 't0', text: 'Primera', rank: 'A'),
        await pdfTask('t1', rank: 'B'),
        await pdfTask('t2', rank: 'C', name: null),
      ]);
      expect(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't1')),
          matching: find.text('Programa.pdf'),
        ),
        findsOneWidget,
      );
      // Sin nombre, "PDF" como texto (y la insignia).
      expect(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't2')),
          matching: find.text('PDF'),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('CA-008-20: el lector lee "{n} de {total}: {texto}. Con PDF" '
        'y, sin texto, el nombre; la insignia es decorativa', (tester) async {
      final handle = tester.ensureSemantics();
      await openListWith(tester, [
        await pdfTask('t1', text: 'Congreso', rank: 'A'),
        await pdfTask('t2', rank: 'B'),
        await pdfTask('t3', text: 'Billetes', rank: 'C'),
      ]);
      expect(
        find.bySemanticsLabel('1 de 3. Tarea actual: Congreso. Con PDF'),
        findsOneWidget,
      );
      // [Pendiente: pregunta al propietario] la spec dice "{nombre}. PDF"
      // (CA-008-20) y la tabla de textos, `a11yRowWithPdf` con el nombre.
      expect(
        find.bySemanticsLabel('2 de 3: Programa.pdf. Con PDF'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('3 de 3: Billetes. Con PDF'),
        findsOneWidget,
      );
      // La insignia no se lee por separado.
      expect(find.bySemanticsLabel('PDF'), findsNothing);
      handle.dispose();
    });

    testWidgets('CA-004-01: eliminar una fila sin texto dice el nombre', (
      tester,
    ) async {
      await openListWith(tester, [
        sampleTask(id: 't0', text: 'Primera', rank: 'A'),
        await pdfTask('t1', rank: 'B'),
      ]);
      await tester.tap(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't1')),
          matching: find.byWidgetPredicate(
            (w) => w is UnaIcon && w.icon == UnaIcons.trash,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(DeleteConfirmSheet), findsOneWidget);
      expect(
        tester
            .widget<DeleteConfirmSheet>(find.byType(DeleteConfirmSheet))
            .label,
        'Programa.pdf',
      );
    });
  });

  group('CA-008-19: completar y eliminar', () {
    /// La imagen fija de la cara (lo que se veía del PDF), si la hay.
    Future<Color?> faceColor(WidgetTester tester, Finder overlay) async {
      final images = tester
          .widgetList<RawImage>(
            find.descendant(of: overlay, matching: find.byType(RawImage)),
          )
          .map((r) => r.image)
          .whereType<ui.Image>()
          .toList();
      if (images.isEmpty) return null;
      final image = images.first;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final data = bytes!;
      // Centro de la imagen.
      final i = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
      return Color.fromARGB(
        data.getUint8(i + 3),
        data.getUint8(i),
        data.getUint8(i + 1),
        data.getUint8(i + 2),
      );
    }

    testWidgets('CL-003-4/8: la rotura muestra la franja y lo que se veía del '
        'PDF, y el anuncio dice "Siguiente: {nombre}"', (tester) async {
      final announcements = listenAnnouncements(tester);
      await repo.insert(await pdfTask('t1', text: 'Congreso', rank: 'A'));
      await repo.insert(await pdfTask('t2', rank: 'B'));
      await pumpUnaApp(
        tester,
        repo: repo,
        screenReader: true,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCompleteButton)),
      );
      await tester.pump();
      await tester.pump(UnaMotion.holdToComplete);
      await tester.pump(_frame);
      await gesture.up();
      await tester.pump(UnaMotion.holdDonePause);
      await tester.pump(_frame);
      await tester.pump(const Duration(milliseconds: 100));

      final overlay = find.byType(CelebrationOverlay);
      expect(overlay, findsOneWidget);
      // La franja, en las dos mitades.
      expect(
        find.descendant(of: overlay, matching: find.byType(PdfStrip)),
        findsWidgets,
      );
      // Lo que se veía (la página visible, con su zoom), no la versión de
      // pantalla guardada.
      expect(await faceColor(tester, overlay), _visiblePage);
      expect(find.byType(MissingAttachmentCard), findsNothing);
      await tester.pumpAndSettle();
      expect(
        announcements,
        contains('Tarea completada. Siguiente: Programa.pdf'),
      );
      // ADR-0012: los archivos de la completada ya no están.
      expect(await store.storedIds(), {'p-t2'});
    });

    for (final reduced in [false, true]) {
      testWidgets(
        'el arrugado${reduced ? ' (reducir movimiento: fundido)' : ''} '
        'muestra lo que se veía, la confirmación dice el nombre y el '
        'anuncio también',
        (tester) async {
          final announcements = listenAnnouncements(tester);
          await repo.insert(await pdfTask('t1', rank: 'A', name: 'Mapa.pdf'));
          await repo.insert(await pdfTask('t2', rank: 'B'));
          await pumpUnaApp(
            tester,
            repo: repo,
            reduced: reduced,
            overrides: overrides(),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Eliminar'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DeleteConfirmSheet>(find.byType(DeleteConfirmSheet))
                .label,
            'Mapa.pdf',
          );
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is BrutalButton && w.label == 'Eliminar',
            ),
          );
          await tester.pump(_frame);
          await tester.pump(_frame);
          await tester.pump(
            (reduced ? UnaMotion.crumpleReducedFade : UnaMotion.crumple) * 0.3,
          );

          final overlay = find.byType(CrumpleOverlay);
          expect(overlay, findsOneWidget);
          expect(
            find.descendant(of: overlay, matching: find.byType(PdfStrip)),
            findsOneWidget,
          );
          expect(await faceColor(tester, overlay), _visiblePage);
          expect(find.byType(MissingAttachmentCard), findsNothing);
          await tester.pump(UnaMotion.crumple);
          await tester.pumpAndSettle();
          expect(
            announcements,
            contains('Tarea eliminada. Siguiente: Programa.pdf'),
          );
          expect(await store.storedIds(), {'p-t2'});
        },
      );
    }
  });
}
