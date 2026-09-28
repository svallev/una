import '../entities/attachment.dart';
import '../entities/pdf_position.dart';
import 'image_importer.dart' show CopiedImage;

/// PDF elegido en el selector, aún sin copiar. [token] es opaco (solo lo
/// entiende el importador); [name] es el nombre visible que da el proveedor,
/// **sin sanear** (lo sanea `ImportPdf`, CA-008-07).
typedef PickedPdf = ({String token, String? name});

/// Lo que se sabe de un PDF que se ha podido abrir.
typedef PdfInfo = ({int pageCount, int width, int height});

/// Separación entre páginas en la versión de pantalla: [px] filas del color
/// [argb] (como el borde que dibuja el visor entre páginas, CA-008-08).
typedef PageGap = ({int px, int argb});

/// Sin separación.
const PageGap noPageGap = (px: 0, argb: 0xFFFFFFFF);

/// Por qué no se ha podido importar un PDF (spec 008 §5).
enum PdfImportError {
  notPdf,
  tooLarge,
  tooManyPages,
  protected,
  unreadable,
  noSpace,
}

class PdfImportFailure implements Exception {
  const PdfImportFailure(this.error);
  final PdfImportError error;
  @override
  String toString() => 'PdfImportFailure(${error.name})';
}

/// Selector, copia y comprobación de PDF (canal nativo + PDFium). Todo lo que
/// escribe va a la zona de preparación `<id>`; nunca fuera. La cancelación se
/// señala con `ImageImportCancelled`, como en las imágenes.
abstract interface class PdfImporter {
  /// Abre el selector de documentos del sistema, solo PDF, sin permisos
  /// (CA-008-01). Devuelve null si el usuario cancela.
  Future<PickedPdf?> pick(String id);

  /// Copia lo elegido a la preparación `<id>`, contando los bytes y abortando al
  /// pasar de [maxBytes] (CA-008-14); devuelve los primeros [headBytes].
  Future<CopiedImage> copy(
    PickedPdf picked,
    String id, {
    required int maxBytes,
    required int headBytes,
  });

  /// Abre la copia **sin contraseña**, comprueba que tiene entre 1 y
  /// [maxPages] páginas y que la primera se puede dibujar, y deja en la
  /// preparación `document.pdf` y su versión de pantalla (CA-008-03/14).
  Future<PdfInfo> inspect(String id, {required int maxPages});

  /// Rehace la versión de pantalla de un PDF **guardado**: lo que se ve desde
  /// [position], la página desde su fracción guardada y las siguientes
  /// separadas por [gap], hasta el alto de la pantalla (CA-008-08, CA-008-18).
  /// Si ya no existe, no hace nada.
  Future<void> renderScreen(
    Attachment attachment,
    PdfPosition position, {
    PageGap gap = noPageGap,
  });

  /// Aborta el trabajo en curso de `<id>` y borra su preparación.
  Future<void> cancel(String id);
}
