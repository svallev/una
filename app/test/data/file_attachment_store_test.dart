import 'dart:io';
import 'dart:typed_data';

import 'package:app/data/attachments/file_attachment_store.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:flutter_test/flutter_test.dart';

final _bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

StagedImage _staged(String id, {int width = 4000, int height = 3000}) => (
  id: id,
  origin: AttachmentOrigin.camera,
  width: width,
  height: height,
  byteSize: 4,
);

List<String> _names(StagedImage s) {
  final tiles = ImageTiles(s.width, s.height);
  return [
    for (var r = 0; r < tiles.rows; r++)
      for (var c = 0; c < tiles.columns; c++) ImageTiles.fileName(r, c),
    'screen.jpg',
    'thumb.jpg',
  ];
}

/// Misma batería para el almacén en disco y el de memoria.
void _contract(
  String name,
  ({
    AttachmentStore store,
    void Function(String id, String name) stage,
    void Function(String id, String name) remove,
    bool Function(String id, String name) storedExists,
    Future<void> Function() dispose,
  })
  Function()
  create,
) {
  group('Contrato AttachmentStore · $name', () {
    late AttachmentStore store;
    late void Function(String, String) stage;
    late void Function(String, String) remove;
    late bool Function(String, String) exists;
    late Future<void> Function() dispose;

    setUp(() {
      final c = create();
      (store, stage, remove, exists, dispose) = (
        c.store,
        c.stage,
        c.remove,
        c.storedExists,
        c.dispose,
      );
    });
    tearDown(() => dispose());

    void stageAll(StagedImage s) {
      for (final n in _names(s)) {
        stage(s.id, n);
      }
    }

    test(
      'CA-007-07: commit mueve la preparación y devuelve el adjunto',
      () async {
        final s = _staged('a1');
        stageAll(s);
        final at = DateTime.utc(2026, 9, 26);
        final a = await store.commit(s, at);
        expect(a.id, 'a1');
        expect(
          (a.width, a.height, a.byteSize, a.mime),
          (4000, 3000, 4, 'image/jpeg'),
        );
        expect(a.origin, AttachmentOrigin.camera);
        expect(a.createdAt, at);
        expect(await store.stagingIds(), isEmpty);
        expect(await store.storedIds(), {'a1'});
        expect(exists('a1', 'full-0-0.jpg'), isTrue);
        expect(await store.check(a), AttachmentFiles.ok);
      },
    );

    test(
      'CA-007-16: delete y deleteStaging borran todo; si no existe, nada',
      () async {
        final s = _staged('a1');
        stageAll(s);
        await store.commit(s, DateTime.utc(2026));
        stageAll(_staged('b2'));
        await store.delete('a1');
        await store.deleteStaging('b2');
        await store.delete('nope');
        await store.deleteStaging('nope');
        expect(await store.storedIds(), isEmpty);
        expect(await store.stagingIds(), isEmpty);
      },
    );

    test('CA-007-19: estado de los archivos', () async {
      final s = _staged('t', width: 1080, height: 20000);
      stageAll(s);
      final a = await store.commit(s, DateTime.utc(2026));
      expect(a.tiles.rows, 5);
      expect(await store.check(a), AttachmentFiles.ok);
      remove('t', 'thumb.jpg');
      expect(await store.check(a), AttachmentFiles.derivedMissing);
      remove('t', 'full-3-0.jpg');
      expect(await store.check(a), AttachmentFiles.missing);
      await store.delete('t');
      expect(await store.check(a), AttachmentFiles.missing);
    });
  });
}

void main() {
  _contract('disco', () {
    final tmp = Directory.systemTemp.createTempSync('una_store_');
    final store = FileAttachmentStore(
      filesRoot: Directory('${tmp.path}/files'),
      stagingRoot: Directory('${tmp.path}/cache/import'),
    );
    return (
      store: store,
      stage: (id, name) => store.stagingFile(id, name)
        ..createSync(recursive: true)
        ..writeAsBytesSync(_bytes),
      remove: (id, name) => store.file('attachments/$id/$name').deleteSync(),
      storedExists: (id, name) =>
          store.file('attachments/$id/$name').existsSync(),
      dispose: () async => tmp.deleteSync(recursive: true),
    );
  });

  _contract('memoria', () {
    final store = MemoryAttachmentStore();
    return (
      store: store,
      stage: (id, name) => store.putStaging(id, name, _bytes),
      remove: store.removeFile,
      storedExists: (id, name) => store.bytes('attachments/$id/$name') != null,
      dispose: () async {},
    );
  });

  group('FileAttachmentStore: rutas seguras (T-3)', () {
    late Directory tmp;
    late FileAttachmentStore store;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('una_store_');
      store = FileAttachmentStore(
        filesRoot: Directory('${tmp.path}/files'),
        stagingRoot: Directory('${tmp.path}/cache/import'),
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('CA-007-14: un id con ../ nunca forma una ruta', () async {
      final outside = File('${tmp.path}/files/secret')
        ..createSync(recursive: true);
      await store.delete('../secret');
      await store.deleteStaging('../../files/secret');
      await store.delete('..');
      expect(outside.existsSync(), isTrue);
      expect(
        () => store.commit(_staged('../x'), DateTime.utc(2026)),
        throwsArgumentError,
      );
    });

    test(
      'CA-007-16: la preparación lista y borra también archivos sueltos',
      () async {
        File('${tmp.path}/cache/import/camera-123.jpg')
          ..createSync(recursive: true)
          ..writeAsBytesSync(_bytes);
        expect(await store.stagingIds(), {'camera-123.jpg'});
        await store.deleteStaging('camera-123.jpg');
        expect(await store.stagingIds(), isEmpty);
      },
    );
  });
}
