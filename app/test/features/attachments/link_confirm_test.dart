import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';
import '../../support/fake_pdf_importer.dart';
import '../../support/fake_pdf_view.dart';
import '../../support/pump_app.dart';

class _Opener implements LinkOpener {
  bool available = true;
  final opened = <LinkTarget>[];
  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return available;
  }
}

void main() {
  late MemoryAttachmentStore store;
  late _Opener opener;

  setUp(() {
    store = MemoryAttachmentStore();
    opener = _Opener();
    taskPdfCalls.clear();
  });

  Future<void> pump(WidgetTester tester) async {
    store
      ..putStaging(
        'p1',
        'document.pdf',
        Uint8List.fromList('%PDF-1.7'.codeUnits),
      )
      ..putStaging('p1', 'screen.jpg', tinyImage);
    final a = await store.commit(
      const StagedPdf(
        id: 'p1',
        byteSize: 1000,
        pageCount: 1,
        width: 595,
        height: 842,
        originalName: 'x.pdf',
      ),
      DateTime.utc(2026),
    );
    final base = sampleTask();
    await pumpWithApp(
      tester,
      CurrentTaskScreen(task: base.withContent('x', a, base.updatedAt)),
      overrides: [
        attachmentStoreProvider.overrideWithValue(store),
        pdfImporterProvider.overrideWithValue(FakePdfImporter(store)),
        linkOpenerProvider.overrideWithValue(opener),
        ...fakePdfViews,
      ],
    );
    await tester.pumpAndSettle();
  }

  final web = WebLink(Uri.parse('https://example.com/p'), 'example.com');

  testWidgets('CA-008-12: pregunta con el dominio y abre solo con "Abrir"', (
    tester,
  ) async {
    await pump(tester);
    taskPdfCalls.last.onLink!(web);
    await tester.pumpAndSettle();
    expect(find.text('¿Abrir example.com en el navegador?'), findsOneWidget);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(opener.opened, [web]);
  });

  testWidgets('CA-008-12: "Cancelar" no abre nada', (tester) async {
    await pump(tester);
    taskPdfCalls.last.onLink!(web);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(opener.opened, isEmpty);
  });

  testWidgets(
    'CA-008-12: correo y teléfono, "con otra app"; sin app, el aviso',
    (tester) async {
      opener.available = false;
      await pump(tester);
      taskPdfCalls.last.onLink!(
        PhoneLink(Uri.parse('tel:+34600000000'), '+34600000000'),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿Abrir +34600000000 con otra app?'), findsOneWidget);
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay ninguna app para abrir este enlace.'),
        findsOneWidget,
      );
    },
  );
}
