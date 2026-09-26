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
import 'package:app/features/attachments/image_import_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/attachments.dart';

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'img-${_n++}';
}

const _jpegHead = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];
const _pngHead = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0];
final _svgHead = '<?xml version="1.0"?><svg'.codeUnits;
// ftyp heic
const _heicHead = [
  0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, //
  0x68, 0x65, 0x69, 0x63, 0x00, 0x00, 0x00, 0x00,
  0x6D, 0x69, 0x66, 0x31, 0x68, 0x65, 0x69, 0x63,
];

/// Importador falso: escribe en la preparación como el nativo y se puede
/// retrasar, hacer fallar o cancelar paso a paso.
class _FakeImporter implements ImageImporter {
  _FakeImporter(this.store);

  final MemoryAttachmentStore store;

  @override
  bool heicSupported = true;

  bool userCancelsPicker = false;
  Object? pickError;
  List<int> head = _jpegHead;
  Object? copyError;
  Object? sanitizeError;
  Duration copyDelay = Duration.zero;
  Duration sanitizeDelay = Duration.zero;

  final picks = <String>[];
  final limits = <int>[];
  final cancelled = <String>[];
  final sniffedTypes = <ImageType>[];
  final _waits = <String, Completer<void>>{};

  Future<void> _wait(String id, Duration d) async {
    if (d == Duration.zero) return;
    final c = Completer<void>();
    _waits[id] = c;
    final t = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    try {
      await c.future;
    } finally {
      t.cancel();
      _waits.remove(id);
    }
  }

  @override
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) async {
    picks.add(id);
    if (pickError case final e?) throw e;
    if (userCancelsPicker) return null;
    return (token: 'content://$id', origin: origin);
  }

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) async {
    limits.add(maxBytes);
    store.putStaging(id, 'original', Uint8List.fromList(head));
    await _wait(id, copyDelay);
    if (copyError case final e?) throw e;
    return (byteSize: head.length, head: head);
  }

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) async {
    limits
      ..add(maxPixels)
      ..add(storedMaxPixels);
    sniffedTypes.add(type);
    await _wait(id, sanitizeDelay);
    if (sanitizeError case final e?) throw e;
    return stageImage(store, id, origin: origin);
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    final c = _waits[id];
    if (c != null && !c.isCompleted) {
      c.completeError(const ImageImportCancelled());
    }
    await store.deleteStaging(id);
  }
}

void main() {
  late MemoryAttachmentStore store;
  late _FakeImporter importer;
  late ImportRegistry registry;
  late ProviderContainer container;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = _FakeImporter(store);
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
    container.listen(imageImportProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  ImageImportController ctrl() => container.read(imageImportProvider.notifier);
  ImageImportState state() => container.read(imageImportProvider);
  Future<Set<String>> staging() => store.stagingIds();

  testWidgets('CA-007-13: el tipo se decide por el contenido y queda lista', (
    tester,
  ) async {
    importer.head = _pngHead;
    await ctrl().pick(AttachmentOrigin.gallery);

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
      await ctrl().pick(AttachmentOrigin.gallery);

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

  testWidgets('CA-007-02/03: sin cámara se avisa; cancelar el selector no '
      'cambia nada', (tester) async {
    importer.pickError = const ImageImportFailure(ImageImportError.noCamera);
    await ctrl().pick(AttachmentOrigin.camera);
    expect(state().error, ImageImportError.noCamera);
    expect(registry.active, isEmpty);

    importer
      ..pickError = null
      ..userCancelsPicker = true;
    await ctrl().pick(AttachmentOrigin.gallery);
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
}
