import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/services/link_policy.dart';
import 'package:flutter_test/flutter_test.dart';

LinkTarget _url(String s) => classifyLink(url: Uri.parse(s));

void main() {
  group('CA-008-12: los enlaces siguen siendo enlaces, salvo los peligrosos', () {
    test('un enlace a otra página del PDF desplaza a esa página', () {
      expect(classifyLink(destPage: 2), const InternalLink(2));
      // Si trae las dos cosas, manda el destino interno.
      expect(
        classifyLink(url: Uri.parse('https://example.com'), destPage: 3),
        const InternalLink(3),
      );
    });

    test('https y http: al navegador, mostrando el dominio real', () {
      final web = _url('https://example.com/programa?x=1') as WebLink;
      expect(web.host, 'example.com');
      expect(web.uri.toString(), 'https://example.com/programa?x=1');
      expect((_url('HTTP://Example.ORG/') as WebLink).host, 'example.org');
    });

    test('con usuario o contraseña en la dirección no hace nada (T-5)', () {
      expect(_url('https://user:pass@example.com/'), const BlockedLink());
      expect(_url('https://user@example.com/'), const BlockedLink());
    });

    test('sin dominio no hace nada', () {
      expect(_url('https:///ruta'), const BlockedLink());
      expect(_url('http:'), const BlockedLink());
    });

    test('punycode si un dominio mezcla alfabetos; si no, tal cual', () {
      // "аpple.com" con la "а" cirílica.
      final mixed = _url('https://аpple.com/') as WebLink;
      expect(mixed.host, 'xn--pple-43d.com');
      expect(
        (_url('https://xn--pple-43d.com/') as WebLink).host,
        'xn--pple-43d.com',
      );
      // Un dominio solo en cirílico o solo con acentos latinos se muestra legible.
      expect((_url('https://пример.рф/') as WebLink).host, 'пример.рф');
      expect((_url('https://españa.es/') as WebLink).host, 'españa.es');
    });

    test(
      'el camino con caracteres de dirección no afecta a lo que se muestra',
      () {
        final web = _url('https://example.com/%E2%80%AEgnp.exe') as WebLink;
        expect(web.host, 'example.com');
      },
    );

    test(
      'mailto: solo destinatarios y asunto (nunca adjuntos, copias ni cuerpo)',
      () {
        final mail = _url(
          'mailto:info@example.com?subject=Hola&cc=x@evil.test&bcc=y@evil.test'
          '&attach=/data/data/secret&attachment=/sdcard/x&body=Texto',
        ) as MailLink;
        expect(mail.display, 'info@example.com');
        expect(mail.uri.scheme, 'mailto');
        expect(mail.uri.path, 'info@example.com');
        expect(mail.uri.queryParameters, {'subject': 'Hola'});
      },
    );

    test('mailto: varios destinatarios, también el parámetro to', () {
      final mail = _url(
        'mailto:a@example.com,b@example.com?to=c@example.com',
      ) as MailLink;
      expect(mail.display, 'a@example.com, b@example.com, c@example.com');
      expect(mail.uri.path, 'a@example.com,b@example.com,c@example.com');
      expect(mail.uri.queryParameters, isEmpty);
    });

    test('mailto: sin destinatario válido no hace nada', () {
      expect(_url('mailto:?subject=Hola'), const BlockedLink());
      expect(_url('mailto:no-es-correo'), const BlockedLink());
    });

    test('tel: solo marca el número (sin parámetros)', () {
      final tel = _url('tel:+34 600-00-00-00;ext=1') as PhoneLink;
      expect(tel.display, '+34600000000');
      expect(tel.uri.toString(), 'tel:+34600000000');
      expect(_url('tel:abc'), const BlockedLink());
    });

    test('cualquier otro esquema no hace nada', () {
      for (final s in [
        'javascript:alert(1)',
        'file:///data/data/invalid.pending.app/',
        'content://invalid.pending.app.fileprovider/x',
        'intent://scan/#Intent;scheme=zxing;end',
        'data:text/html,<h1>x</h1>',
        'market://details?id=x',
        'sms:+34600000000',
        'ftp://example.com',
        'relativo/sin/esquema',
      ]) {
        expect(_url(s), const BlockedLink(), reason: s);
      }
      expect(classifyLink(), const BlockedLink());
    });

    test('lo que se muestra va sin caracteres de control ni de dirección', () {
      final mail = _url('mailto:info%E2%80%AE@example.com') as MailLink;
      expect(mail.display, 'info@example.com');
      expect(mail.display.runes.any((r) => r == 0x202E), isFalse);
    });
  });

  group('Punycode (RFC 3492)', () {
    test('vectores conocidos', () {
      expect(toPunycodeLabel('аpple'), 'xn--pple-43d');
      expect(toPunycodeLabel('bücher'), 'xn--bcher-kva');
      expect(toPunycodeLabel('example'), 'example');
    });
  });
}
