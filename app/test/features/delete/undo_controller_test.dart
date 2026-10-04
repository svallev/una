import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/features/complete/completion_controller.dart';
import 'package:app/features/delete/deletion_controller.dart';
import 'package:app/features/delete/undo_controller.dart';
import 'package:app/features/menu/menu_sheet.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/undo.dart';

final _created = DateTime.utc(2026, 10, 1, 8);

/// Error cuyo texto lleva el de la tarea, como uno de SQLite con la sentencia
/// (P5: no puede salir a ningún registro).
class _Leaky implements Exception {
  const _Leaky();

  @override
  String toString() => 'SqliteException: INSERT INTO tasks VALUES (secreto)';
}

/// Repositorio cuya escritura al recuperar puede fallar o esperar.
class _Repo extends InMemoryTaskRepository {
  int inserts = 0;
  Object? insertError;
  Completer<void>? insertGate;
  Completer<void>? removeGate;

  @override
  Future<void> insert(Task task) async {
    inserts++;
    final gate = insertGate;
    if (gate != null) await gate.future;
    final e = insertError;
    if (e != null) throw e;
    return super.insert(task);
  }

  @override
  Future<bool> remove(String id) async {
    final gate = removeGate;
    if (gate != null) await gate.future;
    return super.remove(id);
  }
}

/// Almacén cuyo borrado puede fallar.
class _Store extends MemoryAttachmentStore {
  Object? deleteError;

  @override
  Future<void> delete(String id) async {
    final e = deleteError;
    if (e != null) throw e;
    return super.delete(id);
  }
}

/// Contenedor con el controlador, sin pantallas: tres tareas con imagen
/// (`a`, `b`, `c`).
class _H {
  _H(this.tester, this.container, this.repo, this.store, this.timeouts);

  final WidgetTester tester;
  final ProviderContainer container;
  final _Repo repo;
  final _Store store;
  final FakeAccessibilityTimeouts timeouts;

  UndoController get undo => container.read(undoProvider.notifier);
  UndoState get state => container.read(undoProvider);
  AttachmentJanitor get janitor => container.read(attachmentJanitorProvider);

  /// Elimina [id] como lo hará el listado: la fila sale y sus archivos quedan
  /// retenidos.
  Future<Task> delete(String id) async =>
      (await container.read(deletePendingTaskProvider).call(id)).deleted;

  /// Elimina [id] y lo deja con la card a la vista (desde el listado).
  Future<Task> deleteAndShow(String id, {bool screenReader = false}) async {
    final task = await delete(id);
    expect(undo.hold(task, host: UndoHost.list, epoch: undo.epoch), isTrue);
    undo.cardShown(state.serial, screenReader: screenReader);
    return task;
  }

  Future<bool> hasFiles(String id) async =>
      (await store.storedIds()).contains('img-$id');
}

Future<_H> _harness(
  WidgetTester tester, {
  FakeAccessibilityTimeouts? timeouts,
}) async {
  final repo = _Repo();
  final store = _Store();
  final t = timeouts ?? FakeAccessibilityTimeouts();
  for (final (i, id) in ['a', 'b', 'c'].indexed) {
    final attachment = await store.commit(
      stageImage(store, 'img-$id'),
      _created,
    );
    await repo.insert(
      Task(
        id: id,
        text: 'Tarea $id',
        status: TaskStatus.pending,
        rank: 'M${String.fromCharCode(66 + i)}',
        colorKey: i,
        createdAt: _created,
        updatedAt: _created,
        attachment: attachment,
      ),
    );
  }
  repo.inserts = 0;
  // Dentro del árbol: al acabar el test se desmonta y se cancelan sus
  // temporizadores.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(repo),
        attachmentStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(TesterClock(tester)),
        accessibilityTimeoutsProvider.overrideWithValue(t),
      ],
      child: const SizedBox(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SizedBox)),
  );
  return _H(tester, container, repo, store, t);
}

const _ms = Duration(milliseconds: 1);

void main() {
  group('Duración (CA-014-06)', () {
    testWidgets('CA-014-06, CA-014-15: la card dura 4 s exactos: a 3,99 s '
        'sigue; a los 4 s la eliminación es definitiva y se borran sus '
        'archivos', (tester) async {
      final h = await _harness(tester);
      final task = await h.deleteAndShow('b');
      expect(h.state.phase, UndoPhase.visible);
      expect(h.state.task, task);
      expect(h.state.host, UndoHost.list);

      await tester.pump(const Duration(seconds: 1));
      expect(h.undo.fraction, closeTo(0.75, 1e-9));
      await tester.pump(const Duration(milliseconds: 2990));
      expect(h.state.phase, UndoPhase.visible);
      expect(h.janitor.held, {'img-b'});
      expect(await h.hasFiles('b'), isTrue);

      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
      expect(h.state.task, isNull, reason: 'suelta la tarea');
      expect(h.janitor.held, isEmpty);
      await tester.pump();
      expect(await h.hasFiles('b'), isFalse);
      expect(await h.repo.findById('b'), isNull);
    });

    testWidgets('CA-014-06: "cardShown" solo cuenta la primera vez: no '
        'reinicia el tiempo', (tester) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      await tester.pump(const Duration(seconds: 2));
      h.undo.cardShown(h.state.serial, screenReader: true);
      await tester.pump(const Duration(seconds: 2));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-06: con "Tiempo para actuar" de 10 s, dura 10 s', (
      tester,
    ) async {
      final h = await _harness(
        tester,
        timeouts: FakeAccessibilityTimeouts(recommendedMs: 10000),
      );
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 9990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-06: el tiempo del sistema llega con la cuenta en '
        'marcha y la alarga; uno menor no la acorta; se pide en cada '
        'eliminación', (tester) async {
      final timeouts = FakeAccessibilityTimeouts(
        recommendedMs: 10000,
        gate: Completer<void>(),
      );
      final h = await _harness(tester, timeouts: timeouts);
      await h.deleteAndShow('b');
      await tester.pump(const Duration(seconds: 1));
      timeouts.gate!.complete();
      await tester.pump();
      expect(h.undo.fraction, closeTo(0.9, 1e-9));
      await tester.pump(const Duration(milliseconds: 8990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
      expect(timeouts.reads, 1);

      timeouts
        ..gate = null
        ..recommendedMs = 2000;
      await h.deleteAndShow('c');
      expect(timeouts.reads, 2);
      await tester.pump(const Duration(milliseconds: 3990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-06: Android 8 y 9 con un servicio de accesibilidad, '
        '10 s; sin servicio, 4 s', (tester) async {
      final timeouts = FakeAccessibilityTimeouts(serviceEnabled: true);
      final h = await _harness(tester, timeouts: timeouts);
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 9990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);

      timeouts.serviceEnabled = false;
      await h.deleteAndShow('c');
      await tester.pump(const Duration(milliseconds: 3990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-06: sin canal (o si falla) 4 s, sin que el error '
        'salga', (tester) async {
      final h = await _harness(
        tester,
        timeouts: FakeAccessibilityTimeouts(error: const _Leaky()),
      );
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 3990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA-014-06, CA-014-21: la duración no cambia con "Quitar '
        'animaciones" del sistema', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 3990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
    });
  });

  group('Foco (CA-014-17)', () {
    testWidgets('CA-014-17: con el lector, el tiempo no empieza hasta el '
        'primer foco; se detiene mientras lo tiene y sigue al salir', (
      tester,
    ) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b', screenReader: true);
      final serial = h.state.serial;
      await tester.pump(const Duration(minutes: 1));
      expect(h.state.phase, UndoPhase.visible);
      expect(h.undo.fraction, 1);

      h.undo.focusChanged(serial, UndoFocus.reader, focused: true);
      await tester.pump(const Duration(minutes: 1));
      expect(h.state.phase, UndoPhase.visible);
      expect(h.undo.fraction, 1);

      h.undo.focusChanged(serial, UndoFocus.reader, focused: false);
      await tester.pump(const Duration(seconds: 1));
      h.undo.focusChanged(serial, UndoFocus.reader, focused: true);
      await tester.pump(const Duration(minutes: 1));
      expect(h.undo.fraction, closeTo(0.75, 1e-9));
      h.undo.focusChanged(serial, UndoFocus.reader, focused: false);
      await tester.pump(const Duration(milliseconds: 2990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-17: el foco del lector que llega antes de dibujarse '
        'la card también cuenta como primer foco', (tester) async {
      final h = await _harness(tester);
      final task = await h.delete('b');
      h.undo.hold(task, host: UndoHost.list, epoch: h.undo.epoch);
      final serial = h.state.serial;
      h.undo
        ..focusChanged(serial, UndoFocus.reader, focused: true)
        ..focusChanged(serial, UndoFocus.reader, focused: false)
        ..cardShown(serial, screenReader: true);
      await tester.pump(const Duration(seconds: 4));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-17: si el lector se apaga, el tiempo sigue (también '
        'si esperaba al primer foco o tenía el foco)', (tester) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b', screenReader: true);
      await tester.pump(const Duration(minutes: 1));
      h.undo.screenReaderChanged(enabled: true);
      await tester.pump(const Duration(minutes: 1));
      expect(h.state.phase, UndoPhase.visible);
      h.undo.screenReaderChanged(enabled: false);
      await tester.pump(const Duration(milliseconds: 3990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);

      await h.deleteAndShow('c', screenReader: true);
      h.undo.focusChanged(h.state.serial, UndoFocus.reader, focused: true);
      await tester.pump(const Duration(minutes: 1));
      expect(h.state.phase, UndoPhase.visible);
      // El aviso de pérdida de foco no llega: lo dice el apagado del lector.
      h.undo.screenReaderChanged(enabled: false);
      await tester.pump(const Duration(seconds: 4));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-17, CA-014-20: con teclado, el foco solo detiene el '
        'tiempo en modo tradicional; tocar la pantalla lo reanuda', (
      tester,
    ) async {
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      final serial = h.state.serial;
      await tester.pump(const Duration(seconds: 1));
      h.undo.focusChanged(serial, UndoFocus.keyboard, focused: true);
      await tester.pump(const Duration(minutes: 1));
      expect(h.state.phase, UndoPhase.visible);
      expect(h.undo.fraction, closeTo(0.75, 1e-9));

      // Toque en la pantalla: el foco sigue ahí, pero ya no se ve.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pump(const Duration(milliseconds: 2990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);

      // Con la pantalla táctil, el foco del teclado no para nada.
      await h.deleteAndShow('c');
      h.undo.focusChanged(h.state.serial, UndoFocus.keyboard, focused: true);
      await tester.pump(const Duration(seconds: 4));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-08, CA-014-17: cada eliminación empieza con el foco '
        'de cero; lo que llega tarde de la anterior no cuenta', (tester) async {
      final h = await _harness(tester);
      await h.deleteAndShow('a', screenReader: true);
      final first = h.state.serial;
      h.undo.focusChanged(first, UndoFocus.reader, focused: true);

      // Otra eliminación: la anterior es definitiva (CA-014-08).
      final b = await h.delete('b');
      h.undo.hold(b, host: UndoHost.list, epoch: h.undo.epoch);
      final second = h.state.serial;
      expect(second, isNot(first));
      expect(h.state.task, b);
      expect(h.janitor.held, {'img-b'});
      await tester.pump();
      expect(await h.hasFiles('a'), isFalse);

      h.undo
        ..focusChanged(first, UndoFocus.reader, focused: false)
        ..cardShown(first, screenReader: false)
        ..cardShown(second, screenReader: true);
      // No hereda el foco de la anterior: espera al primero de esta.
      await tester.pump(const Duration(minutes: 1));
      expect(h.state.phase, UndoPhase.visible);
      h.undo
        ..focusChanged(second, UndoFocus.reader, focused: true)
        ..focusChanged(second, UndoFocus.reader, focused: false);
      await tester.pump(const Duration(seconds: 4));
      expect(h.state.phase, UndoPhase.none);
    });
  });

  group('Estados (plan §4)', () {
    testWidgets('CA-014-01: desde la pantalla principal, la card espera al '
        'arrugado y su tiempo no corre hasta que se ve', (tester) async {
      final h = await _harness(tester);
      final task = await h.delete('a');
      expect(h.undo.hold(task, host: UndoHost.home, epoch: h.undo.epoch), true);
      expect(h.state.phase, UndoPhase.crumpling);
      h.undo.cardShown(h.state.serial, screenReader: false);
      await tester.pump(const Duration(seconds: 10));
      expect(h.state.phase, UndoPhase.crumpling);
      expect(await h.undo.undo(), isNull, reason: 'sin card no se deshace');

      h.undo.show();
      expect(h.state.phase, UndoPhase.visible);
      h.undo.cardShown(h.state.serial, screenReader: false);
      await tester.pump(const Duration(milliseconds: 3990));
      expect(h.state.phase, UndoPhase.visible);
      await tester.pump(const Duration(milliseconds: 10));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-11: lo que la hace definitiva durante el arrugado '
        'impide que aparezca la card', (tester) async {
      final h = await _harness(tester);
      final task = await h.delete('a');
      h.undo
        ..hold(task, host: UndoHost.home, epoch: h.undo.epoch)
        ..commit()
        ..show();
      expect(h.state.phase, UndoPhase.none);
      expect(h.janitor.held, isEmpty);
    });

    testWidgets('CA-014-10: al eliminar la última desde el listado, la card '
        'se ve ya sobre "Todo hecho." y recuerda a dónde volver', (
      tester,
    ) async {
      final h = await _harness(tester);
      final task = await h.delete('c');
      h.undo.hold(
        task,
        host: UndoHost.home,
        returnTo: UndoHost.list,
        epoch: h.undo.epoch,
      );
      expect(h.state.phase, UndoPhase.visible);
      expect(h.state.returnTo, UndoHost.list);
      await tester.pump(UnaMotion.doubleTapWindow);
      final outcome = await h.undo.undo();
      expect(outcome, isA<Restored>());
      final restored = outcome! as Restored;
      expect(restored.task, task);
      expect(restored.host, UndoHost.home);
      expect(restored.returnTo, UndoHost.list);
    });

    testWidgets('CA-014-11, CA-014-15: commit es síncrono e idempotente, '
        'suelta la tarea y borra sus archivos sin esperar al disco', (
      tester,
    ) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      h.undo.commit();
      // Sin `await`: ya no hay card ni tarea, y los archivos ya no están
      // protegidos del barrido.
      expect(h.state.phase, UndoPhase.none);
      expect(h.state.task, isNull);
      expect(h.janitor.held, isEmpty);
      expect(h.undo.fraction, 0);
      h.undo.commit();
      expect(h.state.phase, UndoPhase.none);
      await tester.pump();
      expect(await h.hasFiles('b'), isFalse);
      expect(await h.undo.undo(), isNull);
      expect(h.repo.inserts, 0);
      // El temporizador ya no hace nada.
      await tester.pump(const Duration(seconds: 5));
      expect(h.state.phase, UndoPhase.none);
    });

    testWidgets('CA-014-11, CL-014-15: si la app ha pasado a segundo plano '
        'mientras se guardaba, o está oculta, es definitiva sin card; '
        '"inactive" no cuenta', (tester) async {
      final h = await _harness(tester);
      final epoch = h.undo.epoch;
      final a = await h.delete('a');
      h.undo.appHidden();
      expect(h.undo.epoch, isNot(epoch));
      expect(h.undo.hold(a, host: UndoHost.home, epoch: epoch), isFalse);
      expect(h.state.phase, UndoPhase.none);
      expect(h.janitor.held, isEmpty);
      await tester.pump();
      expect(await h.hasFiles('a'), isFalse);

      addTearDown(() {
        for (final s in [
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(s);
        }
      });
      // La cortina o un diálogo del sistema: no cuenta (CA-014-12).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final b = await h.delete('b');
      expect(h.undo.hold(b, host: UndoHost.list, epoch: h.undo.epoch), isTrue);
      expect(h.state.phase, UndoPhase.visible);

      // Oculta ahora: la de B pasa a ser definitiva al llegar la de C.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      final c = await h.delete('c');
      expect(h.undo.hold(c, host: UndoHost.list, epoch: h.undo.epoch), isFalse);
      expect(h.state.phase, UndoPhase.none);
      expect(h.janitor.held, isEmpty);
    });

    testWidgets('CA-014-08: una eliminación nueva hace definitiva la '
        'anterior; solo se deshace la última', (tester) async {
      final h = await _harness(tester);
      final a = await h.deleteAndShow('a');
      final b = await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 400));
      expect(await h.hasFiles('a'), isFalse);
      final outcome = await h.undo.undo();
      expect((outcome! as Restored).task, b);
      expect(await h.repo.findById(a.id), isNull);
      expect(await h.repo.findById(b.id), b);
    });
  });

  group('Deshacer (CA-014-09, CA-014-23)', () {
    testWidgets('CL-014-3: nada en los primeros 350 ms; después, una sola '
        'recuperación aunque se pulse dos veces', (tester) async {
      final h = await _harness(tester);
      final task = await h.deleteAndShow('b');
      expect(await h.undo.undo(), isNull);
      await tester.pump(const Duration(milliseconds: 349));
      expect(await h.undo.undo(), isNull);
      expect(h.state.phase, UndoPhase.visible);
      expect(h.repo.inserts, 0);

      await tester.pump(_ms);
      final first = h.undo.undo();
      final second = h.undo.undo();
      expect(h.state.phase, UndoPhase.restoring);
      expect(await second, isNull);
      final outcome = await first;
      expect(outcome, isA<Restored>());
      final restored = outcome! as Restored;
      expect(restored.task, task);
      expect(restored.host, UndoHost.list);
      expect(restored.returnTo, isNull);
      expect(h.repo.inserts, 1);
      expect(h.state.phase, UndoPhase.none);
      expect(await h.repo.findById('b'), task);
      expect(h.janitor.held, isEmpty);

      // Sus archivos siguen: ni el tiempo ni el barrido los tocan.
      await tester.pump(const Duration(seconds: 5));
      await h.janitor.sweep();
      expect(await h.hasFiles('b'), isTrue);
    });

    testWidgets('CA-014-09: deshacer detiene el tiempo (una recuperación '
        'lenta no la hace definitiva)', (tester) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      h.repo.insertGate = Completer<void>();
      await tester.pump(const Duration(milliseconds: 3900));
      final pending = h.undo.undo();
      await tester.pump(const Duration(seconds: 2));
      expect(h.state.phase, UndoPhase.restoring);
      expect(h.janitor.held, {'img-b'});
      h.repo.insertGate!.complete();
      expect(await pending, isA<Restored>());
      await tester.pump();
      expect(await h.hasFiles('b'), isTrue);
    });

    testWidgets('CL-014-4: "Deshacer" justo al acabar el tiempo: si la card '
        'aún se ve, se recupera; si no, nada', (tester) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 3999));
      expect(await h.undo.undo(), isA<Restored>());

      await h.deleteAndShow('c');
      await tester.pump(const Duration(seconds: 4));
      expect(await h.undo.undo(), isNull);
      expect(h.repo.inserts, 1);
      expect(await h.repo.findById('c'), isNull);
    });

    testWidgets('CA-014-23: si falla, queda el aviso (sin tiempo) y '
        '"Reintentar" la recupera; falta de espacio con su mensaje', (
      tester,
    ) async {
      final h = await _harness(tester);
      final task = await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 400));
      h.repo.insertError = StateError('database or disk is full');
      final failed = await h.undo.undo();
      expect(failed, isA<UndoFailed>());
      expect((failed! as UndoFailed).noSpace, isTrue);
      expect(h.state.phase, UndoPhase.failed);
      expect(h.state.task, task);
      expect(h.janitor.held, {'img-b'});

      // El aviso no caduca.
      await tester.pump(const Duration(minutes: 1));
      expect(h.state.phase, UndoPhase.failed);
      h.repo.insertError = StateError('disk I/O error');
      expect(
        await h.undo.undo(),
        isA<UndoFailed>().having((f) => f.noSpace, 'noSpace', isFalse),
      );

      h.repo.insertError = null;
      expect(await h.undo.undo(), isA<Restored>());
      expect(h.state.phase, UndoPhase.none);
      expect(await h.repo.findById('b'), task);
      expect(h.janitor.held, isEmpty);
    });

    testWidgets('CA-014-23: si algo la hace definitiva mientras se recupera '
        'y la recuperación falla, es definitiva sin aviso', (tester) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 400));
      h.repo
        ..insertGate = Completer<void>()
        ..insertError = StateError('disk I/O error');
      final pending = h.undo.undo();
      h.undo.commit();
      expect(h.state.phase, UndoPhase.restoring, reason: 'solo se anota');
      h.repo.insertGate!.complete();
      expect(await pending, isNull);
      expect(h.state.phase, UndoPhase.none);
      expect(h.janitor.held, isEmpty);
      await tester.pump();
      expect(await h.hasFiles('b'), isFalse);
    });

    testWidgets('CA-014-23: si la recuperación sale bien, un commit anotado '
        'no borra nada', (tester) async {
      final h = await _harness(tester);
      final task = await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 400));
      h.repo.insertGate = Completer<void>();
      final pending = h.undo.undo();
      h.undo.commit();
      h.repo.insertGate!.complete();
      expect(await pending, isA<Restored>());
      expect(h.state.phase, UndoPhase.none);
      await tester.pump();
      expect(await h.hasFiles('b'), isTrue);
      expect(await h.repo.findById('b'), task);
    });

    testWidgets('CA-014-23: con el aviso de error, lo que la hace definitiva '
        '(o descartarlo) borra sus archivos y ya no se puede recuperar', (
      tester,
    ) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 400));
      h.repo.insertError = StateError('disk I/O error');
      expect(await h.undo.undo(), isA<UndoFailed>());
      h.undo.commit();
      expect(h.state.phase, UndoPhase.none);
      h.repo.insertError = null;
      expect(await h.undo.undo(), isNull);
      await tester.pump();
      expect(await h.hasFiles('b'), isFalse);
      expect(await h.repo.findById('b'), isNull);
    });

    testWidgets('CA-014-09: una eliminación que llega mientras se recupera '
        'la anterior no se pierde', (tester) async {
      final h = await _harness(tester);
      await h.deleteAndShow('a');
      await tester.pump(const Duration(milliseconds: 400));
      h.repo
        ..insertGate = Completer<void>()
        ..insertError = StateError('disk I/O error');
      final pending = h.undo.undo();
      final c = await h.delete('c');
      h.undo.hold(c, host: UndoHost.list, epoch: h.undo.epoch);
      h.repo.insertGate!.complete();
      expect(await pending, isNull, reason: 'la anterior ya no tiene aviso');
      expect(h.state.phase, UndoPhase.visible);
      expect(h.state.task, c);
      expect(h.janitor.held, {'img-c'});
      await tester.pump();
      expect(await h.hasFiles('a'), isFalse);
      expect(await h.hasFiles('c'), isTrue);
    });

    testWidgets('P5: un error con el texto de la tarea (al recuperar, al '
        'leer el tiempo del sistema o al borrar los archivos) no se escapa '
        'ni se registra', (tester) async {
      final printed = <String?>[];
      final debugPrintBefore = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message);

      final h = await _harness(
        tester,
        timeouts: FakeAccessibilityTimeouts(error: const _Leaky()),
      );
      h.store.deleteError = const _Leaky();
      await h.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 400));
      h.repo.insertError = const _Leaky();
      final failed = await h.undo.undo();
      expect(failed, isA<UndoFailed>());
      expect(failed.toString(), isNot(contains('secreto')));
      h.undo.commit();
      await h.deleteAndShow('c');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      debugPrint = debugPrintBefore;
      expect(tester.takeException(), isNull);
      expect(printed, isEmpty);
    });

    testWidgets('CA-014-13: al cerrar la app con una eliminación pendiente, '
        'es definitiva; durante una recuperación, no se borra nada', (
      tester,
    ) async {
      final h = await _harness(tester);
      await h.deleteAndShow('b');
      final janitor = h.janitor;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(janitor.held, isEmpty);
      expect(await h.hasFiles('b'), isFalse);

      final h2 = await _harness(tester);
      await h2.deleteAndShow('b');
      await tester.pump(const Duration(milliseconds: 400));
      h2.repo.insertGate = Completer<void>();
      final pending = h2.undo.undo();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(await h2.hasFiles('b'), isTrue);
      h2.repo.insertGate!.complete();
      expect(await pending, isNull);
      expect(await h2.repo.findById('b'), isNotNull);
      expect(await h2.hasFiles('b'), isTrue);
    });
  });

  group('Con la app (CA-014-07, CA-014-11, CA-014-12)', () {
    late ProviderContainer container;
    UndoController undo() => container.read(undoProvider.notifier);
    UndoPhase phase() => container.read(undoProvider).phase;
    NavigatorState navigator(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator).first);

    Future<_Repo> pump(WidgetTester tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: _Repo(),
        tasks: ['Primera', 'Segunda', 'Tercera', 'Cuarta', 'Quinta', 'Sexta'],
        clock: TesterClock(tester),
        overrides: [
          accessibilityTimeoutsProvider.overrideWithValue(
            FakeAccessibilityTimeouts(),
          ),
        ],
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(HomeRouter)),
      );
      return repo;
    }

    /// Retiene a mano la eliminación de [id] con la card "a la vista" (aún
    /// no hay card que dibujar: sin `cardShown`, el tiempo no corre).
    Future<void> holdByHand(WidgetTester tester, String id) async {
      final deleted = (await container.read(deletePendingTaskProvider).call(id))
          .deleted;
      undo()
        ..hold(deleted, host: UndoHost.home, epoch: undo().epoch)
        ..show();
      await tester.pump();
      expect(phase(), UndoPhase.visible);
    }

    PageRoute<void> page() => PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const ColoredBox(color: Colors.white),
    );

    testWidgets('CA-014-07: una hoja (el menú) no es otra pantalla; ir al '
        'listado desde él, sí; volver de él, también', (tester) async {
      await pump(tester);
      await holdByHand(tester, 't5');

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuSheet), findsOneWidget);
      expect(phase(), UndoPhase.visible);
      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MenuSheet), findsNothing);
      expect(phase(), UndoPhase.visible);

      await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas mis tareas'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsOneWidget);
      expect(phase(), UndoPhase.none);

      // Volver del listado (botón o gesto atrás, CL-014-17).
      await holdByHand(tester, 't4');
      await navigator(tester).maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(TaskListScreen), findsNothing);
      expect(phase(), UndoPhase.none);
    });

    testWidgets('CA-014-11: push y pop de cualquier PageRoute la hacen '
        'definitiva', (tester) async {
      await pump(tester);
      await holdByHand(tester, 't5');
      unawaited(navigator(tester).push(page()));
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.none);

      await holdByHand(tester, 't4');
      navigator(tester).pop();
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.none);
    });

    testWidgets('CA-014-10: la guarda de navegación vale para una sola ruta '
        'y una sola vez, y no queda puesta si falla la navegación', (
      tester,
    ) async {
      await pump(tester);
      final nav = navigator(tester);

      // Ir a su ruta no la hace definitiva (volver al listado al deshacer).
      await holdByHand(tester, 't5');
      final guarded = page();
      unawaited(undo().guardNavigation(guarded, () => nav.push(guarded)));
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.visible);

      // Una vez consumida, la misma ruta sí cuenta: volver de ella.
      nav.pop();
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.none);

      // Volver de su ruta tampoco (ir a "Todo hecho." desde el listado).
      final list = page();
      unawaited(nav.push(list));
      await tester.pumpAndSettle();
      await holdByHand(tester, 't1');
      undo().guardNavigation(list, nav.pop);
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.visible);
      undo().commit();

      // Otra ruta durante la navegación guardada sí cuenta, y la guarda no
      // se queda puesta.
      await holdByHand(tester, 't4');
      final other = page();
      final later = page();
      unawaited(undo().guardNavigation(later, () => nav.push(other)));
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.none);
      await holdByHand(tester, 't3');
      unawaited(nav.push(later));
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.none);

      // Si la navegación falla, la guarda tampoco se queda.
      await holdByHand(tester, 't2');
      final failing = page();
      expect(
        () => undo().guardNavigation<void>(
          failing,
          () => throw StateError('no navigator'),
        ),
        throwsStateError,
      );
      expect(phase(), UndoPhase.visible);
      unawaited(nav.push(failing));
      await tester.pumpAndSettle();
      expect(phase(), UndoPhase.none);
    });

    testWidgets('CA-014-11, CA-014-12: pasar a segundo plano (hidden) la '
        'hace definitiva; la cortina o un diálogo del sistema (inactive), '
        'no', (tester) async {
      await pump(tester);
      await holdByHand(tester, 't5');
      final epoch = undo().epoch;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(phase(), UndoPhase.visible);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(phase(), UndoPhase.visible);

      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      expect(phase(), UndoPhase.none);
      expect(undo().epoch, isNot(epoch));
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      // Al volver, sigue sin card (CL-014-15).
      expect(phase(), UndoPhase.none);
    });

    testWidgets('CA-014-11: completar la hace definitiva antes de cambiar la '
        'cola', (tester) async {
      final repo = await pump(tester);
      await holdByHand(tester, 't5');
      final current = container.read(currentTaskProvider)!;
      final completing = container
          .read(completionProvider.notifier)
          .complete(current);
      expect(phase(), UndoPhase.none);
      expect(await completing, isNotNull);
      await tester.pumpAndSettle();
      expect(await repo.findById(current.id), isNull);
    });

    testWidgets('CA-014-13: desmontar la app con una eliminación pendiente la '
        'hace definitiva y borra sus archivos', (tester) async {
      final store = _Store();
      final repo = _Repo();
      final attachment = await store.commit(
        stageImage(store, 'img-z'),
        _created,
      );
      await repo.insert(
        Task(
          id: 'z',
          text: 'Con imagen',
          status: TaskStatus.pending,
          rank: 'Z',
          colorKey: 3,
          createdAt: _created,
          updatedAt: _created,
          attachment: attachment,
        ),
      );
      await pumpUnaApp(
        tester,
        repo: repo,
        tasks: ['Primera'],
        clock: TesterClock(tester),
        overrides: [attachmentStoreProvider.overrideWithValue(store)],
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(HomeRouter)),
      );
      await holdByHand(tester, 'z');
      expect(await store.storedIds(), {'img-z'});
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(await store.storedIds(), isEmpty);
    });
  });

  group('Arrugado en segundo plano (CA-014-11)', () {
    testWidgets('CL-014-15: finishNow termina el arrugado ya; mientras aún se '
        'guarda, no hace nada', (tester) async {
      final repo = await pumpUnaApp(
        tester,
        repo: _Repo(),
        tasks: ['Primera', 'Segunda'],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeRouter)),
      );
      final deletion = container.read(deletionProvider.notifier);
      final focus = container.read(screenFocusProvider);
      repo.removeGate = Completer<void>();
      final pending = deletion.delete(container.read(currentTaskProvider)!);
      expect(container.read(deletionProvider).phase, DeletionPhase.deleting);
      deletion.finishNow();
      expect(container.read(deletionProvider).phase, DeletionPhase.deleting);

      repo.removeGate!.complete();
      expect(await pending, isNotNull);
      expect(container.read(deletionProvider).phase, DeletionPhase.crumpling);
      deletion.finishNow();
      expect(container.read(deletionProvider).phase, DeletionPhase.idle);
      expect(container.read(screenFocusProvider), focus + 1);
      await tester.pumpAndSettle();
    });
  });
}
