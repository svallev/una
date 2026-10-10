// Goldens de Ajustes (spec 015, tablero 16 del prototipo): el nivel 1, los dos
// estados del interruptor y la página de Idioma, en español e inglés, a ×1,0 y
// ×2,0. La spec 017 añade la fila "Bloquear zoom" (en el nivel 1 y suelta en
// sus dos estados: `settings_lockzoom_*`). Se generan y comparan solo en Linux (CI); en el Mac, con
// `GOLDENS_ANY_OS=1` (para revisarlos a ojo, no se suben).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/una_icons.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

/// Se ven a 360 dp de ancho (el móvil más estrecho de CA-015-22).
const _size = Size(360, 780);

const _langs = ['es', 'en'];
const _scales = [1.0, 2.0];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required String lang,
  required double scale,
}) async {
  await pumpWithApp(
    tester,
    child,
    locale: Locale(lang),
    textScale: scale,
    size: _size,
  );
  await tester.pumpAndSettle();
}

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

/// Los dos estados de una fila con interruptor, uno sobre otro, sobre el papel.
/// Con [lockZoom] es la fila de la spec 017 (icono de la lupa con el menos,
/// nombre y subtítulo propios); sin él, la de "Pantalla siempre activa".
class _SwitchStates extends StatelessWidget {
  const _SwitchStates({this.lockZoom = false});

  final bool lockZoom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: UnaColors.paper,
      child: SafeArea(
        child: Padding(
          // El margen lateral de las filas de Ajustes.
          padding: const EdgeInsets.symmetric(horizontal: UnaSpace.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final on in [false, true]) ...[
                UnaSwitchRow(
                  icon: lockZoom ? UnaIcons.magnifierMinus : UnaIcons.phone,
                  label: lockZoom
                      ? l10n.settingsLockZoom
                      : l10n.settingsKeepAwake,
                  subtitle: lockZoom
                      ? l10n.settingsLockZoomHint
                      : l10n.settingsKeepAwakeHint,
                  value: on,
                  onToggle: () {},
                ),
                const SizedBox(height: UnaSpace.l),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in _langs) {
    for (final scale in _scales) {
      final name = '${lang}_x${scale.toStringAsFixed(1)}';

      testWidgets('CA-015-01b: Ajustes (nivel 1), $name', (tester) async {
        await _pump(tester, const SettingsScreen(), lang: lang, scale: scale);
        await _golden(tester, 'settings_$name');
      }, skip: _skip);

      testWidgets('CA-015-03: los dos estados del interruptor, $name', (
        tester,
      ) async {
        await _pump(tester, const _SwitchStates(), lang: lang, scale: scale);
        await _golden(tester, 'settings_switch_$name');
      }, skip: _skip);

      // Spec 017 (CA-017-01, 15): la fila "Bloquear zoom" en sus dos estados.
      testWidgets('CA-017-01: la fila "Bloquear zoom" en sus dos estados, '
          '$name', (tester) async {
        await _pump(
          tester,
          const _SwitchStates(lockZoom: true),
          lang: lang,
          scale: scale,
        );
        await _golden(tester, 'settings_lockzoom_$name');
      }, skip: _skip);

      testWidgets('CA-015-07: página de Idioma (nivel 2), $name', (
        tester,
      ) async {
        await _pump(tester, const LanguagePage(), lang: lang, scale: scale);
        await _golden(tester, 'settings_language_$name');
      }, skip: _skip);
    }
  }
}
