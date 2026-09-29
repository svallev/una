import 'package:app/domain/services/host_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA-009-14: dominio visible', () {
    test('sin www. delante en la barra; entero en las confirmaciones', () {
      expect(
        displayHost('www.congreso.ejemplo.com', dropWww: true),
        'congreso.ejemplo.com',
      );
      expect(displayHost('WWW.Example.COM', dropWww: true), 'example.com');
      expect(displayHost('www.example.com'), 'www.example.com');
      // Solo el del principio, y nunca deja un sufijo suelto.
      expect(
        displayHost('m.www.example.com', dropWww: true),
        'm.www.example.com',
      );
      expect(displayHost('www.com', dropWww: true), 'www.com');
      expect(
        displayHost('www2.example.com', dropWww: true),
        'www2.example.com',
      );
    });

    test('saneado: sin caracteres de control ni de cambio de dirección', () {
      expect(displayHost('exa%E2%80%AEmple.com'), 'example.com');
      expect(displayHost('exa\u202Emple\u200F.com\u0007'), 'example.com');
      final shown = displayHost('%E2%81%A6evil.com%E2%81%A9');
      expect(shown, 'evil.com');
    });

    test('punycode si mezcla alfabetos; legible si usa uno solo', () {
      // "аpple" con la "а" cirílica.
      expect(displayHost('аpple.com'), 'xn--pple-43d.com');
      expect(displayHost('%D0%B0pple.com'), 'xn--pple-43d.com');
      expect(displayHost('xn--pple-43d.com'), 'xn--pple-43d.com');
      expect(displayHost('пример.рф'), 'пример.рф');
      expect(displayHost('españa.es'), 'españa.es');
    });

    test('lo que llega en punycode (la WebView da ASCII) se ve legible si '
        'usa un solo alfabeto', () {
      expect(displayHost('xn--e1afmkfd.xn--p1ai'), 'пример.рф');
      expect(displayHost('www.xn--espaa-rta.es', dropWww: true), 'españa.es');
      expect(displayHost('XN--BCHER-KVA.example'), 'bücher.example');
    });

    test('un punycode mal formado o que esconde caracteres peligrosos se '
        'queda como llegó', () {
      final hidden = toPunycodeLabel('exa\u202Emple');
      expect(hidden, startsWith('xn--'));
      expect(displayHost('$hidden.com'), '$hidden.com');
      expect(displayHost('xn--a!b.com'), 'xn--a!b.com');
      expect(displayHost('xn--.com'), 'xn--.com');
    });

    test('el dominio de la dirección guardada, como en la barra', () {
      expect(
        webAddressHost('https://www.example.com/programa?x=1'),
        'example.com',
      );
      expect(webAddressHost('https://xn--e1afmkfd.xn--p1ai'), 'пример.рф');
      expect(
        webAddressHost('https://[2606:4700:4700::1111]/'),
        '2606:4700:4700::1111',
      );
      expect(webAddressHost(null), isNull);
      expect(webAddressHost('no es una dirección'), isNull);
      expect(webAddressHost('https:///ruta'), isNull);
    });
  });

  group('Punycode (RFC 3492)', () {
    test('ida y vuelta', () {
      for (final label in [
        'bücher',
        'аpple',
        'пример',
        'españa',
        '日本語',
        'ñ',
        'a-ü-b',
      ]) {
        final encoded = toPunycodeLabel(label);
        expect(encoded, startsWith('xn--'));
        expect(fromPunycodeLabel(encoded), label);
      }
    });

    test('vectores conocidos', () {
      expect(fromPunycodeLabel('xn--bcher-kva'), 'bücher');
      expect(fromPunycodeLabel('xn--pple-43d'), 'аpple');
      expect(fromPunycodeLabel('xn--e1afmkfd'), 'пример');
      expect(fromPunycodeLabel('xn--wgv71a119e'), '日本語');
    });

    test('lo que no es punycode válido → null', () {
      expect(fromPunycodeLabel('example'), isNull);
      expect(fromPunycodeLabel('xn--'), isNull);
      expect(fromPunycodeLabel('xn--a!'), isNull);
      expect(fromPunycodeLabel('xn--abc-'), isNull);
      expect(fromPunycodeLabel('xn--${'9' * 60}'), isNull);
    });
  });
}
