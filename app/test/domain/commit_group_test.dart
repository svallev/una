import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/services/commit_group.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';

/// Almacén que falla al mover la foto número [failAt] (0 = la primera) y,
/// si [restageFails], tampoco puede devolver nada a la preparación.
class _FlakyStore extends MemoryAttachmentStore {
  _FlakyStore({this.failAt, this.restageFails = false});

  final int? failAt;
  final bool restageFails;
  int commits = 0;
  int stagingListings = 0;

  @override
  Future<Attachment> commit(StagedAttachment staged, DateTime at) {
    if (commits++ == failAt) throw StateError('E/S al mover');
    return super.commit(staged, at);
  }

  @override
  Future<void> restage(String id) {
    if (restageFails) throw StateError('E/S al devolver');
    return super.restage(id);
  }

  @override
  Future<Set<String>> stagingIds() {
    stagingListings++;
    return super.stagingIds();
  }
}

void main() {
  final at = DateTime.utc(2026);
  final ids = [for (var i = 0; i < 10; i++) 'foto$i'];

  List<StagedAttachment> stageAll(MemoryAttachmentStore store) => [
    for (final id in ids) stageImage(store, id),
  ];

  test('CA-016-16: un grupo de 10 se mueve entero y en orden', () async {
    final store = _FlakyStore();
    final moved = await commitGroup(store, stageAll(store), at);
    expect([for (final a in moved) a.id], ids);
    // Una sola consulta de la zona temporal, no una por foto.
    expect(store.stagingListings, 1);
    expect(await store.storedIds(), ids.toSet());
    expect(await store.stagingIds(), isEmpty);
  });

  for (final failAt in [0, 4, 9]) {
    test(
      'CA-016-16: si falla al mover la foto ${failAt + 1}, las movidas '
      'vuelven a la preparación y no queda ninguna en attachments/',
      () async {
        final store = _FlakyStore(failAt: failAt);
        await expectLater(
          commitGroup(store, stageAll(store), at),
          throwsA(isA<StateError>()),
        );
        expect(await store.storedIds(), isEmpty);
        expect(await store.stagingIds(), ids.toSet());
      },
    );

    test(
      'CA-016-16: si falla la foto ${failAt + 1} y no se puede devolver '
      'nada, las movidas se borran: no queda ningún archivo huérfano',
      () async {
        final store = _FlakyStore(failAt: failAt, restageFails: true);
        await expectLater(
          commitGroup(store, stageAll(store), at),
          throwsA(isA<StateError>()),
        );
        expect(await store.storedIds(), isEmpty);
        // Solo quedan las que no llegaron a moverse (siguen preparadas).
        expect(await store.stagingIds(), ids.skip(failAt).toSet());
      },
    );
  }

  test('CL-016-6b: si falta una preparación (el sistema vació la zona '
      'temporal), StagedPhotosLost y no se mueve nada', () async {
    final store = _FlakyStore();
    final staged = stageAll(store);
    await store.deleteStaging('foto3');
    await store.deleteStaging('foto7');
    final error = await commitGroup(
      store,
      staged,
      at,
    ).then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, isA<StagedPhotosLost>());
    expect((error! as StagedPhotosLost).ids, ['foto3', 'foto7']);
    expect(store.commits, 0);
    expect(await store.storedIds(), isEmpty);
    expect(await store.stagingIds(), hasLength(8));
  });

  test('StagedPhotosLost no lleva más que ids (nada que registrar)', () {
    expect(StagedPhotosLost(['a', 'b']).toString(), 'StagedPhotosLost(2)');
  });

  test(
    'CA-016-16: una web no tiene preparación: no la busca ni falla',
    () async {
      final store = _FlakyStore();
      const web = StagedWeb(id: 'w', url: 'https://example.org');
      final moved = await commitGroup(store, [web], at);
      expect(moved.single.isWeb, isTrue);
      expect(store.stagingListings, 0);
    },
  );

  test('CA-016-16: un grupo vacío no hace nada', () async {
    final store = _FlakyStore();
    expect(await commitGroup(store, const [], at), isEmpty);
    expect(store.stagingListings, 0);
  });

  group('sizeOf', () {
    test('CA-016-04: mide la preparación; 0 si no existe', () async {
      final store = MemoryAttachmentStore();
      final staged = stageImage(store, 'a', width: 100, height: 100);
      expect(await store.sizeOf('a'), greaterThan(0));
      expect(await store.sizeOf('a'), staged.byteSize + 2 * tinyImage.length);
      expect(await store.sizeOf('nope'), 0);
    });

    test('CA-016-04: si no se puede medir, se usa el estimado', () async {
      final broken = _SizeFails();
      expect(
        await stagedSizeOrEstimate(broken, 'a'),
        ImageLimits.storedPhotoEstimate,
      );
      final ok = MemoryAttachmentStore();
      stageImage(ok, 'a', width: 100, height: 100);
      expect(await stagedSizeOrEstimate(ok, 'a'), await ok.sizeOf('a'));
    });
  });
}

class _SizeFails extends MemoryAttachmentStore {
  @override
  Future<int> sizeOf(String id) async => throw StateError('E/S');
}
