// Rendimiento de la lista de licencias y del texto de una licencia (spec 012,
// CA-012-15): el nivel 2 aparece en < 300 ms y, al desplazar, el p90 de los
// fotogramas es ≤ 16,7 ms. Se ejecuta en el dispositivo en modo profile (en el
// móvil del propietario, siempre con --keep-app-running; en el emulador, con
// la app `.profile`):
//   flutter drive --profile --no-dds --keep-app-running \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/licenses_perf_test.dart -d <serial>
import 'dart:convert';
import 'dart:io';

import 'package:app/app/bundled_licenses.dart';
import 'package:app/app/providers.dart';
import 'package:app/app/una_app.dart';
import 'package:app/domain/entities/rank.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/settings/license_detail_screen.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<void> _wipeDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  // Solo en las apps de pruebas (`.debug`, `.profile`).
  if (!dir.path.contains('.debug') && !dir.path.contains('.profile')) {
    throw StateError('Pruebas fuera de la app de pruebas: ${dir.path}');
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${dir.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
}

/// Lo mismo que hace `ServicesBinding.initLicenses` con `NOTICES.Z`.
Future<void> _registerNotices() async {
  final data = await rootBundle.load('NOTICES.Z');
  final raw = utf8.decode(
    gzip.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ),
  );
  final separator = '\n${'-' * 80}\n';
  LicenseRegistry.addLicense(() async* {
    for (final block in raw.split(separator)) {
      final split = block.indexOf('\n\n');
      if (split < 0) continue;
      final packages = block.substring(0, split).split('\n');
      yield LicenseEntryWithLineBreaks(packages, block.substring(split + 2));
    }
  });
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Fotogramas reales al ritmo de la pantalla (no solo los que pide el test).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('rendimiento: lista y texto de licencias', (tester) async {
    final semantics = tester.ensureSemantics();
    await _wipeDatabase();
    await bootstrap();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeRouter)),
    );
    await container.read(settingsRepositoryProvider).setFirstRunDone();
    final now = DateTime.now();
    await container
        .read(taskRepositoryProvider)
        .insert(
          Task(
            id: 'perf-0',
            text: 'Licencias',
            status: TaskStatus.pending,
            rank: Rank.evenlySpaced(1).first,
            colorKey: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(HomeRouter)));
    await tester.tap(find.bySemanticsLabel(l10n.menuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.menuSettings));
    await tester.pumpAndSettle();

    // El binding de pruebas no carga `NOTICES.Z` (Flutter lo añade solo en la
    // app real): se registra igual que hace el motor, para medir con las
    // licencias reales (paquetes Dart y motor), más las propias de la app.
    await _registerNotices();
    registerBundledLicenses();

    // Diagnóstico: que la fuente real lee algo en este binding.
    Object? diag;
    try {
      final all = await container.read(licenseSourceProvider).load();
      diag = 'ok: ${all.length} elementos';
    } on Object catch (e, st) {
      diag = 'error: $e\n$st';
    }
    // ignore: avoid_print
    print('DIAG $diag');
    if (diag.toString().startsWith('error')) fail('$diag');

    // Abrir el nivel 2: desde el toque hasta ver la lista.
    final watch = Stopwatch()..start();
    await tester.tap(find.text(l10n.settingsLicenses));
    while (find.text('abseil-cpp').evaluate().isEmpty) {
      if (watch.elapsedMilliseconds > 20000) {
        fail('la lista no aparece en 20 s');
      }
      await tester.pump();
    }
    watch.stop();
    binding.reportData = {
      'diag': {'load': '$diag'},
      'open_licenses': {'open_licenses_ms': watch.elapsedMilliseconds},
    };
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      final list = find.byType(ListView);
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -900), 3000);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, 900), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'licenses_list_scroll_frames');

    // Nivel 3: el paquete con más licencias (angle, decenas de textos).
    await tester.scrollUntilVisible(
      find.text('angle'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('angle'));
    await tester.pumpAndSettle();
    expect(find.byType(LicenseDetailScreen), findsOneWidget);

    await binding.watchPerformance(() async {
      final list = find.byType(ListView);
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -900), 3000);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, 900), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'license_text_scroll_frames');
    semantics.dispose();
  });
}
