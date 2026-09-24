import 'dart:convert';

import 'package:app/app/font_licenses.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'P4: las familias de los tokens van empaquetadas (nunca se descargan)',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      final families = manifest
          .map((f) => (f as Map<String, dynamic>)['family'] as String)
          .toSet();
      expect(families, containsAll([UnaFonts.display, UnaFonts.mono]));
    },
  );

  test('las licencias OFL de las fuentes quedan registradas', () async {
    registerFontLicenses();
    final packages = <String>{};
    await for (final l in LicenseRegistry.licenses) {
      packages.addAll(l.packages);
    }
    expect(packages, containsAll(['Archivo', 'Space Mono']));
  });
}
