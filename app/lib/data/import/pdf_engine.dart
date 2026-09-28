import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../../domain/ports/pdf_importer.dart';

/// Una página dibujada: píxeles BGRA de [width] × [height].
typedef RenderedPage = ({Uint8List bgra, int width, int height});

/// Cómo abrir el PDF, **sin contraseña**: de un archivo (móvil) o de sus bytes
/// (web de pruebas, CL-008-12). Sin `dart:io`, para que compile en la web.
typedef PdfOpen = Future<PdfDocument> Function();

/// Lo que la importación necesita de PDFium (pdfrx), sin interfaz de usuario
/// (spec 008). Nunca da contraseña, nunca abre URLs y dibuja con fondo blanco.
abstract final class PdfEngine {
  /// El PDF de la ruta [path].
  static PdfOpen file(String path) =>
      () => PdfDocument.openFile(path, passwordProvider: null);

  /// El PDF de [bytes] (en memoria).
  static PdfOpen data(Uint8List bytes) =>
      () => PdfDocument.openData(bytes, passwordProvider: null);

  /// Abre [open] **sin contraseña** y comprueba que tiene entre 1 y [maxPages]
  /// páginas y que la primera se puede dibujar (CA-008-03, CA-008-14,
  /// CL-008-1/3). Lanza [PdfImportFailure]; cualquier error del motor (también
  /// los que no son `PdfException`, como el `RangeError` de un árbol de
  /// páginas cíclico) cuenta como ilegible.
  static Future<(PdfInfo, RenderedPage)> inspect(
    PdfOpen open, {
    required int maxPages,
    required int renderWidth,
  }) async {
    await pdfrxFlutterInitialize();
    final PdfDocument doc;
    try {
      doc = await open();
    } on PdfPasswordException {
      throw const PdfImportFailure(PdfImportError.protected);
    } on Object {
      throw const PdfImportFailure(PdfImportError.unreadable);
    }
    try {
      final count = doc.pages.length;
      if (count < 1) throw const PdfImportFailure(PdfImportError.unreadable);
      if (count > maxPages) {
        throw const PdfImportFailure(PdfImportError.tooManyPages);
      }
      final page = doc.pages.first;
      final rendered = await _render(page, renderWidth);
      return (
        (
          pageCount: count,
          width: page.width.round(),
          height: page.height.round(),
        ),
        rendered,
      );
    } on PdfImportFailure {
      rethrow;
    } on Object {
      throw const PdfImportFailure(PdfImportError.unreadable);
    } finally {
      await doc.dispose();
    }
  }

  /// Dibuja la página [pageNumber] (desde 1) de [open] a [width] px de ancho.
  static Future<RenderedPage> renderPage(
    PdfOpen open,
    int pageNumber, {
    required int width,
  }) async {
    await pdfrxFlutterInitialize();
    final PdfDocument doc;
    try {
      doc = await open();
    } on Object {
      throw const PdfImportFailure(PdfImportError.unreadable);
    }
    try {
      if (pageNumber < 1 || pageNumber > doc.pages.length) {
        throw const PdfImportFailure(PdfImportError.unreadable);
      }
      return await _render(doc.pages[pageNumber - 1], width);
    } on PdfImportFailure {
      rethrow;
    } on Object {
      throw const PdfImportFailure(PdfImportError.unreadable);
    } finally {
      await doc.dispose();
    }
  }

  static Future<RenderedPage> _render(PdfPage page, int width) async {
    if (page.width <= 0 || page.height <= 0) {
      throw const PdfImportFailure(PdfImportError.unreadable);
    }
    final w = width.clamp(1, 4096);
    final h = (w * page.height / page.width).round().clamp(1, 16384);
    final image = await page.render(
      width: w,
      height: h,
      fullWidth: w.toDouble(),
      fullHeight: h.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );
    if (image == null) throw const PdfImportFailure(PdfImportError.unreadable);
    try {
      return (
        bgra: Uint8List.fromList(image.pixels),
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
    }
  }
}
