import 'dart:async';

import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/usecases/import_image.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/fake_image_importer.dart';

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'img-${_n++}';
}

String _token(int i) => 'content://many-$i';

const _unreadable = ImageImportFailure(ImageImportError.unreadable);

void main() {
  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late ImportRegistry registry;
  late ImportImage importImage;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    registry = ImportRegistry();
    importImage = ImportImage(
      importer: importer,
      janitor: janitorFor(InMemoryTaskRepository(), store, registry),
      ids: _SeqIds(),
    );
  });

  Future<ImportGroup> pick() async => (await importImage.pickMany())!;

  /// Corre [prepareAll] avanzando el reloj falso de 1 s en 1 s hasta que acaba.
  Future<({GroupResult? result, Object? error})> run(
    WidgetTester tester,
    ImportGroup group, {
    void Function(int index, int total)? onProgress,
    int reservedBytes = 0,
    Iterable<String> replacedStagedIds = const [],
  }) async {
    GroupResult? result;
    Object? error;
    var done = false;
    unawaited(
      group
          .prepareAll(
            onProgress: onProgress,
            reservedBytes: reservedBytes,
            replacedStagedIds: replacedStagedIds,
          )
          .then<void>((r) => result = r, onError: (Object e) => error = e)
          .whenComplete(() => done = true),
    );
    for (var i = 0; i < 400 && !done; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(done, isTrue, reason: 'prepareAll no terminó');
    return (result: result, error: error);
  }

  group('ImportImage.pickMany (CA-016-02)', () {
    test('CA-016-02: pide como mucho 10 y registra un id por foto', () async {
      importer.manyTotal = 4;
      final group = await pick();
      expect(importer.pickManyMax, [10]);
      expect(group.length, 4);
      expect(group.limited, isFalse);
      expect(registry.active, hasLength(4));
      expect(importer.copiedTokens, isEmpty, reason: 'nada copiado aún');
    });

    test('CA-016-02: el selector devuelve 5000 → solo 10 y limited', () async {
      importer.manyTotal = 5000;
      final group = await pick();
      expect(group.length, 10);
      expect(group.limited, isTrue);
      expect(registry.active, hasLength(10));
    });

    test('CA-016-02: justo 10 no es limited; 11 sí', () async {
      importer.manyTotal = 10;
      expect((await pick()).limited, isFalse);
      importer.manyTotal = 11;
      expect((await pick()).limited, isTrue);
    });

    test(
      'CA-016-02: un selector que ignora el tope se recorta igual',
      () async {
        // Un importador que devuelve más de lo pedido (defensa en profundidad).
        final greedy = _GreedyImporter(importer);
        final import = ImportImage(
          importer: greedy,
          janitor: janitorFor(InMemoryTaskRepository(), store, registry),
          ids: _SeqIds(),
        );
        final group = (await import.pickMany())!;
        expect(group.length, 10);
        expect(group.limited, isTrue);
        expect(registry.active, hasLength(10));
      },
    );

    test('CA-016-02: si el usuario cancela, nada queda registrado', () async {
      importer.userCancelsPicker = true;
      expect(await importImage.pickMany(), isNull);
      expect(registry.active, isEmpty);
    });

    test('CA-016-02: si el selector falla, nada queda registrado', () async {
      importer.pickError = const ImageImportFailure(
        ImageImportError.unreadable,
      );
      await expectLater(
        importImage.pickMany(),
        throwsA(isA<ImageImportFailure>()),
      );
      expect(registry.active, isEmpty);
    });
  });

  group('prepareAll: una tras otra (CA-016-04)', () {
    testWidgets('CA-016-04: nunca más de una foto en curso ni de un original, '
        'y en el orden del selector', (tester) async {
      importer
        ..manyTotal = 10
        ..copyDelay = const Duration(seconds: 1)
        ..sanitizeDelay = const Duration(seconds: 1);
      final group = await pick();
      final progress = <(int, int)>[];
      final out = await run(
        tester,
        group,
        onProgress: (i, n) => progress.add((i, n)),
      );
      expect(out.error, isNull);
      expect(out.result!.staged.map((s) => s.id), [
        for (var i = 0; i < 10; i++) 'img-$i',
      ]);
      expect(out.result!.failed, isEmpty);
      expect(importer.maxActive, 1, reason: 'una sola llamada a la vez');
      expect(importer.maxOriginals, 1, reason: 'un solo original a la vez');
      expect(importer.copiedTokens, [for (var i = 0; i < 10; i++) _token(i)]);
      expect(progress, [for (var i = 1; i <= 10; i++) (i, 10)]);
      // Las preparadas siguen protegidas hasta que se guarden.
      expect(registry.active, hasLength(10));
      expect(await store.stagingIds(), hasLength(10));
    });

    testWidgets('CA-016-02: 5000 elementos → solo 10 tocados', (tester) async {
      importer.manyTotal = 5000;
      final group = await pick();
      final out = await run(tester, group);
      expect(out.result!.staged, hasLength(10));
      expect(out.result!.limited, isTrue);
      expect(importer.copiedTokens, hasLength(10));
    });

    testWidgets('CA-016-03: una sola foto = el camino de la 007 (sin espacio '
        'previo; si falla, su error)', (tester) async {
      importer
        ..manyTotal = 1
        ..freeSpaceBytes = 0;
      final group = await pick();
      var out = await run(tester, group);
      expect(out.error, isNull, reason: 'no se comprueba el espacio con una');
      expect(out.result!.staged, hasLength(1));
      expect(out.result!.limited, isFalse);

      importer.copyErrorsByToken[_token(0)] = const ImageImportFailure(
        ImageImportError.tooLarge,
      );
      out = await run(tester, await pick());
      expect(out.error, isA<ImageImportFailure>());
      expect(
        (out.error! as ImageImportFailure).error,
        ImageImportError.tooLarge,
      );
      expect(
        registry.active,
        hasLength(1),
        reason: 'solo la primera, guardada',
      );
    });
  });

  group('prepareAll: fallos (CA-016-05, CL-016-16, CL-016-19)', () {
    for (final failing in [0, 4, 9]) {
      testWidgets('CA-016-05: falla la foto ${failing + 1} de 10 → se omite, '
          'las demás siguen en orden y no queda su preparación', (
        tester,
      ) async {
        importer
          ..manyTotal = 10
          ..copyErrorsByToken[_token(failing)] = const ImageImportFailure(
            ImageImportError.unsupportedType,
          );
        final out = await run(tester, await pick());
        expect(out.error, isNull);
        expect(out.result!.staged.map((s) => s.id), [
          for (var i = 0; i < 10; i++)
            if (i != failing) 'img-$i',
        ]);
        expect(out.result!.failed, [ImageImportError.unsupportedType]);
        expect(
          importer.copiedTokens,
          hasLength(10),
          reason: 'sigue tras fallar',
        );
        // Solo las buenas siguen registradas y en disco.
        expect(registry.active, {
          for (var i = 0; i < 10; i++)
            if (i != failing) 'img-$i',
        });
        expect(await store.stagingIds(), registry.active);
      });
    }

    testWidgets('CA-016-24: una foto de origen propio entre las válidas falla '
        'y las demás siguen', (tester) async {
      importer
        ..manyTotal = 4
        ..copyErrorsByToken[_token(1)] = _unreadable;
      final out = await run(tester, await pick());
      expect(out.result!.staged.map((s) => s.id), ['img-0', 'img-2', 'img-3']);
      expect(out.result!.failed, [ImageImportError.unreadable]);
    });

    testWidgets('CA-016-05: el tipo se decide por el contenido de cada una', (
      tester,
    ) async {
      importer
        ..manyTotal = 3
        ..headsByToken[_token(1)] = const [0x25, 0x50, 0x44, 0x46, 0x2D]; // PDF
      final out = await run(tester, await pick());
      expect(out.result!.staged, hasLength(2));
      expect(out.result!.failed, [ImageImportError.unsupportedType]);
    });

    testWidgets('CA-016-05: fallan todas → el error de la PRIMERA y no queda '
        'nada', (tester) async {
      importer
        ..manyTotal = 3
        ..copyErrorsByToken[_token(0)] = const ImageImportFailure(
          ImageImportError.tooManyPixels,
        )
        ..copyErrorsByToken[_token(1)] = const ImageImportFailure(
          ImageImportError.tooLarge,
        )
        ..copyErrorsByToken[_token(2)] = _unreadable;
      final out = await run(tester, await pick());
      expect(out.result, isNull);
      expect(
        (out.error! as ImageImportFailure).error,
        ImageImportError.tooManyPixels,
      );
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-16: un fallo con ruta y nombre solo deja un código', (
      tester,
    ) async {
      importer
        ..manyTotal = 3
        ..copyErrorsByToken[_token(1)] = const FormatException(
          '/sdcard/DCIM/Vacaciones-secretas-2026.jpg',
        );
      final out = await run(tester, await pick());
      expect(out.result!.failed, [ImageImportError.unreadable]);
      expect(out.result!.failed.single, isA<ImageImportError>());
      expect('${out.result!.failed}', isNot(contains('secretas')));
    });
  });

  group('prepareAll: espacio libre (CL-016-6)', () {
    // 30 MB + 10 × 16 MB = 190 MB.
    const needed = 30 * 1000 * 1000 + 10 * 16 * 1000 * 1000;

    testWidgets('CL-016-6: sin espacio → noSpace sin escribir nada ni tocar '
        'ninguna foto', (tester) async {
      importer
        ..manyTotal = 3
        ..freeSpaceBytes = needed - 1;
      final out = await run(tester, await pick());
      expect(
        (out.error! as ImageImportFailure).error,
        ImageImportError.noSpace,
      );
      expect(importer.copiedTokens, isEmpty);
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-6: con justo el espacio exigido, sigue', (
      tester,
    ) async {
      importer
        ..manyTotal = 3
        ..freeSpaceBytes = needed;
      final out = await run(tester, await pick());
      expect(out.error, isNull);
      expect(out.result!.staged, hasLength(3));
    });

    testWidgets('CL-016-6: se suma lo que ocupa el grupo que se reemplaza '
        '(guardado y preparado)', (tester) async {
      // Lo preparado se mide con sizeOf: tinyImage.length × teselas.
      store.putStaging('old', 'a', tinyImage);
      final oldSize = await store.sizeOf('old');
      importer
        ..manyTotal = 3
        ..freeSpaceBytes = needed + 5000 + oldSize - 1;
      var out = await run(
        tester,
        await pick(),
        reservedBytes: 5000,
        replacedStagedIds: ['old'],
      );
      expect(
        (out.error! as ImageImportFailure).error,
        ImageImportError.noSpace,
      );

      importer.freeSpaceBytes = needed + 5000 + oldSize;
      out = await run(
        tester,
        await pick(),
        reservedBytes: 5000,
        replacedStagedIds: ['old'],
      );
      expect(out.error, isNull);
    });

    testWidgets(
      'CL-016-6: espacio desconocido o error al medirlo → no bloquea',
      (tester) async {
        importer
          ..manyTotal = 3
          ..freeSpaceBytes = null;
        expect((await run(tester, await pick())).error, isNull);
        importer.freeSpaceError = StateError('boom');
        expect((await run(tester, await pick())).error, isNull);
      },
    );

    testWidgets('CL-016-6: quedarse sin espacio a mitad detiene todo y '
        'descarta también lo ya preparado', (tester) async {
      importer
        ..manyTotal = 8
        ..copyErrorsByToken[_token(4)] = const ImageImportFailure(
          ImageImportError.noSpace,
        );
      final out = await run(tester, await pick());
      expect(
        (out.error! as ImageImportFailure).error,
        ImageImportError.noSpace,
      );
      expect(importer.copiedTokens, hasLength(5), reason: 'se detiene');
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });
  });

  group('prepareAll: cancelar (CA-016-04, CL-016-9)', () {
    testWidgets('CL-016-9: cancelar antes de la primera → no se toca nada', (
      tester,
    ) async {
      importer.manyTotal = 5;
      final group = await pick();
      await group.cancel();
      final out = await run(tester, group);
      expect(out.error, isA<ImageImportCancelled>());
      expect(importer.copiedTokens, isEmpty);
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-9: cancelar entre fotos (al empezar la 4.ª) → no '
        'empieza ninguna más y se descarta todo', (tester) async {
      importer.manyTotal = 10;
      final group = await pick();
      final out = await run(
        tester,
        group,
        onProgress: (i, n) {
          if (i == 4) unawaited(group.cancel());
        },
      );
      expect(out.error, isA<ImageImportCancelled>());
      expect(importer.copiedTokens, hasLength(3), reason: 'la 4.ª ni empieza');
      expect(group.state, GroupState.cancelled);
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-9: cancelar a mitad de la copia de la 4.ª', (
      tester,
    ) async {
      importer
        ..manyTotal = 10
        ..copyDelaysByToken[_token(3)] = const Duration(seconds: 10);
      final group = await pick();
      final out = await run(
        tester,
        group,
        onProgress: (i, n) {
          if (i == 4) {
            unawaited(
              Future<void>.delayed(const Duration(seconds: 3), group.cancel),
            );
          }
        },
      );
      expect(out.error, isA<ImageImportCancelled>());
      expect(importer.copiedTokens, hasLength(4));
      expect(importer.cancelled, contains('img-3'));
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-9: cancelar a mitad de la limpieza de la 4.ª', (
      tester,
    ) async {
      importer.manyTotal = 10;
      final group = await pick();
      var sanitizing = false;
      importer.sanitizeDelay = Duration.zero;
      final out = await run(
        tester,
        group,
        onProgress: (i, n) {
          if (i == 4) {
            importer.sanitizeDelay = const Duration(seconds: 10);
            sanitizing = true;
            unawaited(
              Future<void>.delayed(const Duration(seconds: 3), group.cancel),
            );
          }
        },
      );
      expect(sanitizing, isTrue);
      expect(out.error, isA<ImageImportCancelled>());
      expect(importer.copiedTokens, hasLength(4));
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-9: cancelar con el nativo colgado no deja el editor '
        'esperando y no se empieza la siguiente', (tester) async {
      importer
        ..manyTotal = 4
        ..cancelHangs = true
        ..copyDelaysByToken[_token(1)] = const Duration(seconds: 15);
      final group = await pick();
      final out = await run(
        tester,
        group,
        onProgress: (i, n) {
          if (i == 2) {
            unawaited(
              Future<void>.delayed(const Duration(seconds: 2), group.cancel),
            );
          }
        },
      );
      expect(out.error, isA<ImageImportCancelled>());
      expect(importer.copiedTokens, hasLength(2));
      expect(registry.active, isEmpty);
      await tester.pump(const Duration(seconds: 30)); // el nativo acaba solo
    });
  });

  group('prepareAll: tiempos (CA-016-04, CA-016-05)', () {
    testWidgets('CA-016-04: 20 s por foto: la lenta falla y las demás siguen', (
      tester,
    ) async {
      importer
        ..manyTotal = 4
        ..copyDelaysByToken[_token(1)] = const Duration(seconds: 60);
      final out = await run(tester, await pick());
      expect(out.result!.staged.map((s) => s.id), ['img-0', 'img-2', 'img-3']);
      expect(out.result!.failed, [ImageImportError.unreadable]);
      expect(importer.cancelled, contains('img-1'));
    });

    testWidgets('CA-016-04: tras un tiempo agotado no empieza la siguiente '
        'hasta que la llamada nativa acaba (nunca dos a la vez)', (
      tester,
    ) async {
      importer
        ..manyTotal = 3
        ..cancelSettleDelay = const Duration(seconds: 2)
        ..copyDelaysByToken[_token(0)] = const Duration(seconds: 60);
      final group = await pick();
      GroupResult? result;
      unawaited(group.prepareAll().then((r) => result = r));
      await tester.pump(const Duration(seconds: 20)); // vence la 1.ª
      await tester.pump(const Duration(milliseconds: 1500));
      expect(importer.copiedTokens, [_token(0)], reason: 'aún se está yendo');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(importer.copiedTokens, hasLength(greaterThan(1)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(result, isNotNull);
      expect(importer.maxActive, 1);
      expect(importer.maxOriginals, 1);
    });

    testWidgets('CA-016-04: si la llamada nativa no acaba, la siguiente '
        'empieza a los 3 s', (tester) async {
      importer
        ..manyTotal = 2
        ..cancelSettleDelay = const Duration(seconds: 30)
        ..copyDelaysByToken[_token(0)] = const Duration(seconds: 60);
      final group = await pick();
      unawaited(group.prepareAll());
      await tester.pump(const Duration(seconds: 20));
      await tester.pump(const Duration(milliseconds: 2900));
      expect(importer.copiedTokens, [_token(0)]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(importer.copiedTokens, [_token(0), _token(1)]);
      await tester.pump(const Duration(seconds: 40));
    });

    testWidgets('CA-016-05: el total de 2 min vence → se conservan las '
        'preparadas y las que faltan cuentan como fallidas', (tester) async {
      importer
        ..manyTotal = 10
        ..copyDelay = const Duration(seconds: 19);
      final group = await pick();
      final out = await run(tester, group);
      expect(out.error, isNull, reason: 'no es una cancelación');
      expect(group.state, GroupState.expired);
      // 6 × 19 s = 114 s: la 7.ª vence a los 120 s; con las 3 que no llegaron.
      expect(out.result!.staged, hasLength(6));
      expect(out.result!.failed, [
        for (var i = 0; i < 4; i++) ImageImportError.unreadable,
      ]);
      expect(importer.copiedTokens, hasLength(7));
      expect(importer.cancelled, contains('img-6'));
      // Las preparadas se conservan y protegidas; nada más en disco.
      expect(registry.active, {for (var i = 0; i < 6; i++) 'img-$i'});
      expect(await store.stagingIds(), registry.active);
    });

    testWidgets('CA-016-05: vence el total y no había ninguna buena → el '
        'error de la primera', (tester) async {
      importer
        ..manyTotal = 10
        ..copyDelay = const Duration(seconds: 200);
      final out = await run(tester, await pick());
      expect(out.error, isA<ImageImportFailure>());
      expect(registry.active, isEmpty);
      // 6 × 20 s = 120 s: las 4 últimas ni empiezan.
      expect(importer.copiedTokens, hasLength(6));
    });
  });

  group('ImportGroup.dispose: una única salida (CL-016-17)', () {
    test('CL-016-17: cerrar el editor entre pickMany y prepareAll deja el '
        'registro vacío', () async {
      importer.manyTotal = 5;
      final group = await pick();
      expect(registry.active, hasLength(5));
      await group.dispose();
      expect(registry.active, isEmpty);
      expect(importer.copiedTokens, isEmpty);
    });

    testWidgets('CL-016-17: tras el fallo de la 5.ª y cerrar el editor, solo '
        'quedan registradas las preparadas hasta que se guardan', (
      tester,
    ) async {
      importer
        ..manyTotal = 6
        ..copyErrorsByToken[_token(4)] = _unreadable;
      final group = await pick();
      final out = await run(tester, group);
      expect(out.result!.staged, hasLength(5));
      expect(registry.active, hasLength(5));
      // Tras entregarlas, dispose no toca lo que ya es del editor.
      await group.dispose();
      expect(registry.active, hasLength(5));
      // El editor las descarta (cerrar sin guardar): ya no queda nada.
      for (final s in out.result!.staged) {
        await importImage.janitor.discardStaging(s.id);
      }
      expect(registry.active, isEmpty);
      expect(await store.stagingIds(), isEmpty);
    });

    testWidgets('CL-016-17: cancelar a mitad y volver a cancelar no falla ni '
        'duplica nada', (tester) async {
      importer.manyTotal = 3;
      final group = await pick();
      await group.cancel();
      await group.cancel();
      await group.dispose();
      final out = await run(tester, group);
      expect(out.error, isA<ImageImportCancelled>());
      expect(registry.active, isEmpty);
    });

    testWidgets('CA-016-04: prepareAll solo se puede llamar una vez', (
      tester,
    ) async {
      importer.manyTotal = 2;
      final group = await pick();
      await run(tester, group);
      await expectLater(group.prepareAll(), throwsStateError);
    });
  });
}

/// Un selector que devuelve más de lo que se le pidió.
class _GreedyImporter extends FakeImageImporter {
  _GreedyImporter(FakeImageImporter base) : super(base.store);

  @override
  Future<PickedImages?> pickMany({required int max}) async => (
    items: [
      for (var i = 0; i < 25; i++)
        (token: 'content://x-$i', origin: AttachmentOrigin.gallery),
    ],
    total: 25,
  );
}
