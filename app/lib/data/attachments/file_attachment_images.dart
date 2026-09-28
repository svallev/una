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

  @override
  PdfSource stagedPdf(String id) => (
    path: store.stagingFile(id, 'document.pdf').path,
    bytes: null,
    key: 'staged:$id',
  );

  @override
  PdfSource storedPdf(String relPath) =>
      (path: store.file(relPath).path, bytes: null, key: relPath);
}
