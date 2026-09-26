import 'dart:typed_data';

import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';

/// PNG válido de 1 × 1 px para las versiones de prueba (se decodifica de
/// verdad: una imagen ilegible mostraría "Adjunto no disponible").
final Uint8List tinyImage = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0xFC, 0xCF, 0xC0, 0x50,
  0x0F, 0x00, 0x04, 0x85, 0x01, 0x80, 0x84, 0xA9, 0x8C, 0x21, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Deja en [store] una preparación completa (teselas, pantalla y miniatura).
StagedImage stageImage(
  MemoryAttachmentStore store,
  String id, {
  AttachmentOrigin origin = AttachmentOrigin.camera,
  int width = 4000,
  int height = 3000,
}) {
  final tiles = ImageTiles(width, height);
  for (var r = 0; r < tiles.rows; r++) {
    for (var c = 0; c < tiles.columns; c++) {
      store.putStaging(id, ImageTiles.fileName(r, c), tinyImage);
    }
  }
  store
    ..putStaging(id, 'screen.jpg', tinyImage)
    ..putStaging(id, 'thumb.jpg', tinyImage);
  return (
    id: id,
    origin: origin,
    width: width,
    height: height,
    byteSize: tinyImage.length * tiles.rows * tiles.columns,
  );
}

AttachmentJanitor janitorFor(
  InMemoryTaskRepository repo,
  MemoryAttachmentStore store, [
  ImportRegistry? registry,
]) => AttachmentJanitor(
  store: store,
  repository: repo,
  registry: registry ?? ImportRegistry(),
);
