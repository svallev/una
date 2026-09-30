import 'package:app/app/providers.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/domain/ports/license_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements LicenseSource {
  _Source(this._results);
  final List<Future<List<LicensePackage>> Function()> _results;
  int calls = 0;

  @override
  Future<List<LicensePackage>> load() => _results[calls++]();
}

const _pkg = LicensePackage(
  name: 'pdfrx',
  texts: [
    LicenseText([(text: 'MIT', indent: 0)]),
  ],
);

ProviderContainer _container(LicenseSource source) {
  final c = ProviderContainer(
    overrides: [licenseSourceProvider.overrideWithValue(source)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('CA-012-16: crear el contenedor no lee las licencias', () {
    final source = _Source([
      () async => [_pkg],
    ]);
    _container(source);
    expect(source.calls, 0);
  });

  test('CA-012-03: licensesProvider entrega la lista de la fuente', () async {
    final source = _Source([
      () async => [_pkg],
    ]);
    final c = _container(source);
    final sub = c.listen(licensesProvider, (_, _) {});
    expect(await c.read(licensesProvider.future), [_pkg]);
    expect(source.calls, 1);
    sub.close();
  });

  test('CA-012-15: si la lectura falla, es un error (sin reintento solo)', () async {
    final source = _Source([
      () async => throw StateError('lectura'),
      () async => [_pkg],
    ]);
    final c = _container(source);
    final sub = c.listen(licensesProvider, (_, _) {});
    await expectLater(c.read(licensesProvider.future), throwsStateError);
    // Riverpod 3 reintenta solo por defecto; aquí "Reintentar" es del usuario.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(source.calls, 1);
    expect(c.read(licensesProvider).hasError, isTrue);
    sub.close();
  });

  test('CA-012-15: "Reintentar" (invalidate) vuelve a leer', () async {
    final source = _Source([
      () async => throw StateError('lectura'),
      () async => [_pkg],
    ]);
    final c = _container(source);
    final sub = c.listen(licensesProvider, (_, _) {});
    await expectLater(c.read(licensesProvider.future), throwsStateError);
    c.invalidate(licensesProvider);
    expect(await c.read(licensesProvider.future), [_pkg]);
    expect(source.calls, 2);
    sub.close();
  });

  test('spec §5, CL-012-6: una lista vacía se trata como error', () async {
    final source = _Source([() async => const []]);
    final c = _container(source);
    final sub = c.listen(licensesProvider, (_, _) {});
    await expectLater(
      c.read(licensesProvider.future),
      throwsA(isA<LicensesUnavailable>()),
    );
    sub.close();
  });

  test(
    'CA-012-16: sin oyentes se libera y se lee de nuevo al volver',
    () async {
      final source = _Source([
        () async => [_pkg],
        () async => [_pkg],
      ]);
      final c = _container(source);
      var sub = c.listen(licensesProvider, (_, _) {});
      await c.read(licensesProvider.future);
      sub.close();
      await Future<void>.delayed(Duration.zero);
      sub = c.listen(licensesProvider, (_, _) {});
      await c.read(licensesProvider.future);
      expect(source.calls, 2);
      sub.close();
    },
  );
}
