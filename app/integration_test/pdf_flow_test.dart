// Flujo completo con PDF en el emulador (spec 008, T-008-22): PDFium, el JPEG
// nativo, el almacén en disco y la interfaz reales. Solo el selector se
// sustituye ([FixturePdfImporter]): entrega un fichero de prueba en lugar de
// abrir el selector de documentos del sistema (otra app). El selector real se
// prueba a mano.
//
//   flutter test integration_test/pdf_flow_test.dart -d emulator-5554
import 'dart:io';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/attachments/file_attachment_store.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/data/image_services.dart';
import 'package:app/data/import/native_pdf_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/ports/pdf_importer.dart';
import 'package:app/features/all_done/all_done_screen.dart';
import 'package:app/features/attachments/attachment_preview.dart';
import 'package:app/features/attachments/import_error_text.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/pdf_position_controller.dart';
import 'package:app/features/attachments/pdf_strip.dart';
import 'package:app/features/attachments/task_pdf.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/current_task/current_task_screen.dart';
import 'package:app/features/first_run/welcome_intro.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/fixture_pdf_importer.dart';

late Directory _support;
late Directory _cache;
late FixturePdfImporter _importer;
late FileAttachmentStore _store;

/// Solo en las apps de pruebas (`.debug`, `.profile`): nunca borra datos
/// reales.
Future<void> _wipe() async {
  final docs = await getApplicationDocumentsDirectory();
  if (!docs.path.contains('.debug') && !docs.path.contains('.profile')) {
    throw StateError('Pruebas de integración fuera de la app .debug: $docs');
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${docs.path}/una.sqlite$suffix');
    if (f.existsSync()) f.deleteSync();
  }
  for (final d in [
    Directory('${_support.path}/attachments'),
    Directory('${_cache.path}/import'),
  ]) {
    if (d.existsSync()) d.deleteSync(recursive: true);
  }
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

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeRouter)));

/// Espera (en tiempo real: PDFium y el JPEG nativo tardan de verdad) a que
/// [done] se cumpla, como mucho [timeout].
Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Tiempo agotado: $reason');
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// (+) → "Subir archivo" con el fichero de prueba [name] → espera a la vista
/// previa del PDF o al aviso de error. Devuelve el texto del aviso, o null.
Future<String?> _attachPdf(WidgetTester tester, String name) async {
  final l10n = _l10n(tester);
  _importer.next = name;
  await tester.tap(find.bySemanticsLabel(l10n.attachButton));
  await _settle(tester);
  await tester.tap(find.text(l10n.attachPickFile));
  final errors = {
    for (final e in PdfImportError.values) importErrorText(l10n, e),
  };
  String? shown;
  await _until(tester, () {
    for (final text in errors) {
      if (find.text(text).evaluate().isNotEmpty) {
        shown = text;
        return true;
      }
    }
    return find.byType(AttachmentPreview).evaluate().isNotEmpty &&
        find.byType(PdfStrip).evaluate().isNotEmpty &&
        find.text(l10n.pdfPreparing).evaluate().isEmpty;
  }, reason: name);
  await tester.pump(const Duration(milliseconds: 300));
  return shown;
}

Future<void> _saveEditor(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w is BrutalButton && !w.iconOnly).last,
  );
  await _settle(tester);
}

/// Espera a que el visor esté listo: la versión de pantalla se quita.
Future<void> _untilViewerReady(WidgetTester tester) => _until(
  tester,
  () =>
      find.byType(TaskPdfView).evaluate().isNotEmpty &&
      find
          .descendant(
            of: find.byType(TaskPdfView),
            matching: find.byType(TaskPdfFace),
          )
          .evaluate()
          .isEmpty,
  reason: 'visor listo',
);

PdfPosition? _visible(WidgetTester tester, String attachmentId) =>
    _container(tester).read(pdfPositionProvider(attachmentId)).position;

/// Desplaza el PDF hacia abajo [times] veces (con el dedo) y deja asentar.
Future<void> _scrollDown(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.drag(find.byType(TaskPdfView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await _settle(tester);
}

/// Deja pasar [time] en tiempo real. Con el visor de pdfrx a la vista no se
/// usa `pumpAndSettle`: sigue pidiendo fotogramas y no termina nunca.
Future<void> _settle(
  WidgetTester tester, [
  Duration time = const Duration(seconds: 1),
]) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Desmonta la app y cierra la BD (antes de rearrancar o de borrarla).
Future<void> _shutdown(WidgetTester tester) async {
  final repo =
      _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
  await tester.pumpWidget(const SizedBox());
  await repo.db.close();
}

List<String> _files(Directory d) => d.existsSync()
    ? (d
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort())
    : const [];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _support = await getApplicationSupportDirectory();
    _cache = await getTemporaryDirectory();
  });

  testWidgets('CA-008-01/04/08/09/16: PDF → tarea actual → posición guardada '
      'al pasar a segundo plano → arranque en frío en esa posición → '
      'completar borra el PDF', (tester) async {
    await _wipe();
    await bootstrap(openImages: _openImages);
    await _settle(tester);

    // Primera tarea: texto + PDF de 20 páginas.
    await tester.tap(find.byType(WelcomeIntro));
    await _settle(tester);
    expect(await _attachPdf(tester, 'pages_20.pdf'), isNull);
    await tester.enterText(find.byType(TextField), 'Horario del congreso');
    await _saveEditor(tester);

    expect(find.byType(CurrentTaskScreen), findsOneWidget);
    final repo =
        _container(tester).read(taskRepositoryProvider) as DriftTaskRepository;
    final task = (await repo.currentTask())!;
    final attachment = task.attachment!;
    expect(attachment.kind, AttachmentKind.pdf);
    expect(attachment.origin, AttachmentOrigin.file);
    expect(attachment.originalName, 'pages_20.pdf');
    expect(attachment.pageCount, 20);

    // Franja con "PDF", el nombre y el tamaño; las páginas con el motor real.
    final strip = tester.widget<PdfStrip>(find.byType(PdfStrip));
    expect(strip.type, 'PDF');
    expect(strip.name, 'pages_20.pdf');
    await _untilViewerReady(tester);
    expect(_visible(tester, attachment.id), PdfPosition.start);

    // En disco: el PDF y su versión de pantalla; nada en la preparación.
    final dir = Directory('${_support.path}/${attachment.dir}');
    expect(_files(dir), ['document.pdf', 'screen.jpg']);
    expect(
      Directory('${_cache.path}/import').listSync().whereType<Directory>(),
      isEmpty,
    );
    final firstScreen = File('${dir.path}/screen.jpg').readAsBytesSync();

    // Se desplaza a una página intermedia.
    await _scrollDown(tester, 12);
    final seen = _visible(tester, attachment.id)!;
    expect(seen.page, greaterThan(3));
    expect(seen.page, lessThan(20));

    // Segundo plano: se guarda la posición y la versión de pantalla pasa a
    // ser esa página (el próximo arranque la pinta en el primer fotograma).
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // En segundo plano no hay fotogramas (`pump` no volvería): se espera
    // fuera del reloj del test.
    PdfPosition? saved;
    await tester.runAsync(() async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(end)) {
        saved = await _store.readPosition(attachment.id);
        final screen = File('${dir.path}/screen.jpg').readAsBytesSync();
        if (saved == seen && !_sameBytes(screen, firstScreen)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    // La posición y la versión de pantalla, ya con esa página.
    expect(saved, seen);
    expect(
      _sameBytes(File('${dir.path}/screen.jpg').readAsBytesSync(), firstScreen),
      isFalse,
    );
    expect(_files(dir), ['document.pdf', 'position.json', 'screen.jpg']);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    // Arranque en frío: sin ningún toque, la tarea con el PDF en la última
    // posición; antes del visor, la versión de pantalla de esa página.
    await _shutdown(tester);
    await bootstrap(openImages: _openImages);
    await _until(
      tester,
      () => find.byType(TaskPdfView).evaluate().isNotEmpty,
      reason: 'tarea con PDF',
    );
    expect(
      tester.widget<TaskPdfView>(find.byType(TaskPdfView)).args.initialPosition,
      seen,
    );
    await _untilViewerReady(tester);
    await _settle(tester);
    final restored = _visible(tester, attachment.id)!;
    expect(restored.page, seen.page);
    expect(restored.offset, closeTo(seen.offset, 0.02));
    expect(find.byType(MissingAttachmentCard), findsNothing);
    _expectNoException(tester);

    // Completar (mantener pulsado 1,2 s) borra la tarea y su PDF (CA-008-16).
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToCompleteButton)),
    );
    await tester.pump();
    await tester.pump(UnaMotion.holdToComplete);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await _settle(tester, const Duration(seconds: 5));
    expect(find.byType(AllDoneScreen), findsOneWidget);
    await _until(
      tester,
      () => !dir.existsSync(),
      reason: 'directorio del adjunto borrado',
    );
    await _shutdown(tester);
  });

  testWidgets('CA-008-02/03/14, CL-008-1/3: los PDF malformados se rechazan '
      'en el editor sin cerrar la app; los raros pero válidos se ven', (
    tester,
  ) async {
    await _wipe();
    await bootstrap(openImages: _openImages);
    await _settle(tester);
    await tester.tap(find.byType(WelcomeIntro));
    await _settle(tester);
    final l10n = _l10n(tester);
    final rejected = {
      'truncated.pdf': l10n.errPdfUnreadable,
      'cyclic.pdf': l10n.errPdfUnreadable,
      'zero_pages.pdf': l10n.errPdfUnreadable,
      'protected_user.pdf': l10n.errPdfProtected,
      'pages_21.pdf': l10n.errPdfTooManyPages(20),
      'pages_10000.pdf': l10n.errPdfTooManyPages(20),
      'html_as.pdf': l10n.errPdfType,
      'zip_as.pdf': l10n.errPdfType,
      'header_late.pdf': l10n.errPdfType,
    };
    for (final MapEntry(key: name, value: error) in rejected.entries) {
      expect(await _attachPdf(tester, name), error, reason: name);
      // El editor queda como estaba: sin adjunto.
      expect(find.byType(AttachmentPreview), findsNothing, reason: name);
      _expectNoException(tester, name);
      ScaffoldMessenger.of(tester.element(find.byType(TextField)))
          .clearSnackBars();
      await _settle(tester);
    }
    // Nada queda en la preparación.
    expect(
      Directory('${_cache.path}/import').existsSync()
          ? Directory('${_cache.path}/import').listSync()
          : const <FileSystemEntity>[],
      isEmpty,
    );

    // Válidos aunque raros: la bomba de compresión, JavaScript y formulario
    // (no se ejecutan), la cabecera tras basura y solo contraseña de
    // permisos. Cada uno sustituye al anterior y se ve como tarea.
    for (final name in [
      'bomb.pdf',
      'js_form.pdf',
      'header_offset.pdf',
      'protected_owner_only.pdf',
    ]) {
      expect(await _attachPdf(tester, name), isNull, reason: name);
      _expectNoException(tester, name);
    }
    await _saveEditor(tester);
    expect(find.byType(CurrentTaskScreen), findsOneWidget);
    await _untilViewerReady(tester);
    expect(find.byType(MissingAttachmentCard), findsNothing);
    _expectNoException(tester);
    await _shutdown(tester);
  });

  testWidgets('CL-008-4: una página intermedia que no se puede dibujar no '
      'cierra la app ni impide ver las demás', (tester) async {
    await _wipe();
    await bootstrap(openImages: _openImages);
    await _settle(tester);
    await tester.tap(find.byType(WelcomeIntro));
    await _settle(tester);
    expect(await _attachPdf(tester, 'broken_page.pdf'), isNull);
    await _saveEditor(tester);
    final task = (await _container(tester)
        .read(taskRepositoryProvider)
        .currentTask())!;
    expect(task.attachment!.pageCount, 3);
    await _untilViewerReady(tester);

    // Se pasa por la página 2 (estropeada) hasta el final: la 3 se ve (su
    // nodo para el lector, con su texto) y la posición sigue a las páginas.
    final semantics = tester.ensureSemantics();
    await _scrollDown(tester, 6);
    expect(_visible(tester, task.attachment!.id)!.page, greaterThan(1));
    final l10n = _l10n(tester);
    await _until(
      tester,
      () => find
          .bySemanticsLabel(
            RegExp('^${RegExp.escape(l10n.pdfPageA11y(3, 3))}.*Pagina 3 de 3'),
          )
          .evaluate()
          .isNotEmpty,
      reason: 'página 3 con su texto',
    );
    expect(find.byType(MissingAttachmentCard), findsNothing);
    expect(find.byType(TaskPdfView), findsOneWidget);
    _expectNoException(tester);
    await _shutdown(tester);
    semantics.dispose();
  });
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Ningún error de la app hasta ahora; si lo hay, con su pila en el registro.
void _expectNoException(WidgetTester tester, [String? reason]) {
  final e = tester.takeException();
  if (e is Error) debugPrint('$e\n${e.stackTrace}');
  expect(e, isNull, reason: reason);
}
