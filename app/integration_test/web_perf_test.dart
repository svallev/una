// Rendimiento de la tarea con página web (spec 009, T-009-18; CA-009-07).
// Deja en la app de pruebas (`.profile`) la tarea con texto y, encima, la
// tarea web (actual). En el móvil del propietario, siempre con
// --keep-app-running y con el binario ya compilado, para que flutter no
// deduzca otro paquete (docs/perf/baseline.md):
//
//   flutter build apk --profile --target=integration_test/web_perf_test.dart
//   flutter drive --profile --no-dds --keep-app-running \
//     --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/web_perf_test.dart -d <serial>
//
// Con `--dart-define=WEB_PERF_URL=https://…` se cambia la dirección. Después,
// la app normal `.profile` arranca con la tarea web para medir el arranque en
// frío y `dumpsys meminfo`.
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/features/web/task_web.dart';
import 'package:app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _url = String.fromEnvironment(
  'WEB_PERF_URL',
  defaultValue: 'https://example.org/',
);
const _text = 'Horario del congreso';

/// Solo en las apps de pruebas (`.debug`, `.profile`).
Future<void> _wipe() async {
  final docs = await getApplicationDocumentsDirectory();
  if (!docs.path.contains('.debug') && !docs.path.contains('.profile')) {
    throw StateError('Pruebas fuera de la app de pruebas: ${docs.path}');
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${docs.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
}

/// Memoria del proceso en MB (PSS y RSS de `/proc/self/smaps_rollup`). No
/// cuenta la WebView (proceso aparte) ni la GPU.
Map<String, double> _memory() {
  final out = <String, double>{};
  for (final line in File('/proc/self/smaps_rollup').readAsLinesSync()) {
    final m = RegExp(r'^(Pss|Rss):\s+(\d+) kB').firstMatch(line);
    if (m != null) out[m[1]!.toLowerCase()] = int.parse(m[2]!) / 1024;
  }
  return out;
}

Future<void> _wait(WidgetTester tester, Duration time) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('CA-009-07: tarea web actual sobre una tarea con texto', (
    tester,
  ) async {
    await _wipe();
    await bootstrap();
    await _wait(tester, const Duration(seconds: 1));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeRouter)),
    );
    await container.read(createTaskProvider).call(_text);
    await _wait(tester, const Duration(seconds: 2));
    final report = <String, Object>{'text': _memory()};

    final web = StagedWeb(
      id: container.read(idGeneratorProvider).newId(),
      url: _url,
    );
    final watch = Stopwatch()..start();
    await container.read(createTaskProvider).call('', attachments: [web]);
    await _wait(tester, const Duration(milliseconds: 500));
    expect(find.byType(TaskWeb), findsOneWidget);
    // Espera a la página (el aviso de sin conexión también acaba el bucle).
    await _wait(tester, const Duration(seconds: 10));
    report['web_shown'] = _memory();
    report['web_url'] = _url;
    report['web_wait_ms'] = watch.elapsedMilliseconds;
    binding.reportData = {...?binding.reportData, 'web_memory': report};
  });
}
