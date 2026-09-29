import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registra las licencias de lo que va empaquetado sin ser un paquete de pub
/// para que aparezcan en la pantalla de licencias: las OFL de las fuentes (la
/// OFL exige distribuirlas con la fuente). Solo se leen al abrir esa pantalla.
void registerBundledLicenses() {
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
