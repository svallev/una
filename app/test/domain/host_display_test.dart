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

  group('CA-020-27: una dirección mal codificada no lanza', () {
    // Escapes que no son UTF-8 válido (`%C3`, `%E2%82`) o ni siquiera son
    // hexadecimales (`%`, `%ZZ`): el dominio se muestra tal cual (en
    // minúsculas), sin excepción y sin decodificar a medias.
    test('CA-020-27: displayHost con %C3, %, %ZZ y %E2%82', () {
      expect(displayHost('%C3.es'), '%c3.es');
      expect(displayHost('%.es'), '%.es');
      expect(displayHost('%ZZ.es'), '%zz.es');
      expect(displayHost('%E2%82.es'), '%e2%82.es');
      expect(displayHost('a.%C3'), 'a.%c3');
      expect(displayHost('%E2%82', dropWww: true), '%e2%82');
      // Un escape válido junto a uno roto: nada se decodifica a medias.
      expect(displayHost('%C3%B1%C3.es'), '%c3%b1%c3.es');
    });

    test('CA-020-27: webAddressHost con el escape en el dominio', () {
      expect(webAddressHost('https://%C3.es/'), '%c3.es');
      expect(webAddressHost('https://%E2%82.es/'), '%e2%82.es');
      expect(webAddressHost('https://www.%C3.es/x'), '%c3.es');
      // `Uri.host` da `%25` para el `%` suelto: se decodifica a `%`.
      expect(webAddressHost('https://%/'), '%');
      expect(webAddressHost('https://%ZZ.es/'), '%zz.es');
    });

    test('CA-020-27: webAddressHost con el escape en la ruta', () {
      expect(webAddressHost('https://dominio.es/%C3'), 'dominio.es');
      expect(webAddressHost('https://dominio.es/%'), 'dominio.es');
      expect(webAddressHost('https://dominio.es/%ZZ'), 'dominio.es');
      expect(webAddressHost('https://dominio.es/%E2%82?q=%C3#%'), 'dominio.es');
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
