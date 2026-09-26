import 'package:flutter/painting.dart';

import 'attachment_images.dart';
import 'file_attachment_store.dart';

class FileAttachmentImages implements AttachmentImages {
  FileAttachmentImages(this.store);

  final FileAttachmentStore store;

  @override
  ImageProvider staged(String id, String name) =>
      FileImage(store.stagingFile(id, name));

  @override
  ImageProvider stored(String relPath) => FileImage(store.file(relPath));
}
