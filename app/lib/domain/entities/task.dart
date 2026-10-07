import 'package:flutter/foundation.dart';

import 'attachment.dart';

/// Estado de una tarea. Desde ADR-0012 todas las tareas guardadas están
/// pendientes: completar y eliminar las borran. `completed`, `completedAt` y
/// `deletedAt` se conservan porque siguen en el esquema, sin uso.
enum TaskStatus { pending, completed }

/// Tarea (docs/architecture.md §3). Inmutable; los cambios crean copias.
@immutable
class Task {
  Task({
    required this.id,
    required this.text,
    required this.status,
    required this.rank,
    required this.colorKey,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.deletedAt,
    this.dueDate,
    this.parentId,
    this.source = 'local',
    this.externalId,
    Attachment? attachment,
    List<Attachment>? attachments,
  }) : assert(
         attachment == null || attachments == null,
         'attachment y attachments no se pasan a la vez',
       ),
       attachments = List.unmodifiable(
         attachments ?? (attachment == null ? const [] : [attachment]),
       );

  /// Longitud máxima del texto (spec 001, CL-001-2).
  static const int maxTextLength = 10000;

  /// Número de colores de la paleta (colorKey 0..4).
  static const int paletteSize = 5;

  final String id;
  final String? text;
  final TaskStatus status;
  final String rank;
  final int colorKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;
  // Campos previstos para la hoja de ruta (Bloques 1–3); nulos en la v1.
  final DateTime? dueDate;
  final String? parentId;
  final String source;
  final String? externalId;

  /// Adjuntos (spec 016, ADR-0024): ninguno, uno de cualquier tipo o de 2 a 10
  /// imágenes, en su orden. Lista inmutable. **No se valida aquí** (una mezcla
  /// rara leída de la BD no debe cerrar la app): la validación es de
  /// [AttachmentGroup.isValidGroup], `CreateTask` y `EditTask`. Una tarea tiene
  /// texto no vacío o adjuntos, o ambos.
  final List<Attachment> attachments;

  /// El primer adjunto, o null si no hay ninguno (la imagen, el PDF o la web
  /// de las specs 007–009; la primera foto de un grupo).
  Attachment? get attachment => attachments.firstOrNull;

  bool get isPending => status == TaskStatus.pending && deletedAt == null;

  /// La misma tarea con otro texto (spec 005): conserva posición, color y
  /// adjunto.
  Task withText(String newText, DateTime at) =>
      withContent(newText, null, at, attachments: attachments);

  /// La misma tarea con otro contenido (spec 007): conserva posición y color.
  /// [newAttachment] es el atajo de un solo adjunto; para un grupo (spec 016)
  /// se pasa [attachments] (no los dos a la vez).
  Task withContent(
    String? newText,
    Attachment? newAttachment,
    DateTime at, {
    List<Attachment>? attachments,
  }) => Task(
    id: id,
    text: newText,
    status: status,
    rank: rank,
    colorKey: colorKey,
    createdAt: createdAt,
    updatedAt: at,
    completedAt: completedAt,
    deletedAt: deletedAt,
    dueDate: dueDate,
    parentId: parentId,
    source: source,
    externalId: externalId,
    attachment: newAttachment,
    attachments: attachments,
  );

  /// La misma tarea en otra posición de la cola (spec 006).
  Task withRank(String newRank, DateTime at) => Task(
    id: id,
    text: text,
    status: status,
    rank: newRank,
    colorKey: colorKey,
    createdAt: createdAt,
    updatedAt: at,
    completedAt: completedAt,
    deletedAt: deletedAt,
    dueDate: dueDate,
    parentId: parentId,
    source: source,
    externalId: externalId,
    attachments: attachments,
  );

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.text == text &&
      other.status == status &&
      other.rank == rank &&
      other.colorKey == colorKey &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.completedAt == completedAt &&
      other.deletedAt == deletedAt &&
      listEquals(other.attachments, attachments);

  @override
  int get hashCode => Object.hash(id, text, status, rank, colorKey, updatedAt);

  @override
  String toString() => 'Task($id, rank: $rank, status: ${status.name})';
}

/// Normaliza y valida el texto de una tarea con adjunto (spec 007, CA-007-04):
/// el texto es opcional y se devuelve null si queda vacío.
String? validateTaskContent(String raw, {required bool hasAttachment}) {
  if (!hasAttachment) return validateTaskText(raw);
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (text.length > Task.maxTextLength) throw const InvalidTaskText.tooLong();
  return text;
}

/// Normaliza y valida el texto de una tarea (sin adjunto).
/// Devuelve el texto recortado o lanza [InvalidTaskText].
String validateTaskText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) throw const InvalidTaskText.empty();
  if (text.length > Task.maxTextLength) throw const InvalidTaskText.tooLong();
  return text;
}

class InvalidTaskText implements Exception {
  const InvalidTaskText.empty() : reason = 'empty';
  const InvalidTaskText.tooLong() : reason = 'tooLong';
  final String reason;
  @override
  String toString() => 'InvalidTaskText($reason)';
}
