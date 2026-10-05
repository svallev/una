// Goldens de Ajustes (spec 015, tablero 16 del prototipo). Se generan y
// comparan solo en Linux (CI); en el Mac, con `GOLDENS_ANY_OS=1`. T-015-13
// añade los demás (EN, texto al 200 %, los dos estados del interruptor).
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

/// Se ven a 360 dp de ancho (el móvil más estrecho de CA-015-22).
const _size = Size(360, 780);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await pumpWithApp(tester, child, size: _size);
  await tester.pumpAndSettle();
}

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-015-01b: Ajustes (nivel 1)', (tester) async {
    await _pump(tester, const SettingsScreen());
    await _golden(tester, 'settings_es_x1.0');
  }, skip: _skip);

  testWidgets('CA-015-07: página de Idioma (nivel 2)', (tester) async {
    await _pump(tester, const LanguagePage());
    await _golden(tester, 'settings_language_es_x1.0');
  }, skip: _skip);
}
