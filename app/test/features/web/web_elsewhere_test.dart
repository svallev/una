// La tarea web fuera de la pantalla principal (spec 009, T-009-16): insignia
// "WEB" y dominio como etiqueta en el listado, la confirmación de eliminar y
// los anuncios; en las caras de completar y eliminar, la barra y la zona de la
// página en blanco, sin WebView (CA-009-17, CA-009-18, CL-009-11).
import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/attachments/task_thumbnail.dart';
import 'package:app/features/complete/celebration_overlay.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/delete/crumple_overlay.dart';
import 'package:app/features/delete/delete_confirm_sheet.dart';
import 'package:app/features/task_list/task_list_row.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/features/web/task_web.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';
import '../task_list/list_harness.dart' show listenAnnouncements, frame;

const _address = 'https://www.congreso.ejemplo.com/programa';
const _host = 'congreso.ejemplo.com';
const _nextAddress = 'https://agenda.festival.example/lunes';
const _nextHost = 'agenda.festival.example';

/// No puede completar (CA-003-12), tras un momento guardando.
class _FailingRepo extends InMemoryTaskRepository {
  @override
  Future<bool> remove(String id) async {
    // Tarda un poco: la pantalla llega a verse guardando.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    throw StateError('disk I/O error');
  }
}

Task _webTask(String id, String url, {required String rank, int color = 3}) {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: id,
    text: null,
    status: TaskStatus.pending,
    rank: rank,
    colorKey: color,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: 'a-$id', url: url), at),
  );
}

/// La vista de una WebView (falsa o real) dentro de [of].
Finder _webViewIn(Finder of) => find.descendant(
  of: of,
  matching: find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('web-view-'),
    skipOffstage: false,
  ),
  // Mientras carga, la vista está montada pero fuera del escenario.
  skipOffstage: false,
);

void main() {
  setUpAll(loadAppFonts);

  late FakeWebPages web;
  late InMemoryTaskRepository repo;

  setUp(() {
    web = FakeWebPages();
    repo = InMemoryTaskRepository();
  });

  List<Override> overrides() => [
    ...web.overrides,
    attachmentStoreProvider.overrideWithValue(MemoryAttachmentStore()),
    imageImporterProvider.overrideWithValue(
      FakeImageImporter(MemoryAttachmentStore()),
    ),
  ];

  Future<void> pumpWith(
    WidgetTester tester,
    List<Task> tasks, {
    bool screenReader = false,
    bool reduced = false,
  }) async {
    for (final t in tasks) {
      await repo.insert(t);
    }
    await pumpUnaApp(
      tester,
      repo: repo,
      screenReader: screenReader,
      reduced: reduced,
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas mis tareas'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
  }

  TaskListRow rowFor(WidgetTester tester, String id) => tester
      .widgetList<TaskListRow>(find.byType(TaskListRow))
      .firstWhere((r) => r.task.id == id);

  Finder thumbOf(WidgetTester tester, String id) => find.descendant(
    of: find.byWidget(rowFor(tester, id)),
    matching: find.byType(TaskThumbnail),
  );

  group('CA-009-17: listado', () {
    testWidgets('insignia negra de 44 px con "WEB" entre el asa y el texto, '
        'que es el dominio sin www.', (tester) async {
      await pumpWith(tester, [
        sampleTask(id: 't0', text: 'Primera', rank: 'A'),
        _webTask('w', _address, rank: 'B'),
      ]);
      await openList(tester);

      final thumb = thumbOf(tester, 'w');
      expect(tester.getSize(thumb), const Size(44, 44));
      expect(
        find.descendant(of: thumb, matching: find.text('WEB')),
        findsOneWidget,
      );
      final badge = find.descendant(
        of: thumb,
        matching: find.byType(ColoredBox),
      );
      expect(tester.widget<ColoredBox>(badge.first).color, UnaColors.ink);
      final label = tester.widget<Text>(
        find.descendant(of: thumb, matching: find.text('WEB')),
      );
      expect(label.style!.fontSize, UnaFontSizes.badge);
      expect(label.style!.color, UnaColors.onInk);
      // El texto de la fila es el dominio (CA-009-14), no la dirección.
      final row = find.byWidget(rowFor(tester, 'w'));
      final text = find.descendant(of: row, matching: find.text(_host));
      expect(text, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.textContaining('https')),
        findsNothing,
      );
      // Entre el asa y el texto.
      final thumbRect = tester.getRect(thumb);
      expect(thumbRect.right, lessThan(tester.getRect(text).left));
      expect(thumbRect.left - tester.getRect(row).left, greaterThan(34));
      // El listado no crea ninguna WebView (la de la tarea actual no es web).
      expect(web.drivers, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA-009-18: el lector lee "{n} de {total}: {dominio}. Página '
        'web"; la insignia es decorativa', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWith(tester, [
        _webTask('w', _address, rank: 'A'),
        sampleTask(id: 't1', text: 'Segunda', rank: 'B'),
        _webTask('v', _nextAddress, rank: 'C'),
      ]);
      await openList(tester);
      expect(
        find.bySemanticsLabel('1 de 3. Tarea actual: $_host. Página web'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('3 de 3: $_nextHost. Página web'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('WEB'), findsNothing);
      handle.dispose();
    });

    testWidgets('eliminar desde el listado: la confirmación y el anuncio dicen '
        'el dominio', (tester) async {
      final announcements = listenAnnouncements(tester);
      await pumpWith(tester, [
        sampleTask(id: 't0', text: 'Primera', rank: 'A'),
        _webTask('w', _address, rank: 'B'),
        _webTask('v', _nextAddress, rank: 'C'),
      ], screenReader: true);
      await openList(tester);

      // La web: la confirmación dice su dominio.
      await tester.tap(
        find.descendant(
          of: find.byWidget(rowFor(tester, 'w')),
          matching: find.byWidgetPredicate(
            (w) => w is UnaIcon && w.icon == UnaIcons.trash,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<DeleteConfirmSheet>(find.byType(DeleteConfirmSheet))
            .label,
        _host,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // La actual: el anuncio dice el dominio de la siguiente (la web).
      await tester.tap(
        find.descendant(
          of: find.byWidget(rowFor(tester, 't0')),
          matching: find.byWidgetPredicate(
            (w) => w is UnaIcon && w.icon == UnaIcons.trash,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is BrutalButton && w.label == 'Eliminar',
        ),
      );
      await tester.pumpAndSettle();
      expect(announcements, contains('Tarea eliminada. Siguiente: $_host'));
    });
  });

  testWidgets('CL-009-11: al empezar a guardar la completada, la página se '
      'suelta; si no se puede guardar, se vuelve a cargar', (tester) async {
    repo = _FailingRepo();
    await pumpWith(tester, [
      _webTask('w', _address, rank: 'A'),
      _webTask('v', _nextAddress, rank: 'B'),
    ]);
    final page = web.last;
    page.started(_address);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToCompleteButton)),
    );
    await tester.pump();
    await tester.pump(UnaMotion.holdToComplete);
    await tester.pump(frame);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(CelebrationOverlay), findsNothing);
    expect(find.text('No hemos podido completar la tarea'), findsOneWidget);
    // Se soltó al empezar a guardar y, como sigue siendo la actual, se carga
    // otra vez con otra WebView.
    expect(page.disposed, isTrue);
    expect(web.janitor.cleared, contains(page.nativeId));
    expect(web.drivers, hasLength(2));
    expect(web.last.loads, [Uri.parse(_address)]);
    expect(_webViewIn(find.byType(TaskWeb)), findsOneWidget);
  });

  group(
    'CA-009-17: completar y eliminar con la barra y la página en blanco',
    () {
      /// La cara de la tarea web en [overlay]: la barra con el dominio, la zona
      /// de la página en blanco (sin WebView, sin línea de carga ni aviso).
      void expectBlankFace(WidgetTester tester, Finder overlay) {
        final faces = find.descendant(
          of: overlay,
          matching: find.byType(TaskWeb),
        );
        expect(faces, findsWidgets);
        for (final face in tester.widgetList<TaskWeb>(faces)) {
          expect(face.live, isFalse);
        }
        final bars = find.descendant(
          of: overlay,
          matching: find.byType(WebBar),
        );
        expect(bars, findsWidgets);
        for (final bar in tester.widgetList<WebBar>(bars)) {
          expect(bar.host, _host);
          expect(bar.badge, 'WEB');
        }
        expect(_webViewIn(overlay), findsNothing);
        expect(
          find.descendant(of: overlay, matching: find.byType(Offstage)),
          findsNothing,
        );
        final zones = find.descendant(
          of: overlay,
          matching: find.byKey(const ValueKey('web-page')),
        );
        expect(zones, findsWidgets);
        for (final zone in zones.evaluate()) {
          final box = tester.widget<ColoredBox>(
            find
                .descendant(
                  of: find.byWidget(zone.widget),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
          expect(box.color, UnaColors.surface);
        }
      }

      for (final reduced in [false, true]) {
        final how = reduced ? ' (reducir movimiento)' : '';
        testWidgets('CL-003-4/8: la rotura$how muestra la barra y la zona en '
            'blanco; la carga se cancela (CL-009-11) y el anuncio dice el '
            'dominio', (tester) async {
          final announcements = listenAnnouncements(tester);
          await pumpWith(
            tester,
            [
              _webTask('w', _address, rank: 'A'),
              _webTask('v', _nextAddress, rank: 'B'),
            ],
            screenReader: true,
            reduced: reduced,
          );
          // Mientras la página carga (CL-009-11).
          final page = web.last;
          expect(page.loads, hasLength(1));

          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(HoldToCompleteButton)),
          );
          await tester.pump();
          await tester.pump(UnaMotion.holdToComplete);
          await tester.pump(frame);
          await gesture.up();
          await tester.pump(UnaMotion.holdDonePause);
          await tester.pump(frame);
          await tester.pump(const Duration(milliseconds: 100));

          final overlay = find.byType(CelebrationOverlay);
          expect(overlay, findsOneWidget);
          expectBlankFace(tester, overlay);
          // La cara no crea ninguna WebView (solo la siguiente tarea, detrás,
          // tiene la suya); la de la completada se ha soltado.
          expect(web.drivers.where((d) => d != page), hasLength(lessThan(2)));
          expect(page.stops, greaterThan(0));
          expect(page.disposed, isTrue);
          expect(web.janitor.cleared, contains(page.nativeId));

          await tester.pumpAndSettle();
          expect(find.byType(CelebrationOverlay), findsNothing);
          expect(
            announcements,
            contains('Tarea completada. Siguiente: $_nextHost'),
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('el arrugado$how muestra la barra y la zona en blanco, la '
            'confirmación y el anuncio dicen el dominio', (tester) async {
          final announcements = listenAnnouncements(tester);
          await pumpWith(tester, [
            _webTask('w', _address, rank: 'A'),
            _webTask('v', _nextAddress, rank: 'B'),
          ], reduced: reduced);
          final page = web.last;
          page.started(_address);
          await tester.pumpAndSettle();

          await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Eliminar'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DeleteConfirmSheet>(find.byType(DeleteConfirmSheet))
                .label,
            _host,
          );
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is BrutalButton && w.label == 'Eliminar',
            ),
          );
          await tester.pump(frame);
          await tester.pump(frame);
          await tester.pump(
            (reduced ? UnaMotion.crumpleReducedFade : UnaMotion.crumple) * 0.3,
          );

          final overlay = find.byType(CrumpleOverlay);
          expect(overlay, findsOneWidget);
          // La cara (la eliminada) con su barra; lo de encima, sin barra.
          expectBlankFace(tester, overlay);
          expect(
            find.descendant(of: overlay, matching: find.byType(WebBar)),
            findsOneWidget,
          );
          // Se soltó la WebView de la eliminada (CL-009-11); la cara no crea
          // ninguna.
          expect(page.disposed, isTrue);
          expect(web.janitor.cleared, contains(page.nativeId));
          expect(web.drivers.where((d) => d != page), hasLength(lessThan(2)));

          await tester.pump(UnaMotion.crumple);
          await tester.pumpAndSettle();
          expect(
            announcements,
            contains('Tarea eliminada. Siguiente: $_nextHost'),
          );
          // La siguiente (web) se ve con su propia WebView.
          expect(tester.widget<WebBar>(find.byType(WebBar)).host, _nextHost);
          expect(web.last, isNot(page));
          expect(tester.takeException(), isNull);
        });
      }
    },
  );
}
