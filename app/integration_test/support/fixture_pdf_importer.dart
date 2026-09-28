import 'dart:convert';
import 'dart:io';

import 'package:app/data/attachments/file_attachment_store.dart';
import 'package:app/data/import/native_pdf_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/ports/image_importer.dart' show CopiedImage;
import 'package:app/domain/ports/pdf_importer.dart';

import '../fixtures/pdf_fixtures.g.dart';

/// Selector de PDF de pruebas (spec 008, T-008-22): PDFium, el JPEG nativo y
/// el almacén en disco de verdad, salvo `pick` y `copy`, que dejan en la
/// preparación el fichero de prueba [next] en lugar de abrir el selector del
/// sistema (otra app, fuera del alcance del test). La copia acotada nativa ya
/// la prueba `pdf_import_test` (CA-008-14).
///
/// `copy` escribe con `dart:io` (no con `debugCopyFile`, que solo existe en
/// las builds de depuración) para que funcione también en modo *profile*.
class FixturePdfImporter implements PdfImporter {
  FixturePdfImporter(this.native, this.store);

  final NativePdfImporter native;
  final FileAttachmentStore store;

  /// Nombre de `pdfFixtures` o ruta absoluta de un fichero del dispositivo (el
  /// escaneado de 20 páginas, que no cabe en el código del test).
  String next = 'pages_20.pdf';

  @override
  Future<PickedPdf?> pick(String id) async =>
      (token: next, name: next.split('/').last);

  @override
  Future<CopiedImage> copy(
    PickedPdf picked,
    String id, {
    required int maxBytes,
    required int headBytes,
  }) async {
    final token = picked.token;
    final bytes = token.startsWith('/')
        ? await File(token).readAsBytes()
        : base64.decode(pdfFixtures[token]!);
    if (bytes.length > maxBytes) {
      throw const PdfImportFailure(PdfImportError.tooLarge);
    }
    final source = store.stagingFile(id, 'source');
    await source.parent.create(recursive: true);
    await source.writeAsBytes(bytes, flush: true);
    return (byteSize: bytes.length, head: bytes.take(headBytes).toList());
  }

  @override
  Future<PdfInfo> inspect(String id, {required int maxPages}) =>
      native.inspect(id, maxPages: maxPages);

  @override
  Future<void> renderScreen(
    Attachment attachment,
    PdfPosition position, {
    PageGap gap = noPageGap,
  }) => native.renderScreen(attachment, position, gap: gap);

  @override
  Future<void> cancel(String id) => native.cancel(id);
}
