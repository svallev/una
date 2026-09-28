// Rendimiento de la tarea con PDF (spec 008, T-008-22; CL-008-5, CA-008-08).
// En el dispositivo, en modo profile (en el móvil del propietario, siempre con
// --keep-app-running y con el binario ya compilado, para que flutter no
// deduzca otro paquete):
//
//   flutter build apk --profile --target=integration_test/pdf_perf_test.dart
//   adb push tools/fixtures/out/scanned_20p.pdf \
//     /sdcard/Android/data/invalid.pending.app.profile/files/scanned_20p.pdf
//   flutter drive --profile --keep-app-running \
//     --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/pdf_perf_test.dart -d <serial>
//
// Deja en la app `.profile` la tarea con el PDF escaneado de 20 páginas
// (tools/fixtures/gen_pdf_fixtures.py) guardada en una página intermedia:
// después, la app normal (`flutter run --profile --use-application-binary`)
// arranca en esa posición para medir el arranque en frío (docs/perf).
// Con `--dart-define=PDF_PERF_TEXT_ONLY=true` deja solo la tarea con texto
// (la referencia de la memoria y del arranque).
import 'dart:async';
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/file_attachment_store.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/import/native_pdf_importer.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/features/attachments/pdf_position_controller.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/fixture_pdf_importer.dart';

const _textOnly = bool.fromEnvironment('PDF_PERF_TEXT_ONLY');
const _text = 'Horario del congreso';

late FixturePdfImporter _importer;
late FileAttachmentStore _store;

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
  final support = await getApplicationSupportDirectory();
  final attachments = Directory('${support.path}/attachments');
  if (attachments.existsSync()) attachments.deleteSync(recursive: true);
}

Future<ImageServices> _openImages() async {
  final real = await openImageServices();
  _store = real.store as FileAttachmentStore;
  _importer = FixturePdfImporter(real.pdfImporter as NativePdfImporter, _store);
  return (
    store: real.store,
    images: real.images,
    importer: real.importer,
    pdfImporter: _importer,
  );
}

/// Memoria del proceso en MB (PSS y RSS de `/proc/self/smaps_rollup`). No
/// cuenta la memoria de la GPU que da `dumpsys meminfo` aparte.
Map<String, double> _memory() {
  final out = <String, double>{};
  for (final line in File('/proc/self/smaps_rollup').readAsLinesSync()) {
    final m = RegExp(r'^(Pss|Rss):\s+(\d+) kB').firstMatch(line);
    if (m != null) out[m[1]!.toLowerCase()] = int.parse(m[2]!) / 1024;
  }
  return out;
}

/// Deja pasar [time] en tiempo real (con el visor a la vista,
/// `pumpAndSettle` no termina).
Future<void> _wait(WidgetTester tester, Duration time) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('CL-008-5, CA-008-08: 20 páginas escaneadas de la 1 a la 20, '
      'memoria sobre la misma tarea con texto', (tester) async {
    await _wipe();
    await bootstrap(openImages: _openImages);
    await _wait(tester, const Duration(seconds: 1));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeRouter)),
    );
    await container.read(createTaskProvider).call(_text);
    await _wait(tester, const Duration(seconds: 3));
    final report = <String, Object>{'text': _memory()};
    if (_textOnly) {
      binding.reportData = {...?binding.reportData, 'pdf_memory': report};
      return;
    }

    // La misma tarea con el PDF escaneado (va arriba: es la actual).
    final scanned = await getExternalStorageDirectory();
    final path = '${scanned!.path}/scanned_20p.pdf';
    expect(File(path).existsSync(), isTrue, reason: 'adb push de $path');
    _importer.next = path;
    final job = (await container.read(importPdfProvider).pick())!;
    final staged = await job.prepare();
    final task = await container
        .read(createTaskProvider)
        .call(_text, attachment: staged);
    final id = task.attachment!.id;
    await _wait(tester, const Duration(seconds: 1));
    expect(find.byType(TaskPdfView), findsOneWidget);
    await _wait(tester, const Duration(seconds: 4));
    report['pdf_page1'] = _memory();

    // De la 1 a la 20 con el dedo; se mide la memoria mientras tanto.
    var peak = 0.0;
    final sampler = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final pss = _memory()['pss']!;
      if (pss > peak) peak = pss;
    });
    PdfPosition? visible() => container.read(pdfPositionProvider(id)).position;
    // Hasta el final: la posición es la página de arriba de la vista, así que
    // con la 20 entera a la vista es la 19 o la 20 y ya no cambia.
    await binding.watchPerformance(() async {
      PdfPosition? last;
      var still = 0;
      for (var i = 0; i < 80 && still < 3; i++) {
        await tester.fling(
          find.byType(TaskPdfView),
          const Offset(0, -400),
          1500,
        );
        await _wait(tester, const Duration(milliseconds: 400));
        final now = visible();
        still = now == last ? still + 1 : 0;
        last = now;
      }
      await _wait(tester, const Duration(seconds: 2));
    }, reportKey: 'pdf_scroll_frames');
    sampler.cancel();
    expect(visible()!.page, greaterThanOrEqualTo(19));
    expect(find.byType(TaskPdfView), findsOneWidget);
    report['pdf_page20'] = _memory();
    report['pdf_peak_pss'] = peak;

    // Vuelve a una página intermedia y la guarda como al pasar a segundo
    // plano: el próximo arranque empieza ahí.
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(TaskPdfView), const Offset(0, 900));
      await _wait(tester, const Duration(milliseconds: 300));
    }
    await _wait(tester, const Duration(seconds: 2));
    final seen = visible()!;
    report['saved_page'] = seen.page;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    PdfPosition? saved;
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && saved != seen; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        saved = await _store.readPosition(id);
      }
      // La versión de pantalla de esa página, en segundo plano.
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(saved, seen);
    binding.reportData = {...?binding.reportData, 'pdf_memory': report};
  });
}
