import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:app/app/locale_resolution.dart';
import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/theme/una_theme.dart';
import 'package:app/app/una_app.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/features/settings/language_page.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:app/features/settings/settings_route.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/live_notice.dart';
import 'package:app/ui/radio_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import '../../support/semantics_locales.dart';
import '../../support/semantics_stops.dart';

/// Repositorio de ajustes controlable: cada escritura de idioma espera a su
/// compuerta o falla con un texto que no debe verse.
class _Repo extends InMemoryTaskRepository {
  final locales = <LocaleChoice>[];
  Completer<void>? gate;
  Object? error;

  @override
  Future<void> setLocale(LocaleChoice choice) async {
    locales.add(choice);
    final g = gate;
    if (g != null) await g.future;
    if (error case final e?) throw e;
    await super.setLocale(choice);
  }
}

/// Foco que cuenta cuántas veces se le pide (CA-015-08: una sola vez).
class _CountingFocus extends FocusNode {
  int requests = 0;

  @override
  void requestFocus([FocusNode? scopeNode]) {
    requests++;
    super.requestFocus(scopeNode);
  }
}

/// Anfitrión de test: lo que será el nivel 1 (T-015-09). Muestra su idioma, abre
/// la página de Idioma y expone el foco de su fila.
class _Host extends StatelessWidget {
  const _Host({required this.focus, required this.semanticsKey});

  final FocusNode focus;
  final GlobalKey semanticsKey;

  static const hostPrefix = 'host:';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [
          Text('$hostPrefix${l10n.settingsTitle}'),
          InkWell(
            key: const ValueKey('open-language'),
            focusNode: focus,
            onTap: () => openLanguagePage(
              context,
              focus: focus,
              semantics: semanticsKey,
            ),
            child: Semantics(key: semanticsKey, child: const Text('abrir')),
          ),
        ],
      ),
    );
  }
}

/// La app como la monta `UnaApp` (idioma elegido, `appFrame`), con el anfitrión
/// de test en lugar de la tarea.
class _App extends ConsumerWidget {
  const _App({required this.focus, required this.semanticsKey});

  final FocusNode focus;
  final GlobalKey semanticsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(settingsProvider.select((s) => s.locale));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: UnaTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeOfChoice(choice),
      localeListResolutionCallback: choice == LocaleChoice.system
          ? (locales, _) => resolveAppLocale(locales)
          : null,
      builder: appFrame,
      home: _Host(focus: focus, semanticsKey: semanticsKey),
    );
  }
}

class _Env {
  _Env(this.repo, this.focus, this.container);
  final _Repo repo;
  final _CountingFocus focus;
  final ProviderContainer container;

  LocaleChoice get choice => container.read(settingsProvider).locale;
}

/// Monta la app con el sistema en [system] y [initial] guardado, y abre la
/// página de Idioma.
Future<_Env> _pump(
  WidgetTester tester, {
  Locale system = const Locale('es'),
  LocaleChoice initial = LocaleChoice.system,
  double textScale = 1.0,
  bool reduced = false,
  Size size = const Size(390, 844),
  bool open = true,
}) async {
  tester.platformDispatcher.localesTestValue = [system];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  await repo.setLocale(initial);
  repo.locales.clear();
  final focus = _CountingFocus();
  addTearDown(focus.dispose);
  final container = ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(repo),
      bootStateProvider.overrideWithValue(
        BootState(currentTask: null, firstRunDone: true, locale: initial),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _App(focus: focus, semanticsKey: GlobalKey()),
    ),
  );
  if (open) {
    await tester.tap(find.byKey(const ValueKey('open-language')));
    await tester.pumpAndSettle();
  }
  return _Env(repo, focus, container);
}

Finder _row(String label) => find.byWidgetPredicate(
  (w) => w is UnaRadioRow && w.label == label,
  description: 'UnaRadioRow "$label"',
);

Finder _mark(String label) =>
    find.descendant(of: _row(label), matching: find.byKey(UnaRadioRow.markKey));

Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.tap(_row(label));
  await tester.pump();
}

/// Cada fotograma del fundido de salida (160 ms).
Future<void> _eachFadeFrame(
  WidgetTester tester,
  void Function(int ms) check,
) async {
  for (var ms = 16; ms < UnaMotion.sheetOut.inMilliseconds; ms += 16) {
    await tester.pump(const Duration(milliseconds: 16));
    check(ms);
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('CA-015-07: la página', () {
    testWidgets('título, Volver y tres opciones en su orden, con la marca en '
        'la vigente', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, initial: LocaleChoice.es);
      expect(find.text('Idioma'), findsOneWidget);
      expect(find.bySemanticsLabel('Volver'), findsOneWidget);
      final system = tester.getTopLeft(find.text('Como el sistema')).dy;
      final es = tester.getTopLeft(_row('Español')).dy;
      final en = tester.getTopLeft(_row('English')).dy;
      expect(system < es && es < en, isTrue, reason: 'orden de las opciones');
      expect(_mark('Como el sistema'), findsNothing);
      expect(_mark('Español'), findsOneWidget);
      expect(_mark('English'), findsNothing);
      handle.dispose();
    });

    testWidgets('"Como el sistema" dice debajo el idioma que resulta, con el '
        'sistema en inglés o en un idioma que la app no admite', (
      tester,
    ) async {
      await _pump(tester, system: const Locale('en'));
      expect(
        tester.widget<UnaRadioRow>(_row('Same as system')).subtitle,
        'English',
      );
    });

    testWidgets('la vigente por defecto es "Como el sistema"', (tester) async {
      await _pump(tester);
      expect(_mark('Como el sistema'), findsOneWidget);
      expect(_mark('Español'), findsNothing);
    });

    testWidgets('las tres opciones forman un grupo de selección única con '
        '"checked" y sin ninguna parada de foco extra', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, initial: LocaleChoice.es);
      expectNoUnnamedSemanticsStops(tester);
      final data = allSemanticsData(tester);
      final system = data.singleWhere(
        (d) => d.label == 'Como el sistema, Español',
      );
      final es = data.singleWhere((d) => d.label == 'Español');
      final en = data.singleWhere((d) => d.label == 'English');
      for (final d in [system, es, en]) {
        expect(d.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(d.hasAction(SemanticsAction.tap), isTrue);
      }
      expect(es.flagsCollection.isChecked, CheckedState.isTrue);
      expect(en.flagsCollection.isChecked, CheckedState.isFalse);
      expect(system.flagsCollection.isChecked, CheckedState.isFalse);
      // El grupo no lleva etiqueta: ninguna parada con nombre más que Volver y
      // las tres opciones.
      final stops = [
        for (final d in data)
          if (d.hasAction(SemanticsAction.tap) || d.flagsCollection.isButton)
            d.label,
      ];
      expect(
        stops,
        unorderedEquals([
          'Volver',
          'Como el sistema, Español',
          'Español',
          'English',
        ]),
      );
      final group = data.singleWhere((d) => d.role == SemanticsRole.radioGroup);
      expect(group.label, isEmpty);
      handle.dispose();
    });

    testWidgets('es desplazable (los avisos y el 200 % caben)', (tester) async {
      await _pump(tester);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('CA-015-08: elegir un idioma', () {
    testWidgets('guardar → volver → aplicar: ni vuelve ni cambia hasta que el '
        'guardado termina', (tester) async {
      final env = await _pump(tester);
      env.repo.gate = Completer<void>();
      await _tapRow(tester, 'English');
      await tester.pump(const Duration(milliseconds: 50));
      expect(env.repo.locales, [LocaleChoice.en]);
      // Sin cambio optimista: la página sigue abierta, en español, con la
      // opción anterior marcada, y el anfitrión sin cambiar.
      expect(find.text('Idioma'), findsOneWidget);
      expect(_mark('Como el sistema'), findsOneWidget);
      expect(_mark('English'), findsNothing);
      expect(find.text('host:Ajustes'), findsNothing); // tapado por la página
      expect(env.choice, LocaleChoice.system);
      expect(env.focus.requests, 0);

      env.repo.gate!.complete();
      await tester.pump();
      expect(env.choice, LocaleChoice.en);
      await tester.pumpAndSettle();
      expect(find.text('Idioma'), findsNothing);
      expect(find.text('host:Settings'), findsOneWidget);
      expect(env.repo.locales, [LocaleChoice.en]);
      expect(await env.repo.locale(), LocaleChoice.en);
    });

    testWidgets('sin un fotograma mezclado: la página sale en el idioma '
        'anterior (texto y marca del lector) y Ajustes aparece en el nuevo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final env = await _pump(tester);
      await _tapRow(tester, 'English');
      // Primer fotograma tras elegir: el guardado ya terminó.
      var frames = 0;
      void check(int _) {
        frames++;
        // La página que sale: sigue en español, nunca en inglés.
        expect(find.text('Idioma'), findsOneWidget);
        expect(find.text('Language'), findsNothing);
        expect(find.text('Como el sistema'), findsOneWidget);
        expect(find.text('Same as system'), findsNothing);
        expect(find.bySemanticsLabel('Volver'), findsOneWidget);
        expect(find.bySemanticsLabel('Back'), findsNothing);
        // Lo de debajo, ya en inglés (nunca "Ajustes" en español).
        expect(find.text('host:Ajustes'), findsNothing);
        expect(find.text('host:Settings'), findsOneWidget);
        // Su marca de idioma para el lector.
        for (final d in allSemanticsData(tester)) {
          if (d.label == 'Idioma' || d.label == 'Volver') {
            expect(d.locale?.languageCode, 'es', reason: d.label);
          }
          if (d.label.startsWith(_Host.hostPrefix)) {
            expect(d.locale?.languageCode, 'en', reason: d.label);
          }
        }
      }

      check(0);
      await _eachFadeFrame(tester, check);
      expect(frames, greaterThan(5));
      expect(env.choice, LocaleChoice.en);
      await tester.pumpAndSettle();
      expect(find.text('Idioma'), findsNothing);
      handle.dispose();
    });

    testWidgets('el foco vuelve a la fila de debajo una sola vez, cuando la '
        'página ya se fue', (tester) async {
      final env = await _pump(tester);
      await _tapRow(tester, 'English');
      await tester.pump(const Duration(milliseconds: 100));
      expect(env.focus.requests, 0, reason: 'aún se está yendo');
      await tester.pumpAndSettle();
      expect(env.focus.requests, 1);
    });

    testWidgets('la misma opción solo vuelve: no escribe ni cambia el idioma, '
        'y el foco va a la fila', (tester) async {
      final env = await _pump(tester, initial: LocaleChoice.es);
      await _tapRow(tester, 'Español');
      await tester.pumpAndSettle();
      expect(env.repo.locales, isEmpty);
      expect(env.choice, LocaleChoice.es);
      expect(find.text('Idioma'), findsNothing);
      expect(find.text('host:Ajustes'), findsOneWidget);
      expect(env.focus.requests, 1);
    });

    testWidgets('error de guardado: la página se queda con la opción anterior '
        'y el aviso, sin cambiar de idioma ni mover el foco', (tester) async {
      final handle = tester.ensureSemantics();
      final env = await _pump(tester);
      env.repo.error = Exception('texto-secreto');
      final before = FocusManager.instance.primaryFocus;
      await _tapRow(tester, 'English');
      await tester.pump(const Duration(milliseconds: 50));
      expect(env.choice, LocaleChoice.system);
      expect(find.text('Idioma'), findsOneWidget);
      expect(_mark('Como el sistema'), findsOneWidget);
      expect(_mark('English'), findsNothing);
      expect(find.text('No se pudo guardar el ajuste.'), findsOneWidget);
      expect(find.textContaining('texto-secreto'), findsNothing);
      expect(FocusManager.instance.primaryFocus, before);
      expect(env.focus.requests, 0);
      // El aviso es una región viva con la marca del idioma de la app.
      final notice = semanticsLabelled(tester, 'No se pudo guardar el ajuste.');
      expect(notice.flagsCollection.isLiveRegion, isTrue);
      expect(notice.locale?.languageCode, 'es');
      handle.dispose();
    });

    testWidgets('dos fallos seguidos: un solo aviso, con intento nuevo cada '
        'vez; y tras uno que funciona, la página vuelve', (tester) async {
      final env = await _pump(tester);
      env.repo.error = Exception('texto-secreto');
      await _tapRow(tester, 'English');
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<LiveNotice>(find.byType(LiveNotice)).attempt, 1);
      await _tapRow(tester, 'English');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(LiveNotice), findsOneWidget);
      expect(tester.widget<LiveNotice>(find.byType(LiveNotice)).attempt, 2);
      expect(find.text('No se pudo guardar el ajuste.'), findsOneWidget);
      env.repo.error = null;
      await _tapRow(tester, 'English');
      await tester.pumpAndSettle();
      expect(env.choice, LocaleChoice.en);
      expect(find.text('Idioma'), findsNothing);
    });

    testWidgets('CL-015-1: mientras se guarda, otros toques se ignoran (ni '
        'un segundo guardado ni dos vueltas)', (tester) async {
      final env = await _pump(tester);
      env.repo.gate = Completer<void>();
      await _tapRow(tester, 'English');
      await _tapRow(tester, 'English');
      await _tapRow(tester, 'Español');
      // Ni siquiera la opción vigente vuelve mientras se guarda otra.
      await _tapRow(tester, 'Como el sistema');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Idioma'), findsOneWidget);
      expect(env.repo.locales, [LocaleChoice.en]);
      env.repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(env.repo.locales, [LocaleChoice.en]);
      expect(env.choice, LocaleChoice.en);
      expect(find.text('host:Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(env.focus.requests, 1);
    });

    testWidgets('CL-015-1: elegir la misma opción dos veces vuelve una sola '
        'vez', (tester) async {
      final env = await _pump(tester, initial: LocaleChoice.es);
      final row = tester.widget<UnaRadioRow>(_row('Español'));
      // Dos toques seguidos (el segundo con la página ya subiendo).
      row.onTap();
      row.onTap();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('host:Ajustes'), findsOneWidget);
      expect(env.focus.requests, 1);
    });

    testWidgets('Volver sube sin guardar nada', (tester) async {
      final env = await _pump(tester);
      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pumpAndSettle();
      expect(env.repo.locales, isEmpty);
      expect(find.text('Idioma'), findsNothing);
      expect(env.focus.requests, 1);
    });

    testWidgets('Volver mientras se guarda: lo guardado se aplica igual (la '
        'app y lo persistido no discrepan)', (tester) async {
      final env = await _pump(tester);
      env.repo.gate = Completer<void>();
      await _tapRow(tester, 'English');
      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Idioma'), findsNothing);
      expect(env.choice, LocaleChoice.system);
      env.repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(await env.repo.locale(), LocaleChoice.en);
      expect(env.choice, LocaleChoice.en);
      expect(find.text('host:Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con reducir movimiento todo ocurre en el mismo fotograma', (
      tester,
    ) async {
      final env = await _pump(tester, reduced: true);
      await _tapRow(tester, 'English');
      expect(env.choice, LocaleChoice.en);
      expect(find.text('Idioma'), findsNothing);
      expect(find.text('Language'), findsNothing);
      expect(find.text('host:Settings'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(env.focus.requests, 1);
    });

    testWidgets('de inglés a español, igual (sin un fotograma mezclado)', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        system: const Locale('en'),
        initial: LocaleChoice.en,
      );
      await _tapRow(tester, 'Español');
      void check(int _) {
        expect(find.text('Language'), findsOneWidget);
        expect(find.text('Idioma'), findsNothing);
        expect(find.text('host:Ajustes'), findsOneWidget);
        expect(find.text('host:Settings'), findsNothing);
      }

      check(0);
      await _eachFadeFrame(tester, check);
      await tester.pumpAndSettle();
      expect(env.choice, LocaleChoice.es);
    });
  });

  group('CA-015-07 y CL-015-13: el idioma que resulta', () {
    testWidgets('con "Como el sistema", un cambio del idioma del sistema con '
        'la página abierta cambia los textos y la línea de debajo, en su '
        'sitio', (tester) async {
      final env = await _pump(tester);
      expect(find.text('Idioma'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Idioma'), findsNothing);
      expect(
        tester.widget<UnaRadioRow>(_row('Same as system')).subtitle,
        'English',
      );
      // Sin salir de la página ni mover el foco.
      expect(env.focus.requests, 0);
    });

    testWidgets('con un idioma elegido los textos no cambian, y la línea de '
        '"Como el sistema" sigue al sistema', (tester) async {
      await _pump(tester, initial: LocaleChoice.es);
      expect(
        tester.widget<UnaRadioRow>(_row('Como el sistema')).subtitle,
        'Español',
      );
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Idioma'), findsOneWidget);
      expect(
        tester.widget<UnaRadioRow>(_row('Como el sistema')).subtitle,
        'English',
      );
    });

    testWidgets('un idioma del sistema que la app no admite se resuelve como '
        'la regla de la 010 (catalán → español, francés → inglés)', (
      tester,
    ) async {
      await _pump(tester, system: const Locale('ca'));
      expect(
        tester.widget<UnaRadioRow>(_row('Como el sistema')).subtitle,
        'Español',
      );
      tester.platformDispatcher.localesTestValue = [const Locale('fr')];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<UnaRadioRow>(_row('Same as system')).subtitle,
        'English',
      );
    });
  });

  group('CA-015-11: lo que oye el lector', () {
    for (final (app, system) in [('es', 'en'), ('en', 'es')]) {
      testWidgets('app en "$app" y sistema en "$system": todo lleva "$app" '
          'salvo "Español" y "English"', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          system: Locale(system),
          initial: app == 'es' ? LocaleChoice.es : LocaleChoice.en,
        );
        expect(localeMarksOutsideApp(tester, app), isEmpty);
        handle.dispose();
      });

      testWidgets('app en "$app": "Español" y "English" llevan su propio '
          'idioma, también en "Como el sistema"', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          system: Locale(system),
          initial: app == 'es' ? LocaleChoice.es : LocaleChoice.en,
        );
        final es = semanticsLabelled(tester, 'Español');
        final en = semanticsLabelled(tester, 'English');
        expect(localeOfName(es, 'Español')?.languageCode, 'es');
        expect(localeOfName(en, 'English')?.languageCode, 'en');
        // "Como el sistema" va en el idioma de la app y su línea de debajo, en
        // el suyo (el idioma que resulta del sistema).
        final resulting = system == 'es' ? 'Español' : 'English';
        final name = app == 'es' ? 'Como el sistema' : 'Same as system';
        final label = semanticsLabelled(tester, '$name, $resulting');
        expect(localeOfName(label, name)?.languageCode, app);
        expect(localeOfName(label, resulting)?.languageCode, system);
        handle.dispose();
      });
    }
  });

  group('CA-015-22: texto grande y movimiento', () {
    for (final (system, initial) in [
      ('es', LocaleChoice.system),
      ('en', LocaleChoice.system),
    ]) {
      testWidgets('200 % a 360 dp en "$system": sin cortes ni desbordes, con '
          'la línea de debajo y el aviso', (tester) async {
        final env = await _pump(
          tester,
          system: Locale(system),
          initial: initial,
          textScale: 2.0,
          size: const Size(360, 780),
        );
        env.repo.error = Exception('x');
        final l10n = lookupAppLocalizations(Locale(system));
        final resulting = system == 'es' ? 'Español' : 'English';
        // La línea de debajo está entera, dentro del ancho.
        final subtitle = find.descendant(
          of: _row(l10n.settingsLanguageSystem),
          matching: find.text(resulting),
        );
        expect(subtitle, findsOneWidget);
        expect(tester.getRect(subtitle).right, lessThanOrEqualTo(360));
        await tester.tap(_row(system == 'es' ? 'English' : 'Español'));
        await tester.pump(const Duration(milliseconds: 50));
        final notice = find.text(l10n.settingsSaveError);
        expect(notice, findsOneWidget);
        // El aviso queda a la vista.
        final rect = tester.getRect(notice);
        expect(rect.bottom, lessThanOrEqualTo(780));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el fundido de la ruta dura 160 ms, o 0 con reducir '
        'movimiento', (tester) async {
      Duration? normal;
      Duration? reduced;
      for (final disable in [false, true]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: disable),
            child: Builder(
              builder: (context) {
                final route = settingsRoute<void>(
                  context,
                  (_) => const SizedBox(),
                );
                final d = (route as PageRouteBuilder<void>).transitionDuration;
                if (disable) {
                  reduced = d;
                } else {
                  normal = d;
                }
                return const SizedBox();
              },
            ),
          ),
        );
      }
      expect(normal, UnaMotion.sheetOut);
      expect(reduced, Duration.zero);
    });
  });
}
