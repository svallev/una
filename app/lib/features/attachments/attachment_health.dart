import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/ports/attachment_store.dart';
import 'pdf_position_controller.dart' show pdfPageGapOfScreen;

/// Estado de los archivos de un adjunto que se muestra (CA-007-19).
enum AttachmentHealth {
  /// Aún se está comprobando: se dibuja la imagen (sin retrasar CA-007-08).
  checking,
  ok,

  /// Falta, está vacía o no se puede leer la versión completa (o el PDF, que
  /// tampoco se puede abrir): "Adjunto no disponible".
  missing,
}

@immutable
class AttachmentHealthState {
  const AttachmentHealthState(this.health, {this.generation = 0});

  final AttachmentHealth health;

  /// Aumenta al regenerar las derivadas: la imagen se vuelve a leer.
  final int generation;
}

/// Cola de reparaciones: regenerar derivadas (o dibujar la página de un PDF)
/// **de una en una**, nunca en paralelo (CA-016-23): con un grupo de 10 fotos
/// de 24 MP, tres decodificaciones a la vez serían el pico de memoria que el
/// grupo no se puede permitir. Un fallo de un trabajo no detiene a los demás.
class RepairQueue {
  Future<void> _tail = Future<void>.value();

  /// Ejecuta [job] cuando terminen los que ya esperaban.
  Future<T> run<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

final attachmentRepairQueueProvider = Provider<RepairQueue>(
  (ref) => RepairQueue(),
);

/// Comprueba los archivos del adjunto al mostrarlo; si solo faltan (o están
/// estropeadas) la versión de pantalla o la miniatura, las regenera en
/// segundo plano desde la completa, sin avisar. Con PDF, la versión de
/// pantalla se dibuja desde el PDF con la página de la última posición
/// (CA-008-18).
final attachmentHealthProvider = NotifierProvider.autoDispose
    .family<AttachmentHealthController, AttachmentHealthState, Attachment>(
      AttachmentHealthController.new,
    );

class AttachmentHealthController extends Notifier<AttachmentHealthState> {
  AttachmentHealthController(this.attachment);

  final Attachment attachment;
  bool _repairing = false;
  bool _repaired = false;

  @override
  AttachmentHealthState build() {
    unawaited(_check());
    return const AttachmentHealthState(AttachmentHealth.checking);
  }

  Future<void> _check() async {
    final AttachmentFiles files;
    try {
      files = await ref.read(attachmentStoreProvider).check(attachment);
    } on Object {
      // Sin poder leer el disco no se sabe qué falta: se intenta dibujar.
      return _set(AttachmentHealth.ok);
    }
    if (!ref.mounted) return;
    switch (files) {
      case AttachmentFiles.ok:
        _set(AttachmentHealth.ok);
      case AttachmentFiles.missing:
        _set(AttachmentHealth.missing);
      case AttachmentFiles.derivedMissing:
        await _repair();
    }
  }

  /// La versión de pantalla o la miniatura existe pero no se puede
  /// decodificar: se regenera una vez; si vuelve a fallar, la completa
  /// tampoco sirve.
  void reportBroken() {
    if (_repairing || state.health == AttachmentHealth.missing) return;
    if (_repaired) return _set(AttachmentHealth.missing);
    unawaited(_repair());
  }

  /// El PDF existe pero el motor no lo puede abrir (CA-008-18).
  void reportUnreadable() => _set(AttachmentHealth.missing);

  Future<void> _repair() async {
    _repairing = true;
    final queue = ref.read(attachmentRepairQueueProvider);
    final images = ref.read(attachmentImagesProvider);
    try {
      // Antes de esperar el turno: después la foto puede haber salido de la
      // vista y su `ref` ya no valdría.
      final importer = ref.read(imageImporterProvider);
      final done = await queue.run<bool>(() async {
        // Si la foto salió de la vista mientras esperaba su turno, no se
        // regenera: solo se repara lo que se ve o está a punto de verse.
        if (!ref.mounted) return false;
        if (attachment.isPdf) {
          await _renderPdfScreen();
        } else {
          await importer.regenerateDerived(attachment);
        }
        return true;
      });
      if (!done || !ref.mounted) return;
      _repaired = true;
      // Que se vuelvan a leer del disco, no de la caché.
      await images.stored(attachment.screenPath).evict();
      final thumb = attachment.thumbPath;
      if (thumb != null) await images.stored(thumb).evict();
      if (!ref.mounted) return;
      state = AttachmentHealthState(
        AttachmentHealth.ok,
        generation: state.generation + 1,
      );
    } on Object {
      // Un fallo al decodificar o regenerar nunca cierra la app: la foto (o
      // el adjunto) pasa a "no disponible" (CA-016-23).
      _set(AttachmentHealth.missing);
    } finally {
      _repairing = false;
    }
  }

  /// La versión de pantalla del PDF es lo que se ve desde la última
  /// posición, lo que se pinta en el primer fotograma (CA-008-08); sin
  /// posición legible, desde el principio. Si el PDF no se puede dibujar,
  /// lanza.
  Future<void> _renderPdfScreen() async {
    final store = ref.read(attachmentStoreProvider);
    final importer = ref.read(pdfImporterProvider);
    PdfPosition? saved;
    try {
      saved = await store.readPosition(attachment.id);
    } on Object {
      saved = null;
    }
    await importer.renderScreen(
      attachment,
      saved ?? PdfPosition.start,
      gap: pdfPageGapOfScreen(),
    );
  }

  void _set(AttachmentHealth health) {
    if (!ref.mounted) return;
    state = AttachmentHealthState(health, generation: state.generation);
  }
}
