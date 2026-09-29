import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/domain/services/web_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shown = 'https://www.ejemplo.com/carta?dia=hoy';

  /// Decisión para un enlace del marco principal, ya vista la página [page].
  WebNavigation follow(
    String url, {
    String page = shown,
    bool serverRedirect = false,
  }) => decideWebNavigation(
    Uri.parse(url),
    shownPage: Uri.parse(page),
    isMainFrame: true,
    isServerRedirect: serverRedirect,
  );

  /// Redirección del servidor durante la carga inicial (antes del primer
  /// `onPageStarted`).
  WebNavigation initial(String url) => decideWebNavigation(
    Uri.parse(url),
    shownPage: null,
    isMainFrame: true,
    isServerRedirect: true,
  );

  /// Navegación de la propia página (enlace, JavaScript, `meta refresh`) que
  /// llega durante la carga inicial, antes del primer `onPageStarted`.
  WebNavigation initialFromPage(String url) => decideWebNavigation(
    Uri.parse(url),
    shownPage: null,
    isMainFrame: true,
    isServerRedirect: false,
  );

  group('CA-009-11: solo la página de la dirección guardada (ADR-0018)', () {
    test('un ancla de la misma página se sigue dentro de la página', () {
      expect(follow('$shown#postres'), const StayInTask());
      expect(
        follow('https://WWW.ejemplo.com/carta?dia=hoy#a'),
        const StayInTask(),
      );
      expect(
        follow('http://www.ejemplo.com/carta?dia=hoy#a'),
        const StayInTask(),
      );
      expect(
        follow('https://ejemplo.com/#arriba', page: 'https://ejemplo.com'),
        const StayInTask(),
      );
      // La página vista ya tenía ancla.
      expect(
        follow('https://ejemplo.com/p#b', page: 'https://ejemplo.com/p#a'),
        const StayInTask(),
      );
    });

    test('cualquier otra página, también del mismo sitio, no hace nada', () {
      for (final url in [
        'https://www.ejemplo.com/programa',
        'https://www.ejemplo.com/carta?dia=manana',
        'https://www.ejemplo.com/carta?dia=hoy',
        'https://ejemplo.com/carta?dia=hoy#a',
        'https://m.ejemplo.com/carta?dia=hoy#a',
        'https://www.ejemplo.com:8443/carta?dia=hoy#a',
        'https://www.otro.com/#a',
        'http://otro.com/',
      ]) {
        expect(follow(url), const BlockNavigation(), reason: url);
      }
    });

    test('ya vista la página, una redirección del servidor (la respuesta de '
        'un formulario) tampoco', () {
      expect(
        follow('https://www.ejemplo.com/gracias', serverRedirect: true),
        const BlockNavigation(),
      );
      expect(
        follow('$shown#a', serverRedirect: true),
        const StayInTask(),
        reason: 'el ancla de la misma página sigue valiendo',
      );
    });

    test('mailto: y tel: no hacen nada', () {
      expect(follow('mailto:ana@ejemplo.com'), const BlockNavigation());
      expect(follow('tel:+34600000000'), const BlockNavigation());
    });

    test('usuario o contraseña en la dirección no hacen nada (T-5)', () {
      expect(
        follow('https://user:pass@www.ejemplo.com/carta?dia=hoy#a'),
        const BlockNavigation(),
      );
      expect(follow('https://ejemplo.com@otro.com/'), const BlockNavigation());
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
      shownPage: Uri.parse(shown),
      isMainFrame: false,
      isServerRedirect: false,
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

    test('T-009-12: una navegación de la propia página que llega antes del '
        'primer onPageStarted (location.href en el <head>) no es una '
        'redirección del servidor: no se sigue (ADR-0018)', () {
      for (final url in [
        'https://ejemplo.com/otra',
        'https://www.otro.org/final',
        'http://otro.org/',
        'http://abc.ejemplo.com/online',
      ]) {
        expect(initialFromPage(url), const BlockNavigation(), reason: url);
      }
    });

    test('pero no a otros esquemas ni con usuario en la dirección', () {
      expect(initial('intent://x#Intent;end'), const BlockNavigation());
      expect(initial('mailto:ana@ejemplo.com'), const BlockNavigation());
      expect(initial('https://u:p@otro.org/'), const BlockNavigation());
    });

    test('se avisa si la página final es de otro dominio, con su dominio', () {
      String? notice(String saved, String started) => redirectNoticeHost(
        saved: Uri.parse(saved),
        started: Uri.parse(started),
      );

      expect(
        notice('https://ejemplo.com/', 'https://www.otro.org/x'),
        'otro.org',
      );
      // Sin lista de sufijos públicos, otro subdominio también se avisa.
      expect(
        notice('https://ejemplo.com/', 'https://m.ejemplo.com/'),
        'm.ejemplo.com',
      );
      // Mismo dominio (con o sin www., http → https, otra ruta): sin aviso.
      expect(
        notice('http://ejemplo.com/', 'https://www.ejemplo.com/b'),
        isNull,
      );
      expect(notice('https://EJEMPLO.com./', 'https://ejemplo.com/'), isNull);
      expect(
        notice(
          'https://xn--e1afmkfd.xn--p1ai/',
          'https://www.xn--e1afmkfd.xn--p1ai/',
        ),
        isNull,
      );
    });
  });

  group('CA-009-11: misma página sin contar el ancla (isSamePage)', () {
    test('igual con otra ancla, con http:// como https:// y sin distinguir '
        'mayúsculas del dominio', () {
      bool same(String a, String b) => isSamePage(Uri.parse(a), Uri.parse(b));
      expect(same('$shown#a', shown), isTrue);
      expect(same('https://ejemplo.com', 'https://EJEMPLO.com/#x'), isTrue);
      expect(same('http://ejemplo.com/a', 'https://ejemplo.com/a'), isTrue);
      expect(same('https://ejemplo.com/a', 'https://ejemplo.com/b'), isFalse);
      expect(same('https://ejemplo.com/?a', 'https://ejemplo.com/?b'), isFalse);
      expect(same('https://ejemplo.com/', 'https://m.ejemplo.com/'), isFalse);
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
        WebLoadError.noResponse,
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
      // Respuesta vacía o conexión cortada por https (neverssl.com).
      expect(
        classify(WebLoadError.noResponse, fromHttp: true),
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
      // CA-009-11: la página intenta ir a otra una y otra vez.
      expect(WebLoadFailure.keepsLeaving.canRetry, isTrue);
      expect(WebLoadFailure.keepsLeaving.canOpenInBrowser, isTrue);
    });
  });
}
