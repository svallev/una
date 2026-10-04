import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/platform/accessibility_timeouts.dart';
import 'package:app/domain/services/undo_duration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// API de Dart del canal `una/a11y` (`AccessibilityTimeouts.kt`). Lo nativo
/// se comprueba en el emulador (T-014-04); aquí, el contrato del canal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('una/a11y');
  const timeouts = ChannelAccessibilityTimeouts();

  late List<MethodCall> calls;

  void answer(Future<Object?> Function(MethodCall call) reply) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return reply(call);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('CA-014-06: lee los hechos del sistema del canal una/a11y', () {
    test('Android 10 o posterior: "Tiempo para actuar" y si hay un servicio; '
        'método "timeouts" sin argumentos', () async {
      answer((_) async => {'recommendedMs': 10000, 'serviceEnabled': true});
      final read = await timeouts.read();
      expect(read.recommendedMs, 10000);
      expect(read.serviceEnabled, isTrue);
      expect(calls.single.method, 'timeouts');
      expect(calls.single.arguments, isNull);
    });

    test('Android 8 y 9: sin "Tiempo para actuar" (nulo) y con un servicio '
        'activo', () async {
      answer((_) async => {'recommendedMs': null, 'serviceEnabled': true});
      final read = await timeouts.read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isTrue);
    });

    test('sin servicio activo: false', () async {
      answer((_) async => {'recommendedMs': 4000, 'serviceEnabled': false});
      final read = await timeouts.read();
      expect(read.recommendedMs, 4000);
      expect(read.serviceEnabled, isFalse);
    });

    test('con el canal, la regla da los 10 s del sistema', () async {
      answer((_) async => {'recommendedMs': 10000, 'serviceEnabled': false});
      const rule = UndoDuration(
        base: UnaMotion.undoWindow,
        legacyA11y: UnaMotion.undoWindowLegacyA11y,
        max: UnaMotion.undoWindowMax,
      );
      expect(rule(await timeouts.read()), const Duration(seconds: 10));
    });
  });

  group('CA-014-06: sin canal o con un error, (null, false) → 4 s', () {
    test('sin canal (MissingPluginException)', () async {
      // Sin manejador registrado, el canal lanza MissingPluginException.
      final read = await timeouts.read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isFalse);
    });

    test('con PlatformException', () async {
      answer((_) async => throw PlatformException(code: 'boom'));
      final read = await timeouts.read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isFalse);
    });

    test('método sin implementar (notImplemented)', () async {
      answer((_) async => throw MissingPluginException());
      final read = await timeouts.read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isFalse);
    });

    test('respuesta nula', () async {
      answer((_) async => null);
      final read = await timeouts.read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isFalse);
    });

    test('valores de otro tipo: se toman como ausentes', () async {
      answer((_) async => {'recommendedMs': '10000', 'serviceEnabled': 'yes'});
      final read = await timeouts.read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isFalse);
    });

    test('una respuesta que no es un mapa', () async {
      answer((_) async => 10000);
      final read = await timeouts.read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isFalse);
    });

    test('la web de pruebas no llama al canal', () async {
      answer((_) async => {'recommendedMs': 10000, 'serviceEnabled': true});
      final read = await const ChannelAccessibilityTimeouts(web: true).read();
      expect(read.recommendedMs, isNull);
      expect(read.serviceEnabled, isFalse);
      expect(calls, isEmpty);
    });
  });

  test('CA-014-06: el proveedor usa el canal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(accessibilityTimeoutsProvider),
      isA<ChannelAccessibilityTimeouts>(),
    );
  });
}
