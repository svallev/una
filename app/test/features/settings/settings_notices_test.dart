import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/live_notice.dart';
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
      'CA-015-12: se quita con la siguiente acción con éxito sobre otro control (abrir una confirmación)',
      (tester) async {
        final repo = SettingsRepo()..error = Exception('x');
        await openSettingsScreen(tester, repo: repo);
        await _tapKeepAwake(tester);
        expect(_saveNotice, findsOneWidget);
        await tester.tap(inSettings(find.text('Política de privacidad')));
        await settleSettings(tester);
        expect(find.text('Cancelar'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await settleSettings(tester);
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
        // De nuevo, y ahora hay app: se quita al abrir la confirmación.
        await _tapHelp(tester);
        expect(_noAppNotice, findsOneWidget);
        opener.available = true;
        await _tapHelp(tester);
        expect(find.text('Cancelar'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await settleSettings(tester);
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
        await _tapHelp(tester);
        await tester.tap(find.text('Abrir'));
        await settleSettings(tester);
        expect(opener.opened, hasLength(1));
        expect(_noAppNotice, findsOneWidget);
        expect(focusedLabel(tester), 'Ayuda');
      },
    );
  });

  group('Los dos avisos a la vez (CA-015-20g, CA-015-21f)', () {
    testWidgets(
      'CA-015-20g: se leen en el orden de la pantalla, el de guardado bajo su fila y el de enlace tras Ayuda, y antes de Cerrar ajustes',
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
        expect(order.sublist(order.length - 10), [
          'Ajustes',
          'Idioma, Como el sistema',
          '$_keepAwake, Imágenes, documentos y web',
          _saveError,
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
