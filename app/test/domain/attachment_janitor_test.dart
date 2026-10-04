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

/// Almacén "lento": deja colar trabajo entre el listado del disco y la lectura
/// de la BD ([afterList]) y antes de cada borrado ([beforeDelete]), como si
/// el usuario eliminara y recuperara una tarea mientras el barrido avanza.
class _HookedStore extends MemoryAttachmentStore {
  Future<void> Function()? afterList;
  Future<void> Function(String id)? beforeDelete;
  final deleted = <String>[];

  @override
  Future<Set<String>> storedIds() async {
    final ids = await super.storedIds();
    final hook = afterList;
    afterList = null;
    await hook?.call();
    return ids;
  }

  @override
  Future<void> delete(String id) async {
    await beforeDelete?.call(id);
    deleted.add(id);
    return super.delete(id);
  }
}

/// Repositorio cuya lectura de adjuntos deja colar trabajo **después** de
/// leerlos ([afterRead], una sola vez), justo antes de que el barrido decida.
class _HookedRepo extends InMemoryTaskRepository {
  Future<void> Function()? afterRead;
  int reads = 0;

  @override
  Future<Set<String>> attachmentIds() async {
    reads++;
    final ids = await super.attachmentIds();
    final hook = reads > 1 ? afterRead : null;
    if (hook != null) afterRead = null;
    await hook?.call();
    return ids;
  }
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
  final at = DateTime.utc(2026);

  setUp(() {
    repo = InMemoryTaskRepository();
    store = MemoryAttachmentStore();
    registry = ImportRegistry();
    janitor = janitorFor(repo, store, registry);
  });

  tearDown(() => repo.dispose());

  Future<Attachment> saved(String id) =>
      store.commit(stageImage(store, id), at);

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

  test('CL-003-1 / CA-004-03 (ADR-0012): si la app muere entre quitar la '
      'tarea y borrar sus archivos, el barrido los recoge', () async {
    final a = await saved('hecha');
    await repo.insert(
      sampleTask(id: 't').withContent('x', a, DateTime.utc(2026)),
    );
    // Se quita la tarea, pero no se llega a llamar a discard.
    await repo.remove('t');
    await janitor.sweep();
    expect(await store.storedIds(), isEmpty);
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

  group('ADR-0021: adjuntos de una eliminación que se puede deshacer', () {
    test('CA-014-15: hold los protege del barrido aunque no tengan tarea; '
        'discardHeld los borra y deja de protegerlos', () async {
      await saved('retenido');
      expect(janitor.hold('retenido'), isTrue);
      await janitor.sweep();
      expect(await store.storedIds(), {'retenido'});

      await janitor.discardHeld('retenido');
      expect(janitor.held, isEmpty);
      expect(await store.storedIds(), isEmpty);
    });

    test('CA-014-15: discardHeld no borra los archivos de un adjunto cuya fila '
        'está en la BD (recuperación que falló al confirmar)', () async {
      final a = await saved('vuelto');
      await repo.insert(
        sampleTask(id: 't').withContent(null, a, DateTime.utc(2026)),
      );
      janitor.hold('vuelto');
      await janitor.discardHeld('vuelto');
      expect(janitor.held, isEmpty);
      expect(await store.storedIds(), {'vuelto'});
    });

    test('hold devuelve si lo ha añadido: solo suelta quien protegió', () {
      expect(janitor.hold('a'), isTrue);
      expect(janitor.hold('a'), isFalse);
      expect(janitor.held, {'a'});
      janitor.releaseHeld('a');
      expect(janitor.held, isEmpty);
    });

    test('releaseHeld deja de protegerlos sin borrar nada', () async {
      await saved('a');
      janitor
        ..hold('a')
        ..releaseHeld('a');
      expect(await store.storedIds(), {'a'});
      // Ya sin protección ni tarea: el barrido sí los recoge.
      await janitor.sweep();
      expect(await store.storedIds(), isEmpty);
    });

    test('CA-014-15: discardHeld no lanza si falla el borrado (lo recoge el '
        'barrido) y deja de protegerlos', () async {
      final j = janitorFor(repo, _BrokenStore(), registry)..hold('x');
      await j.discardHeld('x');
      expect(j.held, isEmpty);
    });

    test('la protección es aparte de las importaciones: release de una '
        'importación no suelta una eliminación con el mismo id', () async {
      await saved('a');
      janitor.hold('a');
      registry.add('a');
      janitor.release('a');
      await janitor.sweep();
      expect(await store.storedIds(), {'a'});
      expect(registry.active, isEmpty);
    });

    test('CA-014-13: sin hold (la app murió), el barrido del siguiente '
        'arranque los borra', () async {
      final a = await saved('img');
      await repo.insert(sampleTask(id: 't').withContent('x', a, at));
      janitor.hold('img');
      await repo.remove('t');
      // Otro proceso: un janitor nuevo, sin nada en `held`.
      await janitorFor(repo, store, ImportRegistry()).sweep();
      expect(await store.storedIds(), isEmpty);
    });

    test('almacén lento: eliminar y recuperar mientras el barrido avanza no '
        'borra los archivos de la tarea recuperada', () async {
      final slow = _HookedStore();
      final j = janitorFor(repo, slow, registry);
      await slow.commit(stageImage(slow, 'huerfano'), at);
      final a = await slow.commit(stageImage(slow, 'img'), at);
      final task = sampleTask(id: 't').withContent('x', a, at);
      await repo.insert(task);
      // Se elimina entre el listado del disco y la lectura de la BD (así
      // 'img' es candidato) y se recupera mientras se borra el huérfano.
      slow
        ..afterList = () async {
          j.hold('img');
          await repo.remove('t');
        }
        ..beforeDelete = (id) async {
          if (id != 'huerfano') return;
          await repo.insert(task);
          j.releaseHeld('img');
        };
      await j.sweep();
      expect(slow.deleted, ['huerfano']);
      expect(await slow.storedIds(), {'img'});
      expect(await repo.findById('t'), task);
    });

    test('el barrido mira la protección antes que la BD: una recuperación '
        'entre las dos comprobaciones no le hace borrar', () async {
      final r = _HookedRepo();
      addTearDown(r.dispose);
      final j = janitorFor(r, store, registry);
      final a = await saved('img');
      final task = sampleTask(id: 't').withContent('x', a, at);
      await r.insert(task);
      j.hold('img');
      await r.remove('t');
      // Si el barrido mirara la BD primero, la recuperación llegaría justo
      // después de esa lectura y antes de mirar la protección.
      r.afterRead = () async {
        await r.insert(task);
        j.releaseHeld('img');
      };
      await j.sweep();
      expect(await store.storedIds(), {'img'});
    });
  });
}
