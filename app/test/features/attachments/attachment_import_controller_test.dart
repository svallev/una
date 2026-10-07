import 'dart:async';
import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/usecases/import_image.dart';
import 'package:app/features/attachments/attachment_import_controller.dart';
import 'package:app/features/attachments/import_error_text.dart';
import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_image_importer.dart';
import '../../support/fake_pdf_importer.dart';

/// Un grupo cuya preparación lanza una excepción sin tipo (CA-016-24).
class _ExplodingGroup implements ImportGroup {
  var runs = 0;

  @override
  bool get limited => false;
  @override
  int get length => 2;
  @override
  GroupState get state => GroupState.running;

  @override
  Future<GroupResult> prepareAll({
    void Function(int index, int total)? onProgress,
    int reservedBytes = 0,
    Iterable<String> replacedStagedIds = const [],
  }) async {
    runs++;
    onProgress?.call(1, 2);
    throw StateError('content://media/secret/1.jpg');
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

class _ExplodingImport extends ImportImage {
  _ExplodingImport(Ref ref, this.group)
    : super(
        importer: ref.read(imageImporterProvider),
        janitor: ref.read(attachmentJanitorProvider),
        ids: ref.read(idGeneratorProvider),
      );
  final ImportGroup group;

  @override
  Future<ImportGroup?> pickMany() async => group;
}

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'img-${_n++}';
}

const _pngHead = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0];
final _svgHead = '<?xml version="1.0"?><svg'.codeUnits;
// ftyp heic
const _heicHead = [
  0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, //
  0x68, 0x65, 0x69, 0x63, 0x00, 0x00, 0x00, 0x00,
  0x6D, 0x69, 0x66, 0x31, 0x68, 0x65, 0x69, 0x63,
];

void main() {
  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late ImportRegistry registry;
  late ProviderContainer container;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    registry = ImportRegistry();
    final repo = InMemoryTaskRepository();
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        attachmentStoreProvider.overrideWithValue(store),
        importRegistryProvider.overrideWithValue(registry),
        idGeneratorProvider.overrideWithValue(_SeqIds()),
        imageImporterProvider.overrideWithValue(importer),
      ],
    );
    // El editor la mantiene viva mientras está abierto.
    container.listen(attachmentImportProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  AttachmentImportController ctrl() =>
      container.read(attachmentImportProvider.notifier);
  AttachmentImportState state() => container.read(attachmentImportProvider);
  Future<Set<String>> staging() => store.stagingIds();

  testWidgets('CA-007-13: el tipo se decide por el contenido y queda lista', (
    tester,
  ) async {
    importer.head = _pngHead;
    expect(await ctrl().pick(AttachmentOrigin.gallery), ImportOutcome.added);

    expect(importer.sniffedTypes, [ImageType.png]);
    expect(importer.limits, [
      ImageLimits.maxBytes,
      ImageLimits.maxPixels,
      ImageLimits.storedMaxPixels,
    ]);
    final image = state().image!;
    expect(image.id, 'img-0');
    expect(image.origin, AttachmentOrigin.gallery);
    expect(state().preparing, isFalse);
    expect(state().error, isNull);
    // Protegida del barrido hasta que se guarde la tarea (CA-007-16).
    expect(registry.active, {'img-0'});
  });

  testWidgets(
    'CA-007-13: un SVG (u otro formato no admitido) da error, no deja nada y '
    'el editor queda como estaba',
    (tester) async {
      await ctrl().pick(AttachmentOrigin.gallery);
      final before = state().image;

      importer.head = _svgHead;
      expect(await ctrl().pick(AttachmentOrigin.gallery), ImportOutcome.failed);

      expect(state().error, ImageImportError.unsupportedType);
      expect(state().image, before);
      expect(importer.sniffedTypes, [ImageType.jpeg]);
      expect(await staging(), {'img-0'});
      expect(registry.active, {'img-0'});
    },
  );

  testWidgets('CA-007-13: HEIC solo si el dispositivo lo decodifica', (
    tester,
  ) async {
    importer
      ..head = _heicHead
      ..heicSupported = false;
    await ctrl().pick(AttachmentOrigin.gallery);
    expect(state().error, ImageImportError.unsupportedType);
    expect(await staging(), isEmpty);

    importer.heicSupported = true;
    await ctrl().pick(AttachmentOrigin.gallery);
    expect(state().error, isNull);
    expect(importer.sniffedTypes, [ImageType.heic]);
  });

  for (final error in [
    ImageImportError.tooLarge,
    ImageImportError.tooManyPixels,
    ImageImportError.unreadable,
    ImageImportError.noSpace,
  ]) {
    testWidgets(
      'CA-007-14 / CL-007-3: si la importación falla (${error.name}), se '
      'avisa y no quedan temporales',
      (tester) async {
        if (error == ImageImportError.tooManyPixels) {
          importer.sanitizeError = ImageImportFailure(error);
        } else {
          importer.copyError = ImageImportFailure(error);
        }
        await ctrl().pick(AttachmentOrigin.camera);

        expect(state().error, error);
        expect(state().image, isNull);
        expect(state().preparing, isFalse);
        expect(await staging(), isEmpty);
        expect(registry.active, isEmpty);
      },
    );
  }

  testWidgets('CA-007-14: a los 20 s se aborta, se avisa y no queda nada', (
    tester,
  ) async {
    importer.sanitizeDelay = const Duration(seconds: 60);
    final done = ctrl().pick(AttachmentOrigin.gallery);
    await tester.pump(const Duration(seconds: 19));
    expect(state().preparing, isTrue);
    expect(importer.cancelled, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await done;

    expect(importer.cancelled, ['img-0']);
    expect(state().error, ImageImportError.unreadable);
    expect(state().preparing, isFalse);
    expect(await staging(), isEmpty);
    expect(registry.active, isEmpty);
  });

  testWidgets('CA-007-14: aunque cancelar se cuelgue (proveedor sin red), a '
      'los 20 s se avisa y no queda nada', (tester) async {
    importer
      ..sanitizeDelay = const Duration(seconds: 60)
      ..cancelHangs = true;
    final done = ctrl().pick(AttachmentOrigin.gallery);
    await tester.pump(const Duration(seconds: 20));
    await done;
    expect(state().error, ImageImportError.unreadable);
    expect(state().preparing, isFalse);
    expect(await staging(), isEmpty);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets('CA-007-15: aunque cancelar se cuelgue, "Cancelar" termina en '
      '2 s como mucho y no queda nada', (tester) async {
    importer
      ..sanitizeDelay = const Duration(seconds: 60)
      ..cancelHangs = true;
    unawaited(ctrl().pick(AttachmentOrigin.gallery));
    await tester.pump(const Duration(seconds: 1));
    expect(state().preparing, isTrue);
    var cancelled = false;
    unawaited(ctrl().cancel().then((_) => cancelled = true));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(cancelled, isTrue);
    expect(state().preparing, isFalse);
    expect(await staging(), isEmpty);
    await tester.pump(const Duration(seconds: 60));
  });

  group('CA-016-24: una excepción sin tipo no deja el editor bloqueado', () {
    for (final (label, run) in <(String, Future<ImportOutcome> Function())>[
      ('el selector múltiple', () => ctrl().pickMany()),
      (
        'el selector de una imagen',
        () => ctrl().pick(AttachmentOrigin.gallery),
      ),
    ]) {
      testWidgets('$label: un StateError sale como "no se pudo leer", sin '
          'preparar y sin su texto', (tester) async {
        importer.pickError = StateError('content://media/secret/1.jpg');
        expect(await run(), ImportOutcome.failed);
        expect(state().error, ImageImportError.unreadable);
        expect(state().preparing, isFalse);
        expect(state().showPreparing, isFalse);
        expect(registry.active, isEmpty);
        expect(await staging(), isEmpty);
        // No queda ocupado: la siguiente importación funciona.
        importer.pickError = null;
        expect(await run(), ImportOutcome.added);
        expect(state().error, isNull);
      });
    }

    testWidgets('al preparar: un fallo inesperado deja el estado limpio, '
        '"Cancelar" no hace nada y se puede volver a importar', (tester) async {
      final exploding = _ExplodingGroup();
      final broken = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
          attachmentStoreProvider.overrideWithValue(store),
          importRegistryProvider.overrideWithValue(registry),
          idGeneratorProvider.overrideWithValue(_SeqIds()),
          imageImporterProvider.overrideWithValue(importer),
          importImageProvider.overrideWith(
            (ref) => _ExplodingImport(ref, exploding),
          ),
        ],
      );
      addTearDown(broken.dispose);
      broken.listen(attachmentImportProvider, (_, _) {});
      final c = broken.read(attachmentImportProvider.notifier);
      final seen = <bool>[];
      broken.listen(
        attachmentImportProvider,
        (_, now) => seen.add(now.preparing),
      );

      expect(await c.pickMany(), ImportOutcome.failed);
      expect(seen, contains(true)); // sí llegó a "Preparando"
      final s = broken.read(attachmentImportProvider);
      expect(s.error, ImageImportError.unreadable);
      expect(s.preparing, isFalse);
      expect(s.showPreparing, isFalse);
      await c.cancel(); // sin trabajo en curso: no hace nada ni lanza
      expect(broken.read(attachmentImportProvider).error, isNotNull);

      // No queda ocupado: la siguiente importación se intenta.
      expect(await c.pickMany(), ImportOutcome.failed);
      expect(exploding.runs, 2);
    });
  });

  testWidgets('CA-007-02/03: sin cámara se avisa; cancelar el selector no '
      'cambia nada', (tester) async {
    importer.pickError = const ImageImportFailure(ImageImportError.noCamera);
    await ctrl().pick(AttachmentOrigin.camera);
    expect(state().error, ImageImportError.noCamera);
    expect(registry.active, isEmpty);

    importer
      ..pickError = null
      ..userCancelsPicker = true;
    expect(
      await ctrl().pick(AttachmentOrigin.gallery),
      ImportOutcome.unchanged,
    );
    expect(state().error, isNull);
    expect(state().image, isNull);
    expect(state().preparing, isFalse);
    expect(await staging(), isEmpty);
    expect(registry.active, isEmpty);
  });

  testWidgets(
    'CA-007-15: "Preparando imagen…" solo aparece si tarda más de 400 ms',
    (tester) async {
      importer.sanitizeDelay = const Duration(milliseconds: 300);
      var done = ctrl().pick(AttachmentOrigin.gallery);
      await tester.pump(Duration.zero);
      expect(state().preparing, isTrue);
      expect(state().showPreparing, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      await done;
      expect(state().preparing, isFalse);
      expect(state().showPreparing, isFalse);
      expect(state().image, isNotNull);

      importer.sanitizeDelay = const Duration(seconds: 2);
      done = ctrl().pick(AttachmentOrigin.gallery);
      await tester.pump(const Duration(milliseconds: 399));
      expect(state().showPreparing, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state().showPreparing, isTrue);
      await tester.pump(const Duration(seconds: 2));
      await done;
      expect(state().showPreparing, isFalse);
      expect(state().image!.id, 'img-1');
    },
  );

  testWidgets('CA-007-15: mientras se prepara, otra importación no hace nada', (
    tester,
  ) async {
    importer.copyDelay = const Duration(seconds: 1);
    final first = ctrl().pick(AttachmentOrigin.gallery);
    await tester.pump(Duration.zero);
    await ctrl().pick(AttachmentOrigin.camera);
    expect(importer.picks, ['img-0']);

    await tester.pump(const Duration(seconds: 1));
    await first;
    expect(state().image!.id, 'img-0');
  });

  testWidgets(
    'CA-007-15: "Cancelar" borra lo copiado y el editor queda como estaba',
    (tester) async {
      await ctrl().pick(AttachmentOrigin.gallery);
      final before = state().image!;

      importer.sanitizeDelay = const Duration(seconds: 5);
      final done = ctrl().pick(AttachmentOrigin.camera);
      await tester.pump(const Duration(seconds: 1));
      expect(state().showPreparing, isTrue);

      await ctrl().cancel();
      expect(state().preparing, isFalse);
      expect(state().showPreparing, isFalse);
      expect(state().image, before);
      await done;

      expect(importer.cancelled, ['img-1']);
      expect(state().error, isNull);
      expect(state().image, before);
      expect(await staging(), {before.id});
      expect(registry.active, {before.id});

      // Se puede volver a importar enseguida.
      importer.sanitizeDelay = Duration.zero;
      await ctrl().pick(AttachmentOrigin.gallery);
      expect(state().image!.id, 'img-2');
    },
  );

  testWidgets(
    'CA-007-06: al sustituir, la anterior se borra solo cuando la nueva está '
    'lista',
    (tester) async {
      await ctrl().pick(AttachmentOrigin.gallery);
      importer.sanitizeDelay = const Duration(seconds: 1);
      final done = ctrl().pick(AttachmentOrigin.camera);
      await tester.pump(Duration.zero);
      expect(await staging(), containsAll(['img-0', 'img-1']));

      await tester.pump(const Duration(seconds: 1));
      await done;
      expect(state().image!.id, 'img-1');
      expect(await staging(), {'img-1'});
      expect(registry.active, {'img-1'});
    },
  );

  testWidgets('CA-007-06: "Quitar adjunto" borra la imagen preparada', (
    tester,
  ) async {
    await ctrl().pick(AttachmentOrigin.gallery);
    await ctrl().remove();
    expect(state().image, isNull);
    expect(await staging(), isEmpty);
    expect(registry.active, isEmpty);
  });

  testWidgets('CA-007-16: al guardar la tarea, la imagen ya no es del editor y '
      'cerrarlo no la borra', (tester) async {
    await ctrl().pick(AttachmentOrigin.gallery);
    ctrl().saved();
    expect(state().image, isNull);
    container.dispose();
    await tester.pump(Duration.zero);
    expect(await staging(), {'img-0'});
  });

  testWidgets(
    'CA-007-16: al cerrar el editor se cancela lo que esté en curso y se '
    'borra lo no guardado',
    (tester) async {
      await ctrl().pick(AttachmentOrigin.gallery);
      importer.sanitizeDelay = const Duration(seconds: 5);
      final done = ctrl().pick(AttachmentOrigin.camera);
      await tester.pump(const Duration(milliseconds: 100));

      container.dispose();
      await done;
      await tester.pump(Duration.zero);

      expect(importer.cancelled, ['img-1']);
      expect(await staging(), isEmpty);
      expect(registry.active, isEmpty);
    },
  );

  testWidgets('clearError quita el aviso sin tocar la imagen', (tester) async {
    await ctrl().pick(AttachmentOrigin.gallery);
    importer.head = _svgHead;
    await ctrl().pick(AttachmentOrigin.gallery);
    ctrl().clearError();
    expect(state().error, isNull);
    expect(state().image!.id, 'img-0');
  });

  group('Grupos de fotos (spec 016, T-016-10)', () {
    List<String> ids(AttachmentImportState s) => [
      for (final a in s.staged) a.id,
    ];

    testWidgets('CA-016-04: un grupo de 10 queda preparado, en orden, y '
        'protegido del barrido', (tester) async {
      importer.manyTotal = 10;
      expect(await ctrl().pickMany(), ImportOutcome.added);

      expect(importer.pickManyMax, [10]);
      expect(ids(state()), [for (var i = 0; i < 10; i++) 'img-$i']);
      expect(state().staged.every((s) => s is StagedImage), isTrue);
      expect(state().preparing, isFalse);
      expect(state().error, isNull);
      expect(state().notice!.added, 10);
      expect(state().notice!.hasWarnings, isFalse);
      expect(registry.active, ids(state()).toSet());
      expect(await staging(), ids(state()).toSet());
      // Una por una, nunca a la vez.
      expect(importer.maxActive, 1);
    });

    testWidgets('CA-016-04: un grupo de 2', (tester) async {
      importer.manyTotal = 2;
      expect(await ctrl().pickMany(), ImportOutcome.added);
      expect(ids(state()), ['img-0', 'img-1']);
      expect(state().notice!.added, 2);
      expect(state().image, isNull, reason: 'image es solo la foto suelta');
    });

    testWidgets('CA-016-03: una sola elegida con "Subir imágenes" queda como '
        'una imagen de la 007', (tester) async {
      importer.manyTotal = 1;
      expect(await ctrl().pickMany(), ImportOutcome.added);
      expect(state().staged, hasLength(1));
      expect(state().image!.id, 'img-0');
      expect(state().notice!.hasWarnings, isFalse);
    });

    testWidgets('CA-016-02: 5000 elegidas → las 10 primeras y el aviso del '
        'límite', (tester) async {
      importer.manyTotal = 5000;
      await ctrl().pickMany();
      expect(state().staged, hasLength(10));
      expect(state().notice!.limited, isTrue);
      expect(state().notice!.failed, 0);
      expect(importer.copiedTokens, hasLength(10));
    });

    testWidgets('CA-016-04: avanza "Preparando foto {i} de {n}" con i desde 1 '
        'y a los 400 ms se enseña', (tester) async {
      importer
        ..manyTotal = 3
        ..copyDelay = const Duration(milliseconds: 300);
      final seen = <(int, int)>[];
      container.listen(attachmentImportProvider, (_, now) {
        if (now.preparing) seen.add((now.preparingIndex, now.preparingTotal));
      });
      final done = ctrl().pickMany();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await done;
      expect(seen.toSet(), containsAll([(1, 3), (2, 3), (3, 3)]));
      expect(state().preparing, isFalse);
      expect(state().preparingIndex, 0);
      expect(state().showPreparing, isFalse);
    });

    testWidgets('CA-016-05: las que fallan se omiten, en orden, y el aviso '
        'cuenta las fallidas', (tester) async {
      importer
        ..manyTotal = 5
        ..copyErrorsByToken['content://many-1'] = const ImageImportFailure(
          ImageImportError.tooLarge,
        )
        ..copyErrorsByToken['content://many-3'] = const ImageImportFailure(
          ImageImportError.unreadable,
        );
      expect(await ctrl().pickMany(), ImportOutcome.added);
      expect(ids(state()), ['img-0', 'img-2', 'img-4']);
      expect(state().notice!.failed, 2);
      expect(state().notice!.added, 3);
      expect(state().error, isNull);
      expect(await staging(), {'img-0', 'img-2', 'img-4'});
      expect(registry.active, {'img-0', 'img-2', 'img-4'});
    });

    testWidgets('CA-016-21: el aviso compuesto, en el orden de la spec y con '
        'cada parte acabada en punto (ES y EN)', (tester) async {
      const notice = ImportNotice(limited: true, added: 8, failed: 1);
      expect(
        importNoticeText(AppLocalizationsEs(), notice),
        'Solo se usarán las 10 primeras. 8 fotos añadidas. '
        'No se pudo añadir 1 foto.',
      );
      expect(
        importNoticeText(AppLocalizationsEn(), notice),
        'Only the first 10 will be used. 8 photos added. '
        "1 photo couldn't be added.",
      );
      expect(
        importNoticeText(
          AppLocalizationsEs(),
          const ImportNotice(limited: false, added: 3, failed: 2),
        ),
        '3 fotos añadidas. No se pudieron añadir 2 fotos.',
      );
      expect(
        importNoticeText(
          AppLocalizationsEn(),
          const ImportNotice(limited: true, added: 10, failed: 0),
        ),
        'Only the first 10 will be used. 10 photos added.',
      );
      expect(
        importNoticeText(
          AppLocalizationsEs(),
          const ImportNotice(limited: false, added: 1, failed: 1),
        ),
        '1 foto añadida. No se pudo añadir 1 foto.',
      );
      // Sin nada que avisar no hay texto compuesto.
      expect(
        importNoticeText(
          AppLocalizationsEs(),
          const ImportNotice(limited: false, added: 4, failed: 0),
        ),
        '4 fotos añadidas.',
      );
    });

    testWidgets('CA-016-05: si fallan todas, el error de la primera y el '
        'editor como estaba', (tester) async {
      await ctrl().pickMany(); // 3 fotos: img-0..2
      final before = ids(state());
      final noticeBefore = state().notice;

      importer
        ..manyTotal = 4
        ..copyError = const ImageImportFailure(ImageImportError.unreadable)
        ..copyErrorsByToken['content://many-0'] = const ImageImportFailure(
          ImageImportError.tooLarge,
        );
      expect(await ctrl().pickMany(), ImportOutcome.failed);

      expect(state().error, ImageImportError.tooLarge);
      expect(ids(state()), before);
      expect(state().notice, noticeBefore);
      expect(await staging(), before.toSet());
      expect(registry.active, before.toSet());
    });

    testWidgets('CL-016-6: sin espacio a mitad se descarta todo el grupo '
        'nuevo y el anterior se conserva', (tester) async {
      await ctrl().pickMany();
      final before = ids(state());
      importer
        ..manyTotal = 4
        ..copyErrorsByToken['content://many-2'] = const ImageImportFailure(
          ImageImportError.noSpace,
        );
      expect(await ctrl().pickMany(), ImportOutcome.failed);
      expect(state().error, ImageImportError.noSpace);
      expect(ids(state()), before);
      expect(await staging(), before.toSet());
      expect(registry.active, before.toSet());
    });

    testWidgets('CA-016-04: pasa al grupo lo que reemplaza: lo guardado '
        '(reservedBytes) y lo preparado (replacedStagedIds)', (tester) async {
      const needed =
          ImageLimits.maxBytes +
          ImageLimits.maxGroup * ImageLimits.storedPhotoEstimate;
      importer
        ..manyTotal = 3
        ..freeSpaceBytes = needed;
      // Justo lo que hace falta, sin nada que reemplazar: pasa.
      expect(await ctrl().pickMany(), ImportOutcome.added);

      // Lo guardado que se reemplaza se suma.
      expect(await ctrl().pickMany(reservedBytes: 1), ImportOutcome.failed);
      expect(state().error, ImageImportError.noSpace);
      ctrl().clearError();

      // Y lo preparado en el editor también.
      store.putStaging('img-0', 'extra', Uint8List(1024));
      expect(await ctrl().pickMany(), ImportOutcome.failed);
      expect(state().error, ImageImportError.noSpace);
      expect(ids(state()), ['img-0', 'img-1', 'img-2']);
    });

    testWidgets('CA-016-06: un grupo nuevo reemplaza al anterior (nunca se '
        'suman) y el anterior se borra solo cuando el nuevo está listo', (
      tester,
    ) async {
      await ctrl().pickMany(); // img-0..2
      importer
        ..manyTotal = 2
        ..copyDelay = const Duration(seconds: 1);
      final done = ctrl().pickMany(); // img-3..4
      await tester.pump(const Duration(milliseconds: 100));
      // A medias: el anterior sigue ahí.
      expect(ids(state()), ['img-0', 'img-1', 'img-2']);
      expect(await staging(), containsAll(['img-0', 'img-1', 'img-2']));

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(await done, ImportOutcome.added);
      expect(ids(state()), ['img-3', 'img-4']);
      expect(await staging(), {'img-3', 'img-4'});
      expect(registry.active, {'img-3', 'img-4'});
    });

    testWidgets('CA-016-06: una foto de la cámara reemplaza al grupo entero', (
      tester,
    ) async {
      await ctrl().pickMany();
      expect(await ctrl().pick(AttachmentOrigin.camera), ImportOutcome.added);
      expect(ids(state()), ['img-3']);
      expect(state().image!.origin, AttachmentOrigin.camera);
      expect(state().notice, isNull);
      expect(await staging(), {'img-3'});
      expect(registry.active, {'img-3'});
    });

    testWidgets('CA-016-06: un PDF reemplaza al grupo entero', (tester) async {
      final pdfs = FakePdfImporter(store);
      final c2 = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
          attachmentStoreProvider.overrideWithValue(store),
          importRegistryProvider.overrideWithValue(registry),
          idGeneratorProvider.overrideWithValue(_SeqIds()),
          imageImporterProvider.overrideWithValue(importer),
          pdfImporterProvider.overrideWithValue(pdfs),
        ],
      )..listen(attachmentImportProvider, (_, _) {});
      addTearDown(c2.dispose);
      final c = c2.read(attachmentImportProvider.notifier);
      await c.pickMany();
      expect(await c.pick(AttachmentOrigin.file), ImportOutcome.added);
      final s = c2.read(attachmentImportProvider);
      expect(s.staged, hasLength(1));
      expect(s.pdf, isNotNull);
      expect(s.notice, isNull);
      expect(await staging(), {s.pdf!.id});
    });

    testWidgets('CA-016-06: "Cancelar" a mitad del grupo nuevo conserva el '
        'anterior y no deja nada del nuevo', (tester) async {
      await ctrl().pickMany();
      final before = ids(state());
      importer
        ..manyTotal = 5
        ..copyDelaysByToken['content://many-2'] = const Duration(seconds: 30);
      final done = ctrl().pickMany();
      await tester.pump(const Duration(seconds: 1));
      expect(state().preparing, isTrue);
      expect(state().preparingIndex, 3);

      await ctrl().cancel();
      expect(await done, ImportOutcome.unchanged);
      expect(state().preparing, isFalse);
      expect(state().error, isNull);
      expect(ids(state()), before);
      expect(await staging(), before.toSet());
      expect(registry.active, before.toSet());
    });

    testWidgets('CL-016-9: "Cancelar" con el grupo 4 de 10 en marcha no deja '
        'nada: stagingIds vacío', (tester) async {
      importer
        ..manyTotal = 10
        ..copyDelaysByToken['content://many-3'] = const Duration(seconds: 30);
      final done = ctrl().pickMany();
      await tester.pump(const Duration(seconds: 1));
      expect(state().preparingIndex, 4);

      await ctrl().cancel();
      expect(await done, ImportOutcome.unchanged);
      expect(state().staged, isEmpty);
      expect(state().notice, isNull);
      expect(await staging(), isEmpty);
      expect(registry.active, isEmpty);
      // Se puede volver a importar.
      importer
        ..copyDelaysByToken.clear()
        ..manyTotal = 2;
      expect(await ctrl().pickMany(), ImportOutcome.added);
    });

    testWidgets('CA-016-04: mientras se prepara, otra importación no hace '
        'nada', (tester) async {
      importer
        ..manyTotal = 2
        ..copyDelay = const Duration(seconds: 1);
      final first = ctrl().pickMany();
      await tester.pump(Duration.zero);
      expect(await ctrl().pickMany(), ImportOutcome.unchanged);
      expect(
        await ctrl().pick(AttachmentOrigin.camera),
        ImportOutcome.unchanged,
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await first;
      expect(importer.pickManyMax, [10]);
      expect(importer.picks, isEmpty);
    });

    testWidgets('CA-016-02: cancelar el selector no cambia nada', (
      tester,
    ) async {
      await ctrl().pickMany();
      final before = ids(state());
      importer.userCancelsPicker = true;
      expect(await ctrl().pickMany(), ImportOutcome.unchanged);
      expect(ids(state()), before);
      expect(state().error, isNull);
      expect(registry.active, before.toSet());
    });

    testWidgets('CA-016-06: "Quitar adjunto" quita todo el grupo', (
      tester,
    ) async {
      importer.manyTotal = 6;
      await ctrl().pickMany();
      await ctrl().remove();
      expect(state().staged, isEmpty);
      expect(state().notice, isNull);
      expect(await staging(), isEmpty);
      expect(registry.active, isEmpty);
    });

    testWidgets('CA-016-07: al guardar, el grupo ya no es del editor y '
        'cerrarlo no lo borra', (tester) async {
      await ctrl().pickMany();
      ctrl().saved();
      expect(state().staged, isEmpty);
      expect(state().notice, isNull);
      container.dispose();
      await tester.pump(Duration.zero);
      expect(await staging(), {'img-0', 'img-1', 'img-2'});
    });

    testWidgets('CL-016-6b: StagedPhotosLost quita las perdidas, en su orden, '
        'y avisa de cuántas no se añadieron', (tester) async {
      importer.manyTotal = 4;
      await ctrl().pickMany();
      await ctrl().dropLost(['img-1', 'img-3']);

      expect(ids(state()), ['img-0', 'img-2']);
      expect(state().notice!.failed, 2);
      expect(state().notice!.added, 0);
      expect(state().notice!.limited, isFalse);
      expect(
        importNoticeText(AppLocalizationsEs(), state().notice!),
        'No se pudieron añadir 2 fotos.',
      );
      expect(registry.active, {'img-0', 'img-2'});

      // Si queda una, es la imagen de la 007.
      await ctrl().dropLost(['img-0']);
      expect(state().image!.id, 'img-2');
      // Si no queda ninguna, el editor sin imagen.
      await ctrl().dropLost(['img-2']);
      expect(state().staged, isEmpty);
      expect(registry.active, isEmpty);
    });

    testWidgets('CA-016-16: al cerrar el editor importando se cancela el '
        'grupo y se borra lo preparado y lo anterior', (tester) async {
      await ctrl().pickMany();
      importer
        ..manyTotal = 5
        ..copyDelaysByToken['content://many-2'] = const Duration(seconds: 30);
      final done = ctrl().pickMany();
      await tester.pump(const Duration(seconds: 1));

      container.dispose();
      await done;
      await tester.pump(const Duration(seconds: 3));

      expect(await staging(), isEmpty);
      expect(registry.active, isEmpty);
    });

    testWidgets('CL-016-7: cerrar el editor con el selector abierto no deja '
        'nada registrado ni preparado', (tester) async {
      importer
        ..manyTotal = 3
        ..pickDelay = const Duration(seconds: 2);
      final done = ctrl().pickMany();
      await tester.pump(const Duration(seconds: 1));
      container.dispose();
      await tester.pump(const Duration(seconds: 2));
      expect(await done, ImportOutcome.unchanged);

      expect(importer.copiedTokens, isEmpty);
      expect(await staging(), isEmpty);
      expect(registry.active, isEmpty);
    });

    testWidgets('CL-016-20: la importación sigue con la app en segundo plano '
        'y al girar', (tester) async {
      importer
        ..manyTotal = 3
        ..copyDelay = const Duration(seconds: 2);
      final done = ctrl().pickMany();
      await tester.pump(const Duration(seconds: 1));

      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      tester.view.physicalSize = const Size(800, 400);
      await tester.pump(const Duration(seconds: 2));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(tester.view.resetPhysicalSize);
      expect(state().preparing, isTrue);
      expect(importer.cancelled, isEmpty);

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(await done, ImportOutcome.added);
      expect(state().staged, hasLength(3));
    });
  });
}
