import 'package:app/domain/entities/license_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA-013-01: la clave interna de las bibliotecas de Android lleva ":" '
      '(un nombre de paquete de pub no puede) y no es un texto visible', () {
    expect(androidLibrariesLicenseKey, 'una:android-libraries');
    expect(androidLibrariesLicenseKey, contains(':'));
    // Nunca se muestra tal cual: no se parece al nombre traducido.
    expect(androidLibrariesLicenseKey, isNot(contains('Bibliotecas')));
    expect(androidLibrariesLicenseKey, isNot(contains('Android libraries')));
  });

  group('CA-013-01: compareLicenseNames', () {
    List<String> sorted(List<String> names) =>
        [...names]..sort(compareLicenseNames);

    test('orden alfabético sin distinguir mayúsculas', () {
      expect(sorted(['zeta', 'Beta', 'alpha', 'Archivo']), [
        'alpha',
        'Archivo',
        'Beta',
        'zeta',
      ]);
    });

    test('si empatan sin mayúsculas, decide la regla sensible a ellas '
        '(salida determinista)', () {
      expect(compareLicenseNames('a', 'A'), greaterThan(0));
      expect(compareLicenseNames('A', 'a'), lessThan(0));
      expect(sorted(['b', 'a', 'A', 'B']), ['A', 'a', 'B', 'b']);
    });

    test('un mismo nombre compara igual', () {
      expect(compareLicenseNames('pdfrx', 'pdfrx'), 0);
    });
  });
}
