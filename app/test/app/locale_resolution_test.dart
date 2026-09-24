import 'package:app/app/locale_resolution.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA-010-01: cualquier es-* → español; el resto → inglés', () {
    for (final l in ['es', 'es_ES', 'es_MX', 'es_419']) {
      final parts = l.split('_');
      expect(
        resolveAppLocale([
          Locale(parts[0], parts.length > 1 ? parts[1] : null),
        ]),
        const Locale('es'),
        reason: l,
      );
    }
    for (final code in ['en', 'fr', 'ca', 'gl', 'eu', 'pt', 'de']) {
      expect(
        resolveAppLocale([Locale(code)]),
        const Locale('en'),
        reason: code,
      );
    }
  });

  test(
    'CA-010-02: se usa el primer idioma admitido de la lista del dispositivo',
    () {
      expect(
        resolveAppLocale(const [Locale('fr', 'FR'), Locale('es', 'ES')]),
        const Locale('es'),
      );
      expect(
        resolveAppLocale(const [
          Locale('de'),
          Locale('en', 'GB'),
          Locale('es'),
        ]),
        const Locale('en'),
      );
      expect(resolveAppLocale(null), const Locale('en'));
    },
  );

  test('CA-010-03: el ajuste manual manda', () {
    expect(
      resolveAppLocale(const [Locale('es')], setting: 'en'),
      const Locale('en'),
    );
    expect(
      resolveAppLocale(const [Locale('en')], setting: 'es'),
      const Locale('es'),
    );
  });
}
