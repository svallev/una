import 'attachments/attachment_images.dart';
import 'attachments/memory_attachment_store.dart';
import 'image_services.dart';
import 'import/web_image_importer.dart';
import 'import/web_pdf_importer.dart';

/// Web de pruebas (CL-007-12, CL-008-12, ADR-0010): el selector del navegador
/// y las imágenes y los PDF solo en memoria, como las tareas.
Future<ImageServices> openImageServices() async {
  final store = MemoryAttachmentStore();
  return (
    store: store,
    images: MemoryAttachmentImages(store),
    importer: WebImageImporter(store),
    pdfImporter: WebPdfImporter(store),
  );
}
