import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Nombre de la entrada de las bibliotecas de Android (AndroidX, Kotlin) en la
/// lista de licencias (CA-012-03, P-012-3). Es un dato de la lista, como el
/// nombre de un paquete; el texto de la licencia es contenido de terceros.
const androidLibrariesLicenseName = 'Bibliotecas de Android (AndroidX, Kotlin)';

/// Separa las licencias de un mismo archivo: una línea de 80 `=`.
final _separator = RegExp(r'^={80}$', multiLine: true);

/// Archivos de licencias que van empaquetados sin ser un paquete de pub y que
/// `NOTICES` de Flutter no incluye (CA-012-03): `(nombre en la lista, ruta)`.
///
/// - Las OFL de las fuentes (la OFL exige distribuirlas con la fuente).
/// - PDFium (`libpdfium.so`, `tools/pdfium.lock`): su licencia y los avisos de
///   sus terceros; la primera línea dice de qué versión y de qué `.tgz` sale.
/// - SQLite (`libsqlite3.so`, que descarga el paquete `sqlite3`): dominio público.
/// - Las bibliotecas de Android del `releaseRuntimeClasspath`: Apache-2.0 y la
///   lista de artefactos (`tools/check-licenses.sh` comprueba que está completa).
const _bundled = <(String, String)>[
  ('Archivo', 'assets/fonts/archivo/OFL.txt'),
  ('Space Mono', 'assets/fonts/space_mono/OFL.txt'),
  ('PDFium', 'assets/licenses/pdfium.txt'),
  ('SQLite', 'assets/licenses/sqlite.txt'),
  (androidLibrariesLicenseName, 'assets/licenses/android.txt'),
];

/// Registra esas licencias para que aparezcan en la pantalla de licencias.
///
/// Son **perezosas**: `LicenseRegistry` ejecuta el generador solo cuando se
/// piden las licencias (al abrir esa pantalla), nunca antes del primer
/// fotograma (CA-012-16, P2). Un archivo puede traer varias licencias
/// separadas por una línea de 80 `=` (cada una es un texto, con su título en
/// la primera línea). [bundle] es solo para los tests.
void registerBundledLicenses({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final assets = bundle ?? rootBundle;
    for (final (name, path) in _bundled) {
      final text = await assets.loadString(path);
      for (final section in text.split(_separator)) {
        final trimmed = section.trim();
        if (trimmed.isEmpty) continue;
        yield LicenseEntryWithLineBreaks([name], trimmed);
      }
    }
  });
}
