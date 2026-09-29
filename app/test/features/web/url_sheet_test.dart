import 'package:app/app/theme/tokens.g.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/sheet_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/focus.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Abre la hoja desde un botón y recoge lo que devuelve.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final results = <String?>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async => results.add(await showUrlSheet(context)),
        child: const Text('abrir-hoja'),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  late List<String> announcements;

  void listen(WidgetTester tester) {
    announcements = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
  }

  Future<_HostState> open(
    WidgetTester tester, {
    Locale locale = const Locale('es'),
    double textScale = 1.0,
    Size size = const Size(390, 844),
    bool reduced = false,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    listen(tester);
    await pumpWithApp(
      tester,
      const _Host(),
      locale: locale,
      textScale: textScale,
      size: size,
      disableAnimations: reduced,
      viewInsets: viewInsets,
    );
    await tester.tap(find.text('abrir-hoja'));
    await tester.pumpAndSettle();
    expect(find.byType(UrlSheet), findsOneWidget);
    return tester.state<_HostState>(find.byType(_Host));
  }

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  group('CA-009-20: con el teclado', () {
    testWidgets('spec §6 (WCAG 2.4.7): con Tab, la X de la hoja muestra el '
        'anillo de foco', (tester) async {
      await open(tester);
      expect(await tabUntilRing(tester, 'Cerrar'), isTrue);
    });

    testWidgets('la hoja sube sobre el teclado: campo y "Abrir" a la vista', (
      tester,
    ) async {
      const keyboard = 320.0;
      await open(tester, viewInsets: const EdgeInsets.only(bottom: keyboard));
      final top = 844 - keyboard;
      expect(tester.getRect(find.byType(TextField)).bottom, lessThan(top));
      expect(tester.getRect(find.byType(BrutalButton)).bottom, lessThan(top));
    });
  });

  group('CA-009-01: la hoja "Cargar URL"', () {
    testWidgets('título, X, campo, ayuda y botón, con el foco en el campo', (
      tester,
    ) async {
      await open(tester);
      final handle = tester.ensureSemantics();
      expect(find.text('CARGAR URL'), findsOneWidget);
      expect(find.bySemanticsLabel('Cerrar'), findsWidgets);
      expect(find.text('https://'), findsOneWidget);
      expect(find.text('Se abre como tarea, arriba del todo.'), findsOneWidget);
      expect(find.text('Abrir'), findsOneWidget);
      expect(field(tester).focusNode.hasFocus, isTrue);
      handle.dispose();
    });

    testWidgets(
      'teclado de URL, sin autocorrección, mayúscula inicial ni sugerencias',
      (tester) async {
        await open(tester);
        final editable = field(tester);
        expect(editable.keyboardType, TextInputType.url);
        expect(editable.autocorrect, isFalse);
        expect(editable.enableSuggestions, isFalse);
        expect(editable.textCapitalization, TextCapitalization.none);
        // El teclado no aprende de lo escrito (MASVS-STORAGE-2).
        expect(editable.enableIMEPersonalizedLearning, isFalse);
        expect(editable.autofillHints ?? const <String>[], isEmpty);
      },
    );

    testWidgets('la hoja da nombre a la ruta: el lector anuncia el título', (
      tester,
    ) async {
      await open(tester);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Cargar URL'), findsWidgets);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Cargar URL').first,
      );
      expect(node.label, 'Cargar URL');
      handle.dispose();
    });

    testWidgets('en inglés', (tester) async {
      await open(tester, locale: const Locale('en'));
      expect(find.text('LOAD URL'), findsOneWidget);
      expect(find.text('It opens as a task, on top.'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('se cierra con la X y devuelve null', (tester) async {
      final host = await open(tester);
      await tester.enterText(find.byType(TextField), 'ejemplo.com');
      await tester.tap(
        find.descendant(
          of: find.byType(SheetHeader),
          matching: find.byType(InkResponse),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UrlSheet), findsNothing);
      expect(host.results, [null]);
    });

    testWidgets('se cierra tocando fuera', (tester) async {
      final host = await open(tester);
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.byType(UrlSheet), findsNothing);
      expect(host.results, [null]);
    });

    testWidgets('se cierra con el gesto atrás', (tester) async {
      final host = await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UrlSheet), findsNothing);
      expect(host.results, [null]);
    });

    testWidgets('se cierra deslizando hacia abajo (DEV-21)', (tester) async {
      final host = await open(tester);
      await tester.fling(find.text('CARGAR URL'), const Offset(0, 500), 2000);
      await tester.pumpAndSettle();
      expect(find.byType(UrlSheet), findsNothing);
      expect(host.results, [null]);
    });
  });

  group('CA-009-02: validación', () {
    for (final (input, message) in [
      ('', 'Escribe una dirección web.'),
      ('   ', 'Escribe una dirección web.'),
      (
        'javascript:alert(1)',
        'Solo se admiten direcciones web (http o https).',
      ),
      (
        'data:text/html,hola',
        'Solo se admiten direcciones web (http o https).',
      ),
      ('file:///etc/passwd', 'Solo se admiten direcciones web (http o https).'),
      (
        'intent://x#Intent;end',
        'Solo se admiten direcciones web (http o https).',
      ),
      ('about:blank', 'Solo se admiten direcciones web (http o https).'),
      ('ftp://ejemplo.com', 'Solo se admiten direcciones web (http o https).'),
      ('localhost', 'Esa dirección no parece válida.'),
      ('intranet', 'Esa dirección no parece válida.'),
      ('10.0.0.1', 'Esa dirección no parece válida.'),
      ('192.168.1.5', 'Esa dirección no parece válida.'),
      ('http://127.0.0.1:8080', 'Esa dirección no parece válida.'),
      ('https://user:pass@ejemplo.com', 'Esa dirección no parece válida.'),
      ('https://ejemplo.com/${'a' * 2048}', 'Esa dirección no parece válida.'),
    ]) {
      testWidgets(
        'CA-009-02: "${input.length > 30 ? '${input.substring(0, 30)}…' : input}" '
        '→ $message',
        (tester) async {
          final host = await open(tester);
          await submit(tester, input);

          // La hoja sigue abierta, con el error bajo el campo y el texto en
          // su sitio.
          expect(find.byType(UrlSheet), findsOneWidget);
          expect(host.results, isEmpty);
          expect(find.text(message), findsOneWidget);
          expect(
            tester.getTopLeft(find.text(message)).dy,
            greaterThan(tester.getBottomLeft(find.byType(TextField)).dy),
          );
          expect(field(tester).controller.text, input);
          expect(field(tester).focusNode.hasFocus, isTrue);
          // Un único anuncio: el texto del error.
          expect(announcements, [message]);
        },
      );
    }

    testWidgets('WCAG 1.3.1 / 3.3.1: el error se lee con el campo (al volver '
        'a él, el lector lo dice) y una sola vez al recorrer la hoja', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      final before = tester.getSemantics(find.byType(TextField));
      expect(before.hint, isEmpty);
      await submit(tester, '');
      const message = 'Escribe una dirección web.';
      // Se ve bajo el campo.
      expect(find.text(message), findsOneWidget);
      final node = tester.getSemantics(find.byType(TextField));
      expect(node.label, startsWith('Cargar URL'));
      expect(node.hint, message);
      expect(
        node.getSemanticsData().validationResult,
        SemanticsValidationResult.invalid,
      );
      final read = [
        for (final n in tester.semantics.simulatedAccessibilityTraversal())
          ...[n.label, n.value, n.hint].where((t) => t.contains(message)),
      ];
      expect(read, [message]);
      // Al escribir, el campo deja de decirlo.
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pump();
      expect(tester.getSemantics(find.byType(TextField)).hint, isEmpty);
      handle.dispose();
    });

    testWidgets('el error se anuncia cada vez que se repite', (tester) async {
      await open(tester);
      await submit(tester, '');
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(announcements, [
        'Escribe una dirección web.',
        'Escribe una dirección web.',
      ]);
    });

    testWidgets('al escribir desaparece el error', (tester) async {
      await open(tester);
      await submit(tester, '');
      expect(find.text('Escribe una dirección web.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pump();
      expect(find.text('Escribe una dirección web.'), findsNothing);
    });

    for (final (input, url) in [
      ('ejemplo.com', 'https://ejemplo.com'),
      (
        '  https://www.ejemplo.com/programa  ',
        'https://www.ejemplo.com/programa',
      ),
      ('http://ejemplo.com/a', 'http://ejemplo.com/a'),
      ('ejemplo.com:8080/x', 'https://ejemplo.com:8080/x'),
    ]) {
      testWidgets('"$input" se acepta y devuelve la dirección normalizada', (
        tester,
      ) async {
        final host = await open(tester);
        await submit(tester, input);
        expect(find.byType(UrlSheet), findsNothing);
        expect(host.results, [url]);
        // Ningún anuncio al abrir (CA-009-19).
        expect(announcements, isEmpty);
      });
    }

    testWidgets('CA-009-20: Intro en el campo equivale a "Abrir"', (
      tester,
    ) async {
      final host = await open(tester);
      await tester.enterText(find.byType(TextField), 'ejemplo.com');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(host.results, ['https://ejemplo.com']);
    });

    testWidgets('Intro con un error lo muestra igual', (tester) async {
      final host = await open(tester);
      await tester.enterText(find.byType(TextField), 'localhost');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(host.results, isEmpty);
      expect(find.text('Esa dirección no parece válida.'), findsOneWidget);
    });
  });

  testWidgets('CA-009-03: un doble toque rápido en "Abrir" devuelve una vez', (
    tester,
  ) async {
    final host = await open(tester);
    await tester.enterText(find.byType(TextField), 'ejemplo.com');
    await tester.tap(find.text('Abrir'));
    await tester.tap(find.text('Abrir'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(host.results, ['https://ejemplo.com']);
    // No se ha cerrado nada más que la hoja.
    expect(find.text('abrir-hoja'), findsOneWidget);
  });

  testWidgets(
    'CA-009-20: al 200 % en 360 dp se ve entera y los botones miden >= 48',
    (tester) async {
      await open(tester, textScale: 2.0, size: const Size(360, 640));
      await submit(tester, 'localhost');
      expect(tester.takeException(), isNull);
      expect(find.text('Esa dirección no parece válida.'), findsOneWidget);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.byType(TextField),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(UnaSizes.urlField),
      );
      // "Abrir" es un BrutalButton (sin InkWell): se mide el botón entero.
      final button = tester.getSize(
        find.ancestor(
          of: find.text('Abrir'),
          matching: find.byType(BrutalButton),
        ),
      );
      expect(button.height, greaterThanOrEqualTo(48));
      final close = tester.getSize(
        find.descendant(
          of: find.byType(SheetHeader),
          matching: find.byType(InkResponse),
        ),
      );
      expect(close.height, greaterThanOrEqualTo(48));
    },
  );

  testWidgets('con reducir movimiento la hoja no se desliza', (tester) async {
    listen(tester);
    await pumpWithApp(tester, const _Host(), disableAnimations: true);
    await tester.tap(find.text('abrir-hoja'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(UrlSheet), findsOneWidget);
  });
}
