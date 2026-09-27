import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfPageLayout;

import '../../support/attachments.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;

  setUp(() {
    store = MemoryAttachmentStore();
    taskPdfCalls.clear();
  });

  Future<Task> pdfTask({
    String? text = 'Programa',
    String? name = 'Programa.pdf',
  }) async {
    store
      ..putStaging(
        'p1',
        'document.pdf',
        Uint8List.fromList('%PDF-1.7'.codeUnits),
      )
      ..putStaging('p1', 'screen.jpg', tinyImage);
    final attachment = await store.commit(
      StagedPdf(
        id: 'p1',
        byteSize: 2400000,
        pageCount: 12,
        width: 595,
        height: 842,
        originalName: name,
      ),
      DateTime.utc(2026, 9, 27),
    );
    final base = sampleTask(text: text ?? 'x', colorKey: 2);
    return base.withContent(text, attachment, base.updatedAt);
  }

  Future<void> pumpScreen(WidgetTester tester, Task task) async {
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: task),
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        ...fakePdfViews,
      ],
    );
    await tester.pumpAndSettle();
  }

  group('CA-008-08: tarea actual con PDF', () {
    testWidgets('franja, visor al ancho, logotipo, menú y botón de completar', (
      tester,
    ) async {
      await pumpScreen(tester, await pdfTask());

      final strip = tester.widget<PdfStrip>(find.byType(PdfStrip));
      expect(
        (strip.type, strip.name, strip.size),
        ('PDF', 'Programa.pdf', '2,4 MB'),
      );
      expect(find.byType(SquareIconButton), findsOneWidget);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      // El visor ocupa todo el ancho (sin los márgenes de 24 de la cabecera).
      final viewer = tester.getRect(find.byKey(const Key('fake-task-pdf')));
      expect(viewer.left, 0);
      expect(viewer.width, 390);
      // Entre la franja y el botón.
      expect(
        viewer.top,
        greaterThan(tester.getRect(find.byType(PdfStrip)).bottom - 1),
      );
      expect(
        viewer.bottom,
        lessThan(tester.getRect(find.byType(HoldToCompleteButton)).top),
      );
    });

    testWidgets(
      'el visor recibe el PDF, la versión de pantalla, el texto y el color de la nota',
      (tester) async {
        final task = await pdfTask();
        await pumpScreen(tester, task);
        final args = taskPdfCalls.last;
        expect(args.source.key, task.attachment!.documentPath);
        expect(args.source.bytes, isNotNull);
        expect(args.caption, 'Programa');
        expect(args.captionColor, UnaPalettes.classic[2]);
        // Sin posición guardada: el principio (CA-008-09).
        expect(args.initialPosition, PdfPosition.start);
      },
    );

    testWidgets('la nota es blanca; el color queda en la banda (prototipo)', (
      tester,
    ) async {
      await pumpScreen(tester, await pdfTask());
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == UnaColors.surface,
        ),
        findsWidgets,
      );
      final menu = tester.widget<SquareIconButton>(
        find.byType(SquareIconButton),
      );
      expect(menu.fill, UnaColors.surface);
    });

    testWidgets('CA-008-20: la lectura dice el tipo, el nombre y el tamaño', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, await pdfTask());
      expect(
        find.bySemanticsLabel(
          'Tarea actual: Programa. Con PDF, Programa.pdf, 2,4 MB',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('CA-008-20: sin texto, el nombre; sin nombre, "PDF"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, await pdfTask(text: null, name: null));
      expect(
        find.bySemanticsLabel('Tarea actual: PDF. PDF, 2,4 MB'),
        findsOneWidget,
      );
      expect(taskPdfCalls.last.caption, isNull);
      handle.dispose();
    });
  });

  testWidgets('CA-008-09: el visor empieza en la última posición guardada', (
    tester,
  ) async {
    final task = await pdfTask();
    await store.writePosition('p1', const PdfPosition(page: 7, offset: 0.25));
    await pumpScreen(tester, task);
    expect(
      taskPdfCalls.last.initialPosition,
      const PdfPosition(page: 7, offset: 0.25),
    );
  });

  test(
    'CA-008-09: la posición visible sale de la parte de arriba de la vista',
    () {
      final layout = PdfPageLayout(
        pageLayouts: const [
          Rect.fromLTWH(0, 100, 600, 800),
          Rect.fromLTWH(0, 903, 600, 800),
        ],
        documentSize: const Size(600, 1703),
      );
      expect(
        positionIn(layout, const Rect.fromLTWH(0, 0, 600, 900)),
        PdfPosition.start,
      );
      expect(
        positionIn(layout, const Rect.fromLTWH(0, 500, 600, 900)),
        const PdfPosition(page: 1, offset: 0.5),
      );
      expect(
        positionIn(layout, const Rect.fromLTWH(0, 1103, 600, 900)).page,
        2,
      );
    },
  );
}
