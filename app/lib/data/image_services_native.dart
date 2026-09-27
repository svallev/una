import 'attachments/file_attachment_images.dart';
import 'attachments/file_attachment_store.dart';
import 'image_services.dart';
import 'import/native_image_importer.dart';
import 'import/native_pdf_importer.dart';

Future<ImageServices> openImageServices() async {
  final store = await FileAttachmentStore.open();
  return (
    store: store,
    images: FileAttachmentImages(store),
    importer: await NativeImageImporter.open(),
    pdfImporter: NativePdfImporter(
      stagingFile: store.stagingFile,
      storedFile: store.file,
    ),
  );
}
