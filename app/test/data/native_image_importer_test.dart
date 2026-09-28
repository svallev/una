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
}
