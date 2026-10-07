import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/ports/attachment_store.dart';
import 'attachment_health.dart';

/// Los adjuntos de una tarea como clave de un proveedor (igualdad por
/// contenido: una lista de Dart no se compara por valor).
@immutable
class AttachmentGroupKey {
  AttachmentGroupKey(List<Attachment> attachments)
    : attachments = List.unmodifiable(attachments);

  final List<Attachment> attachments;

  @override
  bool operator ==(Object other) =>
      other is AttachmentGroupKey && listEquals(other.attachments, attachments);

  @override
  int get hashCode => Object.hashAll(attachments);
}

@immutable
class GroupHealthState {
  const GroupHealthState(this.health, {this.missingIds = const {}});

  /// [AttachmentHealth.missing] solo si la tarea entera no se puede mostrar:
  /// faltan **todas** las fotos o el grupo no es válido (CA-016-18b, CA-016-25).
  final AttachmentHealth health;

  /// Fotos cuyo archivo falta, está vacío o no se pudo leer. Las que no están
  /// aquí se ven con normalidad; las que sí, como "Foto no disponible" en su
  /// sitio (CA-016-18a).
  final Set<String> missingIds;
}

/// Salud de **todos** los adjuntos de una tarea (spec 016): decide si se ve la
/// tarjeta "Adjunto no disponible" (CA-016-18b).
///
/// - Un grupo no válido (`isValidGroup` falso: tipo desconocido, medidas
///   fuera de rango, mezcla, más de 10) es "no disponible" **al instante**,
///   sin tocar el disco ni dibujar nada: la salud decide antes de cualquier
///   layout (plan §5, CA-016-25).
/// - Un solo adjunto: lo que diga [attachmentHealthProvider], como en las
///   specs 007 y 008 (también regenera sus derivadas).
/// - Un grupo de 2 a 10 fotos: solo un `check` barato de cada una, sin
///   regenerar nada. Regenerar es de cada foto (`attachmentHealthProvider`),
///   solo la que está a la vista y las contiguas, una tras otra.
final groupHealthProvider = NotifierProvider.autoDispose
    .family<GroupHealthController, GroupHealthState, AttachmentGroupKey>(
      GroupHealthController.new,
    );

class GroupHealthController extends Notifier<GroupHealthState> {
  GroupHealthController(this.key);

  final AttachmentGroupKey key;

  /// Las que `check` dio por perdidas y las que el carrusel ha ido
  /// encontrando ilegibles ([reportMissing]).
  final _missing = <String>{};
  bool _checked = false;

  List<Attachment> get _all => key.attachments;

  @override
  GroupHealthState build() {
    final all = _all;
    if (!all.isValidGroup) {
      return GroupHealthState(
        AttachmentHealth.missing,
        missingIds: {for (final a in all) a.id},
      );
    }
    if (all.isEmpty) return const GroupHealthState(AttachmentHealth.ok);
    if (all.length == 1) {
      final single = all.single;
      final health = ref.watch(attachmentHealthProvider(single)).health;
      return GroupHealthState(
        health,
        missingIds: health == AttachmentHealth.missing ? {single.id} : const {},
      );
    }
    unawaited(_check());
    return const GroupHealthState(AttachmentHealth.checking);
  }

  Future<void> _check() async {
    final store = ref.read(attachmentStoreProvider);
    for (final a in _all) {
      try {
        if (await store.check(a) == AttachmentFiles.missing) _missing.add(a.id);
      } on Object {
        // Sin poder leer el disco no se sabe qué falta: se intenta dibujar.
      }
      if (!ref.mounted) return;
    }
    _checked = true;
    _publish();
  }

  /// Una foto que se intentó dibujar y no se pudo, ni regenerándola: cuenta
  /// como perdida. Si ya lo están todas, la tarea entera es "no disponible".
  void reportMissing(String id) {
    if (!_all.any((a) => a.id == id) || !_missing.add(id)) return;
    if (_checked) _publish();
  }

  void _publish() {
    if (!ref.mounted) return;
    state = GroupHealthState(
      _missing.length >= _all.length
          ? AttachmentHealth.missing
          : AttachmentHealth.ok,
      missingIds: Set.unmodifiable(_missing),
    );
  }
}
