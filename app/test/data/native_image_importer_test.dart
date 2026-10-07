import 'package:app/data/import/native_image_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('una/images');
  final calls = <MethodCall>[];
  late Object? Function(MethodCall) reply;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply(call);
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('capabilities: HEIC según el dispositivo (Android 9+)', () async {
    reply = (_) => {'heic': true};
    expect((await NativeImageImporter.open()).heicSupported, isTrue);
    reply = (_) => {'heic': false};
    expect((await NativeImageImporter.open()).heicSupported, isFalse);
  });

  test('CA-007-13/14: pick, copy y sanitize pasan los límites y leen la '
      'respuesta', () async {
    final importer = NativeImageImporter(heicSupported: true);
    reply = (call) => switch (call.method) {
      'pick' => {'token': 't-1'},
      'copy' => {
        'byteSize': 1234,
        'head': Uint8List.fromList(const [0xFF, 0xD8, 0xFF]),
      },
      'sanitize' => {'width': 4000, 'height': 3000, 'byteSize': 999},
      _ => null,
    };

    final picked = await importer.pick(AttachmentOrigin.camera, 'id-1');
    expect(picked, (token: 't-1', origin: AttachmentOrigin.camera));
    final copied = await importer.copy(
      picked!,
      'id-1',
      maxBytes: ImageLimits.maxBytes,
    );
    expect(copied.byteSize, 1234);
    expect(copied.head, [0xFF, 0xD8, 0xFF]);
    final staged = await importer.sanitize(
      'id-1',
      ImageType.jpeg,
      AttachmentOrigin.camera,
      maxPixels: ImageLimits.maxPixels,
      storedMaxPixels: ImageLimits.storedMaxPixels,
    );
    expect(
      staged,
      const StagedImage(
        id: 'id-1',
        origin: AttachmentOrigin.camera,
        width: 4000,
        height: 3000,
        byteSize: 999,
      ),
    );

    expect(calls.map((c) => c.method), ['pick', 'copy', 'sanitize']);
    expect(calls[0].arguments, {'origin': 'camera', 'id': 'id-1'});
    expect(calls[1].arguments, {
      'token': 't-1',
      'id': 'id-1',
      'maxBytes': ImageLimits.maxBytes,
    });
    expect(calls[2].arguments, {
      'id': 'id-1',
      'type': 'jpeg',
      'maxPixels': ImageLimits.maxPixels,
      'storedMaxPixels': ImageLimits.storedMaxPixels,
    });
  });

  test('CA-007-02/03: si el usuario cancela, pick devuelve null', () async {
    reply = (_) => null;
    final importer = NativeImageImporter(heicSupported: true);
    expect(await importer.pick(AttachmentOrigin.gallery, 'id-1'), isNull);
  });

  for (final (code, expected) in [
    ('tooLarge', ImageImportError.tooLarge),
    ('tooManyPixels', ImageImportError.tooManyPixels),
    ('noCamera', ImageImportError.noCamera),
    ('noSpace', ImageImportError.noSpace),
    ('unreadable', ImageImportError.unreadable),
    ('somethingElse', ImageImportError.unreadable),
  ]) {
    test('CA-007-14 / CL-007-3: el código "$code" es ${expected.name}', () {
      reply = (_) => throw PlatformException(code: code);
      final importer = NativeImageImporter(heicSupported: true);
      expect(
        importer.copy(
          (token: 't', origin: AttachmentOrigin.gallery),
          'id-1',
          maxBytes: ImageLimits.maxBytes,
        ),
        throwsA(
          isA<ImageImportFailure>().having((e) => e.error, 'error', expected),
        ),
      );
    });
  }

  test('CA-007-15: "cancelled" es ImageImportCancelled', () {
    reply = (_) => throw PlatformException(code: 'cancelled');
    final importer = NativeImageImporter(heicSupported: true);
    expect(
      importer.sanitize(
        'id-1',
        ImageType.png,
        AttachmentOrigin.gallery,
        maxPixels: ImageLimits.maxPixels,
        storedMaxPixels: ImageLimits.storedMaxPixels,
      ),
      throwsA(isA<ImageImportCancelled>()),
    );
  });
  group('selector múltiple y espacio libre (spec 016)', () {
    final importer = NativeImageImporter(heicSupported: true);

    test('CA-016-02: pickMany pide el tope y devuelve las elegidas en el orden '
        'de Android, de la galería', () async {
      reply = (_) => {
        'tokens': ['t-1', 't-2', 't-3'],
        'total': 3,
      };
      final picked = await importer.pickMany(max: 10);
      expect(calls.single.method, 'pickMany');
      expect(calls.single.arguments, {'max': 10});
      expect(picked!.total, 3);
      expect(picked.items, [
        (token: 't-1', origin: AttachmentOrigin.gallery),
        (token: 't-2', origin: AttachmentOrigin.gallery),
        (token: 't-3', origin: AttachmentOrigin.gallery),
      ]);
    });

    test('CA-016-02 / CL-016-15: un selector que devuelve 5000 elementos '
        'solo deja pasar 10 y avisa del total', () async {
      reply = (_) => {
        'tokens': [for (var i = 0; i < 5000; i++) 't-$i'],
        'total': 5000,
      };
      final picked = await importer.pickMany(max: 10);
      expect(picked!.items, hasLength(10));
      expect(picked.items.first.token, 't-0');
      expect(picked.items.last.token, 't-9');
      expect(picked.total, 5000);
    });

    test('CA-016-03: una sola elegida es un grupo de una', () async {
      reply = (_) => {
        'tokens': ['t-1'],
        'total': 1,
      };
      final picked = await importer.pickMany(max: 10);
      expect(picked!.items, hasLength(1));
      expect(picked.total, 1);
    });

    test('CA-016-02: sin total, se usa lo devuelto', () async {
      reply = (_) => {
        'tokens': ['a', 'b'],
      };
      expect((await importer.pickMany(max: 10))!.total, 2);
    });

    test('CA-016-02: si el usuario cancela (o no elige nada), pickMany '
        'devuelve null', () async {
      reply = (_) => null;
      expect(await importer.pickMany(max: 10), isNull);
      reply = (_) => {'tokens': <String>[], 'total': 0};
      expect(await importer.pickMany(max: 10), isNull);
    });

    for (final code in ['busy', 'unreadable', 'somethingElse']) {
      test('CA-016-02: el error "$code" del selector es un fallo sin texto, '
          'nunca una excepción de plataforma', () async {
        reply = (_) => throw PlatformException(
          code: code,
          message: 'content://media/secret/123.jpg',
        );
        await expectLater(
          importer.pickMany(max: 10),
          throwsA(
            isA<ImageImportFailure>()
                .having((e) => e.error, 'error', ImageImportError.unreadable)
                .having(
                  (e) => e.toString(),
                  'texto',
                  isNot(contains('content://')),
                ),
          ),
        );
      });
    }

    for (final (label, answer) in <(String, Object?)>[
      (
        'un elemento que no es texto',
        {
          'tokens': ['t-1', 7],
          'total': 2,
        },
      ),
      (
        'un elemento nulo',
        {
          'tokens': ['t-1', null],
          'total': 2,
        },
      ),
      ('tokens que no es una lista', {'tokens': 'content://x', 'total': 1}),
      (
        'un total que no es un número',
        {
          'tokens': ['t-1'],
          'total': 'muchos',
        },
      ),
    ]) {
      test('CA-016-24: una respuesta del canal con $label es un fallo '
          'ilegible, no un TypeError', () async {
        reply = (_) => answer;
        await expectLater(
          importer.pickMany(max: 10),
          throwsA(
            isA<ImageImportFailure>().having(
              (e) => e.error,
              'error',
              ImageImportError.unreadable,
            ),
          ),
        );
      });
    }

    test('CA-016-02: sin canal (iOS), pickMany falla como ilegible', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(
        importer.pickMany(max: 10),
        throwsA(isA<ImageImportFailure>()),
      );
    });

    test('CL-016-6: freeSpace lee los bytes libres', () async {
      reply = (_) => 123456789012; // más de 32 bits
      expect(await importer.freeSpace(), 123456789012);
      expect(calls.single.method, 'freeSpace');
    });

    test('CL-016-6: freeSpace desconocido (null, error o sin canal) no '
        'bloquea', () async {
      reply = (_) => null;
      expect(await importer.freeSpace(), isNull);
      reply = (_) => throw PlatformException(code: 'unreadable');
      expect(await importer.freeSpace(), isNull);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(await importer.freeSpace(), isNull);
    });
  });
}
