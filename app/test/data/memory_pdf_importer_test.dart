import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/import/memory_pdf_importer.dart';
import 'package:app/data/import/pdf_engine.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/ports/image_importer.dart' show ImageImportCancelled;
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/services/pdf_sniffer.dart';
import 'package:app/domain/usecases/import_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../support/pdfrx.dart';

/// Importador de PDF de la web de pruebas (CL-008-12, ADR-0010): el archivo
/// que da el selector del navegador, todo en memoria y con el PDFium real. El
/// selector y el JPEG del `canvas` se sustituyen (sin navegador en los tests).
void main() {
  setUpAll(initPdfrxForTests);

  late MemoryAttachmentStore store;
  late List<RenderedPage> encoded;
  PickedBytes? next;
  late int reads;

  /// JPEG "falso": solo importa que llegue a donde toca.
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  PickedBytes file(String name, {String? fileName, int? size}) {
    final bytes = base64Decode(pdfFixtures[name]!);
    return (
      name: fileName ?? name,
      size: size ?? bytes.length,
      read: () async {
        reads++;
        return bytes;
      },
    );
  }

  MemoryPdfImporter importer({Future<PickedBytes?> Function()? pick}) =>
      MemoryPdfImporter(
        store,
        pickFile: pick ?? () async => next,
        encodeJpeg: (page) async {
          encoded.add(page);
          return jpeg;
        },
        screenWidthPx: () => 360,
      );

  setUp(() {
    store = MemoryAttachmentStore();
    encoded = [];
    next = null;
    reads = 0;
  });

  ImportPdf useCase(PdfImporter importer) => ImportPdf(
    importer: importer,
    janitor: AttachmentJanitor(
      store: store,
      repository: InMemoryTaskRepository(),
      registry: ImportRegistry(),
    ),
    ids: _Ids(),
  );

  group('CL-008-12: la web de pruebas importa el PDF en memoria', () {
    test('elegir, copiar y comprobar deja el PDF y su versión de pantalla '
        'en la preparación, sin el original suelto', () async {
      next = file('pages_20.pdf', fileName: 'Programa.pdf');
      final job = (await useCase(importer()).pick())!;
      expect(job.picked.name, 'Programa.pdf');
      final staged = await job.prepare();

      expect(staged.pageCount, 20);
      expect(staged.originalName, 'Programa.pdf');
      expect(
        staged.byteSize,
        base64Decode(pdfFixtures['pages_20.pdf']!).length,
      );
      expect(
        store.stagingBytes(staged.id, 'document.pdf'),
        base64Decode(pdfFixtures['pages_20.pdf']!),
      );
      expect(store.stagingBytes(staged.id, 'screen.jpg'), jpeg);
      expect(store.stagingBytes(staged.id, 'source'), isNull);
      // La primera página, al ancho de la pantalla.
      expect(encoded.single.width, 360);

      // Guardada, el visor la lee de memoria.
      final attachment = await store.commit(staged, DateTime.utc(2026, 9, 28));
      expect(await store.check(attachment), AttachmentFiles.ok);
      final source = MemoryAttachmentImages(store)
          .storedPdf(attachment.documentPath);
      expect(source.path, isNull);
      expect(source.bytes, base64Decode(pdfFixtures['pages_20.pdf']!));
    });

    test('cancelar el selector no deja nada', () async {
      next = null;
      expect(await useCase(importer()).pick(), isNull);
      expect(await store.stagingIds(), isEmpty);
    });

    test('CA-008-14: más de 10 MB se rechaza sin leerlo', () async {
      next = file('one_page.pdf', size: PdfLimits.maxBytes + 1);
      final job = (await useCase(importer()).pick())!;
      await expectLater(
        job.prepare(),
        throwsA(_error(PdfImportError.tooLarge)),
      );
      expect(reads, 0);
      expect(await store.stagingIds(), isEmpty);
    });

    test(
      'CA-008-02: lo que no es un PDF se rechaza por el contenido',
      () async {
        next = file('html_as.pdf');
        final job = (await useCase(importer()).pick())!;
        await expectLater(
          job.prepare(),
          throwsA(_error(PdfImportError.notPdf)),
        );
        expect(await store.stagingIds(), isEmpty);
      },
    );

    test('CA-008-03 / CL-008-1/3: con contraseña, más de 20 páginas o '
        'ilegible, su error y nada guardado', () async {
      for (final (name, error) in [
        ('protected_user.pdf', PdfImportError.protected),
        ('pages_21.pdf', PdfImportError.tooManyPages),
        ('truncated.pdf', PdfImportError.unreadable),
      ]) {
        next = file(name);
        final job = (await useCase(importer()).pick())!;
        await expectLater(job.prepare(), throwsA(_error(error)), reason: name);
      }
      expect(await store.stagingIds(), isEmpty);
    });

    test('CA-008-15: cancelar mientras se lee lo borra todo', () async {
      final reading = Completer<Uint8List>();
      final base = file('one_page.pdf');
      next = (name: base.name, size: base.size, read: () => reading.future);
      final job = (await useCase(importer()).pick())!;
      final prepared = job.prepare();
      await Future<void>.delayed(Duration.zero);
      await job.cancel();
      reading.complete(await base.read());
      await expectLater(prepared, throwsA(isA<ImageImportCancelled>()));
      expect(await store.stagingIds(), isEmpty);
    });

    test('CA-008-08/18: rehace la versión de pantalla con la página pedida; '
        'sin el PDF, no hace nada', () async {
      next = file('mixed_sizes.pdf');
      final job = (await useCase(importer()).pick())!;
      final attachment = await store.commit(
        await job.prepare(),
        DateTime.utc(2026, 9, 28),
      );
      store.removeFile(attachment.id, 'screen.jpg');
      encoded.clear();

      await importer().renderScreen(
        attachment,
        const PdfPosition(page: 2, offset: 0.5),
      );
      expect(store.bytes(attachment.screenPath), jpeg);
      // La página 2 es apaisada (842 × 595).
      expect(
        (encoded.single.width, encoded.single.height),
        (360, (360 * 595 / 842).round()),
      );

      await store.delete(attachment.id);
      await importer().renderScreen(
        attachment,
        const PdfPosition(page: 1, offset: 0),
      );
      expect(await store.storedIds(), isEmpty);
    });
  });
}

Matcher _error(PdfImportError error) =>
    isA<PdfImportFailure>().having((e) => e.error, 'error', error);

class _Ids implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'pdf${_n++}';
}
