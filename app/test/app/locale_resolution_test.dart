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
    for (final code in ['en', 'fr', 'gl', 'eu', 'pt', 'de', 'it']) {
      expect(
        resolveAppLocale([Locale(code)]),
        const Locale('en'),
        reason: code,
      );
    }
  });

  test('CA-010-01: es-419 con subetiquetas (como lo entrega Android)', () {
    expect(
      resolveAppLocale(const [
        Locale.fromSubtags(languageCode: 'es', countryCode: '419'),
      ]),
      const Locale('es'),
    );
    expect(
      resolveAppLocale(const [
        Locale.fromSubtags(languageCode: 'es', scriptCode: 'Latn'),
      ]),
      const Locale('es'),
    );
    // Variantes regionales sin distinción (CL-010-3).
    expect(resolveAppLocale(const [Locale('en', 'GB')]), const Locale('en'));
    expect(
      resolveAppLocale(const [Locale('pt', 'BR'), Locale('gl', 'ES')]),
      const Locale('en'),
    );
  });

  test('CA-010-01: el catalán (ca-*) abre en español', () {
    for (final l in const [
      Locale('ca'),
      Locale('ca', 'ES'),
      Locale('ca', 'AD'),
    ]) {
      expect(resolveAppLocale([l]), const Locale('es'), reason: '$l');
    }
    // Primer idioma admitido de la lista (CA-010-02).
    expect(
      resolveAppLocale(const [Locale('fr', 'FR'), Locale('ca', 'ES')]),
      const Locale('es'),
    );
    expect(
      resolveAppLocale(const [Locale('ca', 'ES'), Locale('en', 'GB')]),
      const Locale('es'),
    );
    expect(
      resolveAppLocale(const [Locale('en', 'GB'), Locale('ca', 'ES')]),
      const Locale('en'),
    );
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

  test('CA-010-02: lista sin ningún idioma admitido (o vacía) → inglés', () {
    expect(
      resolveAppLocale(const [
        Locale('fr', 'FR'),
        Locale('gl', 'ES'),
        Locale('de', 'DE'),
      ]),
      const Locale('en'),
    );
    expect(resolveAppLocale(const []), const Locale('en'));
  });

  test('CL-010-4: idiomas de derecha a izquierda (ar, he) → inglés', () {
    for (final l in const [
      Locale('ar'),
      Locale('ar', 'EG'),
      Locale('he'),
      Locale('he', 'IL'),
    ]) {
      expect(resolveAppLocale([l]), const Locale('en'), reason: '$l');
    }
    // Con español detrás en la lista, manda el primero admitido.
    expect(
      resolveAppLocale(const [Locale('ar'), Locale('es', 'ES')]),
      const Locale('es'),
    );
  });
}
