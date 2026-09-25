// Goldens de la spec 003. Como los de la 001, se generan y se comparan solo en
// Linux (CI): ver docs/testing.md, "Goldens".
@Tags(['golden'])
library;

import 'dart:io';

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

/// `GOLDENS_ANY_OS=1` permite generarlos en local para revisarlos (no se suben).
final _skip =
    !Platform.isLinux && Platform.environment['GOLDENS_ANY_OS'] != '1';

const _task = 'Llamar a Marta para confirmar la cena';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-003-01: relleno a mitad al mantener pulsado', (tester) async {
    await pumpWithApp(tester, CurrentTaskScreen(task: sampleTask(text: _task)));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToCompleteButton)),
    );
    await tester.pump();
    await tester.pump(UnaMotion.holdToComplete ~/ 2);
    await expectLater(
      find.byType(CurrentTaskScreen),
      matchesGoldenFile('goldens/complete_holding_es.png'),
    );
    await gesture.up();
    await tester.pump(UnaMotion.holdRelease);
    await tester.pump(UnaMotion.holdRelease);
  }, skip: _skip);

  for (final (name, at) in [
    ('tearing', const Duration(milliseconds: 700)),
    ('congrats', const Duration(milliseconds: 1600)),
  ]) {
    testWidgets('CA-003-03b: enhorabuena ($name)', (tester) async {
      await pumpWithApp(
        tester,
        CelebrationOverlay(
          face: CurrentTaskScreen(
            task: sampleTask(text: _task),
            faceOnly: true,
          ),
          colorKey: 1,
          hasNext: true,
          onFadeStart: () {},
          onFinished: () {},
        ),
      );
      await tester.pump();
      await tester.pump(at);
      await expectLater(
        find.byType(CelebrationOverlay),
        matchesGoldenFile('goldens/celebration_${name}_es.png'),
      );
      await tester.pump(UnaMotion.successHold + UnaMotion.successFade);
    }, skip: _skip);
  }

  testWidgets('CA-003-05: "Todo hecho."', (tester) async {
    await pumpWithApp(tester, AllDoneScreen(onCreate: () {}));
    await tester.pump();
    await tester.pump(UnaMotion.enter);
    await expectLater(
      find.byType(AllDoneScreen),
      matchesGoldenFile('goldens/all_done_es.png'),
    );
  }, skip: _skip);
}
