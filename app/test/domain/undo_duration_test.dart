import 'package:app/app/theme/tokens.g.dart';
import 'package:app/domain/services/undo_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Las duraciones de los tokens, como las usa el controlador.
  const rule = UndoDuration(
    base: UnaMotion.undoWindow,
    legacyA11y: UnaMotion.undoWindowLegacyA11y,
    max: UnaMotion.undoWindowMax,
  );

  test('CA-014-06: los tokens son 4 s, 10 s y 10 min', () {
    expect(UnaMotion.undoWindow, const Duration(seconds: 4));
    expect(UnaMotion.undoWindowLegacyA11y, const Duration(seconds: 10));
    expect(UnaMotion.undoWindowMax, const Duration(minutes: 10));
  });

  group('CA-014-06: Android 10 o posterior (hay "Tiempo para actuar")', () {
    test('un tiempo mayor alarga la card', () {
      expect(
        rule((recommendedMs: 10000, serviceEnabled: false)),
        const Duration(seconds: 10),
      );
      expect(
        rule((recommendedMs: 120000, serviceEnabled: true)),
        const Duration(minutes: 2),
      );
    });

    test('el valor por defecto del sistema (el mismo 4000) deja 4 s, '
        'también con un servicio activo', () {
      expect(
        rule((recommendedMs: 4000, serviceEnabled: false)),
        const Duration(seconds: 4),
      );
      expect(
        rule((recommendedMs: 4000, serviceEnabled: true)),
        const Duration(seconds: 4),
      );
    });

    test('un tiempo menor no acorta (ni cero ni negativo)', () {
      for (final ms in [3999, 1000, 0, -5]) {
        expect(
          rule((recommendedMs: ms, serviceEnabled: true)),
          const Duration(seconds: 4),
          reason: '$ms',
        );
      }
    });

    test('un valor absurdo se queda en 10 min', () {
      for (final ms in [600001, 3600000, 1 << 62]) {
        expect(
          rule((recommendedMs: ms, serviceEnabled: false)),
          const Duration(minutes: 10),
          reason: '$ms',
        );
      }
      expect(
        rule((recommendedMs: 600000, serviceEnabled: false)),
        const Duration(minutes: 10),
      );
    });
  });

  group('CA-014-06: Android 8 y 9 (sin "Tiempo para actuar")', () {
    test('con un servicio de accesibilidad activo, 10 s', () {
      expect(
        rule((recommendedMs: null, serviceEnabled: true)),
        const Duration(seconds: 10),
      );
    });

    test('sin servicio, 4 s', () {
      expect(
        rule((recommendedMs: null, serviceEnabled: false)),
        const Duration(seconds: 4),
      );
    });
  });

  test('CA-014-06: sin canal (iOS, web de pruebas, tests), 4 s', () {
    // El puerto devuelve (null, false) sin canal o con un error.
    expect(
      rule((recommendedMs: null, serviceEnabled: false)),
      UnaMotion.undoWindow,
    );
  });
}
