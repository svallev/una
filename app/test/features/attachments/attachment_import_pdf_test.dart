import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/features/attachments/attachment_import_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'id-${_n++}';
}

void main() {
  late MemoryAttachmentStore store;
  late FakePdfImporter pdfs;
  late FakeImageImporter images;
  late ImportRegistry registry;
  late ProviderContainer container;

  setUp(() {
    store = MemoryAttachmentStore();
    pdfs = FakePdfImporter(store);
    images = FakeImageImporter(store);
    registry = ImportRegistry();
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        attachmentStoreProvider.overrideWithValue(store),
        importRegistryProvider.overrideWithValue(registry),
        idGeneratorProvider.overrideWithValue(_SeqIds()),
        imageImporterProvider.overrideWithValue(images),
        pdfImporterProvider.overrideWithValue(pdfs),
      ],
    );
    container.listen(attachmentImportProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  AttachmentImportController ctrl() =>
      container.read(attachmentImportProvider.notifier);
  AttachmentImportState state() => container.read(attachmentImportProvider);

  testWidgets('CA-008-01/04: "Subir archivo" deja un PDF preparado', (
    tester,
  ) async {
    expect(await ctrl().pick(AttachmentOrigin.file), ImportOutcome.added);
    expect(state().pdf, isA<StagedPdf>());
    expect(state().pdf!.originalName, 'Programa.pdf');
    expect(state().image, isNull);
    expect(images.picks, isEmpty);
    expect(await store.stagingIds(), {'id-0'});
  });

  testWidgets('CA-008-01: cancelar el selector no cambia nada', (tester) async {
    pdfs.userCancelsPicker = true;
    expect(await ctrl().pick(AttachmentOrigin.file), ImportOutcome.unchanged);
    expect(state().staged, isNull);
    expect(await store.stagingIds(), isEmpty);
  });

  testWidgets(
    'CA-008-15: "Preparando PDF…" a los 400 ms y "Cancelar" lo deja como estaba',
    (tester) async {
      pdfs.inspectDelay = const Duration(seconds: 5);
      final outcome = ctrl().pick(AttachmentOrigin.file);
      await tester.pump(const Duration(milliseconds: 10));
      expect(state().preparing, isTrue);
      expect(state().preparingKind, AttachmentKind.pdf);
      expect(state().showPreparing, isFalse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(state().showPreparing, isTrue);
      await ctrl().cancel();
      expect(await outcome, ImportOutcome.unchanged);
      expect(state().preparing, isFalse);
      expect(state().staged, isNull);
      expect(await store.stagingIds(), isEmpty);
    },
  );

  for (final error in PdfImportError.values) {
    testWidgets(
      'CA-008-02/03/14: error ${error.name} → aviso y todo como estaba',
      (tester) async {
        pdfs.inspectError = PdfImportFailure(error);
        expect(await ctrl().pick(AttachmentOrigin.file), ImportOutcome.failed);
        expect(state().error, error);
        expect(state().staged, isNull);
        expect(await store.stagingIds(), isEmpty);
      },
    );
  }

  testWidgets(
    'CA-008-04: un PDF sustituye a una imagen preparada (y al revés)',
    (tester) async {
      await ctrl().pick(AttachmentOrigin.gallery);
      final image = state().image!;
      await ctrl().pick(AttachmentOrigin.file);
      expect(state().pdf, isNotNull);
      expect(await store.stagingIds(), {state().pdf!.id});
      await ctrl().pick(AttachmentOrigin.camera);
      expect(state().image, isNotNull);
      expect(state().image!.id, isNot(image.id));
      expect(await store.stagingIds(), {state().image!.id});
    },
  );

  testWidgets('CA-008-16: al cerrar el editor se borra el PDF no guardado', (
    tester,
  ) async {
    await ctrl().pick(AttachmentOrigin.file);
    expect(await store.stagingIds(), hasLength(1));
    container.dispose();
    await tester.pump();
    expect(await store.stagingIds(), isEmpty);
    container = ProviderContainer();
  });
}
