import 'dart:convert';
import 'dart:io';

import 'package:app/data/import/pdf_engine.dart';
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/fixtures/pdf_fixtures.g.dart';
import '../support/pdfrx.dart';

void main() {
  late Directory tmp;

  setUpAll(initPdfrxForTests);
  setUp(() => tmp = Directory.systemTemp.createTempSync('una_pdf_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File fixture(String name) =>
      File('${tmp.path}/$name')
        ..writeAsBytesSync(base64Decode(pdfFixtures[name]!));

  Future<PdfImportError?> errorOf(String name) async {
    try {
      await PdfEngine.inspect(fixture(name), maxPages: 20, renderWidth: 360);
      return null;
    } on PdfImportFailure catch (e) {
      return e.error;
    }
  }

  test('CA-008-02/03: un PDF válido da sus páginas, su tamaño y la primera dibujada', () async {
    final (info, page) = await PdfEngine.inspect(
      fixture('one_page.pdf'),
      maxPages: 20,
      renderWidth: 360,
    );
    expect(info, (pageCount: 1, width: 595, height: 842));
    expect(page.width, 360);
    expect(page.height, (360 * 842 / 595).round());
    expect(page.bgra.length, page.width * page.height * 4);
    // Fondo blanco (BGRA): la esquina de arriba a la izquierda.
    expect(page.bgra.sublist(0, 4), [255, 255, 255, 255]);
  });

  test('CA-008-03: 20 páginas se aceptan; 21 no', () async {
    expect(await errorOf('pages_20.pdf'), isNull);
    expect(await errorOf('pages_21.pdf'), PdfImportError.tooManyPages);
    expect(await errorOf('pages_10000.pdf'), PdfImportError.tooManyPages);
  });

  test('CL-008-1/2: con contraseña de apertura, protegido; solo de permisos, se abre', () async {
    expect(await errorOf('protected_user.pdf'), PdfImportError.protected);
    expect(await errorOf('protected_owner_only.pdf'), isNull);
  });

  test('CL-008-3 / CA-008-14: corruptos, cíclicos, vacíos o sin páginas → ilegible', () async {
    for (final name in [
      'truncated.pdf',
      'cyclic.pdf',
      'zero_pages.pdf',
      'empty.pdf',
      'html_as.pdf',
      'zip_as.pdf',
    ]) {
      expect(await errorOf(name), PdfImportError.unreadable, reason: name);
    }
  });

  test('CA-008-14: la bomba de compresión se abre sin colgarse', () async {
    final sw = Stopwatch()..start();
    expect(await errorOf('bomb.pdf'), isNull);
    expect(sw.elapsed, lessThan(const Duration(seconds: 20)));
  });

  test(
    'CA-008-13: con JavaScript y formulario se abre (nada se ejecuta)',
    () async {
      expect(await errorOf('js_form.pdf'), isNull);
    },
  );

  test('CA-008-08: dibuja cualquier página a un ancho dado', () async {
    final page = await PdfEngine.renderPage(
      fixture('mixed_sizes.pdf'),
      2,
      width: 300,
    );
    // La página 2 es apaisada (842 × 595).
    expect((page.width, page.height), (300, (300 * 595 / 842).round()));
    await expectLater(
      PdfEngine.renderPage(fixture('mixed_sizes.pdf'), 4, width: 300),
      throwsA(isA<PdfImportFailure>()),
    );
  });
}
