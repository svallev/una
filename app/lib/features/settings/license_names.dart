import '../../domain/entities/license_package.dart';
import '../../l10n/generated/app_localizations.dart';

/// El nombre que se ve de un elemento de la lista de licencias (CA-013-01): el
/// de siempre, salvo la entrada de las bibliotecas de Android, que se registra
/// con una clave interna ([androidLibrariesLicenseKey]) y se muestra con el
/// texto de la app, en su idioma. Lo usan la fila, la etiqueta del lector y el
/// título del nivel 3.
String licenseDisplayName(AppLocalizations l10n, LicensePackage package) =>
    package.name == androidLibrariesLicenseKey
    ? l10n.licensesAndroidLibraries
    : package.name;

/// [packages] ordenados por el nombre que se ve (CL-013-1), con la misma regla
/// que la fuente ([compareLicenseNames]). No modifica la lista recibida.
List<LicensePackage> sortedForDisplay(
  AppLocalizations l10n,
  List<LicensePackage> packages,
) {
  final names = {for (final p in packages) p: licenseDisplayName(l10n, p)};
  return [...packages]
    ..sort((a, b) => compareLicenseNames(names[a]!, names[b]!));
}
