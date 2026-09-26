import '../domain/ports/attachment_store.dart';
import '../domain/ports/image_importer.dart';
import 'image_services_native.dart'
    if (dart.library.js_interop) 'image_services_web.dart'
    as impl;

/// Archivos de los adjuntos e importación de imágenes de la plataforma
/// (spec 007): en disco y por el canal nativo en móvil; en memoria en la web
/// de pruebas (CL-007-12).
typedef ImageServices = ({AttachmentStore store, ImageImporter importer});

Future<ImageServices> openImageServices() => impl.openImageServices();
