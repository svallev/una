import '../entities/license_package.dart';

/// De dónde salen las licencias de lo de terceros que va en la app (CA-012-03).
abstract interface class LicenseSource {
  /// Todas, agrupadas por elemento y en orden alfabético. Lanza si no se pueden
  /// leer.
  Future<List<LicensePackage>> load();
}

/// No hay licencias que mostrar: no debe ocurrir, y se trata como un error de
/// lectura (spec 012 §5).
class LicensesUnavailable implements Exception {
  const LicensesUnavailable();

  @override
  String toString() => 'LicensesUnavailable';
}
