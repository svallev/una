import 'package:app/data/in_memory_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fonts.dart';

/// El enlace "Ajustes" del menú no queda bajo la barra de navegación del
/// sistema (spec 015, CA-015-01a y CA-015-22; hallazgo del emulador, T-015-14:
/// con el texto al 200 % a 360 dp y la navegación de tres botones, la mitad de
/// "Settings" quedaba tapada).
void main() {
  setUpAll(loadAppFonts);

  for (final (name, size, scale) in [
    ('390 dp, texto normal', const Size(390, 844), 1.0),
    ('360 dp, texto al 200 %', const Size(360, 800), 2.0),
  ]) {
    testWidgets('CA-015-22: con la barra de tres botones (48), "Ajustes" queda '
        'por encima del margen inferior ($name)', (tester) async {
      const inset = 48.0;
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Primera', 'Segunda'],
        size: size,
        textScale: scale,
        bottomInset: inset,
      );
      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      final link = tester.getRect(find.text('Ajustes'));
      expect(
        link.bottom,
        lessThanOrEqualTo(size.height - inset),
        reason: 'el texto de "Ajustes" no puede quedar bajo la barra',
      );
    });
  }
}
