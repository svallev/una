import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

/// Monta la app con [tasks] (la primera, la actual) y abre el listado desde
/// el menú (CA-006-01).
Future<InMemoryTaskRepository> openList(
  WidgetTester tester, {
  required List<String> tasks,
  InMemoryTaskRepository? repo,
  bool screenReader = false,
  bool reduced = false,
  Clock? clock,
}) async {
  final r = await pumpUnaApp(
    tester,
    repo: repo ?? InMemoryTaskRepository(),
    tasks: tasks,
    screenReader: screenReader,
    reduced: reduced,
    clock: clock,
  );
  await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Todas mis tareas'));
  await tester.pumpAndSettle();
  expect(find.byType(TaskListScreen), findsOneWidget);
  return r;
}

/// La fila (visible) cuyo texto es [text].
Finder rowOf(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byType(TaskListRow),
);

/// Asa de la fila [text].
Finder handleOf(String text) => find.descendant(
  of: rowOf(text).first,
  matching: find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_GripPainter',
  ),
);

Future<List<String>> order(InMemoryTaskRepository repo) async => [
  for (final Task t in await repo.pendingTasks()) t.text ?? '',
];

/// Textos de las filas en el orden en que se ven.
List<String> shownOrder(WidgetTester tester) {
  // Sin la fila levantada ni su hueco invisible.
  final hidden = find.ancestor(
    of: find.byType(TaskListRow),
    matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
  );
  final hiddenRows = find.descendant(
    of: hidden,
    matching: find.byType(TaskListRow),
  ).evaluate().map((e) => e.widget).toSet();
  final withPos = [
    for (final e in find.byType(TaskListRow).evaluate())
      if (!(e.widget as TaskListRow).lifted && !hiddenRows.contains(e.widget))
        (
          tester.getTopLeft(find.byWidget(e.widget)).dy,
          (e.widget as TaskListRow).task.text ?? '',
        ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, text) in withPos) text];
}

List<String> listenAnnouncements(WidgetTester tester) {
  final announcements = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final map = message! as Map<Object?, Object?>;
      if (map['type'] == 'announce') {
        final data = map['data']! as Map<Object?, Object?>;
        announcements.add(data['message']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announcements;
}

/// Tiempo de un fotograma.
const frame = Duration(milliseconds: 16);

class FakeClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 26, 9);
  @override
  DateTime now() => value;
}

/// Pasa a segundo plano durante [d] y vuelve (CA-001-12).
void background(WidgetTester tester, FakeClock clock, Duration d) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  clock.value = clock.value.add(d);
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}
