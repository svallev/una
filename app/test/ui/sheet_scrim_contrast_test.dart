import 'package:app/app/theme/tokens.g.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 024, CA-024-02 (plan §1.3): con el velo de una hoja abierta, los iconos claros de la
/// barra de estado contrastan 3:1 o más con lo que queda detrás (cada color de nota y
/// `paper`), y los oscuros de la barra de navegación, con la hoja (`paper`). Todo se calcula
/// desde los tokens, sin números fijados.
///
/// [Suposición] los iconos claros del sistema son blancos; los mide C-024-2 en dispositivo.
void main() {
  /// Contraste WCAG entre dos colores opacos.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// El fondo [under] con el velo `scrim` encima.
  Color underScrim(Color under) => Color.alphaBlend(UnaColors.scrim, under);

  final backgrounds = <String, Color>{
    'paper': UnaColors.paper,
    for (final (name, palette) in [
      ('classic', UnaPalettes.classic),
      ('neon', UnaPalettes.neon),
      ('mono', UnaPalettes.mono),
    ])
      for (final (i, c) in palette.indexed) '$name[$i]': c,
  };

  test('CA-024-02: la lista de fondos cubre las tres paletas y paper', () {
    expect(backgrounds.length, 1 + 5 * 3);
  });

  for (final entry in backgrounds.entries) {
    test(
      'CA-024-02: iconos claros sobre ${entry.key} con el velo contrastan 3:1 o más',
      () {
        final shown = underScrim(entry.value);
        expect(
          contrast(const Color(0xFFFFFFFF), shown),
          greaterThanOrEqualTo(3),
          reason: 'blanco sobre ${entry.key} con velo ($shown)',
        );
      },
    );
  }

  test('CA-024-02: con el velo, los iconos oscuros de hoy no llegarían a 3:1 en algún fondo (por eso se piden claros)', () {
    // Documenta por qué se pide el estilo claro: sin cambiarlo, los oscuros fallan.
    final failing = [
      for (final e in backgrounds.entries)
        if (contrast(const Color(0xFF000000), underScrim(e.value)) < 3) e.key,
    ];
    expect(failing, isNotEmpty);
  });

  test('CA-024-02: los iconos oscuros de la barra de navegación contrastan 3:1 o más con la hoja (paper)', () {
    expect(
      contrast(const Color(0xFF000000), UnaColors.paper),
      greaterThanOrEqualTo(3),
    );
    expect(contrast(UnaColors.ink, UnaColors.paper), greaterThanOrEqualTo(3));
  });

  test('CA-024-01: los iconos claros sobre la card de deshacer (ink) contrastan 3:1 o más', () {
    expect(
      contrast(const Color(0xFFFFFFFF), UnaColors.ink),
      greaterThanOrEqualTo(3),
    );
  });
}
