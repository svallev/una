import 'dart:io';

import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/services/public_suffix.dart';
import 'package:app/domain/services/web_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

/// La lista empaquetada (la misma que el asset; tools/psl.lock la fija).
final _asset = File('assets/psl/public_suffix_list.dat');

void main() {
  late PublicSuffixList psl;

  setUpAll(() => psl = PublicSuffixList.parse(_asset.readAsStringSync()));

  /// Decisión para un enlace del marco principal, ya cargada una página de
  /// [site] (el sitio de referencia).
  WebNavigation follow(String url, {String site = 'ejemplo.com'}) =>
      decideWebNavigation(
        Uri.parse(url),
        referenceSite: site,
        isMainFrame: true,
        psl: psl,
      );

  /// Decisión durante la carga inicial (antes del primer `onPageStarted`).
  WebNavigation initial(String url) => decideWebNavigation(
    Uri.parse(url),
    referenceSite: null,
    isMainFrame: true,
    psl: psl,
  );

  group('CA-009-11: el sitio es el dominio registrable', () {
    String? site(String url) => webSiteOf(Uri.parse(url), psl);

    test('subdominios del mismo dominio registrable son el mismo sitio', () {
      expect(site('https://www.ejemplo.com/a'), 'ejemplo.com');
      expect(site('https://m.ejemplo.com/'), 'ejemplo.com');
      expect(site('https://EJEMPLO.com./'), 'ejemplo.com');
    });

    test('con la PSL: co.uk, comodines, excepciones y dominios privados', () {
      expect(site('https://www.ejemplo.co.uk/'), 'ejemplo.co.uk');
      expect(site('https://otro.co.uk/'), 'otro.co.uk');
      expect(site('https://a.b.city.kobe.jp/'), 'city.kobe.jp');
      expect(site('https://www.foo.kobe.jp/'), 'www.foo.kobe.jp');
      expect(site('https://ana.github.io/'), 'ana.github.io');
      expect(site('https://luis.github.io/'), 'luis.github.io');
    });

    test('un dominio internacional es el mismo en Unicode y en punycode', () {
      expect(
        site('https://www.xn--e1afmkfd.xn--p1ai/'),
        site('https://пример.рф/'),
      );
      expect(
        site('https://www.xn--e1afmkfd.xn--p1ai/'),
        'xn--e1afmkfd.xn--p1ai',
      );
    });

    test('una IP o un sufijo público son su propio sitio', () {
      expect(site('https://93.184.216.34/x'), '93.184.216.34');
      expect(site('https://[2001:db8::1]/'), '2001:db8::1');
      expect(site('https://github.io/'), 'github.io');
    });

    test('sin dominio no hay sitio', () {
      expect(site('mailto:ana@ejemplo.com'), isNull);
      expect(site('https:///ruta'), isNull);
    });
  });

  group('CA-009-11: navegación contenida', () {
    test('al mismo sitio navega dentro de la tarea', () {
      expect(follow('https://ejemplo.com/programa'), const StayInTask());
      expect(follow('https://m.ejemplo.com/'), const StayInTask());
      expect(follow('https://a.b.ejemplo.com/x?y=1#z'), const StayInTask());
    });

    test('a otro sitio: al navegador tras confirmar, con el host entero', () {
      final leave = follow('https://www.otro.com/pagina') as LeaveTask;
      final web = leave.target as WebLink;
      expect(web.host, 'www.otro.com');
      expect(web.uri.toString(), 'https://www.otro.com/pagina');
      // Mismo sufijo público no es el mismo sitio.
      expect(
        follow('https://otro.co.uk/', site: 'ejemplo.co.uk'),
        isA<LeaveTask>(),
      );
      expect(
        follow('https://luis.github.io/', site: 'ana.github.io'),
        isA<LeaveTask>(),
      );
    });

    test('el host del navegador sale saneado y en punycode si mezcla', () {
      // "аpple.com" con la "а" cirílica.
      final leave = follow('https://аpple.com/') as LeaveTask;
      expect((leave.target as WebLink).host, 'xn--pple-43d.com');
    });

    test('http:// dentro del sitio se carga como https:// (CA-009-09)', () {
      expect(
        follow('http://www.ejemplo.com/a?b=1'),
        StayInTask(Uri.parse('https://www.ejemplo.com/a?b=1')),
      );
    });

    test('http:// a otro sitio va al navegador tal cual', () {
      final leave = follow('http://otro.com/') as LeaveTask;
      expect((leave.target as WebLink).uri.toString(), 'http://otro.com/');
    });

    test('mailto: y tel: siguen la regla de los enlaces del PDF', () {
      final mail = follow(
        'mailto:ana@ejemplo.com?subject=Hola&body=secreto',
      ) as LeaveTask;
      expect(mail.target, isA<MailLink>());
      expect((mail.target as MailLink).display, 'ana@ejemplo.com');
      expect(mail.target.toString(), isNot(contains('secreto')));

      final tel = follow('tel:+34 600 000 000') as LeaveTask;
      expect((tel.target as PhoneLink).display, '+34600000000');
    });

    test('mailto: o tel: sin destino válido no hacen nada', () {
      expect(follow('mailto:'), const BlockNavigation());
      expect(follow('tel:abc'), const BlockNavigation());
    });

    test('usuario o contraseña en la dirección no hacen nada (T-5)', () {
      expect(follow('https://user:pass@ejemplo.com/'), const BlockNavigation());
      expect(follow('https://ejemplo.com@otro.com/'), const BlockNavigation());
      expect(follow('https://user@otro.com/'), const BlockNavigation());
    });

    test('cualquier otro esquema no hace nada', () {
      for (final url in [
        'javascript:alert(1)',
        'file:///sdcard/a.pdf',
        'content://com.android.contacts/contacts',
        'intent://scan/#Intent;scheme=zxing;end',
        'data:text/html,<b>x</b>',
        'about:blank',
        'blob:https://ejemplo.com/1234',
        'whatsapp://send?text=hola',
        'market://details?id=x',
        'desconocido:algo',
        'https:///sin-dominio',
      ]) {
        expect(follow(url), const BlockNavigation(), reason: url);
      }
    });
  });

  group('CA-009-11: marcos internos (iframes) de la página', () {
    WebNavigation frame(String url) => decideWebNavigation(
      Uri.parse(url),
      referenceSite: 'ejemplo.com',
      isMainFrame: false,
      psl: psl,
    );

    test('un marco interno web se carga dentro de la página, de cualquier '
        'sitio', () {
      expect(frame('https://www.youtube.com/embed/x'), const StayInTask());
      expect(frame('about:blank'), const StayInTask());
      expect(frame('about:srcdoc'), const StayInTask());
    });

    test('ni sale de la tarea ni carga otros esquemas', () {
      expect(frame('https://user:pass@otro.com/'), const BlockNavigation());
      expect(frame('mailto:ana@ejemplo.com'), const BlockNavigation());
      expect(frame('intent://x#Intent;end'), const BlockNavigation());
      expect(frame('javascript:alert(1)'), const BlockNavigation());
      expect(frame('data:text/html,x'), const BlockNavigation());
    });
  });

  group('CL-009-1: carga inicial con redirecciones', () {
    test('se siguen las redirecciones, también a otro sitio', () {
      expect(initial('https://ejemplo.com/'), const StayInTask());
      expect(initial('https://www.otro.org/final'), const StayInTask());
      expect(
        initial('http://otro.org/'),
        StayInTask(Uri.parse('https://otro.org/')),
      );
    });

    test('pero no a otros esquemas ni con usuario en la dirección', () {
      expect(initial('intent://x#Intent;end'), const BlockNavigation());
      expect(initial('mailto:ana@ejemplo.com'), const BlockNavigation());
      expect(initial('https://u:p@otro.org/'), const BlockNavigation());
    });

    test('se avisa si la página final es de otro sitio, con su dominio', () {
      String? notice(String saved, String started) => redirectNoticeHost(
        saved: Uri.parse(saved),
        started: Uri.parse(started),
        psl: psl,
      );

      expect(
        notice('https://ejemplo.com/', 'https://www.otro.org/x'),
        'otro.org',
      );
      // Mismo sitio (otro subdominio, o http → https): sin aviso.
      expect(notice('https://ejemplo.com/', 'https://m.ejemplo.com/'), isNull);
      expect(notice('http://ejemplo.com/', 'https://www.ejemplo.com/'), isNull);
      expect(
        notice('https://ejemplo.co.uk/', 'https://otro.co.uk/'),
        'otro.co.uk',
      );
    });
  });

  group(
    'CA-009-09: la dirección guardada http:// se intenta como https://',
    () {
      test('cambia solo el esquema', () {
        expect(
          httpsVersion(Uri.parse('http://ejemplo.com/a b?c=1#d')).toString(),
          'https://ejemplo.com/a%20b?c=1#d',
        );
        expect(
          httpsVersion(Uri.parse('http://ejemplo.com:8080/')).toString(),
          'https://ejemplo.com:8080/',
        );
        // El puerto 80 es el de http: con https se usa el suyo.
        expect(
          httpsVersion(Uri.parse('http://ejemplo.com:80/')).toString(),
          'https://ejemplo.com/',
        );
        final https = Uri.parse('https://ejemplo.com/');
        expect(httpsVersion(https), https);
      });
    },
  );

  group('Fallos de carga (WebLoadFailure)', () {
    WebLoadFailure? classify(
      WebLoadError error, {
      bool mainFrame = true,
      bool fromHttp = false,
    }) => classifyLoadError(
      error,
      isMainFrame: mainFrame,
      upgradedFromHttp: fromHttp,
    );

    test('CA-009-08: sin red (DNS) es siempre "sin conexión", aunque llegara '
        'antes onPageStarted', () {
      expect(classify(WebLoadError.hostLookup), WebLoadFailure.offline);
      expect(
        classify(WebLoadError.hostLookup, fromHttp: true),
        WebLoadFailure.offline,
      );
    });

    test('CA-009-08: cualquier otro error de red del marco principal es "sin '
        'conexión"', () {
      for (final e in [
        WebLoadError.connect,
        WebLoadError.secureHandshake,
        WebLoadError.timeout,
        WebLoadError.other,
      ]) {
        expect(classify(e), WebLoadFailure.offline, reason: '$e');
      }
    });

    test('CA-009-08: los 20 s sin que la página empiece a verse', () {
      expect(webLoadTimeout, const Duration(seconds: 20));
      expect(classify(WebLoadError.timeout), WebLoadFailure.offline);
    });

    test('CA-009-09: una dirección http:// cuyo https no conecta es "sin '
        'conexión segura"', () {
      expect(
        classify(WebLoadError.connect, fromHttp: true),
        WebLoadFailure.insecure,
      );
      expect(
        classify(WebLoadError.secureHandshake, fromHttp: true),
        WebLoadFailure.insecure,
      );
      expect(
        classify(WebLoadError.timeout, fromHttp: true),
        WebLoadFailure.offline,
      );
    });

    test('CA-009-10: un certificado no válido es siempre "certificado"', () {
      expect(classify(WebLoadError.certificate), WebLoadFailure.certificate);
      expect(
        classify(WebLoadError.certificate, fromHttp: true),
        WebLoadFailure.certificate,
      );
    });

    test('CL-009-4: una descarga (PDF u otro archivo) no es una página', () {
      expect(classify(WebLoadError.download), WebLoadFailure.notAPage);
    });

    test('los errores de un recurso suelto o un marco interno no tapan la '
        'página', () {
      for (final e in WebLoadError.values) {
        expect(classify(e, mainFrame: false), isNull, reason: '$e');
      }
    });

    test('§5: las acciones de cada aviso', () {
      expect(WebLoadFailure.offline.canRetry, isTrue);
      expect(WebLoadFailure.offline.canOpenInBrowser, isFalse);
      expect(WebLoadFailure.insecure.canRetry, isFalse);
      expect(WebLoadFailure.insecure.canOpenInBrowser, isTrue);
      expect(WebLoadFailure.certificate.canRetry, isTrue);
      expect(WebLoadFailure.certificate.canOpenInBrowser, isTrue);
      expect(WebLoadFailure.notAPage.canRetry, isFalse);
      expect(WebLoadFailure.notAPage.canOpenInBrowser, isTrue);
    });
  });
}
