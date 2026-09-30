import 'package:app/data/links/native_link_opener.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/services/link_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// API de Dart del canal `una/links` (`LinkOpener.kt`). Lo nativo se comprueba
/// en el emulador; aquí, el contrato del canal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('una/links');
  const opener = NativeLinkOpener();

  late List<MethodCall> calls;

  void answer(Future<Object?> Function(MethodCall call) reply) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return reply(call);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final web = classifyLink(url: Uri.parse('https://example.com/privacy'));

  group('CA-012-04: canOpen consulta al canal antes de la confirmación', () {
    test(
      'pregunta con el mismo tipo y dirección que open, sin abrir',
      () async {
        answer((_) async => true);
        expect(await opener.canOpen(web), isTrue);
        expect(calls.single.method, 'canOpen');
        expect(calls.single.arguments, {
          'kind': 'web',
          'uri': 'https://example.com/privacy',
        });
      },
    );

    test('sin app que lo atienda: false', () async {
      answer((_) async => false);
      expect(await opener.canOpen(web), isFalse);
    });

    test('respuesta nula: false', () async {
      answer((_) async => null);
      expect(await opener.canOpen(web), isFalse);
    });

    test('sin canal (MissingPluginException): false', () async {
      // Sin manejador registrado, el canal lanza MissingPluginException.
      expect(await opener.canOpen(web), isFalse);
    });

    test('con PlatformException: false', () async {
      answer((_) async => throw PlatformException(code: 'boom'));
      expect(await opener.canOpen(web), isFalse);
    });

    test('un enlace bloqueado o interno no llega al canal', () async {
      answer((_) async => true);
      expect(await opener.canOpen(const BlockedLink()), isFalse);
      expect(await opener.canOpen(const InternalLink(2)), isFalse);
      expect(calls, isEmpty);
    });

    test('correo y teléfono usan su tipo', () async {
      answer((_) async => true);
      await opener.canOpen(classifyLink(url: Uri.parse('mailto:a@b.co')));
      await opener.canOpen(classifyLink(url: Uri.parse('tel:+34600000000')));
      expect(calls.map((c) => (c.arguments as Map)['kind']), ['mail', 'tel']);
    });
  });

  group('CA-008-12: open sigue igual', () {
    test('open manda "open" con tipo y dirección', () async {
      answer((_) async => true);
      expect(await opener.open(web), isTrue);
      expect(calls.single.method, 'open');
      expect(calls.single.arguments, {
        'kind': 'web',
        'uri': 'https://example.com/privacy',
      });
    });

    test('open: sin canal o con error, false', () async {
      expect(await opener.open(web), isFalse);
      answer((_) async => throw PlatformException(code: 'boom'));
      expect(await opener.open(web), isFalse);
    });
  });
}
