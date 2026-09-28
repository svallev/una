import 'dart:io';

import 'package:app/domain/services/public_suffix.dart';
import 'package:flutter_test/flutter_test.dart';

/// La lista empaquetada (la misma que el asset; tools/psl.lock la fija).
final _asset = File('assets/psl/public_suffix_list.dat');

void main() {
  late PublicSuffixList psl;

  setUpAll(() => psl = PublicSuffixList.parse(_asset.readAsStringSync()));

  // Casos de la suite oficial de la PSL (publicsuffix/list, tests/test_psl.txt),
  // contra la lista real. `checkPublicSuffix(entrada, dominio registrable)`.
  void check(String? host, String? expected) {
    expect(
      host == null ? null : psl.registrableDomain(host),
      expected,
      reason: '$host',
    );
  }

  group(
    'CA-009-11: mismo sitio = mismo dominio registrable (suite oficial)',
    () {
      test('entrada nula y mayúsculas', () {
        check(null, null);
        check('COM', null);
        check('example.COM', 'example.com');
        check('WwW.example.COM', 'example.com');
      });

      test('punto inicial', () {
        check('.com', null);
        check('.example', null);
        check('.example.com', null);
        check('.example.example', null);
      });

      test('TLD que no está en la lista: regla por defecto "*"', () {
        check('example', null);
        check('example.example', 'example.example');
        check('b.example.example', 'example.example');
        check('a.b.example.example', 'example.example');
      });

      test('TLD con una sola regla', () {
        check('biz', null);
        check('domain.biz', 'domain.biz');
        check('b.domain.biz', 'domain.biz');
        check('a.b.domain.biz', 'domain.biz');
      });

      test('TLD con reglas de dos niveles', () {
        check('com', null);
        check('example.com', 'example.com');
        check('b.example.com', 'example.com');
        check('a.b.example.com', 'example.com');
        check('uk.com', null);
        check('example.uk.com', 'example.uk.com');
        check('b.example.uk.com', 'example.uk.com');
        check('a.b.example.uk.com', 'example.uk.com');
        check('test.ac', 'test.ac');
      });

      test('TLD con solo una regla comodín', () {
        check('mm', null);
        check('c.mm', null);
        check('b.c.mm', 'b.c.mm');
        check('a.b.c.mm', 'b.c.mm');
      });

      test('TLD más complejo (jp): comodines y excepciones', () {
        check('jp', null);
        check('test.jp', 'test.jp');
        check('www.test.jp', 'test.jp');
        check('ac.jp', null);
        check('test.ac.jp', 'test.ac.jp');
        check('www.test.ac.jp', 'test.ac.jp');
        check('kyoto.jp', null);
        check('test.kyoto.jp', 'test.kyoto.jp');
        check('ide.kyoto.jp', null);
        check('b.ide.kyoto.jp', 'b.ide.kyoto.jp');
        check('a.b.ide.kyoto.jp', 'b.ide.kyoto.jp');
        check('c.kobe.jp', null);
        check('b.c.kobe.jp', 'b.c.kobe.jp');
        check('a.b.c.kobe.jp', 'b.c.kobe.jp');
        check('city.kobe.jp', 'city.kobe.jp');
        check('www.city.kobe.jp', 'city.kobe.jp');
      });

      test('TLD con comodín y excepciones (ck)', () {
        check('ck', null);
        check('test.ck', null);
        check('b.test.ck', 'b.test.ck');
        check('a.b.test.ck', 'b.test.ck');
        check('www.ck', 'www.ck');
        check('www.www.ck', 'www.ck');
      });

      test('US K12', () {
        check('us', null);
        check('test.us', 'test.us');
        check('www.test.us', 'test.us');
        check('ak.us', null);
        check('test.ak.us', 'test.ak.us');
        check('www.test.ak.us', 'test.ak.us');
        check('k12.ak.us', null);
        check('test.k12.ak.us', 'test.k12.ak.us');
        check('www.test.k12.ak.us', 'test.k12.ak.us');
      });

      test('etiquetas IDN', () {
        check('食狮.com.cn', '食狮.com.cn');
        check('食狮.公司.cn', '食狮.公司.cn');
        check('www.食狮.公司.cn', '食狮.公司.cn');
        check('shishi.公司.cn', 'shishi.公司.cn');
        check('公司.cn', null);
        check('食狮.中国', '食狮.中国');
        check('www.食狮.中国', '食狮.中国');
        check('shishi.中国', 'shishi.中国');
        check('中国', null);
      });

      test('las mismas, en punycode', () {
        check('xn--85x722f.com.cn', 'xn--85x722f.com.cn');
        check('xn--85x722f.xn--55qx5d.cn', 'xn--85x722f.xn--55qx5d.cn');
        check('www.xn--85x722f.xn--55qx5d.cn', 'xn--85x722f.xn--55qx5d.cn');
        check('shishi.xn--55qx5d.cn', 'shishi.xn--55qx5d.cn');
        check('xn--55qx5d.cn', null);
        check('xn--85x722f.xn--fiqs8s', 'xn--85x722f.xn--fiqs8s');
        check('www.xn--85x722f.xn--fiqs8s', 'xn--85x722f.xn--fiqs8s');
        check('shishi.xn--fiqs8s', 'shishi.xn--fiqs8s');
        check('xn--fiqs8s', null);
      });
    },
  );

  group('CA-009-11: casos de la app', () {
    test('los ejemplos de la spec: www. y m. son el mismo sitio', () {
      expect(psl.registrableDomain('www.ejemplo.com'), 'ejemplo.com');
      expect(psl.registrableDomain('m.ejemplo.com'), 'ejemplo.com');
    });

    test('co.uk: dos dominios distintos no son el mismo sitio', () {
      expect(psl.registrableDomain('www.ejemplo.co.uk'), 'ejemplo.co.uk');
      expect(psl.registrableDomain('otro.co.uk'), 'otro.co.uk');
      expect(psl.registrableDomain('co.uk'), isNull);
    });

    test(
      'la sección privada cuenta: cada usuario de github.io es un sitio',
      () {
        expect(psl.registrableDomain('ana.github.io'), 'ana.github.io');
        expect(psl.registrableDomain('www.ana.github.io'), 'ana.github.io');
        expect(psl.registrableDomain('github.io'), isNull);
      },
    );

    test('una IP o un host mal formado no tienen dominio registrable', () {
      for (final host in [
        '',
        '127.0.0.1',
        '93.184.216.34',
        '::1',
        '[2001:db8::1]',
        'example.com.',
        'a..example.com',
        'example .com',
      ]) {
        expect(psl.registrableDomain(host), isNull, reason: host);
      }
    });

    test('lista mínima: regla, comodín y excepción', () {
      final small = PublicSuffixList.parse('''
// Comentario
com
*.test.com   texto tras un espacio que se ignora
!ok.test.com

公司.cn
''');
      expect(small.registrableDomain('a.com'), 'a.com');
      expect(small.registrableDomain('x.test.com'), isNull);
      expect(small.registrableDomain('a.x.test.com'), 'a.x.test.com');
      expect(small.registrableDomain('ok.test.com'), 'ok.test.com');
      expect(small.registrableDomain('a.ok.test.com'), 'ok.test.com');
      expect(small.registrableDomain('a.xn--55qx5d.cn'), 'a.xn--55qx5d.cn');
      // Sin reglas para el TLD: la regla por defecto.
      expect(small.registrableDomain('b.a.org'), 'a.org');
    });

    test('la lista empaquetada tiene sus dos secciones', () {
      final text = _asset.readAsStringSync();
      expect(text, contains('===BEGIN ICANN DOMAINS==='));
      expect(text, contains('===END PRIVATE DOMAINS==='));
      expect(psl.ruleCount, greaterThan(9000));
    });
  });
}
