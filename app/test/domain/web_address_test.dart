import 'package:app/domain/services/web_address.dart';
import 'package:flutter_test/flutter_test.dart';

WebAddressCheck _check(String input) => validateWebAddress(input);

String _valid(String input) {
  final check = _check(input);
  expect(check, isA<ValidWebAddress>(), reason: input);
  return (check as ValidWebAddress).url;
}

void _error(String input, WebAddressError error) {
  final check = _check(input);
  expect(check, isA<InvalidWebAddress>(), reason: input);
  expect((check as InvalidWebAddress).error, error, reason: input);
}

void main() {
  group('CA-009-02: validación de la dirección', () {
    test('vacía o solo espacios → "Escribe una dirección web."', () {
      _error('', WebAddressError.empty);
      _error('   \n\t ', WebAddressError.empty);
    });

    test('quita los espacios del principio y del final', () {
      expect(
        _valid('  https://example.com/programa  \n'),
        'https://example.com/programa',
      );
    });

    test('sin esquema se añade https://', () {
      expect(_valid('example.com'), 'https://example.com');
      expect(
        _valid('www.example.com/ruta?x=1#a'),
        'https://www.example.com/ruta?x=1#a',
      );
      // Con puerto: no es un esquema.
      expect(_valid('example.com:8443/x'), 'https://example.com:8443/x');
      expect(_valid('www.example.com:8080'), 'https://www.example.com:8080');
    });

    test('http y https se aceptan tal cual, con el esquema y el dominio en '
        'minúsculas (CA-009-04)', () {
      expect(_valid('http://example.com/a'), 'http://example.com/a');
      expect(_valid('HTTPS://Example.COM/Ruta'), 'https://example.com/Ruta');
    });

    test(
      'otro esquema → "Solo se admiten direcciones web (http o https)."',
      () {
        for (final input in [
          'javascript:alert(1)',
          'JavaScript:alert(1)',
          'data:text/html,<b>x</b>',
          'file:///etc/passwd',
          'content://com.example/x',
          'intent://scan/#Intent;scheme=zxing;end',
          'about:blank',
          'ftp://example.com/',
          'mailto:info@example.com',
          'tel:+34600000000',
          'chrome://crash',
          'blob:https://example.com/uuid',
          'ws://example.com/',
        ]) {
          _error(input, WebAddressError.scheme);
        }
      },
    );

    test('no analizable, sin dominio o host sin punto → no válida', () {
      for (final input in [
        'https://',
        'https:///ruta',
        'https:example.com',
        'exa mple.com',
        'https://exa mple.com/',
        'intranet',
        'https://intranet/',
        'https://a..b.com/',
        'https://.example.com/',
        'https://exa%mple.com/',
        'https://exa<mple.com/',
        'https://example.com:99999/',
        'https://${'a' * 64}.com/',
      ]) {
        _error(input, WebAddressError.invalid);
      }
    });

    test('direcciones privadas o locales → no válida', () {
      for (final input in [
        'localhost',
        'localhost:3000',
        'https://localhost/',
        'https://LOCALHOST./',
        'app.localhost',
        'impresora.local',
        'router.home.arpa',
        'servicio.internal',
        '127.0.0.1',
        '127.1',
        '0x7f.1',
        '0177.0.0.1',
        '2130706433',
        '10.0.0.5',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.1.1',
        '169.254.169.254',
        '100.64.0.1',
        '0.0.0.0',
        '224.0.0.1',
        '255.255.255.255',
        'https://[::1]/',
        'https://[::]/',
        'https://[fe80::1]/',
        'https://[fd00::1]/',
        'https://[fc00::1]/',
        'https://[ff02::1]/',
        'https://[::ffff:192.168.0.1]/',
        'https://[::ffff:7f00:1]/',
      ]) {
        _error(input, WebAddressError.invalid);
      }
    });

    test(
      'publicWebHost: el mismo filtro de dominio para las redirecciones '
      '(T-009-21): privado, loopback o local → null; público, normalizado',
      () {
        for (final host in [
          '192.168.1.1',
          '10.0.0.1',
          '10.20.30.40',
          '127.0.0.1',
          '172.16.0.1',
          '169.254.169.254',
          'localhost',
          'LOCALHOST.',
          'impresora.local',
          'intranet',
          '::1',
          'fe80::1',
          'fd00::1',
          '::ffff:192.168.0.1',
          '',
        ]) {
          expect(publicWebHost(host), isNull, reason: host);
        }
        expect(publicWebHost('WWW.Ejemplo.COM.'), 'www.ejemplo.com');
        expect(publicWebHost('8.8.8.8'), '8.8.8.8');
        expect(publicWebHost('2001:4860:4860::8888'), '2001:4860:4860::8888');
      },
    );

    test('una IP pública se admite (en su forma normal)', () {
      expect(_valid('8.8.8.8'), 'https://8.8.8.8');
      expect(_valid('172.32.0.1/x'), 'https://172.32.0.1/x');
      expect(
        _valid('https://[2606:4700:4700::1111]/'),
        'https://[2606:4700:4700::1111]/',
      );
    });

    test('una IP mal formada → no válida', () {
      _error('1.2.3.4.5', WebAddressError.invalid);
      _error('256.1.1.1', WebAddressError.invalid);
      _error('1.2.3.08', WebAddressError.invalid);
      _error('https://[1::2::3]/', WebAddressError.invalid);
    });

    test('usuario o contraseña en la dirección → no válida (T-5)', () {
      for (final input in [
        'https://user:pass@example.com/',
        'https://user@example.com/',
        'https://@example.com/',
        'http://example.com:x@evil.com/',
      ]) {
        _error(input, WebAddressError.invalid);
      }
      // Sin esquema, `user:` parece uno: tampoco se admite.
      expect(_check('user:pass@example.com'), isA<InvalidWebAddress>());
    });

    test(r'la barra invertida es "/", como en un navegador: el dominio es el '
        'que queda delante', () {
      expect(
        _valid(r'https://evil.com\@good.com'),
        'https://evil.com/@good.com',
      );
    });

    test('caracteres de control → no válida', () {
      _error('https://example.com/a\u0000b', WebAddressError.invalid);
      _error('https://exa\u0007mple.com/', WebAddressError.invalid);
    });
  });

  group('CL-009-8: direcciones largas, con espacios o internacionales', () {
    test('más de 2048 caracteres → no válida; 2048 sí', () {
      const prefix = 'https://example.com/';
      final ok = prefix + 'a' * (maxWebAddressLength - prefix.length);
      expect(ok.length, maxWebAddressLength);
      expect(_valid(ok), ok);
      _error('${ok}a', WebAddressError.invalid);
    });

    test('el límite cuenta la dirección que se guarda (con https:// y los '
        'escapes)', () {
      final bare = 'example.com/${'a' * (maxWebAddressLength - 12)}';
      expect(bare.length, maxWebAddressLength);
      _error(bare, WebAddressError.invalid);
    });

    test('los espacios internos de la ruta se codifican', () {
      expect(
        _valid('example.com/mi programa?q=a b#c d'),
        'https://example.com/mi%20programa?q=a%20b#c%20d',
      );
    });

    test('los caracteres internacionales de la ruta se codifican', () {
      expect(
        _valid('https://example.com/año?q=ñ'),
        'https://example.com/a%C3%B1o?q=%C3%B1',
      );
    });

    test('un dominio internacional se guarda en punycode', () {
      expect(_valid('пример.рф'), 'https://xn--e1afmkfd.xn--p1ai');
      expect(_valid('https://España.es/ruta'), 'https://xn--espaa-rta.es/ruta');
      expect(_valid('https://xn--espaa-rta.es/'), 'https://xn--espaa-rta.es/');
    });

    test('un escape ya codificado no se vuelve a codificar', () {
      expect(_valid('https://example.com/a%20b'), 'https://example.com/a%20b');
    });
  });
}
