// Importación nativa de PDF (spec 008, T-008-08/09). En el emulador (nunca en
// el móvil del propietario sin su permiso):
//   flutter test integration_test/pdf_import_test.dart -d emulator-5554
//
// Los ficheros de prueba vienen de tools/fixtures/gen_pdf_fixtures.py y se
// escriben en `cache/fixtures/`, el único sitio que acepta `debugCopyFile`.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/data/attachments/file_attachment_store.dart';
import 'package:app/data/import/native_pdf_importer.dart';
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:app/domain/services/pdf_sniffer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'fixtures/pdf_fixtures.g.dart';

late NativePdfImporter importer;
late FileAttachmentStore store;
late Directory cache;
var _n = 0;

Directory _staging(String id) => Directory('${cache.path}/import/$id');

/// Copia y comprueba el fichero de prueba [name] como lo haría `ImportPdf`.
Future<(PdfInfo, Directory)> _import(String name, {String? path}) async {
  final id = 'pdf-it-${_n++}';
  final source =
      path ??
      (File('${cache.path}/fixtures/$name')
            ..createSync(recursive: true)
            ..writeAsBytesSync(base64.decode(pdfFixtures[name]!)))
          .path;
  try {
    final copied = await importer.debugCopyFile(
      source,
      id,
      maxBytes: PdfLimits.maxBytes,
      headBytes: PdfLimits.headBytes,
    );
    if (!isPdf(copied.head)) {
      throw const PdfImportFailure(PdfImportError.notPdf);
    }
    final info = await importer.inspect(id, maxPages: PdfLimits.maxPages);
    return (info, _staging(id));
  } on Object {
    await store.deleteStaging(id);
    rethrow;
  }
}

Future<PdfImportError?> _errorOf(String name, {String? path}) async {
  try {
    await _import(name, path: path);
    return null;
  } on PdfImportFailure catch (e) {
    return e.error;
  } on Object {
    return PdfImportError.unreadable;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    cache = await getTemporaryDirectory();
    store = await FileAttachmentStore.open();
    importer = NativePdfImporter(
      stagingFile: store.stagingFile,
      storedFile: store.file,
    );
  });

  testWidgets(
    'CA-008-01/02/08: un PDF válido deja document.pdf y la versión de pantalla al ancho',
    (tester) async {
      final (info, dir) = await tester.runAsync(
        () => _import('one_page.pdf'),
      ) as (PdfInfo, Directory);
      expect(info, (pageCount: 1, width: 595, height: 842));
      final doc = File('${dir.path}/document.pdf');
      expect(
        doc.readAsBytesSync(),
        base64.decode(pdfFixtures['one_page.pdf']!),
      );
      expect(File('${dir.path}/source').existsSync(), isFalse);
      final screen = File('${dir.path}/screen.jpg');
      final bytes = screen.readAsBytesSync();
      expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]); // JPEG
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        return (await codec.getNextFrame()).image;
      });
      final view = tester.view.physicalSize;
      expect(image!.width, view.shortestSide.round());
      expect(image.height, (image.width * 842 / 595).round());
      // Fondo blanco (el JPEG de la página, con el texto negro arriba).
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final last = data.lengthInBytes - 4;
      expect(data.getUint8(last), greaterThan(240));
      await store.deleteStaging(
        dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      );
    },
  );

  testWidgets(
    'CA-008-02: la cabecera tras basura se acepta; lo que no es PDF, no',
    (tester) async {
      await tester.runAsync(() async {
        expect(await _errorOf('header_offset.pdf'), isNull);
        for (final name in ['html_as.pdf', 'zip_as.pdf', 'header_late.pdf']) {
          expect(await _errorOf(name), PdfImportError.notPdf, reason: name);
        }
        expect(await _errorOf('empty.pdf'), PdfImportError.unreadable);
      });
    },
  );

  testWidgets('CA-008-03: 20 páginas sí; 21 y 10 000 no', (tester) async {
    await tester.runAsync(() async {
      expect(await _errorOf('pages_20.pdf'), isNull);
      expect(await _errorOf('pages_21.pdf'), PdfImportError.tooManyPages);
      expect(await _errorOf('pages_10000.pdf'), PdfImportError.tooManyPages);
    });
  });

  testWidgets('CA-008-14: un flujo sin fin se corta en 10 MB', (tester) async {
    await tester.runAsync(() async {
      expect(
        await _errorOf('zero', path: '/dev/zero'),
        PdfImportError.tooLarge,
      );
    });
  });

  testWidgets(
    'CL-008-1/2/3, CA-008-14: protegidos, corruptos y malformados, sin cerrar la app',
    (tester) async {
      await tester.runAsync(() async {
        expect(await _errorOf('protected_user.pdf'), PdfImportError.protected);
        expect(await _errorOf('protected_owner_only.pdf'), isNull);
        for (final name in ['truncated.pdf', 'cyclic.pdf', 'zero_pages.pdf']) {
          expect(await _errorOf(name), PdfImportError.unreadable, reason: name);
        }
        final sw = Stopwatch()..start();
        expect(await _errorOf('bomb.pdf'), isNull);
        expect(sw.elapsed, lessThan(PdfLimits.timeout));
        expect(await _errorOf('js_form.pdf'), isNull);
        expect(await _errorOf('links.pdf'), isNull);
        expect(await _errorOf('mixed_sizes.pdf'), isNull);
      });
    },
  );

  testWidgets('CA-008-14: los errores no dejan nada en la preparación', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final before = await store.stagingIds();
      await _errorOf('pages_21.pdf');
      await _errorOf('html_as.pdf');
      await _errorOf('protected_user.pdf');
      expect(await store.stagingIds(), before);
    });
  });
}
