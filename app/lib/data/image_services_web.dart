import 'attachments/attachment_images.dart';
import 'attachments/memory_attachment_store.dart';
import 'image_services.dart';
import 'import/unavailable_image_importer.dart';

/// Hasta T-007-19 (`WebImageImporter`), la web de pruebas no importa imágenes.
Future<ImageServices> openImageServices() async {
  final store = MemoryAttachmentStore();
  return (
    store: store,
    images: MemoryAttachmentImages(store),
    importer: const UnavailableImageImporter(),
  );
}
