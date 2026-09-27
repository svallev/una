import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/features/attachments/attach_sheet.dart';
import 'package:app/features/attachments/attachment_import_controller.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/sheet_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

final _plus = find.bySemanticsLabel('Añadir foto, imagen o archivo');

void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late FakePdfImporter pdfs;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    pdfs = FakePdfImporter(store);
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    EditorMode mode = EditorMode.first,
    Locale locale = const Locale('es'),
    double textScale = 1.0,
  }) async {
    await pumpWithApp(
      tester,
      TaskEditorScreen(
        mode: mode,
        task: mode == EditorMode.edit ? sampleTask() : null,
      ),
      locale: locale,
      textScale: textScale,
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        imageImporterProvider.overrideWithValue(importer),
        pdfImporterProvider.overrideWithValue(pdfs),
        ...fakePdfViews,
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    expect(find.byType(AttachSheet), findsOneWidget);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TaskEditorScreen)));

  for (final mode in EditorMode.values) {
    testWidgets(
      'CA-007-01: en el editor (${mode.name}), (+) abre "Añadir a la tarea" '
      'con cuatro filas de dos líneas',
      (tester) async {
        await pumpEditor(tester, mode: mode);
        await openSheet(tester);

        expect(find.bySemanticsLabel('Añadir a la tarea'), findsWidgets);
        for (final (title, hint) in [
          ('Hacer foto', 'Con la cámara · va arriba del todo'),
          ('Subir imagen', 'Desde tu galería · va arriba del todo'),
          ('Subir archivo', 'PDF · va arriba del todo'),
          ('Cargar URL', 'Una página web · va arriba del todo'),
        ]) {
          expect(find.text(title), findsOneWidget);
          expect(find.text(hint), findsOneWidget);
        }
        final rows = find.byType(SheetRow);
        expect(rows, findsNWidgets(4));
        for (final row in rows.evaluate()) {
          expect(
            tester.getSize(find.byWidget(row.widget)).height,
            greaterThanOrEqualTo(UnaSizes.sheetRowTall),
          );
        }
      },
    );
  }

  testWidgets('CA-007-01: el lector lee cada fila con su segunda línea', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpEditor(tester);
    await openSheet(tester);

    for (final label in [
      'Hacer foto. Con la cámara, va arriba del todo',
      'Subir imagen. Desde tu galería, va arriba del todo',
      'Subir archivo. PDF, va arriba del todo',
      'Cargar URL. Una página web, va arriba del todo',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(
          label: label,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    }
    expect(find.bySemanticsLabel('Cerrar'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('CA-007-01: en inglés', (tester) async {
    await pumpEditor(tester, locale: const Locale('en'));
    await tester.tap(find.bySemanticsLabel('Add a photo, image or file'));
    await tester.pumpAndSettle();
    for (final text in [
      'Take photo',
      'With the camera · goes on top',
      'Upload image',
      'From your gallery · goes on top',
      'Upload file',
      'Load URL',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('CA-007-01: se cierra con la X', (tester) async {
    await pumpEditor(tester);
    await openSheet(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SheetHeader),
        matching: find.byType(InkResponse),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttachSheet), findsNothing);
    expect(importer.picks, isEmpty);
  });

  testWidgets('CA-007-01: se cierra tocando fuera', (tester) async {
    await pumpEditor(tester);
    await openSheet(tester);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.byType(AttachSheet), findsNothing);
  });

  testWidgets('CA-007-01: se cierra con el gesto atrás', (tester) async {
    await pumpEditor(tester);
    await openSheet(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AttachSheet), findsNothing);
    expect(find.byType(TaskEditorScreen), findsOneWidget);
  });

  testWidgets('CA-007-01 / DEV-21: se cierra deslizando hacia abajo', (
    tester,
  ) async {
    await pumpEditor(tester);
    await openSheet(tester);
    await tester.fling(find.text('Hacer foto'), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(find.byType(AttachSheet), findsNothing);
  });

  testWidgets(
    'CA-007-01 / DEV-18: "Cargar URL" se ve activa pero no hace nada hasta '
    'la 009',
    (tester) async {
      await pumpEditor(tester);
      await openSheet(tester);
      await tester.tap(find.text('Cargar URL'));
      await tester.pumpAndSettle();
      expect(find.byType(AttachSheet), findsOneWidget);
      expect(importer.picks, isEmpty);
      expect(pdfs.picks, isEmpty);
      for (final row in tester.widgetList<SheetRow>(find.byType(SheetRow))) {
        expect(row.enabled, isTrue);
      }
    },
  );

  testWidgets(
    'CA-008-01: "Subir archivo" cierra la hoja y abre el selector de PDF',
    (tester) async {
      await pumpEditor(tester, mode: EditorMode.create);
      await openSheet(tester);
      await tester.tap(find.text('Subir archivo'));
      await tester.pumpAndSettle();
      expect(find.byType(AttachSheet), findsNothing);
      expect(pdfs.picks, hasLength(1));
      expect(importer.picks, isEmpty);
      expect(containerOf(tester).read(attachmentImportProvider).pdf, isNotNull);
    },
  );

  for (final (row, origin) in [
    ('Hacer foto', AttachmentOrigin.camera),
    ('Subir imagen', AttachmentOrigin.gallery),
  ]) {
    testWidgets(
      'CA-007-02/03: "$row" cierra la hoja y abre ${origin.name} del sistema',
      (tester) async {
        await pumpEditor(tester, mode: EditorMode.create);
        await openSheet(tester);
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();

        expect(find.byType(AttachSheet), findsNothing);
        expect(importer.origins, [origin]);
        expect(
          containerOf(tester).read(attachmentImportProvider).image,
          isNotNull,
        );
      },
    );
  }

  testWidgets(
    'CA-007-15: mientras se prepara la imagen, (+) y "Continuar" no hacen nada',
    (tester) async {
      await pumpEditor(tester, mode: EditorMode.create);
      await tester.enterText(find.byType(TextField), 'Algo');
      importer.sanitizeDelay = const Duration(seconds: 5);
      await openSheet(tester);
      await tester.tap(find.text('Subir imagen'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        containerOf(tester).read(attachmentImportProvider).preparing,
        isTrue,
      );

      await tester.tap(_plus);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AttachSheet), findsNothing);

      await tester.tap(find.text('Continuar'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      // No sube la hoja "¿Dónde la pones?".
      expect(find.byType(BottomSheet), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(
        containerOf(tester).read(attachmentImportProvider).image,
        isNotNull,
      );
    },
  );

  testWidgets('CA-007-01: con texto al 200 % las filas crecen sin cortarse', (
    tester,
  ) async {
    await pumpEditor(tester, textScale: 2.0);
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    final first = tester.getSize(find.byType(SheetRow).first).height;
    expect(first, greaterThan(UnaSizes.sheetRowTall));
  });
}
