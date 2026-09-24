import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registra las licencias OFL de las fuentes empaquetadas para que aparezcan en
/// la pantalla de licencias (la OFL exige distribuirlas con la fuente).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, path) in [
      ('Archivo', 'assets/fonts/archivo/OFL.txt'),
      ('Space Mono', 'assets/fonts/space_mono/OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(path));
    }
  });
}
