import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';

/// Repositorio espía del barrido (CA-020-19): las filas son solo un conjunto de
/// ids (50 000 en el test), cuenta cuántos ids lleva cada consulta y no deja
/// leer la lista entera.
class _SpyRepo extends InMemoryTaskRepository {
  _SpyRepo(this.rows);

  final Set<String> rows;

  /// Tamaño de cada consulta por lote, en orden.
  final List<int> batchSizes = [];

  /// Lo que se ha preguntado, en orden.
  final List<List<String>> batches = [];
  int wholeReads = 0;

  /// Si es verdadero, la siguiente consulta lanza.
  bool failNext = false;

  /// Si no es nulo, falla la consulta número [failAt] (desde 1).
  int? failAt;

  /// Se llama tras responder a una consulta (para simular un cambio en la BD
  /// entre dos consultas).
  void Function(List<String> ids)? afterBatch;

  @override
  Future<Set<String>> attachmentIds() async {
    wholeReads++;
    return {...rows};
  }

  @override
  Future<Set<String>> existingAttachmentIds(Iterable<String> ids) async {
    final list = ids.toList();
    batches.add(list);
    batchSizes.add(list.length);
    if (failNext || failAt == batches.length) {
      failNext = false;
      throw StateError('BD');
    }
    final found = {for (final id in list) ?(rows.contains(id) ? id : null)};
    afterBatch?.call(list);
    return found;
  }
}

void main() {
  late MemoryAttachmentStore store;
  late ImportRegistry registry;

  setUp(() {
    store = MemoryAttachmentStore();
    registry = ImportRegistry();
  });

  void onDisk(Iterable<String> ids) {
    for (final id in ids) {
      store.putStored(id, 'thumb.jpg', tinyImage);
    }
  }

  group('CA-020-19: el barrido por lotes', () {
    test(
      'con 50 000 filas y huérfanos mezclados, ninguna consulta pasa de 500 '
      'ids, nunca lee la lista entera y el resultado es el de siempre',
      () async {
        final inDb = {for (var i = 0; i < 50000; i++) 'k$i'};
        final orphans = {for (var i = 0; i < 1200; i++) 'huerfano$i'};
        final protectedByImport = {'imp0', 'imp1'};
        final held = {'ret0', 'ret1'};
        final repo = _SpyRepo(inDb);
        final janitor = AttachmentJanitor(
          store: store,
          repository: repo,
          registry: registry,
        );
        onDisk(inDb);
        onDisk(orphans);
        onDisk(protectedByImport);
        onDisk(held);
        protectedByImport.forEach(registry.add);
        janitor.holdAll(held);

        await janitor.sweep();

        expect(repo.wholeReads, 0, reason: 'nunca attachmentIds()');
        expect(repo.batchSizes, isNotEmpty);
        expect(
          repo.batchSizes.reduce((a, b) => a > b ? a : b),
          lessThanOrEqualTo(500),
        );
        // Todos los candidatos con archivo salvo los protegidos, en lotes de
        // 500 (más una consulta por cada huérfano, justo antes de borrar).
        expect(
          repo.batches.where((b) => b.length > 1).length,
          greaterThan(100),
        );
        // `equals` sobre 50 000 elementos es cuadrático: se compara a mano.
        final left = await store.storedIds();
        expect(left.length, inDb.length + 4);
        expect(
          left.containsAll({...inDb, ...protectedByImport, ...held}),
          isTrue,
        );
      },
    );

    test(
      'CA-020-19: la comprobación final es por id, justo antes de borrar',
      () async {
        final repo = _SpyRepo({'a'});
        final janitor = AttachmentJanitor(
          store: store,
          repository: repo,
          registry: registry,
        );
        onDisk(['a', 'huerfano']);
        await janitor.sweep();
        expect(repo.batches, [
          ['a', 'huerfano'],
          ['huerfano'],
        ]);
        expect(await store.storedIds(), {'a'});
      },
    );

    test('CA-020-19: una tarea recuperada entre el lote y el borrado no se '
        'borra (la protección primero y la BD después)', () async {
      final repo = _SpyRepo({});
      final janitor = AttachmentJanitor(
        store: store,
        repository: repo,
        registry: registry,
      );
      onDisk(['recuperada', 'huerfano']);
      // El lote dice que ninguna tiene fila; antes de la comprobación final,
      // «deshacer» guarda la fila de «recuperada».
      repo.afterBatch = (ids) {
        if (ids.length > 1) repo.rows.add('recuperada');
      };
      await janitor.sweep();
      expect(await store.storedIds(), {'recuperada'});
    });

    test('CA-020-19 / CA-014-13: una retenida y una importación en curso, '
        'aunque no tengan fila, no se tocan ni se consultan', () async {
      final repo = _SpyRepo({});
      final janitor = AttachmentJanitor(
        store: store,
        repository: repo,
        registry: registry,
      );
      onDisk(['ret', 'imp', 'huerfano']);
      janitor.hold('ret');
      registry.add('imp');
      await janitor.sweep();
      expect(await store.storedIds(), {'ret', 'imp'});
      expect(repo.batches.expand((b) => b), isNot(contains('ret')));
      expect(repo.batches.expand((b) => b), isNot(contains('imp')));
    });

    test('CA-020-19: una retención hecha durante el barrido protege al '
        'candidato aunque el lote ya lo diera por sin fila', () async {
      final repo = _SpyRepo({});
      final janitor = AttachmentJanitor(
        store: store,
        repository: repo,
        registry: registry,
      );
      onDisk(['x', 'huerfano']);
      repo.afterBatch = (ids) {
        if (ids.length > 1) janitor.hold('x');
      };
      await janitor.sweep();
      // `x` se retuvo tras el lote: ya no se borra, pero tampoco hay que
      // consultarlo otra vez para saberlo; el huérfano sí cae.
      expect(await store.storedIds(), {'x'});
    });

    test('CA-020-19: si la consulta de un lote lanza, el barrido se corta sin '
        'borrar nada más (tampoco las preparaciones)', () async {
      final repo = _SpyRepo({'a'})..failNext = true;
      final janitor = AttachmentJanitor(
        store: store,
        repository: repo,
        registry: registry,
      );
      onDisk(['a', 'huerfano']);
      stageImage(store, 'prep');
      await janitor.sweep();
      expect(await store.storedIds(), {'a', 'huerfano'});
      expect(await store.stagingIds(), {'prep'});
      expect(repo.batches, hasLength(1));
    });

    test('CA-020-19: si falla la consulta del segundo lote, lo ya borrado '
        'antes está bien y nada más se borra', () async {
      final inDb = {for (var i = 0; i < 600; i++) 'k$i'};
      final repo = _SpyRepo(inDb);
      final janitor = AttachmentJanitor(
        store: store,
        repository: repo,
        registry: registry,
      );
      onDisk(inDb);
      onDisk(['o1', 'o2']);
      // Consultas: 1.ª = lote 1 (500), 2.ª = lote 2 (100 + huérfanos), la
      // siguiente, la comprobación final por id.
      repo.failAt = 2;
      await janitor.sweep();
      expect(await store.storedIds(), {...inDb, 'o1', 'o2'});
    });

    test('CA-020-19: si falla la comprobación final de un huérfano, no se '
        'borra y el barrido se corta', () async {
      final repo = _SpyRepo({'a'});
      final janitor = AttachmentJanitor(
        store: store,
        repository: repo,
        registry: registry,
      );
      onDisk(['a', 'o1', 'o2']);
      repo.failAt = 2;
      await janitor.sweep();
      expect(await store.storedIds(), {'a', 'o1', 'o2'});
      expect(repo.batches, hasLength(2));
    });

    test('CA-020-19: sin archivos en disco no consulta nada', () async {
      final repo = _SpyRepo({'a'});
      final janitor = AttachmentJanitor(
        store: store,
        repository: repo,
        registry: registry,
      );
      stageImage(store, 'prep');
      await janitor.sweep();
      expect(repo.batches, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });
  });
}
