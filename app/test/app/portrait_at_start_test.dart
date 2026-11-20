import 'package:app/data/attachments/attachment_images.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/import/unavailable_image_importer.dart';
import 'package:app/data/import/unavailable_pdf_importer.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/data/repository_factory.dart';
import 'package:app/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  /// Arranca la app y devuelve, en orden, lo que hizo con las orientaciones y
  /// con el almacenamiento (`open`).
  Future<List<String>> boot(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    final events = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          events.add(
            'orientations:${(call.arguments as List<Object?>).join(',')}',
          );
        }
        return null;
      });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    Future<Repositories> open() async {
      events.add('open');
      final r = InMemoryTaskRepository();
      return (tasks: r, settings: r);
    }

    try {
      await bootstrap(open: open, openImages: _images);
      await tester.pump();
    } finally {
      // Antes de que el marco compruebe sus variables de depuración.
      debugDefaultTargetPlatformOverride = null;
    }
    return events;
  }

  testWidgets(
    'CA-028-05: en iOS, antes de abrir el almacenamiento y del primer '
    'fotograma, la app fija solo vertical (el Info.plist declara también las '
    'horizontales, CA-028-13)',
    (tester) async {
      final events = await boot(tester, TargetPlatform.iOS);
      expect(events.first, 'orientations:DeviceOrientation.portraitUp');
      expect(events.where((e) => e.startsWith('orientations')), hasLength(1));
      expect(events, contains('open'));
      expect(events.indexOf('open'), greaterThan(0));
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    'CA-028-05: en Android el arranque no toca las orientaciones (las fija el '
    'manifiesto y el giro del adjunto, CA-008-11)',
    (tester) async {
      final events = await boot(tester, TargetPlatform.android);
      expect(events.where((e) => e.startsWith('orientations')), isEmpty);
      expect(events, contains('open'));
      await tester.pump(const Duration(seconds: 10));
    },
  );
}
