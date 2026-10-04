import 'dart:async';

import 'package:app/domain/ports/accessibility_timeouts.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reloj del test (spec 014): la hora falsa de `testWidgets`, que avanza con
/// `tester.pump(d)` a la vez que los temporizadores. Así la cuenta atrás de la
/// card (medida con [Clock]) y su temporizador nunca se separan: un
/// temporizador que vence a los 4 s ve el reloj a los 4 s.
class TesterClock implements Clock {
  TesterClock(this.tester);

  final WidgetTester tester;

  @override
  DateTime now() => tester.binding.clock.now().toUtc();
}

/// "Tiempo para actuar" del sistema simulado (sin canal). Con [gate], la
/// respuesta espera a que se complete; con [error], falla.
///
/// [touchExploration] es la exploración táctil (TalkBack) que lee el canal.
/// Sin darlo (null) vale lo mismo que `accessibleNavigation` de la plataforma
/// de pruebas, como en un móvil con TalkBack, donde ambos son `true`; con
/// Switch Access, `accessibleNavigation` es `true` y la exploración táctil
/// `false` (T-014-10b): ese caso se pide con `touchExploration: false`.
class FakeAccessibilityTimeouts implements AccessibilityTimeouts {
  FakeAccessibilityTimeouts({
    this.recommendedMs,
    this.serviceEnabled = false,
    this.touchExploration,
    this.gate,
    this.error,
  });

  int? recommendedMs;
  bool serviceEnabled;
  bool? touchExploration;
  Completer<void>? gate;
  Object? error;

  /// Veces que se ha consultado.
  int reads = 0;

  @override
  Future<SystemTimeouts> read() async {
    reads++;
    final g = gate;
    if (g != null) await g.future;
    final e = error;
    if (e != null) throw e;
    return (
      recommendedMs: recommendedMs,
      serviceEnabled: serviceEnabled,
      touchExploration:
          touchExploration ??
          TestWidgetsFlutterBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .accessibleNavigation,
    );
  }
}
