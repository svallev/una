import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';
import 'screen_fingerprint.dart';

/// Ayuda de la spec 021 (T-021-05, CA-021-06): la app se ve igual con el sistema en claro y en
/// oscuro. Dos formas de comprobarlo:
///
/// - [runSuiteInDarkMode]: vuelve a correr una suite de *goldens* existente con el brillo de la
///   plataforma en oscuro **contra los mismos PNG** de claro (si un píxel cambia, falla).
/// - [expectSameInLightAndDark]: para lo que no tiene *golden*, monta la pantalla dos veces
///   (claro y oscuro) y compara píxeles y lectura.

/// Corre [suite] (el `main` de una suite de *goldens*) con el sistema en oscuro.
///
/// Los PNG son los de claro: no hay PNG de oscuro. Por eso el comparador de esta suite **no
/// escribe nunca** (con `--update-goldens` solo compara): así un `--update-goldens` global no
/// puede sobrescribir los PNG de claro con capturas de oscuro.
///
/// Se llama dentro de un `group`. Registra, además, una comprobación de que el brillo en oscuro
/// llega de verdad a la app (si no, la suite pasaría sin comprobar nada).
void runSuiteInDarkMode(void Function() suite) {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late GoldenFileComparator original;

  setUpAll(() {
    original = goldenFileComparator;
    goldenFileComparator = CompareOnlyComparator(original);
  });
  tearDownAll(() => goldenFileComparator = original);
  setUp(() {
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  });
  tearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);

  testWidgets(
    'CA-021-06: el brillo en oscuro llega a la app (MediaQuery y plataforma)',
    (tester) async {
      Brightness? seen;
      await pumpWithApp(
        tester,
        Builder(
          builder: (context) {
            seen = MediaQuery.platformBrightnessOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(tester.platformDispatcher.platformBrightness, Brightness.dark);
      expect(seen, Brightness.dark);
    },
  );

  suite();
}

/// Comparador que delega en [_inner] y que, al pedirle escribir un PNG, solo lo compara.
class CompareOnlyComparator implements GoldenFileComparator {
  CompareOnlyComparator(this._inner);

  final GoldenFileComparator _inner;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) =>
      _inner.compare(imageBytes, golden);

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    if (!await _inner.compare(imageBytes, golden)) {
      throw TestFailure(
        'Con el sistema en oscuro la pantalla no coincide con el PNG de claro '
        '($golden): no se actualiza desde la suite de oscuro.',
      );
    }
  }

  @override
  Uri getTestUri(Uri key, int? version) => _inner.getTestUri(key, version);
}

/// Monta con [stage] la pantalla con el sistema en claro y otra vez en oscuro, y falla si los
/// píxeles o la lectura de la pantalla (árbol semántico) difieren.
///
/// [stage] debe crear **todo** de nuevo cada vez (repositorio, almacén…): completar y eliminar
/// descartan archivos, y un mundo compartido daría dos pantallas distintas por otra razón. Entre
/// las dos pasadas se desmonta la app y se deja pasar el tiempo de sus temporizadores.
Future<void> expectSameInLightAndDark(
  WidgetTester tester,
  Future<void> Function() stage, {
  String? reason,
}) async {
  final handle = tester.ensureSemantics();
  final shots = <Brightness, Fingerprint>{};
  for (final brightness in Brightness.values) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    await stage();
    expect(
      tester.platformDispatcher.platformBrightness,
      brightness,
      reason: 'el brillo simulado debe seguir puesto al comparar',
    );
    shots[brightness] = await fingerprintOf(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }
  tester.platformDispatcher.clearPlatformBrightnessTestValue();
  handle.dispose();
  expectSameFingerprint(
    shots[Brightness.light]!,
    shots[Brightness.dark]!,
    reason: reason ?? 'claro contra oscuro',
  );
}
