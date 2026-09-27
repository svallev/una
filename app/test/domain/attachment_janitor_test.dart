import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/pump_app.dart';

/// Almacén cuyo borrado falla: el janitor no debe lanzar.
class _BrokenStore extends MemoryAttachmentStore {
  @override
  Future<void> delete(String id) async => throw StateError('E/S');
  @override
  Future<void> deleteStaging(String id) async => throw StateError('E/S');
}

/// Almacén en el que una importación empieza mientras el barrido lista la
/// preparación.
class _ImportDuringSweep extends MemoryAttachmentStore {
  _ImportDuringSweep(this.registry);
  final ImportRegistry registry;

  @override
  Future<Set<String>> stagingIds() async {
    registry.add('late');
    putStaging('late', 'source', tinyImage);
    return super.stagingIds();
  }
}

void main() {
  late InMemoryTaskRepository repo;
  late MemoryAttachmentStore store;
  late ImportRegistry registry;
  late AttachmentJanitor janitor;

  setUp(() {
    repo = InMemoryTaskRepository();
    store = MemoryAttachmentStore();
    registry = ImportRegistry();
    janitor = janitorFor(repo, store, registry);
  });

  tearDown(() => repo.dispose());

  Future<Attachment> saved(String id) =>
      store.commit(stageImage(store, id), DateTime.utc(2026));

  test(
    'CA-007-16: el barrido borra los adjuntos sin tarea y las preparaciones',
    () async {
      final a = await saved('con-tarea');
      await repo.insert(
        sampleTask(id: 't').withContent(null, a, DateTime.utc(2026)),
      );
      await saved('huerfano');
      stageImage(store, 'temporal');
      store.putStaging('camara.camera', 'x', tinyImage);
      await janitor.sweep();
      expect(await store.storedIds(), {'con-tarea'});
      expect(await store.stagingIds(), isEmpty);
    },
  );

  test('CA-007-17: las completadas conservan su imagen', () async {
    final a = await saved('hecha');
    await repo.insert(
      sampleTask(id: 't').withContent('x', a, DateTime.utc(2026)),
    );
    await repo.complete('t', DateTime.utc(2026, 9, 27));
    await janitor.sweep();
    expect(await store.storedIds(), {'hecha'});
  });

  test('CA-007-16: una importación en curso nunca se barre (preparación, foto '
      'de la cámara ni adjunto aún sin guardar en la BD)', () async {
    registry
      ..add('en-curso')
      ..add('guardando')
      ..add('camara');
    stageImage(store, 'en-curso');
    store.putStaging('camara.camera', 'x', tinyImage);
    await saved('guardando');
    await janitor.sweep();
    expect(await store.stagingIds(), {'en-curso', 'camara.camera'});
    expect(await store.storedIds(), {'guardando'});
  });

  test(
    'CA-007-16: un borrado que falla no lanza (lo recoge el barrido)',
    () async {
      final broken = _BrokenStore();
      final j = janitorFor(repo, broken, registry);
      await j.discard('x');
      await j.discardStaging('y');
      await j.sweep();
    },
  );

  test('CA-007-16: una importación que empieza durante el barrido tampoco se '
      'barre', () async {
    final s = _ImportDuringSweep(registry);
    await janitorFor(repo, s, registry).sweep();
    expect(await s.stagingIds(), contains('late'));
  });

  test('CA-007-16: discardStaging deja de proteger la importación', () async {
    registry.add('a');
    stageImage(store, 'a');
    await janitor.discardStaging('a');
    expect(registry.active, isEmpty);
    expect(await store.stagingIds(), isEmpty);
  });

  test('CL-007-3: restage devuelve un adjunto a la preparación', () async {
    await saved('a');
    await janitor.restage('a');
    expect(await store.storedIds(), isEmpty);
    expect(await store.stagingIds(), {'a'});
    // Si no existe, no lanza.
    await janitor.restage('nope');
  });
}
