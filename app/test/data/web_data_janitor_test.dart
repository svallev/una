import 'dart:async';
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/data/web/web_data_janitor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Limpiador falso: cuenta las llamadas y puede fallar o quedarse esperando.
class _FakeCleaner implements WebDataCleaner {
  final calls = <int?>[];
  bool result = true;
  Object? error;
  Completer<void>? gate;

  @override
  Future<bool> clearWebData({int? webViewId}) async {
    calls.add(webViewId);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return result;
  }
}

/// Janitor que solo anota cuándo se llama la limpieza del arranque.
class _RecordingJanitor extends WebDataJanitor {
  _RecordingJanitor() : super.inactive();
  int launches = 0;

  @override
  Future<void> clearAfterLaunch() async => launches++;
}

void main() {
  late Directory files;
  late _FakeCleaner cleaner;
  late WebDataJanitor janitor;

  File marker() => File('${files.path}/${WebDataJanitor.markerName}');

  setUp(() {
    files = Directory.systemTemp.createTempSync('una_web_janitor');
    cleaner = _FakeCleaner();
    janitor = WebDataJanitor(filesDir: () async => files, cleaner: cleaner);
  });

  tearDown(() => files.deleteSync(recursive: true));

  group('CA-009-13: la marca files/web_used', () {
    test(
      'CA-009-13: usar la web escribe la marca, vacía, una sola vez',
      () async {
        await janitor.markUsed();
        expect(marker().existsSync(), isTrue);
        expect(marker().lengthSync(), 0);
        await janitor.markUsed();
        expect(marker().existsSync(), isTrue);
        expect(cleaner.calls, isEmpty);
      },
    );

    test('CA-009-13: sin la marca, el arranque no borra nada (no cuesta nada '
        'a quien no usa la web)', () async {
      await janitor.clearAfterLaunch();
      expect(cleaner.calls, isEmpty);
      expect(marker().existsSync(), isFalse);
    });

    test(
      'CA-009-13: con la marca, el arranque borra todo y la quita',
      () async {
        await janitor.markUsed();
        await janitor.clearAfterLaunch();
        expect(cleaner.calls, [null]);
        expect(marker().existsSync(), isFalse);
        // En el siguiente arranque ya no hay nada que borrar.
        await janitor.clearAfterLaunch();
        expect(cleaner.calls, [null]);
      },
    );

    test('CA-009-13: si el borrado del arranque falla, la marca se queda para '
        'el siguiente', () async {
      await janitor.markUsed();
      cleaner.result = false;
      await janitor.clearAfterLaunch();
      expect(marker().existsSync(), isTrue);
      cleaner
        ..result = true
        ..error = StateError('sin WebView');
      await janitor.clearAfterLaunch(); // no lanza
      expect(marker().existsSync(), isTrue);
      cleaner.error = null;
      await janitor.clearAfterLaunch();
      expect(marker().existsSync(), isFalse);
      expect(cleaner.calls, hasLength(3));
    });

    test('CA-009-13: la web no empieza a usarse hasta que acaba la limpieza '
        'del arranque (la marca no se pierde)', () async {
      await janitor.markUsed();
      cleaner.gate = Completer<void>();
      final launch = janitor.clearAfterLaunch();
      var marked = false;
      final use = janitor.markUsed().then((_) => marked = true);
      await pumpEventQueue();
      expect(marked, isFalse, reason: 'espera a la limpieza del arranque');
      cleaner.gate!.complete();
      await Future.wait([launch, use]);
      expect(marked, isTrue);
      expect(marker().existsSync(), isTrue);
    });

    test('CA-009-13: sin carpeta de la app (tests, web), nada lanza', () async {
      final broken = WebDataJanitor(
        filesDir: () async => throw StateError('sin path_provider'),
        cleaner: cleaner,
      );
      await broken.markUsed();
      await broken.clearAfterLaunch();
      expect(await broken.clearOnLeave(), isTrue);
    });
  });

  group('CA-009-13: al salir de la tarea', () {
    test('CA-009-13: borra cookies, almacenamiento y caché con la WebView '
        'que se ve; la marca se queda', () async {
      await janitor.markUsed();
      expect(await janitor.clearOnLeave(webViewId: 7), isTrue);
      expect(cleaner.calls, [7]);
      expect(marker().existsSync(), isTrue);
    });

    test('CA-009-13: si el borrado falla, no lanza y lo dice', () async {
      cleaner.error = StateError('sin WebView');
      expect(await janitor.clearOnLeave(), isFalse);
      cleaner
        ..error = null
        ..result = false;
      expect(await janitor.clearOnLeave(), isFalse);
    });

    test('CA-009-13: los borrados van de uno en uno, en orden', () async {
      cleaner.gate = Completer<void>();
      final first = janitor.clearOnLeave(webViewId: 1);
      final second = janitor.clearOnLeave(webViewId: 2);
      await pumpEventQueue();
      expect(cleaner.calls, [1]);
      cleaner.gate!.complete();
      await Future.wait([first, second]);
      expect(cleaner.calls, [1, 2]);
    });

    test('CA-009-13: inactivo (web de pruebas) no hace nada', () async {
      final none = WebDataJanitor.inactive();
      await none.markUsed();
      await none.clearAfterLaunch();
      expect(await none.clearOnLeave(), isTrue);
    });
  });

  testWidgets('CA-009-13: el arranque borra después del primer fotograma', (
    tester,
  ) async {
    final recording = _RecordingJanitor();
    await pumpUnaApp(
      tester,
      repo: InMemoryTaskRepository(),
      tasks: ['Comprar pan'],
      overrides: [webDataJanitorProvider.overrideWithValue(recording)],
    );
    expect(recording.launches, 1);
    expect(find.text('Comprar pan'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(recording.launches, 1);
  });
}
