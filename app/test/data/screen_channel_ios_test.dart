import 'package:app/data/platform/attachment_rotation.dart';
import 'package:app/data/platform/screen_awake.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que Dart pide en iOS por `una/screen` y por `SystemChrome` (T-028-10,
/// contrato §5). Lo nativo (`Screen.swift`) lo prueba `ScreenTests.swift`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const screen = MethodChannel('una/screen');

  late List<MethodCall> calls;
  late List<List<String>> orientations;

  void mockPlatform() {
    calls = [];
    orientations = [];
    messenger
      ..setMockMethodCallHandler(screen, (call) async {
        calls.add(call);
        return null;
      })
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add([
            for (final o in call.arguments as List<Object?>) o! as String,
          ]);
        }
        return null;
      });
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    mockPlatform();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger
      ..setMockMethodCallHandler(screen, null)
      ..setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('CA-028-13: el giro con adjunto en iOS', () {
    test(
      'pedir el giro abre las dos horizontales y soltarlo vuelve a vertical, '
      'con el aviso de siempre al canal',
      () async {
        AttachmentRotation.request(on: true);
        await settle();
        expect(orientations.last, [
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]);
        expect(calls.last.method, 'rotateWithAttachment');
        expect(calls.last.arguments, true);

        AttachmentRotation.request(on: false);
        await settle();
        expect(orientations.last, ['DeviceOrientation.portraitUp']);
        expect(calls.last.method, 'rotateWithAttachment');
        expect(calls.last.arguments, false);
        expect(orientations, hasLength(2));
      },
    );

    test('cambiar de una tarea con adjunto a otra no pasa por vertical (se '
        'cuenta y se decide al final)', () async {
      AttachmentRotation.request(on: true);
      await settle();
      orientations.clear();
      calls.clear();

      // La nueva se monta antes de que se desmonte la anterior.
      AttachmentRotation.request(on: true);
      AttachmentRotation.request(on: false);
      await settle();
      expect(orientations, isEmpty);
      expect(calls, isEmpty);

      AttachmentRotation.request(on: false);
      await settle();
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
    });
  });

  group('CA-028-13 y CA-007-12: pantalla encendida en iOS', () {
    test('keepOn envía el booleano a una/screen', () async {
      const awake = ChannelScreenAwake();
      await awake.keepOn(true);
      await awake.keepOn(false);
      expect(calls.map((c) => '${c.method}:${c.arguments}'), [
        'keepOn:true',
        'keepOn:false',
      ]);
    });

    test('un canal sin implementar o que falla no rompe la app', () async {
      messenger.setMockMethodCallHandler(screen, null);
      await const ChannelScreenAwake().keepOn(true);
      messenger.setMockMethodCallHandler(screen, (call) async {
        throw PlatformException(code: 'failed');
      });
      await const ChannelScreenAwake().keepOn(true);
    });
  });
}
