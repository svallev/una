import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/live_notice.dart';
import 'package:app/ui/una_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import 'settings_harness.dart';

/// Los dos avisos de error de Ajustes (spec 015, CA-015-12 "Los avisos" y
/// CA-015-25): regiones vivas con la marca de idioma de la app, una vez por
/// intento, que se quitan con la siguiente acción con éxito sobre cualquier
/// control o al salir del nivel, y que pueden verse a la vez.

const _noApp = 'No hay ninguna app para abrir este enlace.';
const _saveError = 'No se pudo guardar el ajuste.';
const _keepAwake = 'Pantalla siempre activa';
const _lockZoom = 'Bloquear zoom';
const _keepLabel = '$_keepAwake, Imágenes, documentos y web';
const _lockLabel = '$_lockZoom, Solo imágenes: sin zoom ni scroll';

Finder get _noAppNotice => inSettings(find.text(_noApp));
Finder get _saveNotice => inSettings(find.text(_saveError));

SemanticsData _data(WidgetTester tester, String label) => tester
    .getSemantics(
      find.descendant(
        of: find.byType(LiveNotice),
        matching: find.bySemanticsLabel(label),
      ),
    )
    .getSemanticsData();

Future<void> _tapKeepAwake(WidgetTester tester) async {
  await tester.tap(inSettings(find.text(_keepAwake)));
  await settleSettings(tester);
}

Future<void> _tapLockZoom(WidgetTester tester) async {
  await tester.tap(inSettings(find.text(_lockZoom)));
  await settleSettings(tester);
}

Future<void> _tapHelp(WidgetTester tester) async {
  final help = inSettings(find.text('Ayuda'));
  await tester.ensureVisible(help);
  await tester.pumpAndSettle();
  await tester.tap(help);
  await settleSettings(tester);
}

void main() {
  setUpAll(loadAppFonts);

  group('El aviso de guardado (CA-015-25)', () {
    testWidgets(
      'CA-015-12: es una región viva con la marca de idioma de la app (es y en) y no usa los anuncios del sistema',
      (tester) async {
        for (final (code, text) in [
          ('es', _saveError),
          ('en', "Couldn't save the setting."),
        ]) {
          final handle = tester.ensureSemantics();
          final repo = SettingsRepo()..error = Exception('x');
          await openSettingsScreen(
            tester,
            locale: Locale(code),
            repo: repo,
            screenReader: true,
          );
          tester.takeAnnouncements();
          await tester.tap(
            inSettings(find.text(code == 'en' ? 'Keep screen on' : _keepAwake)),
          );
          await settleSettings(tester);
          final data = _data(tester, text);
          expect(data.flagsCollection.isLiveRegion, isTrue, reason: code);
          expect(data.locale, Locale(code), reason: code);
          expect(tester.takeAnnouncements(), isEmpty, reason: code);
          expect(
            tester.widget<Text>(inSettings(find.text(text))).style?.color,
            UnaColors.error,
          );
          handle.dispose();
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'CA-015-12: dos fallos seguidos dan dos anuncios (un nodo nuevo cada vez) sin duplicar el nodo',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = SettingsRepo()..error = Exception('x');
        await openSettingsScreen(tester, repo: repo, screenReader: true);
        await _tapKeepAwake(tester);
        expect(find.bySemanticsLabel(_saveError), findsOneWidget);
        final first = _data(tester, _saveError);
        final firstId = tester
            .getSemantics(
              find.descendant(
                of: find.byType(LiveNotice),
                matching: find.bySemanticsLabel(_saveError),
              ),
            )
            .id;
        expect(first.flagsCollection.isLiveRegion, isTrue);

        await _tapKeepAwake(tester);
        expect(find.bySemanticsLabel(_saveError), findsOneWidget);
        final secondId = tester
            .getSemantics(
              find.descendant(
                of: find.byType(LiveNotice),
                matching: find.bySemanticsLabel(_saveError),
              ),
            )
            .id;
        expect(secondId, isNot(firstId), reason: 'un nodo nuevo por intento');
        expect(repo.keepWrites, [true, true]);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-12: se quita con la siguiente acción con éxito (un guardado que sale bien)',
      (tester) async {
        final repo = SettingsRepo()..error = Exception('x');
        await openSettingsScreen(tester, repo: repo);
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsOneWidget);
        repo.error = null;
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsNothing);
        expect(repo.keepWrites, [true, true]);
      },
    );

    testWidgets(
      'CA-015-12: se quita con la siguiente acción con éxito sobre otro control (abrir una web)',
      (tester) async {
        final repo = SettingsRepo()..error = Exception('x');
        final opener = await openSettingsScreen(tester, repo: repo);
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsOneWidget);
        await tester.tap(inSettings(find.text('Política de privacidad')));
        await settleSettings(tester);
        expect(opener.opened, hasLength(1));
        expect(_saveNotice, findsNothing);
      },
    );

    testWidgets('CA-015-12: se quita al salir del nivel (abrir Idioma)', (
      tester,
    ) async {
      final repo = SettingsRepo()..error = Exception('x');
      await openSettingsScreen(tester, repo: repo);
      await _tapKeepAwake(tester);
      expect(_saveNotice, findsOneWidget);
      await tester.tap(inSettings(find.text('Idioma')));
      await settleSettings(tester);
      await tester.binding.handlePopRoute();
      await settleSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(_saveNotice, findsNothing);
    });

    testWidgets(
      'CA-015-25: no mueve el foco y el texto del error no sale por ningún canal',
      (tester) async {
        final printed = <String>[];
        final oldDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
        FlutterErrorDetails? reported;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) => reported = details;
        final repo = SettingsRepo()..error = Exception('texto-secreto');
        await openSettingsScreen(tester, repo: repo);
        final focusBefore = FocusManager.instance.primaryFocus;
        await _tapKeepAwake(tester);
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        expect(find.textContaining('texto-secreto'), findsNothing);
        expect(printed.join(), isNot(contains('texto-secreto')));
        expect(reported, isNull);
        FlutterError.onError = oldOnError;
        debugPrint = oldDebugPrint;
      },
    );
  });

  group('El aviso de enlace (CA-015-12b)', () {
    testWidgets(
      'CA-015-12b: sin app, sale tras Ayuda como región viva con la marca de idioma, sin mover el foco',
      (tester) async {
        final handle = tester.ensureSemantics();
        final opener = FakeOpener()..available = false;
        await openSettingsScreen(tester, opener: opener, screenReader: true);
        tester.takeAnnouncements();
        final focusBefore = FocusManager.instance.primaryFocus;
        await _tapHelp(tester);
        expect(opener.opened, isEmpty);
        expect(_noAppNotice, findsOneWidget);
        expect(
          tester.getTopLeft(find.text(_noApp)).dy,
          greaterThan(tester.getBottomLeft(find.text('Ayuda')).dy),
          reason: 'bajo el bloque de Información y Ayuda',
        );
        final data = _data(tester, _noApp);
        expect(data.flagsCollection.isLiveRegion, isTrue);
        expect(data.locale, const Locale('es'));
        expect(tester.takeAnnouncements(), isEmpty);
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-12b: sale una sola vez, bajo las tres filas, sea cual sea la tocada',
      (tester) async {
        final opener = FakeOpener()..available = false;
        await openSettingsScreen(tester, opener: opener);
        for (final name in [
          'Política de privacidad',
          'Licencias de terceros',
          'Ayuda',
        ]) {
          await tester.tap(inSettings(find.text(name)));
          await settleSettings(tester);
          expect(_noAppNotice, findsOneWidget, reason: name);
        }
      },
    );

    testWidgets(
      'CA-015-12: dos fallos seguidos dan dos anuncios sin duplicar el nodo',
      (tester) async {
        final handle = tester.ensureSemantics();
        final opener = FakeOpener()..available = false;
        await openSettingsScreen(tester, opener: opener, screenReader: true);
        int id() => tester
            .getSemantics(
              find.descendant(
                of: find.byType(LiveNotice),
                matching: find.bySemanticsLabel(_noApp),
              ),
            )
            .id;
        await _tapHelp(tester);
        final first = id();
        await _tapHelp(tester);
        expect(find.bySemanticsLabel(_noApp), findsOneWidget);
        expect(id(), isNot(first));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-12: se quita en cuanto hay app otra vez, aunque después se cancele, y con un guardado que sale bien',
      (tester) async {
        final opener = FakeOpener()..available = false;
        await openSettingsScreen(tester, opener: opener);
        await _tapHelp(tester);
        expect(_noAppNotice, findsOneWidget);
        // Un guardado con éxito sobre otro control lo quita.
        await _tapKeepAwake(tester);
        expect(_noAppNotice, findsNothing);
        // De nuevo, y ahora hay app: se quita al abrir la web.
        await _tapHelp(tester);
        expect(_noAppNotice, findsOneWidget);
        opener.available = true;
        await _tapHelp(tester);
        expect(opener.opened, hasLength(1));
        expect(_noAppNotice, findsNothing);
      },
    );

    testWidgets('CA-015-12: se quita al salir del nivel (abrir Idioma)', (
      tester,
    ) async {
      final opener = FakeOpener()..available = false;
      await openSettingsScreen(tester, opener: opener);
      await _tapHelp(tester);
      expect(_noAppNotice, findsOneWidget);
      await tester.tap(inSettings(find.text('Idioma')));
      await settleSettings(tester);
      await tester.binding.handlePopRoute();
      await settleSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(_noAppNotice, findsNothing);
    });

    testWidgets(
      'CA-015-12b: con app pero que falla al abrir (open da false) sale el mismo aviso',
      (tester) async {
        final opener = FakeOpener()..openResult = false;
        await openSettingsScreen(tester, opener: opener);
        final before = focusedLabel(tester);
        await _tapHelp(tester);
        expect(opener.opened, hasLength(1));
        expect(_noAppNotice, findsOneWidget);
        expect(focusedLabel(tester), before);
      },
    );
  });

  group('Un aviso de guardado por fila (CA-017-04, P-017-1)', () {
    Finder keepRow() => find.byWidgetPredicate(
      (w) => w is UnaSwitchRow && w.label == _keepAwake,
    );
    Finder lockRow() => find.byWidgetPredicate(
      (w) => w is UnaSwitchRow && w.label == _lockZoom,
    );

    testWidgets(
      'CA-017-04: si falla "Bloquear zoom", el aviso sale bajo esa fila, el interruptor no cambia, el foco no se mueve y el texto del error no sale por ningún canal',
      (tester) async {
        final printed = <String>[];
        final oldDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
        FlutterErrorDetails? reported;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) => reported = details;
        final handle = tester.ensureSemantics();
        final repo = SettingsRepo()..lockError = Exception('texto-secreto');
        await openSettingsScreen(tester, repo: repo, screenReader: true);
        final focusBefore = FocusManager.instance.primaryFocus;
        tester.takeAnnouncements();
        await _tapLockZoom(tester);
        expect(repo.lockWrites, [true]);
        expect(_saveNotice, findsOneWidget);
        expect(
          tester.getTopLeft(_saveNotice).dy,
          greaterThan(tester.getBottomLeft(lockRow()).dy - 1),
          reason: 'bajo la fila de Bloquear zoom',
        );
        expect(
          tester.getTopLeft(inSettings(find.text('Información'))).dy,
          greaterThan(tester.getBottomLeft(_saveNotice).dy),
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(_lockLabel))
              .getSemanticsData()
              .flagsCollection
              .isToggled,
          Tristate.isFalse,
        );
        final data = _data(tester, _saveError);
        expect(data.flagsCollection.isLiveRegion, isTrue);
        expect(data.locale, const Locale('es'));
        expect(tester.takeAnnouncements(), isEmpty);
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        expect(find.textContaining('texto-secreto'), findsNothing);
        expect(printed.join(), isNot(contains('texto-secreto')));
        expect(reported, isNull);
        FlutterError.onError = oldOnError;
        debugPrint = oldDebugPrint;
        handle.dispose();
      },
    );

    testWidgets(
      'CA-017-04: el aviso de "Pantalla siempre activa" queda entre las dos filas',
      (tester) async {
        final repo = SettingsRepo()..error = Exception('x');
        await openSettingsScreen(tester, repo: repo);
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsOneWidget);
        expect(
          tester.getTopLeft(_saveNotice).dy,
          greaterThan(tester.getBottomLeft(keepRow()).dy - 1),
        );
        expect(
          tester.getTopLeft(lockRow()).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(_saveNotice).dy),
          reason: 'la fila de Bloquear zoom va después del aviso',
        );
      },
    );

    testWidgets(
      'CA-017-04: los dos fallan a la vez sin claves repetidas, se leen cada uno tras su fila y una vez por fallo',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = SettingsRepo()
          ..error = Exception('x')
          ..lockError = Exception('y');
        await openSettingsScreen(tester, repo: repo, screenReader: true);
        await _tapKeepAwake(tester);
        await _tapLockZoom(tester);
        expect(tester.takeException(), isNull, reason: 'sin Duplicate keys');
        expect(_saveNotice, findsNWidgets(2));
        final order = readingOrder(tester);
        expect(order.sublist(order.length - 9, order.length - 5), [
          _keepLabel,
          _saveError,
          _lockLabel,
          _saveError,
        ]);
        // Cada fallo trae su nodo nuevo: otro intento en la misma fila cambia
        // solo el de esa fila.
        List<int> ids() => find
            .descendant(
              of: find.byType(LiveNotice),
              matching: find.text(_saveError),
            )
            .evaluate()
            .map(
              (e) => tester
                  .getSemantics(find.byElementPredicate((x) => x == e))
                  .id,
            )
            .toList();
        final before = ids();
        expect(before, hasLength(2));
        await _tapLockZoom(tester);
        final after = ids();
        expect(after, hasLength(2));
        expect(after[0], before[0], reason: 'el de la otra fila no se toca');
        expect(after[1], isNot(before[1]), reason: 'nodo nuevo por intento');
        expect(repo.keepWrites, [true]);
        expect(repo.lockWrites, [true, true]);
        handle.dispose();
      },
    );

    testWidgets(
      'P-017-1: con los dos avisos, guardar bien una fila quita solo el suyo y conserva su foco y su nodo',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = SettingsRepo()
          ..error = Exception('x')
          ..lockError = Exception('y');
        await openSettingsScreen(
          tester,
          repo: repo,
          screenReader: true,
          keyboard: true,
        );
        await _tapKeepAwake(tester);
        await _tapLockZoom(tester);
        expect(_saveNotice, findsNWidgets(2));
        // El foco va a la fila de Bloquear zoom y se guarda bien.
        final lockState = tester.state(lockRow());
        final lockNode = tester
            .getSemantics(find.bySemanticsLabel(_lockLabel))
            .id;
        Focus.of(tester.element(find.text(_lockZoom))).requestFocus();
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        repo.lockError = null;
        await _tapLockZoom(tester);
        expect(repo.lockWrites, [true, true]);
        expect(_saveNotice, findsOneWidget, reason: 'el de la otra fila sigue');
        expect(
          tester.getTopLeft(_saveNotice).dy,
          lessThan(tester.getTopLeft(lockRow()).dy),
          reason: 'el que queda es el de Pantalla siempre activa',
        );
        expect(tester.state(lockRow()), same(lockState));
        expect(
          tester.getSemantics(find.bySemanticsLabel(_lockLabel)).id,
          lockNode,
        );
        expect(FocusManager.instance.primaryFocus, same(focus));
        handle.dispose();
      },
    );

    testWidgets(
      'CA-017-04: al quitarse el aviso de la fila de arriba, la fila de Bloquear zoom (con el foco) no se recrea',
      (tester) async {
        final repo = SettingsRepo()..error = Exception('x');
        await openSettingsScreen(tester, repo: repo, keyboard: true);
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsOneWidget);
        final lockState = tester.state(lockRow());
        Focus.of(tester.element(find.text(_lockZoom))).requestFocus();
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        expect(focus, isNotNull);
        repo.error = null;
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsNothing);
        expect(tester.state(lockRow()), same(lockState));
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(focusedLabel(tester), _lockZoom);
      },
    );

    testWidgets(
      'CA-017-04: al quitarse los dos avisos a la vez (abrir una web), la fila de Bloquear zoom con el foco no se recrea',
      (tester) async {
        final repo = SettingsRepo()
          ..error = Exception('x')
          ..lockError = Exception('y');
        final opener = await openSettingsScreen(
          tester,
          repo: repo,
          keyboard: true,
        );
        await _tapKeepAwake(tester);
        await _tapLockZoom(tester);
        expect(_saveNotice, findsNWidgets(2));
        final lockState = tester.state(lockRow());
        Focus.of(tester.element(find.text(_lockZoom))).requestFocus();
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        await tester.tap(inSettings(find.text('Política de privacidad')));
        await settleSettings(tester);
        expect(opener.opened, hasLength(1));
        expect(_saveNotice, findsNothing);
        expect(tester.state(lockRow()), same(lockState));
        expect(FocusManager.instance.primaryFocus, same(focus));
      },
    );

    testWidgets(
      'P-017-1: "el primero falla y el segundo guarda": el aviso del primero sigue',
      (tester) async {
        final repo = SettingsRepo()..gate = Completer<void>();
        await openSettingsScreen(tester, repo: repo);
        await tester.tap(inSettings(find.text(_keepAwake)));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(inSettings(find.text(_lockZoom)));
        await tester.pump(const Duration(milliseconds: 50));
        repo.error = Exception('x');
        repo.gate!.complete();
        await settleSettings(tester);
        expect(repo.keepWrites, [true]);
        expect(repo.lockWrites, [true], reason: 'el segundo se guarda');
        expect(await repo.keepScreenOn(), isFalse);
        expect(await repo.lockZoom(), isTrue);
        expect(
          _saveNotice,
          findsOneWidget,
          reason: 'el aviso del primero sigue',
        );
        expect(
          tester.getTopLeft(_saveNotice).dy,
          lessThan(tester.getTopLeft(lockRow()).dy),
        );
      },
    );

    testWidgets(
      'P-017-1: el aviso de una fila se quita cuando esa fila se guarda bien (también de Pantalla siempre activa, sin tocar el de la otra)',
      (tester) async {
        final repo = SettingsRepo()
          ..error = Exception('x')
          ..lockError = Exception('y');
        await openSettingsScreen(tester, repo: repo);
        await _tapKeepAwake(tester);
        await _tapLockZoom(tester);
        expect(_saveNotice, findsNWidgets(2));
        repo.error = null;
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsOneWidget);
        expect(
          tester.getTopLeft(_saveNotice).dy,
          greaterThan(tester.getTopLeft(lockRow()).dy),
          reason: 'el que queda es el de Bloquear zoom',
        );
        repo.lockError = null;
        await _tapLockZoom(tester);
        expect(_saveNotice, findsNothing);
      },
    );

    testWidgets(
      'P-017-1: los dos se quitan al salir del nivel (abrir Idioma) y al abrir una web con éxito',
      (tester) async {
        final repo = SettingsRepo()
          ..error = Exception('x')
          ..lockError = Exception('y');
        final opener = await openSettingsScreen(tester, repo: repo);
        await _tapKeepAwake(tester);
        await _tapLockZoom(tester);
        expect(_saveNotice, findsNWidgets(2));
        await tester.tap(inSettings(find.text('Política de privacidad')));
        await settleSettings(tester);
        expect(opener.opened, hasLength(1));
        expect(_saveNotice, findsNothing, reason: 'una web abierta con éxito');

        await _tapKeepAwake(tester);
        await _tapLockZoom(tester);
        expect(_saveNotice, findsNWidgets(2));
        await tester.tap(inSettings(find.text('Idioma')));
        await settleSettings(tester);
        await tester.binding.handlePopRoute();
        await settleSettings(tester);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(_saveNotice, findsNothing, reason: 'al salir del nivel');
      },
    );

    testWidgets(
      'CA-015-12b: un guardado de Bloquear zoom que sale bien quita el aviso de enlace',
      (tester) async {
        final opener = FakeOpener()..available = false;
        await openSettingsScreen(tester, opener: opener);
        await _tapHelp(tester);
        expect(_noAppNotice, findsOneWidget);
        await _tapLockZoom(tester);
        expect(_noAppNotice, findsNothing);
      },
    );

    testWidgets(
      'CA-017-04: con un repositorio lento, la segunda fila no se mueve ni avisa antes de su guardado',
      (tester) async {
        final repo = SettingsRepo()
          ..gate = Completer<void>()
          ..lockError = Exception('y');
        await openSettingsScreen(tester, repo: repo);
        await tester.tap(inSettings(find.text(_keepAwake)));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(inSettings(find.text(_lockZoom)));
        await tester.pump(const Duration(seconds: 2));
        expect(_saveNotice, findsNothing, reason: 'nada avisa todavía');
        expect(repo.lockWrites, isEmpty);
        repo.gate!.complete();
        await settleSettings(tester);
        expect(repo.lockWrites, [true]);
        expect(
          _saveNotice,
          findsOneWidget,
          reason: 'avisa al fallar su guardado',
        );
      },
    );

    testWidgets(
      'CA-017-04: el aviso de guardado al 200 % a 360 dp de la fila nueva queda dentro del área visible',
      (tester) async {
        final repo = SettingsRepo()..lockError = Exception('x');
        await openSettingsScreen(
          tester,
          textScale: 2,
          size: const Size(360, 640),
          repo: repo,
        );
        final viewport = tester.getRect(
          inSettings(find.byType(SingleChildScrollView)).first,
        );
        await _tapLockZoom(tester);
        expect(viewport.contains(tester.getCenter(_saveNotice)), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Los dos avisos a la vez (CA-015-20g, CA-015-21f)', () {
    testWidgets(
      'CA-015-20g / CA-017-04: se leen en el orden de la pantalla, el de guardado bajo su fila y el de enlace tras Ayuda, y antes de Cerrar ajustes',
      (tester) async {
        final handle = tester.ensureSemantics();
        final opener = FakeOpener()..available = false;
        final repo = SettingsRepo()..error = Exception('x');
        await openSettingsScreen(
          tester,
          opener: opener,
          repo: repo,
          screenReader: true,
        );
        await _tapKeepAwake(tester);
        await _tapHelp(tester);
        expect(_saveNotice, findsOneWidget);
        expect(_noAppNotice, findsOneWidget);
        const web = 'Abre una página web en el navegador';
        final order = readingOrder(tester);
        expect(order.sublist(order.length - 11), [
          'Ajustes',
          'Idioma, Como el sistema',
          _keepLabel,
          _saveError,
          _lockLabel,
          'Información',
          'Política de privacidad, $web',
          'Licencias de terceros, $web',
          'Ayuda, $web',
          _noApp,
          'Cerrar ajustes', // Lo último: ningún aviso va tras él.
        ]);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-015-21f: al 200 % a 360 dp cada aviso queda dentro del área visible tras aparecer',
      (tester) async {
        final opener = FakeOpener()..available = false;
        final repo = SettingsRepo()..error = Exception('x');
        await openSettingsScreen(
          tester,
          textScale: 2,
          size: const Size(360, 640),
          opener: opener,
          repo: repo,
        );
        final viewport = tester.getRect(
          inSettings(find.byType(SingleChildScrollView)).first,
        );
        await _tapKeepAwake(tester);
        expect(
          viewport.contains(tester.getCenter(_saveNotice)),
          isTrue,
          reason: 'el aviso de guardado se lleva a la vista',
        );
        await _tapHelp(tester);
        expect(
          viewport.contains(tester.getCenter(_noAppNotice)),
          isTrue,
          reason: 'el aviso de enlace se lleva a la vista',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
