import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/services/privacy_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA-012-04: privacyLink solo devuelve direcciones https abribles', () {
    test('https válido: un WebLink con el dominio real', () {
      final link = privacyLink('https://example.com/privacy');
      expect(link, isA<WebLink>());
      expect(link!.host, 'example.com');
      expect(link.uri.toString(), 'https://example.com/privacy');
    });

    test('CA-012-05: el marcador de desarrollo es un https normal', () {
      // La puerta de publicación lo rechaza; aquí solo se abre con confirmación.
      expect(privacyLink('https://example.com/privacy'), isNotNull);
    });

    test('CL-012-8: http no se abre (solo https)', () {
      expect(privacyLink('http://example.com/privacy'), isNull);
      expect(privacyLink('HTTP://example.com/privacy'), isNull);
    });

    test('T-5: usuario@host en la dirección no se abre', () {
      expect(privacyLink('https://user@example.com/privacy'), isNull);
      expect(privacyLink('https://user:pass@example.com/privacy'), isNull);
      expect(privacyLink('https://example.com@evil.test/privacy'), isNull);
    });

    test('otros esquemas, vacía o mal formada: nada que abrir', () {
      expect(privacyLink('mailto:a@b.co'), isNull);
      expect(privacyLink('tel:+34600000000'), isNull);
      expect(privacyLink('javascript:alert(1)'), isNull);
      expect(privacyLink('file:///etc/passwd'), isNull);
      expect(privacyLink(''), isNull);
      expect(privacyLink('   '), isNull);
      expect(privacyLink('example.com/privacy'), isNull);
      expect(privacyLink('https://'), isNull);
      expect(privacyLink('https://exa mple.com'), isNull);
    });

    test('el esquema y el dominio se normalizan (HTTPS mayúsculas)', () {
      final link = privacyLink('HTTPS://Example.COM/Privacy');
      expect(link, isNotNull);
      expect(link!.host, 'example.com');
    });
  });
}
