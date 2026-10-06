import '../entities/attachment.dart';
import '../entities/staged_attachment.dart';
import '../ports/attachment_store.dart';

/// Faltan preparaciones al guardar un grupo de fotos (el sistema vació la zona
/// temporal mientras el editor estaba abierto, CL-016-6b): no se movió nada.
/// [ids] son las que faltan, en el orden del grupo. No lleva más datos: nunca
/// nombres ni rutas.
class StagedPhotosLost implements Exception {
  StagedPhotosLost(Iterable<String> ids) : ids = List.unmodifiable(ids);

  final List<String> ids;

  @override
  String toString() => 'StagedPhotosLost(${ids.length})';
}

/// Mueve las preparaciones [staged] a su sitio definitivo como una unidad
/// (ADR-0024): o quedan todas en `attachments/` o ninguna.
///
/// 1. Pide `stagingIds()` **una vez** y, si falta alguna preparación, lanza
///    [StagedPhotosLost] **sin mover nada**.
/// 2. Mueve las carpetas con [AttachmentStore.commit] en orden. Si una falla,
///    devuelve a la preparación las ya movidas (`restage`; si tampoco puede, las
///    borra) y relanza el error original.
///
/// Devuelve los adjuntos en el orden de [staged], aún sin guardar en la BD.
Future<List<Attachment>> commitGroup(
  AttachmentStore store,
  List<StagedAttachment> staged,
  DateTime at,
) async {
  // Una web no tiene preparación en disco (ADR-0016).
  final onDisk = staged.whereType<StagedWeb>().isEmpty
      ? staged
      : staged.where((s) => s is! StagedWeb).toList();
  if (onDisk.isNotEmpty) {
    final present = await store.stagingIds();
    final lost = [
      for (final s in onDisk)
        if (!present.contains(s.id)) s.id,
    ];
    if (lost.isNotEmpty) throw StagedPhotosLost(lost);
  }
  final moved = <Attachment>[];
  try {
    for (final s in staged) {
      moved.add(await store.commit(s, at));
    }
  } on Object {
    final movedFiles = [
      for (final a in moved)
        if (!a.isWeb) a.id,
    ];
    for (final id in movedFiles.reversed) {
      try {
        await store.restage(id);
      } on Object {
        try {
          await store.delete(id);
        } on Object {
          // Sin registro (CL-007-10): lo recoge el barrido.
        }
      }
    }
    rethrow;
  }
  return List.unmodifiable(moved);
}
