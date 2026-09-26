import 'attachments/file_attachment_store.dart';
import 'image_services.dart';
import 'import/native_image_importer.dart';

Future<ImageServices> openImageServices() async => (
  store: await FileAttachmentStore.open(),
  importer: await NativeImageImporter.open(),
);
