import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

/// Cuenta las consultas por lote.
class _CountingRepo extends InMemoryTaskRepository {
  int batchQueries = 0;
  bool failBatch = false;

  @override
  Future<Set<String>> existingAttachmentIds(Iterable<String> ids) {
    batchQueries++;
    if (failBatch) throw StateError('BD');
    return super.existingAttachmentIds(ids);
  }
}

/// Almacén cuyo borrado y cuya devolución a la preparación fallan solo con
/// [failing]: el resto del lote debe hacerse igual.
class _SelectiveStore extends MemoryAttachmentStore {
  _SelectiveStore(this.failing);

  final Set<String> failing;

  @override
  Future<void> delete(String id) async {
    if (failing.contains(id)) throw StateError('E/S');
    return super.delete(id);
  }

  @override
  Future<void> restage(String id) async {
    if (failing.contains(id)) throw StateError('E/S');
    return super.restage(id);
  }
}

void main() {
  late _CountingRepo repo;
  late MemoryAttachmentStore store;
  late ImportRegistry registry;
  late AttachmentJanitor janitor;
  final at = DateTime.utc(2026);
  final ids = [for (var i = 0; i < 10; i++) 'foto$i'];

  setUp(() {
    repo = _CountingRepo();
    store = MemoryAttachmentStore();
    registry = ImportRegistry();
    janitor = janitorFor(repo, store, registry);
  });

  tearDown(() => repo.dispose());

  Future<List<Attachment>> savedAll(
    MemoryAttachmentStore s, [
    Iterable<String>? which,
  ]) async => [
    for (final id in which ?? ids) await s.commit(stageImage(s, id), at),
  ];

  group('CA-016-16: lotes del janitor', () {
    test('holdAll devuelve solo los que ha retenido esta llamada y los '
        'protege del barrido', () async {
      await savedAll(store);
      expect(janitor.holdAll(['foto0', 'foto1']), {'foto0', 'foto1'});
      expect(janitor.holdAll(['foto1', 'foto2']), {'foto2'});
      expect(janitor.held, {'foto0', 'foto1', 'foto2'});
      await janitor.sweep();
      expect(await store.storedIds(), {'foto0', 'foto1', 'foto2'});
    });

    test('releaseHeldAll deja de proteger sin borrar nada', () async {
      await savedAll(store);
      janitor
        ..holdAll(ids)
        ..releaseHeldAll(ids);
      expect(janitor.held, isEmpty);
      expect(await store.storedIds(), ids.toSet());
    });

    test('discardHeldAll borra las 10 y deja de retenerlas, con una sola '
        'consulta por lote (no una por foto)', () async {
      await savedAll(store);
      janitor.holdAll(ids);
      await janitor.discardHeldAll(ids);
      expect(janitor.held, isEmpty);
      expect(await store.storedIds(), isEmpty);
      expect(repo.batchQueries, 1);
    });

    test('discardHeldAll no borra las que tienen fila en la BD '
        '(recuperación que falló al confirmar) y sí las demás', () async {
      final saved = await savedAll(store);
      await repo.insert(
        sampleTask(id: 't')
            .withContent(null, null, at, attachments: saved.take(2).toList()),
      );
      janitor.holdAll(ids);
      await janitor.discardHeldAll(ids);
      expect(janitor.held, isEmpty);
      expect(await store.storedIds(), {'foto0', 'foto1'});
    });

    test('discardHeldAll: si la BD no se puede leer, no borra nada (lo '
        'recoge otro barrido) y no lanza', () async {
      await savedAll(store);
      repo.failBatch = true;
      janitor.holdAll(ids);
      await janitor.discardHeldAll(ids);
      expect(janitor.held, isEmpty);
      expect(await store.storedIds(), ids.toSet());
    });

    test('un lote vacío no consulta la BD', () async {
      await janitor.discardHeldAll(const []);
      await janitor.discardAll(const []);
      await janitor.restageAll(const []);
      janitor.releaseAll(const []);
      expect(repo.batchQueries, 0);
    });

    test('discardAll borra todas; un fallo con una no impide borrar las '
        'demás ni lanza', () async {
      final s = _SelectiveStore({'foto4'});
      final j = janitorFor(repo, s, registry);
      await savedAll(s);
      await j.discardAll(ids);
      expect(await s.storedIds(), {'foto4'});
    });

    test('restageAll devuelve las 10 a la preparación', () async {
      await savedAll(store);
      await janitor.restageAll(ids);
      expect(await store.storedIds(), isEmpty);
      expect(await store.stagingIds(), ids.toSet());
    });

    test('restageAll: la que no se puede devolver se borra y el lote sigue; '
        'no lanza', () async {
      final s = _SelectiveStore({'foto4'});
      final j = janitorFor(repo, s, registry);
      await savedAll(s);
      await j.restageAll(ids);
      // 'foto4' tampoco se pudo borrar: queda para el barrido.
      expect(await s.stagingIds(), ids.toSet()..remove('foto4'));
      expect(await s.storedIds(), {'foto4'});
    });

    test('releaseAll suelta del registro todas las importaciones', () async {
      ids.forEach(registry.add);
      registry.add('otra');
      janitor.releaseAll(ids);
      expect(registry.active, {'otra'});
    });

    test('el barrido no toca un grupo entero en importación ni uno '
        'retenido', () async {
      for (final id in ids.take(5)) {
        registry.add(id);
        stageImage(store, id);
      }
      await savedAll(store, ids.skip(5));
      janitor.holdAll(ids.skip(5));
      await janitor.sweep();
      expect(await store.stagingIds(), ids.take(5).toSet());
      expect(await store.storedIds(), ids.skip(5).toSet());
    });
  });
}
