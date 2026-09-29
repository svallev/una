import 'package:app/data/web/webview_hardening.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// API de Dart del canal `una/webview` (`WebViewHardening.kt`). Lo nativo se
/// comprueba en el emulador (T-009-09); aquí, el contrato del canal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('una/webview');
  const hardening = ChannelWebViewHardening();

  late List<MethodCall> calls;

  void answer(Object? Function(MethodCall call) reply) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// Simula un aviso de lo nativo hacia Dart.
  Future<void> nativeSays(String method, Object? args) async {
    await messenger.handlePlatformMessage(
      'una/webview',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  test('CA-009-13: harden pide los ajustes de esa WebView y dice si quedaron '
      'puestos (ADR-0017)', () async {
    answer((_) => true);
    expect(await hardening.harden(42), isTrue);
    expect(calls.single.method, 'harden');
    expect(calls.single.arguments, {'id': 42});

    answer((_) => false);
    expect(await hardening.harden(42), isFalse);
  });

  test(
    'CA-009-13: sin canal o con un error nativo, no se da por endurecida',
    () async {
      expect(await hardening.harden(1), isFalse); // sin manejador
      answer((_) => throw PlatformException(code: 'x'));
      expect(await hardening.harden(1), isFalse);
      expect(await hardening.state(1), isNull);
      expect(await hardening.clearWebData(), isFalse);
      await hardening.destroy(1); // no lanza
    },
  );

  test('CA-009-13: state devuelve los ajustes leídos de vuelta', () async {
    answer((_) => {'noFileAccess': true, 'wrapped': false});
    final state = await hardening.state(3);
    expect(state, {'noFileAccess': true, 'wrapped': false});
    expect(calls.single.arguments, {'id': 3});
  });

  test('CA-009-13: clearWebData, con o sin la WebView que se ve', () async {
    answer((_) => true);
    expect(await hardening.clearWebData(webViewId: 5), isTrue);
    expect(await hardening.clearWebData(), isTrue);
    expect(calls.map((c) => c.arguments), [
      {'id': 5},
      <String, Object?>{},
    ]);
  });

  test('ADR-0017: destroy destruye esa WebView', () async {
    answer((_) => null);
    await hardening.destroy(9);
    expect(calls.single.method, 'destroy');
    expect(calls.single.arguments, {'id': 9});
  });

  test('CA-009-11, CL-009-1 (T-009-12): lo nativo dice, antes de cada '
      'petición del marco principal, si es una redirección del servidor; '
      'se consulta una vez y sin la dirección', () async {
    final sub = hardening.events.listen((_) {});
    addTearDown(sub.cancel);
    expect(hardening.takeServerRedirect(4), isFalse); // sin aviso
    await nativeSays('mainFrameRequest', {'id': 4, 'redirect': true});
    expect(hardening.takeServerRedirect(7), isFalse); // otra WebView
    expect(hardening.takeServerRedirect(4), isTrue);
    expect(hardening.takeServerRedirect(4), isFalse); // ya consultada
    await nativeSays('mainFrameRequest', {'id': 4, 'redirect': true});
    await nativeSays('mainFrameRequest', {'id': 4, 'redirect': false});
    expect(hardening.takeServerRedirect(4), isFalse); // la última manda
    await nativeSays('mainFrameRequest', {'id': 5});
    expect(hardening.takeServerRedirect(5), isFalse);
  });

  test('ADR-0017 y CL-009-4: los avisos nativos llegan como eventos', () async {
    final events = <WebViewNativeEvent>[];
    final sub = hardening.events.listen(events.add);
    await nativeSays('renderProcessGone', {'id': 4, 'crashed': true});
    await nativeSays('downloadBlocked', {'id': 4});
    await nativeSays('renderProcessGone', {'id': 6, 'crashed': false});
    await nativeSays('otro', {'id': 1}); // se ignora
    await pumpEventQueue();
    await sub.cancel();
    expect(events, [
      const WebRenderProcessGone(4, crashed: true),
      const WebDownloadBlocked(4),
      const WebRenderProcessGone(6, crashed: false),
    ]);
  });
}
