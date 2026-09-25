import 'package:flutter/foundation.dart';

/// Estado de una tarea. Una tarea eliminada no cambia de estado: lleva
/// `deletedAt` (tombstone, ADR-0006).
enum TaskStatus { pending, completed }

/// Tarea (docs/architecture.md §3). Inmutable; los cambios crean copias.
@immutable
class Task {
  const Task({
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
  });

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

  bool get isPending => status == TaskStatus.pending && deletedAt == null;

  /// La misma tarea, completada en [at] (spec 003, CA-003-03a). Conserva su
  /// texto, su color y su adjunto: queda en el histórico (R14, D8).
  Task complete(DateTime at) => Task(
    id: id,
    text: text,
    status: TaskStatus.completed,
    rank: rank,
    colorKey: colorKey,
    createdAt: createdAt,
    updatedAt: at,
    completedAt: at,
    deletedAt: deletedAt,
    dueDate: dueDate,
    parentId: parentId,
    source: source,
    externalId: externalId,
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
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(id, text, status, rank, colorKey, updatedAt);

  @override
  String toString() => 'Task($id, rank: $rank, status: ${status.name})';
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
