import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/settings/external_page.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:app/ui/live_notice.dart';
import 'package:app/ui/settings_row.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fonts.dart';
import '../../support/pump_app.dart';

// Tres direcciones distintas (CA-015-13a), con dominios que no son los
// marcadores: así se ve que cada fila usa la suya.
const _links = SettingsLinks(
  privacy: 'https://privacidad.una-prueba.org/privacy',
  licenses: 'https://licencias.una-prueba.org/licenses',
  help: 'https://ayuda.una-prueba.org/help',
);

const _noApp = 'No hay ninguna app para abrir este enlace.';

final _labels = {
  ExternalLink.privacy: 'Política de privacidad',
  ExternalLink.licenses: 'Licencias de terceros',
  ExternalLink.help: 'Ayuda',
};

/// Una pantalla mínima con las tres filas de web y el aviso bajo ellas (la de
/// verdad es de T-015-09).
class _Host extends ConsumerStatefulWidget {
  const _Host({super.key, this.links = _links});

  final SettingsLinks links;

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  final session = ExternalPageSession();
  final focus = {
    for (final k in ExternalLink.values) k: FocusNode(debugLabel: k.name),
  };
  final keys = {for (final k in ExternalLink.values) k: GlobalKey()};

  @override
  void dispose() {
    session.dispose();
    for (final f in focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final kind in ExternalLink.values)
              SettingsRow(
                icon: UnaIcons.document,
                label: switch (kind) {
                  ExternalLink.privacy => l10n.settingsPrivacy,
                  ExternalLink.licenses => l10n.settingsThirdPartyLicenses,
                  ExternalLink.help => l10n.settingsHelp,
                },
                opensWebHint: l10n.settingsOpensWebHint,
                focusNode: focus[kind],
                semanticsKey: keys[kind],
                onTap: () => openExternalPage(
                  context,
                  ref,
                  kind,
                  session: session,
                  links: widget.links,
                ),
              ),
            ListenableBuilder(
              listenable: session,
              builder: (context, _) => session.noApp
                  ? LiveNotice(
                      text: AppLocalizations.of(context).errNoAppForLink,
                      attempt: session.attempt,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// El canal `una/links` falso: apunta cada llamada y contesta lo que se le diga.
class _Channel {
  _Channel(this.messenger) {
    messenger.setMockMethodCallHandler(const MethodChannel('una/links'), (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'canOpen') {
        final gate = canOpenGate;
        if (gate != null) await gate.future;
        return canOpen;
      }
      final gate = openGate;
      if (gate != null) await gate.future;
      return open;
    });
  }

  final TestDefaultBinaryMessenger messenger;
  final calls = <MethodCall>[];
  bool canOpen = true;
  bool open = true;

  /// Si no es null, `canOpen` espera a que se complete.
  Completer<void>? canOpenGate;

  /// Si no es null, `open` espera a que se complete.
  Completer<void>? openGate;

  List<String> get methods => [for (final c in calls) c.method];
  Iterable<MethodCall> named(String m) => calls.where((c) => c.method == m);
  void dispose() => messenger.setMockMethodCallHandler(
    const MethodChannel('una/links'),
    null,
  );
}

_Channel _channel(WidgetTester tester) {
  final c = _Channel(tester.binding.defaultBinaryMessenger);
  addTearDown(c.dispose);
  return c;
}

Future<GlobalKey<_HostState>> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('es'),
  SettingsLinks links = _links,
  List<Override> overrides = const [],
}) async {
  final key = GlobalKey<_HostState>();
  await pumpWithApp(
    tester,
    Builder(
      builder: (context) => appFrame(context, _Host(key: key, links: links)),
    ),
    locale: locale,
    overrides: overrides,
  );
  await tester.pumpAndSettle();
  return key;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, ExternalLink kind) async {
  await tester.tap(find.text(_labels[kind]!));
  await _settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  for (final kind in ExternalLink.values) {
    final uri = _links.of(kind);

    testWidgets(
      'CA-015-12a (${kind.name}): canOpen → open, una vez y con la dirección de '
      'la fila, sin ninguna ruta nueva entre el toque y open',
      (tester) async {
        final ch = _channel(tester);
        final h = await _pump(tester);
        final route = ModalRoute.of(h.currentContext!)!;
        final before = FocusManager.instance.primaryFocus;
        await tester.tap(find.text(_labels[kind]!));
        // Mientras se pregunta y se abre, no hay ruta ni hoja nueva.
        for (var i = 0; i < 3; i++) {
          await tester.pump();
          expect(route.isCurrent, isTrue);
          expect(find.byType(LinkConfirmSheet), findsNothing);
        }
        await _settle(tester);
        expect(route.isCurrent, isTrue);
        expect(ch.methods, ['canOpen', 'open']);
        expect(ch.calls.first.arguments, {'kind': 'web', 'uri': uri});
        expect(ch.calls.last.arguments, {'kind': 'web', 'uri': uri});
        expect(find.byType(LiveNotice), findsNothing);
        // No hay diálogo, así que el foco se queda donde estaba.
        expect(FocusManager.instance.primaryFocus, same(before));
      },
    );
  }

  testWidgets('CA-015-12a: canOpen se pregunta en cada toque, sin guardar la '
      'respuesta', (tester) async {
    final ch = _channel(tester)..canOpen = false;
    await _pump(tester);
    await _tap(tester, ExternalLink.privacy);
    expect(find.text(_noApp), findsOneWidget);
    expect(ch.named('open'), isEmpty);
    ch.canOpen = true;
    await _tap(tester, ExternalLink.privacy);
    await _tap(tester, ExternalLink.privacy);
    expect(ch.named('canOpen'), hasLength(3));
    expect(ch.named('open'), hasLength(2));
  });

  for (final url in [
    'http://ayuda.una-prueba.org/help',
    'ftp://ayuda.una-prueba.org/help',
    'https://usuario@ayuda.una-prueba.org/help',
    'javascript:alert(1)',
    'https://',
    '',
  ]) {
    for (final kind in ExternalLink.values) {
      testWidgets(
        'CA-015-12c / CL-015-12 (${kind.name}): "$url" no llama ni a canOpen ni '
        'a open y sale el aviso',
        (tester) async {
          final ch = _channel(tester);
          final links = SettingsLinks(
            privacy: kind == ExternalLink.privacy ? url : _links.privacy,
            licenses: kind == ExternalLink.licenses ? url : _links.licenses,
            help: kind == ExternalLink.help ? url : _links.help,
          );
          await _pump(tester, links: links);
          await _tap(tester, kind);
          expect(ch.calls, isEmpty);
          expect(find.text(_noApp), findsOneWidget);
        },
      );
    }
  }

  testWidgets('CA-015-12b: sin app, el aviso sale bajo las tres filas, es una '
      'región viva, y el foco no se mueve', (tester) async {
    final handle = tester.ensureSemantics();
    final ch = _channel(tester)..canOpen = false;
    await _pump(tester);
    final before = FocusManager.instance.primaryFocus;
    await _tap(tester, ExternalLink.licenses);
    expect(ch.named('open'), isEmpty);
    expect(find.text(_noApp), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(_noApp)).dy,
      greaterThan(tester.getBottomLeft(find.text('Ayuda')).dy),
      reason: 'una sola vez, bajo las tres filas',
    );
    final data = tester.getSemantics(find.text(_noApp)).getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(data.locale, const Locale('es'));
    expect(FocusManager.instance.primaryFocus, same(before));
    handle.dispose();
  });

  testWidgets('CA-015-12b: dos fallos seguidos dan dos avisos nuevos, sin '
      'duplicar el nodo', (tester) async {
    final handle = tester.ensureSemantics();
    _channel(tester).canOpen = false;
    await _pump(tester);
    await _tap(tester, ExternalLink.help);
    final first = tester.getSemantics(find.text(_noApp)).id;
    await _tap(tester, ExternalLink.help);
    expect(find.bySemanticsLabel(_noApp), findsOneWidget);
    expect(tester.getSemantics(find.text(_noApp)).id, isNot(first));
    handle.dispose();
  });

  testWidgets('CA-015-12b: sin app y en inglés, el aviso va en inglés', (
    tester,
  ) async {
    _channel(tester).canOpen = false;
    await _pump(tester, locale: const Locale('en'));
    await tester.tap(find.text('Help'));
    await _settle(tester);
    expect(find.text("There's no app to open this link."), findsOneWidget);
  });

  testWidgets('CA-015-12b: con app pero que falla al abrir (open false), '
      'aviso y el foco no se mueve', (tester) async {
    final ch = _channel(tester)..open = false;
    await _pump(tester);
    await tester.tap(find.text(_labels[ExternalLink.licenses]!));
    await tester.pump();
    final before = FocusManager.instance.primaryFocus;
    await _settle(tester);
    expect(ch.methods, ['canOpen', 'open']);
    expect(find.text(_noApp), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(before));
  });

  testWidgets(
    'CA-015-12b: el aviso se quita al abrir con éxito y se renueva en cada '
    'fallo',
    (tester) async {
      final ch = _channel(tester)..canOpen = false;
      await _pump(tester);
      await _tap(tester, ExternalLink.help);
      expect(find.text(_noApp), findsOneWidget);
      // Hay app pero `open` falla: sigue el aviso (nuevo intento).
      ch
        ..canOpen = true
        ..open = false;
      await _tap(tester, ExternalLink.help);
      expect(find.text(_noApp), findsOneWidget);
      // Abre con éxito: el aviso se va.
      ch.open = true;
      await _tap(tester, ExternalLink.help);
      expect(find.text(_noApp), findsNothing);
      expect(ch.named('open'), hasLength(2));
    },
  );

  testWidgets('CL-015-1: dos toques seguidos (también en filas distintas) '
      'abren una sola vez, mientras se comprueba canOpen y mientras se abre', (
    tester,
  ) async {
    final ch = _channel(tester)
      ..canOpenGate = Completer<void>()
      ..openGate = Completer<void>();
    await _pump(tester);
    await tester.tap(find.text(_labels[ExternalLink.privacy]!));
    await tester.pump();
    await tester.tap(find.text(_labels[ExternalLink.help]!));
    await tester.tap(find.text(_labels[ExternalLink.privacy]!));
    await tester.pump();
    ch.canOpenGate!.complete();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text(_labels[ExternalLink.licenses]!));
    await tester.pump();
    ch.openGate!.complete();
    await _settle(tester);
    expect(ch.methods, ['canOpen', 'open']);
    expect((ch.named('open').single.arguments as Map)['uri'], _links.privacy);
    // Terminado, el estado se libera: otra fila ya se puede abrir.
    ch
      ..canOpenGate = null
      ..openGate = null;
    await _tap(tester, ExternalLink.help);
    expect(ch.methods, ['canOpen', 'open', 'canOpen', 'open']);
  });

  testWidgets('CA-015-13a: la dirección es la misma con la app en es y en en, '
      'y las de AppIdentity no llevan ? ni #', (tester) async {
    final seen = <String>[];
    for (final locale in [const Locale('es'), const Locale('en')]) {
      final ch = _channel(tester);
      await _pump(tester, locale: locale, links: const SettingsLinks());
      await tester.tap(
        find.text(locale.languageCode == 'es' ? 'Ayuda' : 'Help'),
      );
      await _settle(tester);
      seen.add((ch.named('open').single.arguments as Map)['uri'] as String);
    }
    expect(seen[0], seen[1]);
    for (final kind in ExternalLink.values) {
      final a = const SettingsLinks().of(kind);
      expect(a, startsWith('https://'));
      expect(a, isNot(contains('?')));
      expect(a, isNot(contains('#')));
    }
  });

  testWidgets('CA-015-12: no se registra la dirección ni el error (debugPrint, '
      'print ni FlutterError), con un opener que lanza', (tester) async {
    final logged = <String>[];
    final oldDebugPrint = debugPrint;
    final oldOnError = FlutterError.onError;
    debugPrint = (message, {wrapWidth}) => logged.add('$message');
    FlutterError.onError = (d) => logged.add(d.toString());
    final failing = _ThrowingOpener();
    await runZoned(
      () async {
        await _pump(
          tester,
          overrides: [linkOpenerProvider.overrideWithValue(failing)],
        );
        await _tap(tester, ExternalLink.privacy);
        expect(find.text(_noApp), findsOneWidget);
        failing.throwOnOpen = true;
        failing.throwOnCanOpen = false;
        await _tap(tester, ExternalLink.help);
        expect(find.text(_noApp), findsOneWidget);
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    debugPrint = oldDebugPrint;
    FlutterError.onError = oldOnError;
    expect(tester.takeException(), isNull);
    final all = logged.join('\n');
    expect(all, isNot(contains('texto-secreto')));
    expect(all, isNot(contains('una-prueba.org')));
  });
}

class _ThrowingOpener implements LinkOpener {
  bool throwOnCanOpen = true;
  bool throwOnOpen = false;

  @override
  Future<bool> canOpen(LinkTarget target) async {
    if (throwOnCanOpen) throw Exception('texto-secreto');
    return true;
  }

  @override
  Future<bool> open(LinkTarget target) async {
    if (throwOnOpen) throw Exception('texto-secreto');
    return true;
  }
}
