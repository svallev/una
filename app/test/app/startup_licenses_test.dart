import 'package:app/app/bundled_licenses.dart';
import 'package:app/app/providers.dart';
import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/import/unavailable_image_importer.dart';
import 'package:app/data/import/unavailable_pdf_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/license_source.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/settings/licenses_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/pump_app.dart' show sampleTask;

/// El arranque no empeora (spec 012, CA-012-16, P2): ninguna licencia se lee
/// antes del primer fotograma ni al recorrer la app hasta el nivel 1 de la
/// Configuración; solo al abrir el nivel 2.

/// Un `AssetBundle` que apunta qué se pide y lo lee del real.
class _CountingBundle extends CachingAssetBundle {
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    return rootBundle.load(key);
  }
}

/// Cuenta las lecturas de la fuente.
class _CountingSource implements LicenseSource {
  int loads = 0;

  @override
  Future<List<LicensePackage>> load() async {
    loads++;
    return const [
      LicensePackage(
        name: 'zxq_pkg',
        texts: [
          LicenseText([(text: 'Zxq licence text.', indent: 0)]),
        ],
      ),
    ];
  }
}

class _Opener implements LinkOpener {
  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

Future<ImageServices> _images() async {
  final store = MemoryAttachmentStore();
  return (
    store: store,
    images: MemoryAttachmentImages(store),
    importer: const UnavailableImageImporter(),
    pdfImporter: const UnavailablePdfImporter(),
  );
}

void main() {
  late _CountingBundle bundle;
  late int collectorRuns;

  setUp(() {
    LicenseRegistry.reset();
    bundle = _CountingBundle();
    collectorRuns = 0;
    // Como main(): las licencias propias, perezosas; y un recolector de más
    // que avisa si alguien pide las licencias (las de Flutter no están en test).
    registerBundledLicenses(bundle: bundle);
    LicenseRegistry.addLicense(() async* {
      collectorRuns++;
      yield LicenseEntryWithLineBreaks(['zxq'], 'Zxq licence text.');
    });
  });
  tearDown(LicenseRegistry.reset);

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Task menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings and profile'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  testWidgets(
    'CA-012-16: con el arranque real (bootstrap) no se lee ninguna licencia al pintar la tarea ni al abrir la Configuración; solo al abrir el nivel 2',
    (tester) async {
      final repo = InMemoryTaskRepository();
      await repo.insert(sampleTask(text: 'Zxq tarea'));
      await repo.setFirstRunDone();
      await bootstrap(
        open: () async => (tasks: repo, settings: repo),
        openImages: _images,
      );
      await tester.pump();

      // Primer fotograma: la tarea, sin haber leído ninguna licencia.
      expect(find.byType(CurrentTaskScreen), findsOneWidget);
      expect(bundle.loads, isEmpty);
      expect(collectorRuns, 0);

      await openSettings(tester);
      expect(bundle.loads, isEmpty, reason: 'nivel 1: nada');
      expect(collectorRuns, 0);

      await tester.tap(find.text('Open-source licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensesScreen), findsOneWidget);
      // Los archivos se leen fuera del reloj falso de los tests.
      for (var i = 0; i < 100 && find.text('Archivo').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(collectorRuns, 1);
      expect(
        bundle.loads,
        containsAll([
          'assets/fonts/archivo/OFL.txt',
          'assets/fonts/space_mono/OFL.txt',
          'assets/licenses/pdfium.txt',
          'assets/licenses/sqlite.txt',
          'assets/licenses/android.txt',
        ]),
      );
      expect(find.text('Archivo'), findsOneWidget);
    },
  );

  testWidgets(
    'CA-012-16: la fuente de licencias no se llama hasta abrir el nivel 2 (ni tras el menú ni en el nivel 1)',
    (tester) async {
      final source = _CountingSource();
      await pumpUnaApp(
        tester,
        repo: InMemoryTaskRepository(),
        tasks: ['Zxq 1', 'Zxq 2'],
        locale: const Locale('en'),
        overrides: [
          licenseSourceProvider.overrideWithValue(source),
          linkOpenerProvider.overrideWithValue(_Opener()),
        ],
      );
      expect(source.loads, 0);
      await tester.tap(find.bySemanticsLabel('Task menu'));
      await tester.pumpAndSettle();
      expect(source.loads, 0, reason: 'menú abierto');
      await tester.tap(find.text('Settings and profile'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(source.loads, 0, reason: 'nivel 1');

      await tester.tap(find.text('Open-source licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensesScreen), findsOneWidget);
      expect(source.loads, 1);
      expect(
        bundle.loads,
        isEmpty,
        reason: 'la fuente falsa no toca el registro',
      );
    },
  );
}
