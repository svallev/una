import '../domain/ports/attachment_store.dart';
import '../domain/ports/image_importer.dart';
import '../domain/ports/pdf_importer.dart';
import 'attachments/attachment_images.dart';
import 'image_services_native.dart'
    if (dart.library.js_interop) 'image_services_web.dart'
    as impl;

/// Archivos de los adjuntos e importación de imágenes (spec 007) y PDF (spec
/// 008) de la plataforma: en disco y por el canal nativo en móvil; en memoria
/// en la web de pruebas (CL-007-12, CL-008-12).
typedef ImageServices = ({
  AttachmentStore store,
  AttachmentImages images,
  ImageImporter importer,
  PdfImporter pdfImporter,
});

Future<ImageServices> openImageServices() => impl.openImageServices();
