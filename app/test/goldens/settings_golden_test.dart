// Goldens de la spec 012 (pantalla temporal de Configuración y perfil). Se
// generan y comparan solo en Linux (CI); en el Mac, con `GOLDENS_ANY_OS=1`.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/domain/ports/license_source.dart';
import 'package:app/features/settings/license_detail_screen.dart';
import 'package:app/features/settings/licenses_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

/// Los tres niveles se ven a 360 dp de ancho (el móvil más estrecho de
/// CA-012-13).
const _size = Size(360, 780);

class _Source implements LicenseSource {
  const _Source(this.packages);

  final List<LicensePackage> packages;

  @override
  Future<List<LicensePackage>> load() async => packages;
}

LicenseText _text(List<String> paragraphs) =>
    LicenseText([for (final p in paragraphs) (text: p, indent: 0)]);

const _mit = [
  'MIT License',
  'Copyright (c) 2019 Example Authors',
  'Permission is hereby granted, free of charge, to any person obtaining a '
      'copy of this software and associated documentation files (the '
      '"Software"), to deal in the Software without restriction, including '
      'without limitation the rights to use, copy, modify, merge, publish, '
      'distribute, sublicense, and/or sell copies of the Software.',
  'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS '
      'OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
      'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND '
      'NONINFRINGEMENT.',
];

final _packages = [
  LicensePackage(name: 'Archivo', texts: [_text(_mit)]),
  LicensePackage(name: androidLibrariesLicenseKey, texts: [_text(_mit)]),
  LicensePackage(name: 'drift', texts: [_text(_mit)]),
  LicensePackage(
    name: 'PDFium',
    texts: [_text(_mit), _text(_mit.reversed.toList())],
  ),
  LicensePackage(name: 'pdfrx', texts: [_text(_mit)]),
  LicensePackage(name: 'Space Mono', texts: [_text(_mit)]),
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  await pumpWithApp(
    tester,
    child,
    size: _size,
    overrides: [licenseSourceProvider.overrideWithValue(_Source(_packages))],
  );
  await tester.pumpAndSettle();
}

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-012-01: nivel 1 (Configuración y perfil)', (tester) async {
    await _pump(tester, const SettingsScreen());
    await _golden(tester, 'settings_level1_es');
  }, skip: _skip);

  testWidgets('CA-012-03: nivel 2 (lista de licencias)', (tester) async {
    await _pump(tester, const LicensesScreen());
    await _golden(tester, 'settings_level2_es');
  }, skip: _skip);

  testWidgets('CA-012-03: nivel 3 (texto de una licencia)', (tester) async {
    await _pump(tester, LicenseDetailScreen(package: _packages[3]));
    await _golden(tester, 'settings_level3_es');
  }, skip: _skip);
}
