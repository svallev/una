import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/ports/image_importer.dart' show ImageImportCancelled;
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/services/pdf_sniffer.dart';
import 'package:app/domain/usecases/import_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/fake_pdf_importer.dart';

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'pdf-${++_n}';
}

void main() {
  late MemoryAttachmentStore store;
  late FakePdfImporter importer;
  late ImportRegistry registry;
  late ImportPdf importPdf;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakePdfImporter(store);
    registry = ImportRegistry();
    importPdf = ImportPdf(
      importer: importer,
      janitor: janitorFor(InMemoryTaskRepository(), store, registry),
      ids: _SeqIds(),
      timeout: const Duration(milliseconds: 200),
    );
  });

  Future<PdfImportError?> errorOf(Future<Object?> f) async {
    try {
      await f;
      return null;
    } on PdfImportFailure catch (e) {
      return e.error;
    }
  }

  test('CA-008-01: si el usuario cancela el selector, no queda nada', () async {
    importer.userCancelsPicker = true;
    expect(await importPdf.pick(), isNull);
    expect(await store.stagingIds(), isEmpty);
    expect(registry.active, isEmpty);
  });

  test(
    'CA-008-02/03/07: prepara el PDF con sus límites y su nombre saneado',
    () async {
      importer.pickedName = '/sdcard/Download/Programa\u202E.pdf';
      final job = (await importPdf.pick())!;
      expect(registry.active, {job.id});
      final staged = await job.prepare();
      expect(
        staged,
        const StagedPdf(
          id: 'pdf-1',
          byteSize: 2400000,
          pageCount: 3,
          width: 595,
          height: 842,
          originalName: 'Programa.pdf',
        ),
      );
      expect(importer.copyLimits.single, (
        maxBytes: PdfLimits.maxBytes,
        headBytes: PdfLimits.headBytes,
      ));
      expect(importer.pageLimits.single, PdfLimits.maxPages);
      // Sigue protegida del barrido hasta guardar la tarea (CA-008-16).
      expect(registry.active, {'pdf-1'});
      expect(await store.stagingIds(), {'pdf-1'});
    },
  );

  test(
    'CA-008-07: sin nombre o con un nombre vacío tras sanearlo → null',
    () async {
      importer.pickedName = null;
      expect((await (await importPdf.pick())!.prepare()).originalName, isNull);
      importer.pickedName = '\u0000\u202E';
      expect((await (await importPdf.pick())!.prepare()).originalName, isNull);
    },
  );

  test(
    'CA-008-02: lo que no es PDF por el contenido se rechaza y se borra',
    () async {
      importer.head = '<!DOCTYPE html>'.codeUnits;
      final job = (await importPdf.pick())!;
      expect(await errorOf(job.prepare()), PdfImportError.notPdf);
      expect(importer.pageLimits, isEmpty);
      expect(await store.stagingIds(), isEmpty);
      expect(registry.active, isEmpty);
    },
  );

  for (final error in [
    PdfImportError.tooLarge,
    PdfImportError.noSpace,
    PdfImportError.unreadable,
  ]) {
    test(
      'CA-008-14: error al copiar (${error.name}) → mismo error y nada guardado',
      () async {
        importer.copyError = PdfImportFailure(error);
        final job = (await importPdf.pick())!;
        expect(await errorOf(job.prepare()), error);
        expect(await store.stagingIds(), isEmpty);
      },
    );
  }

  for (final error in [
    PdfImportError.tooManyPages,
    PdfImportError.protected,
    PdfImportError.unreadable,
  ]) {
    test('CA-008-03 / CL-008-1/3: al abrirlo, ${error.name}', () async {
      importer.inspectError = PdfImportFailure(error);
      final job = (await importPdf.pick())!;
      expect(await errorOf(job.prepare()), error);
      expect(await store.stagingIds(), isEmpty);
      expect(registry.active, isEmpty);
    });
  }

  test(
    'CA-008-14: cualquier otro error del motor cuenta como ilegible',
    () async {
      importer.inspectError = RangeError('árbol de páginas cíclico');
      final job = (await importPdf.pick())!;
      expect(await errorOf(job.prepare()), PdfImportError.unreadable);
      expect(await store.stagingIds(), isEmpty);
    },
  );

  test('CA-008-14: tras el tiempo máximo, ilegible y se cancela', () async {
    importer.inspectDelay = const Duration(seconds: 5);
    final job = (await importPdf.pick())!;
    expect(await errorOf(job.prepare()), PdfImportError.unreadable);
    expect(importer.cancelled, [job.id]);
    expect(await store.stagingIds(), isEmpty);
  });

  test('CA-008-15: cancelar durante la copia no deja nada', () async {
    importer.copyDelay = const Duration(seconds: 1);
    final job = (await importPdf.pick())!;
    final prepared = job.prepare();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final expectation = expectLater(
      prepared,
      throwsA(isA<ImageImportCancelled>()),
    );
    await job.cancel();
    await expectation;
    expect(await store.stagingIds(), isEmpty);
    expect(registry.active, isEmpty);
  });
}
