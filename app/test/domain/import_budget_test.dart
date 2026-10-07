import 'dart:async';
import 'dart:io';

import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/import/unavailable_image_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/ports/id_generator.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:app/domain/services/attachment_janitor.dart';
import 'package:app/domain/services/import_budget.dart';
import 'package:app/domain/usecases/import_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/attachments.dart';
import '../support/fake_image_importer.dart';
import '../support/undo.dart';

/// Reloj a mano: solo avanza cuando el test lo dice.
class _ManualClock implements Clock {
  var _now = DateTime.utc(2026, 10, 6, 12);

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// Temporizador periódico a mano (el "Ticker" inyectable del presupuesto):
/// el test decide cuándo late y cuánto avanza el reloj entre dos latidos.
class _ManualTicker {
  _ManualTicker(this.clock);

  final _ManualClock clock;
  Duration? period;
  _ManualTimer? timer;

  Timer start(Duration period, void Function(Timer) callback) {
    this.period = period;
    return timer = _ManualTimer(callback);
  }

  /// Un latido tras [gap] de reloj (por defecto, el periodo).
  void beat([Duration? gap]) {
    clock.advance(gap ?? period!);
    timer!.fire();
  }

  void beats(int n) {
    for (var i = 0; i < n; i++) {
      beat();
    }
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function(Timer) _callback;
  var _active = true;
  var _ticks = 0;

  void fire() {
    if (!_active) return;
    _ticks++;
    _callback(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _ticks;
}

class _SeqIds implements IdGenerator {
  var _n = 0;
  @override
  String newId() => 'img-${_n++}';
}

void main() {
  late _ManualClock clock;
  late _ManualTicker ticker;
  late ImportBudget budget;

  setUp(() {
    clock = _ManualClock();
    ticker = _ManualTicker(clock);
    budget = ImportBudget(clock: clock, periodic: ticker.start);
  });

  /// Arranca una foto que no acaba nunca y devuelve cómo expiró.
  Future<BudgetExpiry?> runForever() {
    final c = Completer<void>();
    return budget.runPhoto<BudgetExpiry?>(
      () => c.future.then((_) => null),
      onExpired: (e) => e,
    );
  }

  group('ImportBudget (CA-016-04)', () {
    test('CA-016-04: late cada segundo y los límites son 20 s y 2 min', () {
      expect(ImportBudget.heartbeat, const Duration(seconds: 1));
      expect(budget.photoLimit, const Duration(seconds: 20));
      expect(budget.totalLimit, const Duration(minutes: 2));
    });

    test('CA-016-04: 20 s por foto, ni uno menos ni uno más', () async {
      BudgetExpiry? expired;
      var done = false;
      final c = Completer<void>();
      unawaited(
        budget
            .runPhoto<BudgetExpiry?>(
              () => c.future.then((_) => null),
              onExpired: (e) => e,
            )
            .then((e) {
              expired = e;
              done = true;
            }),
      );
      expect(ticker.period, ImportBudget.heartbeat);
      ticker.beats(19);
      await pumpEventQueue();
      expect(done, isFalse);
      expect(budget.photoElapsed, const Duration(seconds: 19));

      ticker.beat();
      await pumpEventQueue();
      expect(done, isTrue);
      expect(expired, BudgetExpiry.photo);
      expect(ticker.timer!.isActive, isFalse, reason: 'sin latido pendiente');
    });

    test('CA-016-04: el total suma el tiempo activo de todas las fotos y '
        'vence con la que lo agota', () async {
      Future<BudgetExpiry?> photo() {
        final c = Completer<void>();
        return budget.runPhoto<BudgetExpiry?>(
          () => c.future.then((_) => null),
          onExpired: (e) => e,
        );
      }

      // 6 fotos de 19 s: cada una acaba (por su trabajo) tras 19 latidos.
      for (var i = 0; i < 6; i++) {
        final done = Completer<String>();
        final f = budget.runPhoto<String>(
          () => done.future,
          onExpired: (e) => 'expired-${e.name}',
        );
        ticker.beats(19);
        done.complete('ok');
        expect(await f, 'ok', reason: 'foto ${i + 1}');
      }
      expect(budget.totalElapsed, const Duration(seconds: 114));
      expect(budget.totalExpired, isFalse);

      final seventh = photo();
      ticker.beats(5);
      await pumpEventQueue();
      expect(budget.photoElapsed, const Duration(seconds: 5));
      ticker.beat();
      expect(await seventh, BudgetExpiry.total);
      expect(budget.totalExpired, isTrue);
    });

    test('CA-016-04: con el total ya agotado no se empieza la foto', () async {
      final short = ImportBudget(
        clock: clock,
        periodic: ticker.start,
        photoLimit: const Duration(seconds: 20),
        totalLimit: const Duration(seconds: 3),
      );
      final forever = Completer<void>();
      final one = short.runPhoto<String>(
        () => forever.future.then((_) => 'ok'),
        onExpired: (e) => e.name,
      );
      ticker.beats(3);
      expect(await one, 'total');

      var started = false;
      final two = short.runPhoto<String>(() async {
        started = true;
        return 'ok';
      }, onExpired: (e) => 'again-${e.name}');
      expect(await two, 'again-total');
      expect(started, isFalse, reason: 'no empieza nada tras vencer el total');
    });

    test('CA-016-04: un hueco > 3 s (proceso congelado) reinicia la foto '
        'en curso y solo gasta 2 s del total', () async {
      final f = runForever();
      ticker.beats(10);
      expect(budget.photoElapsed, const Duration(seconds: 10));
      expect(budget.totalElapsed, const Duration(seconds: 10));

      // El proceso estuvo congelado 5 min.
      ticker.beat(const Duration(minutes: 5));
      expect(budget.photoElapsed, Duration.zero, reason: 'foto reiniciada');
      expect(
        budget.totalElapsed,
        const Duration(seconds: 12),
        reason: 'min(hueco, 2 s) al total',
      );

      // La foto vuelve a tener sus 20 s enteros.
      ticker.beats(19);
      await pumpEventQueue();
      expect(budget.photoElapsed, const Duration(seconds: 19));
      ticker.beat();
      expect(await f, BudgetExpiry.photo);
    });

    test('CA-016-04: un hueco de hasta 3 s no reinicia y suma lo que dura '
        '(máximo 2 s)', () {
      unawaited(runForever());
      ticker.beat(const Duration(milliseconds: 1500));
      expect(budget.photoElapsed, const Duration(milliseconds: 1500));
      ticker.beat(const Duration(milliseconds: 2800));
      expect(
        budget.photoElapsed,
        const Duration(milliseconds: 1500 + 2000),
        reason: 'suma min(hueco, 2 s) y no reinicia con 3 s o menos',
      );
      ticker.beat(const Duration(seconds: 3));
      expect(budget.photoElapsed, const Duration(milliseconds: 1500 + 4000));
    });

    test('CA-016-04: un reloj que no avanza (o va hacia atrás) cuenta el '
        'periodo del latido', () {
      unawaited(runForever());
      ticker.beat(Duration.zero);
      ticker.beat(const Duration(seconds: -30));
      expect(budget.photoElapsed, const Duration(seconds: 2));
    });

    test('CA-016-04: si el trabajo acaba antes, devuelve su resultado y '
        'para el latido', () async {
      final c = Completer<int>();
      final f = budget.runPhoto<int>(() => c.future, onExpired: (_) => -1);
      ticker.beats(3);
      c.complete(7);
      expect(await f, 7);
      expect(ticker.timer!.isActive, isFalse);
      // Un latido tardío no hace nada ni lanza.
      ticker.timer!.fire();
      expect(budget.totalElapsed, const Duration(seconds: 3));
    });

    test('CA-016-04: un error del trabajo sale tal cual y para el latido', () {
      final f = budget.runPhoto<int>(
        () async => throw StateError('boom'),
        onExpired: (_) => -1,
      );
      expect(f, throwsStateError);
      return f.then((_) {}, onError: (_) {}).whenComplete(() {
        expect(ticker.timer!.isActive, isFalse);
      });
    });

    test('CA-016-04: lo que acaba el trabajo después de vencer se ignora '
        '(sin error sin capturar)', () async {
      final c = Completer<int>();
      final f = budget.runPhoto<int>(() => c.future, onExpired: (_) => -1);
      ticker.beats(20);
      expect(await f, -1);
      c.completeError(StateError('tarde'));
      await pumpEventQueue();
    });

    test('CA-016-04: lo que lanza onExpired llega a quien espera', () async {
      final c = Completer<int>();
      final f = budget.runPhoto<int>(
        () => c.future,
        onExpired: (_) =>
            throw const ImageImportFailure(ImageImportError.unreadable),
      );
      ticker.beats(20);
      await expectLater(f, throwsA(isA<ImageImportFailure>()));
    });

    test('CA-016-04: nunca dos fotos a la vez', () async {
      unawaited(runForever());
      expect(
        () => budget.runPhoto<int>(() async => 1, onExpired: (_) => 0),
        throwsStateError,
      );
    });

    testWidgets('CA-016-04: con el temporizador real (Timer.periodic) y el '
        'reloj del test, vence a los 20 s', (tester) async {
      final real = ImportBudget(clock: TesterClock(tester));
      final c = Completer<int>();
      var expired = false;
      unawaited(
        real
            .runPhoto<int>(() => c.future, onExpired: (_) => -1)
            .then((_) => expired = true),
      );
      await tester.pump(const Duration(seconds: 19));
      expect(expired, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(expired, isTrue);
    });

    testWidgets('CA-016-04: aunque el reloj no avance (SystemClock en un '
        'test con tiempo falso), el latido cuenta su periodo', (tester) async {
      final real = ImportBudget();
      final c = Completer<int>();
      var expired = false;
      unawaited(
        real
            .runPhoto<int>(() => c.future, onExpired: (_) => -1)
            .then((_) => expired = true),
      );
      await tester.pump(const Duration(seconds: 19));
      expect(expired, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(expired, isTrue);
    });
  });

  group('ImportJob.prepare con el presupuesto (CA-016-04, CA-007-14)', () {
    late MemoryAttachmentStore store;
    late FakeImageImporter importer;
    late ImportRegistry registry;
    late ImportImage importImage;

    setUp(() {
      store = MemoryAttachmentStore();
      importer = FakeImageImporter(store);
      registry = ImportRegistry();
      importImage = ImportImage(
        importer: importer,
        janitor: janitorFor(InMemoryTaskRepository(), store, registry),
        ids: _SeqIds(),
      );
    });

    testWidgets('CA-007-14: una sola foto, a los 20 s se aborta y no queda '
        'nada (el mismo presupuesto que el grupo)', (tester) async {
      importer.sanitizeDelay = const Duration(seconds: 60);
      final job = (await importImage.pick(AttachmentOrigin.gallery))!;
      Object? error;
      final done = job.prepare().then<void>(
        (_) {},
        onError: (Object e) {
          error = e;
        },
      );
      await tester.pump(const Duration(seconds: 19));
      expect(error, isNull);
      expect(importer.cancelled, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      await done;
      expect(error, isA<ImageImportFailure>());
      expect((error! as ImageImportFailure).error, ImageImportError.unreadable);
      expect(importer.cancelled, ['img-0']);
      expect(await store.stagingIds(), isEmpty);
      expect(registry.active, isEmpty);
      await tester.pump(const Duration(seconds: 60));
    });

    test(
      'CA-016-04: prepare usa el presupuesto que recibe (el del grupo)',
      () async {
        importer.sanitizeDelay = const Duration(seconds: 60);
        final job = (await importImage.pick(AttachmentOrigin.gallery))!;
        Object? error;
        final done = job
            .prepare(budget: budget)
            .then<void>((_) {}, onError: (Object e) => error = e);
        ticker.beats(19);
        await pumpEventQueue();
        expect(error, isNull);
        ticker.beat();
        await done;
        expect(error, isA<ImageImportFailure>());
        expect(budget.photoElapsed, const Duration(seconds: 20));
        expect(await store.stagingIds(), isEmpty);
      },
    );

    test(
      'CA-016-04: con el total agotado, prepare falla sin copiar nada',
      () async {
        final spent = ImportBudget(
          clock: clock,
          periodic: ticker.start,
          totalLimit: const Duration(seconds: 1),
        );
        final first = Completer<void>();
        unawaited(spent.runPhoto<void>(() => first.future, onExpired: (_) {}));
        ticker.beat();
        final job = (await importImage.pick(AttachmentOrigin.gallery))!;
        await expectLater(
          job.prepare(budget: spent),
          throwsA(isA<ImageImportFailure>()),
        );
        expect(importer.limits, isEmpty, reason: 'no llegó a copiar');
        expect(await store.stagingIds(), isEmpty);
      },
    );
  });

  group('Errores sin texto de excepción (CL-016-16)', () {
    test('CL-016-16: un fallo con ruta y nombre no sale en ningún registro ni '
        'en el error', () async {
      final store = MemoryAttachmentStore();
      final importer = FakeImageImporter(store);
      final registry = ImportRegistry();
      final importImage = ImportImage(
        importer: importer,
        janitor: janitorFor(InMemoryTaskRepository(), store, registry),
        ids: _SeqIds(),
      );

      const secret = '/sdcard/DCIM/Vacaciones-secretas-2026.jpg';
      final printed = <String>[];
      final flutterErrors = <FlutterErrorDetails>[];
      final oldDebugPrint = debugPrint;
      final oldOnError = FlutterError.onError;
      debugPrint = (String? m, {int? wrapWidth}) => printed.add('$m');
      FlutterError.onError = flutterErrors.add;

      Object? caught;
      StackTrace? trace;
      try {
        await runZoned(
          () async {
            for (final fail in <void Function()>[
              () => importer.copyError = const FileSystemException(
                'no se pudo leer',
                secret,
              ),
              () => importer
                ..copyError = null
                ..sanitizeError = StateError('decode failed for $secret'),
            ]) {
              fail();
              final job = (await importImage.pick(AttachmentOrigin.gallery))!;
              try {
                await job.prepare();
              } on Object catch (e, s) {
                caught = e;
                trace = s;
              }
              expect(caught, isA<ImageImportFailure>());
              expect(
                (caught! as ImageImportFailure).error,
                ImageImportError.unreadable,
              );
              expect('$caught', isNot(contains('secretas')));
              expect('$caught', 'ImageImportFailure(unreadable)');
              expect(await store.stagingIds(), isEmpty);
            }
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => printed.add(line),
          ),
        );
      } finally {
        debugPrint = oldDebugPrint;
        FlutterError.onError = oldOnError;
      }
      expect(trace, isNotNull);
      expect(printed.join('\n'), isNot(contains('secretas')));
      expect(
        flutterErrors.map((e) => e.toString()).join('\n'),
        isNot(contains('secretas')),
      );
      expect(registry.active, isEmpty);
    });

    test('CL-016-16: cancelar y vencer siguen siendo ImageImportFailure o '
        'ImageImportCancelled, sin causa', () async {
      final store = MemoryAttachmentStore();
      final importer = FakeImageImporter(store)
        ..copyError = const ImageImportCancelled();
      final importImage = ImportImage(
        importer: importer,
        janitor: janitorFor(InMemoryTaskRepository(), store),
        ids: _SeqIds(),
      );
      final job = (await importImage.pick(AttachmentOrigin.gallery))!;
      await expectLater(job.prepare(), throwsA(isA<ImageImportCancelled>()));
    });
  });

  group('Puertos pickMany y freeSpace (CL-016-15, CA-016-24)', () {
    test(
      'CA-016-24: el falso devuelve como mucho `max` y dice el total',
      () async {
        final importer = FakeImageImporter(MemoryAttachmentStore())
          ..manyTotal = 5000;
        final picked = (await importer.pickMany(max: ImageLimits.maxGroup))!;
        expect(picked.items, hasLength(10));
        expect(picked.total, 5000);
        expect(picked.items.map((i) => i.origin).toSet(), {
          AttachmentOrigin.gallery,
        });
        expect(
          picked.items.map((i) => i.token).toSet(),
          hasLength(10),
          reason: 'un testigo distinto por foto',
        );
        expect(importer.pickManyMax, [10]);
      },
    );

    test(
      'CL-016-15: cancelar el selector es null; un error sale tal cual',
      () async {
        final importer = FakeImageImporter(MemoryAttachmentStore())
          ..userCancelsPicker = true;
        expect(await importer.pickMany(max: 10), isNull);
        importer
          ..userCancelsPicker = false
          ..pickError = const ImageImportFailure(ImageImportError.unreadable);
        await expectLater(
          importer.pickMany(max: 10),
          throwsA(isA<ImageImportFailure>()),
        );
      },
    );

    test('CL-016-6: el espacio libre del falso es configurable y puede ser '
        'desconocido', () async {
      final importer = FakeImageImporter(MemoryAttachmentStore());
      expect(await importer.freeSpace(), isNull);
      importer.freeSpaceBytes = 123;
      expect(await importer.freeSpace(), 123);
    });

    test('CA-016-24: sin plataforma, elegir varias es como cancelar y el '
        'espacio es desconocido', () async {
      const importer = UnavailableImageImporter();
      expect(await importer.pickMany(max: 10), isNull);
      expect(await importer.freeSpace(), isNull);
    });
  });
}
