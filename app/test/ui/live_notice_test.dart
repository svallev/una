import 'package:app/app/theme/tokens.g.dart';
import 'package:app/app/una_app.dart';
import 'package:app/ui/live_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';
import '../support/pump_app.dart';

const _text = 'No se pudo guardar el ajuste.';

/// Una pantalla desplazable con filas y, debajo, el aviso (o ninguno).
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.rows = 3,
    this.shown = true,
    this.noticeFirst = false,
  });

  final int rows;
  final bool shown;

  /// El aviso va antes de las filas (para llevarlo a la vista desde abajo).
  final bool noticeFirst;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int attempt = 1;
  late bool shown = widget.shown;

  void fail() => setState(() {
    shown = true;
    attempt++;
  });

  void clear() => setState(() => shown = false);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shown && widget.noticeFirst)
            LiveNotice(text: _text, attempt: attempt),
          for (var i = 0; i < widget.rows; i++)
            SizedBox(height: 120, child: Text('Fila $i')),
          if (shown && !widget.noticeFirst)
            LiveNotice(text: _text, attempt: attempt),
        ],
      ),
    ),
  );
}

/// Como la app: el contenido lleva la marca de idioma de `appFrame`.
Future<GlobalKey<_HostState>> _pump(
  WidgetTester tester, {
  int rows = 3,
  bool shown = true,
  bool noticeFirst = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  Locale locale = const Locale('es'),
}) async {
  final key = GlobalKey<_HostState>();
  await pumpWithApp(
    tester,
    Builder(
      builder: (context) => appFrame(
        context,
        _Host(key: key, rows: rows, shown: shown, noticeFirst: noticeFirst),
      ),
    ),
    textScale: textScale,
    size: size,
    locale: locale,
  );
  return key;
}

SemanticsNode _node(WidgetTester tester) => tester.getSemantics(
  find.descendant(
    of: find.byType(LiveNotice),
    matching: find.bySemanticsLabel(_text),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('CA-015-12: el aviso es una región viva, con su texto y el '
      'color de error', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final data = _node(tester).getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(data.label, _text);
    final style = tester.widget<Text>(find.text(_text)).style!;
    expect(style.color, UnaColors.error);
    handle.dispose();
  });

  testWidgets('CA-015-12: el aviso hereda la marca de idioma de la app (es y '
      'en), sin ponerse una propia', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(_node(tester).getSemanticsData().locale, const Locale('es'));
    handle.dispose();

    final handle2 = tester.ensureSemantics();
    await _pump(tester, locale: const Locale('en'));
    expect(_node(tester).getSemanticsData().locale, const Locale('en'));
    handle2.dispose();
  });

  testWidgets('CA-015-12: dos fallos seguidos dan dos anuncios (un nodo '
      'nuevo cada vez) sin duplicar el nodo', (tester) async {
    final handle = tester.ensureSemantics();
    final host = await _pump(tester);
    final first = _node(tester).id;
    expect(find.bySemanticsLabel(_text), findsOneWidget);

    // Mismo texto otra vez: se retira y se vuelve a insertar.
    host.currentState!.fail();
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel(_text), findsOneWidget);
    final second = _node(tester).id;
    expect(second, isNot(first));

    host.currentState!.fail();
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel(_text), findsOneWidget);
    expect(_node(tester).id, isNot(second));
    handle.dispose();
  });

  testWidgets('CA-015-12: se quita sin dejar nodo', (tester) async {
    final handle = tester.ensureSemantics();
    final host = await _pump(tester);
    host.currentState!.clear();
    await tester.pump();
    expect(find.byType(LiveNotice), findsNothing);
    expect(find.bySemanticsLabel(_text), findsNothing);
    handle.dispose();
  });

  testWidgets('CA-015-12: no usa los anuncios del sistema', (tester) async {
    final announcements = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map && message['type'] == 'announce') {
          announcements.add(message);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    final host = await _pump(tester);
    host.currentState!.fail();
    await tester.pump();
    await tester.pump();
    expect(announcements, isEmpty);
  });

  testWidgets('CA-015-12: al aparecer queda a la vista (ensureVisible), '
      'también con el texto al 200 %', (tester) async {
    for (final scale in [1.0, 2.0]) {
      final host = await _pump(
        tester,
        rows: 12,
        shown: false,
        textScale: scale,
        size: const Size(360, 640),
      );
      final screen = tester.getRect(find.byType(Scaffold));
      host.currentState!.fail();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final rect = tester.getRect(find.text(_text));
      expect(
        rect.bottom,
        lessThanOrEqualTo(screen.bottom),
        reason: 'escala $scale: el aviso queda dentro de la pantalla',
      );
      expect(rect.top, greaterThanOrEqualTo(screen.top));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('CA-015-12: un nuevo fallo lleva el aviso otra vez a la vista', (
    tester,
  ) async {
    final host = await _pump(tester, rows: 12, size: const Size(360, 640));
    final screen = tester.getRect(find.byType(Scaffold));
    // El usuario se desplaza hacia arriba y el aviso sale de la vista.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text(_text)).top,
      greaterThan(screen.bottom),
      reason: 'el aviso salió de la ventana',
    );
    host.currentState!.fail();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final rect = tester.getRect(find.text(_text));
    expect(rect.top, greaterThanOrEqualTo(screen.top));
    expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
  });

  testWidgets('CA-015-12: con el aviso por encima de la ventana, un nuevo '
      'fallo lo trae a la vista hacia arriba', (tester) async {
    final host = await _pump(
      tester,
      rows: 12,
      noticeFirst: true,
      size: const Size(360, 640),
    );
    final screen = tester.getRect(find.byType(Scaffold));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text(_text)).bottom,
      lessThan(screen.top),
      reason: 'el aviso quedó sobre la ventana',
    );
    host.currentState!.fail();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final rect = tester.getRect(find.text(_text));
    expect(rect.top, greaterThanOrEqualTo(screen.top));
    expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
  });
}
