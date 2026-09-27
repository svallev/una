import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/attachment.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/entities/staged_attachment.dart';
import '../../domain/ports/attachment_store.dart';

/// Adjuntos en el almacenamiento privado de la app (spec 007, plan §1):
///
/// - guardados: `files/attachments/<id>/` (`getApplicationSupportDirectory`),
///   **fuera de `app_flutter/`**, que es lo que entra en la copia en la nube
///   (CA-007-18);
/// - preparación: `cache/import/<id>/` (`getTemporaryDirectory`), la misma
///   ruta que usa el canal nativo. El sistema puede vaciarla y el barrido la
///   limpia.
///
/// Los ids se validan antes de formar rutas: nunca `..` ni separadores (T-3).
class FileAttachmentStore implements AttachmentStore {
  FileAttachmentStore({required this.filesRoot, required this.stagingRoot});

  static Future<FileAttachmentStore> open() async => FileAttachmentStore(
    filesRoot: await getApplicationSupportDirectory(),
    stagingRoot: Directory('${(await getTemporaryDirectory()).path}/import'),
  );

  /// Contenedor de adjuntos: las rutas relativas de [Attachment] cuelgan de aquí.
  final Directory filesRoot;
  final Directory stagingRoot;

  static final _validId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  static String _checked(String id) {
    if (!_validId.hasMatch(id)) throw ArgumentError.value(id, 'id');
    return id;
  }

  Directory get _attachmentsDir => Directory('${filesRoot.path}/attachments');

  Directory _stored(String id) =>
      Directory('${_attachmentsDir.path}/${_checked(id)}');

  Directory _staging(String id) =>
      Directory('${stagingRoot.path}/${_checked(id)}');

  /// Archivo de un adjunto guardado ([relPath] de [Attachment]). Solo
  /// `attachments/<id>/<nombre>.jpg|pdf|json`: nunca sale de su carpeta.
  File file(String relPath) {
    if (!_validRelPath.hasMatch(relPath)) {
      throw ArgumentError.value(relPath, 'relPath');
    }
    return File('${filesRoot.path}/$relPath');
  }

  static final _validRelPath = RegExp(
    r'^attachments/[A-Za-z0-9_-]{1,64}/[a-z0-9-]{1,32}\.(jpg|pdf|json)$',
  );

  /// Archivo de una preparación (vista previa en el editor antes de guardar).
  File stagingFile(String id, String name) =>
      File('${_staging(id).path}/$name');

  @override
  Future<Attachment> commit(StagedAttachment staged, DateTime at) async {
    final from = _staging(staged.id);
    final to = _stored(staged.id);
    await _attachmentsDir.create(recursive: true);
    if (to.existsSync()) await to.delete(recursive: true);
    // Mismo sistema de archivos (datos privados de la app): rename es atómico.
    await from.rename(to.path);
    return attachmentFrom(staged, at);
  }

  @override
  Future<void> restage(String id) async {
    final to = _staging(id);
    await stagingRoot.create(recursive: true);
    if (to.existsSync()) await to.delete(recursive: true);
    await _stored(id).rename(to.path);
  }

  @override
  Future<void> delete(String id) => _deleteEntry(_attachmentsDir, id);

  @override
  Future<void> deleteStaging(String id) => _deleteEntry(stagingRoot, id);

  /// Borra la entrada [name] de [parent] (directorio o archivo suelto: también
  /// restos de otras versiones o de un proceso muerto). Nunca sale de [parent].
  static Future<void> _deleteEntry(Directory parent, String name) async {
    if (name.isEmpty || name.contains('/') || name == '.' || name == '..') {
      return;
    }
    final path = '${parent.path}/$name';
    switch (FileSystemEntity.typeSync(path, followLinks: false)) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(path).delete();
    }
  }

  @override
  Future<Set<String>> storedIds() => _ids(_attachmentsDir);

  @override
  Future<Set<String>> stagingIds() => _ids(stagingRoot);

  /// Nombres de lo que hay en [dir] (directorios o archivos sueltos: un
  /// temporal que no sea un directorio también se barre).
  static Future<Set<String>> _ids(Directory dir) async {
    if (!dir.existsSync()) return {};
    return {
      await for (final e in dir.list(followLinks: false))
        e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
    };
  }

  @override
  Future<AttachmentFiles> check(Attachment attachment) async {
    Future<bool> present(String rel) async {
      final f = file(rel);
      return f.existsSync() && f.lengthSync() > 0;
    }

    if (attachment.isPdf) {
      if (!await present(attachment.documentPath)) {
        return AttachmentFiles.missing;
      }
      return await present(attachment.screenPath)
          ? AttachmentFiles.ok
          : AttachmentFiles.derivedMissing;
    }
    final tiles = attachment.tiles;
    if (tiles.rows == 0 || tiles.columns == 0) return AttachmentFiles.missing;
    for (var r = 0; r < tiles.rows; r++) {
      for (var c = 0; c < tiles.columns; c++) {
        if (!await present('${attachment.dir}/${ImageTiles.fileName(r, c)}')) {
          return AttachmentFiles.missing;
        }
      }
    }
    final thumb = attachment.thumbPath;
    if (!await present(attachment.screenPath) ||
        (thumb != null && !await present(thumb))) {
      return AttachmentFiles.derivedMissing;
    }
    return AttachmentFiles.ok;
  }

  @override
  Future<PdfPosition?> readPosition(String id) async {
    final f = file('attachments/${_checked(id)}/position.json');
    try {
      return PdfPosition.fromJson(await f.readAsString());
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> writePosition(String id, PdfPosition position) async {
    final dir = _stored(id);
    if (!dir.existsSync()) return;
    // Primero a un temporal y luego rename: nunca queda a medias.
    final tmp = File('${dir.path}/position.tmp');
    try {
      await tmp.writeAsString(position.toJson(), flush: true);
      await tmp.rename('${dir.path}/position.json');
    } on FileSystemException {
      // Se completó o eliminó mientras tanto: no pasa nada.
      if (tmp.existsSync()) await tmp.delete();
    }
  }
}
