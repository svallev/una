import 'package:app/app/locale_resolution.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/features/settings/license_names.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

LicensePackage _p(String name) => LicensePackage(name: name, texts: const []);

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));
  final packages = [
    _p('pdfrx'),
    _p(androidLibrariesLicenseKey),
    _p('Archivo'),
    _p('drift'),
  ];

  test(
    'CA-013-01: licenseDisplayName traduce la clave y deja el resto igual',
    () {
      expect(
        licenseDisplayName(es, _p(androidLibrariesLicenseKey)),
        'Bibliotecas de Android (AndroidX, Kotlin)',
      );
      expect(
        licenseDisplayName(en, _p(androidLibrariesLicenseKey)),
        'Android libraries (AndroidX, Kotlin)',
      );
      expect(licenseDisplayName(es, _p('Space Mono')), 'Space Mono');
      expect(licenseDisplayName(en, _p('Space Mono')), 'Space Mono');
    },
  );

  test('CL-013-1: sortedForDisplay ordena por el nombre que se ve (B en español, A en inglés)', () {
    List<String> names(AppLocalizations l) => [
      for (final p in sortedForDisplay(l, packages)) licenseDisplayName(l, p),
    ];
    expect(names(es), [
      'Archivo',
      'Bibliotecas de Android (AndroidX, Kotlin)',
      'drift',
      'pdfrx',
    ]);
    expect(names(en), [
      'Android libraries (AndroidX, Kotlin)',
      'Archivo',
      'drift',
      'pdfrx',
    ]);
  });

  test('CL-013-1: sortedForDisplay no modifica la lista recibida', () {
    final before = [...packages];
    sortedForDisplay(es, packages);
    expect(packages, before);
  });

  test(
    'CL-013-2: el idioma de la app (ca → es; gl, eu → en) decide el nombre',
    () {
      final key = _p(androidLibrariesLicenseKey);
      for (final (system, expected) in [
        (const Locale('ca'), 'Bibliotecas de Android (AndroidX, Kotlin)'),
        (const Locale('gl'), 'Android libraries (AndroidX, Kotlin)'),
        (const Locale('eu'), 'Android libraries (AndroidX, Kotlin)'),
      ]) {
        final app = lookupAppLocalizations(resolveAppLocale([system]));
        expect(licenseDisplayName(app, key), expected, reason: '$system');
      }
    },
  );
}
