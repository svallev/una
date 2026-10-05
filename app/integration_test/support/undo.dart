// Ayudas de los `integration_test` de la spec 014: eliminar deja una card de
// deshacer (4 s) y su barra repinta siempre, así que `pumpAndSettle` no se
// asienta: se avanza el tiempo a mano. En el dispositivo el reloj es el real.
import 'package:app/features/delete/undo_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// El botón "Deshacer" de la card.
final undoButtonFinder = find.byKey(UndoCard.buttonKey);

/// Deja pasar [time] a fotogramas de 100 ms.
Future<void> pumpFor(WidgetTester tester, Duration time) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Avanza hasta que [done] sea cierto (o falla pasado [timeout]).
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 15),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      fail('Tiempo agotado esperando: ${reason ?? 'condición'}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Termina el arrugado: la card ya se ve.
Future<void> pumpUntilCard(WidgetTester tester) => pumpUntil(
  tester,
  () => find.byType(UndoCard).evaluate().isNotEmpty,
  reason: 'la card de deshacer',
);

/// Pasa el tiempo del deshacer: la card desaparece y la eliminación es
/// definitiva (CA-014-15).
Future<void> pumpUntilCardGone(WidgetTester tester) => pumpUntil(
  tester,
  () => find.byType(UndoCard).evaluate().isEmpty,
  timeout: const Duration(seconds: 20),
  reason: 'que la card caduque',
);
