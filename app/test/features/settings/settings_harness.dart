import 'dart:async';

import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

/// Ayudantes de las pruebas de Ajustes (spec 015): abrir la pantalla desde el
/// menú de la tarea con la app completa, leer el orden del lector y el foco.

/// Abrir enlaces sin salir de la prueba: cuenta las preguntas y las
/// aperturas.
class FakeOpener implements LinkOpener {
  bool available = true;
  bool openResult = true;
  int canOpenCalls = 0;
  final opened = <LinkTarget>[];

  @override
  Future<bool> canOpen(LinkTarget target) async {
    canOpenCalls++;
    return available;
  }

  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return openResult;
  }
}

/// Repositorio cuyo guardado de "Pantalla siempre activa" se puede retener
/// ([gate]) o hacer fallar ([error]). Guarda lo escrito.
class SettingsRepo extends InMemoryTaskRepository {
  final keepWrites = <bool>[];
  Completer<void>? gate;
  Object? error;

  @override
  Future<void> setKeepScreenOn(bool value) async {
    keepWrites.add(value);
    final g = gate;
    if (g != null) await g.future;
    if (error case final e?) throw e;
    await super.setKeepScreenOn(value);
  }
}

/// Deja asentar la animación de una ruta y el temporizador del foco.
Future<void> settleSettings(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

/// Abre el menú de la tarea y "Ajustes" (el nivel 1) con la app completa.
/// Con [keyboard], la app está en modo teclado (anillo de foco visible). Con
/// [appLanguage], el idioma de la app si no es el del sistema ([locale]).
Future<FakeOpener> openSettingsScreen(
  WidgetTester tester, {
  Locale locale = const Locale('es'),
  bool screenReader = false,
  bool reduced = false,
  double textScale = 1.0,
  Size size = const Size(390, 844),
  double bottomInset = 0,
  FakeOpener? opener,
  InMemoryTaskRepository? repo,
  bool keyboard = false,
  String? appLanguage,
}) async {
  final o = opener ?? FakeOpener();
  if (keyboard) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
  }
  await pumpUnaApp(
    tester,
    repo: repo ?? InMemoryTaskRepository(),
    tasks: ['Primera', 'Segunda'],
    locale: locale,
    screenReader: screenReader,
    reduced: reduced,
    textScale: textScale,
    size: size,
    bottomInset: bottomInset,
    overrides: [linkOpenerProvider.overrideWithValue(o)],
  );
  // Los textos del menú son los del idioma de la app (por defecto, el del
  // sistema).
  final en = (appLanguage ?? locale.languageCode) == 'en';
  await tester.tap(
    find.bySemanticsLabel(en ? 'Task menu' : 'Menú de la tarea'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(en ? 'Settings' : 'Ajustes'));
  await settleSettings(tester);
  expect(find.byType(SettingsScreen), findsOneWidget);
  return o;
}

/// Lo que se busca solo dentro de Ajustes (la tarea sigue montada debajo).
Finder inSettings(Finder f) =>
    find.descendant(of: find.byType(SettingsScreen), matching: f);

/// Etiquetas de todos los nodos, en el orden en que los recorre el lector.
List<String> readingOrder(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) out.add(node.label);
    for (final c in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(c);
    }
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

/// Qué tiene el foco de teclado: la etiqueta del botón cuadrado, o el primer
/// texto que hay dentro del nodo enfocado.
String? focusedLabel(WidgetTester tester) {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return null;
  final icon = ctx.findAncestorWidgetOfExactType<SquareIconButton>();
  if (icon != null) return icon.label;
  final texts = find.descendant(
    of: find.byElementPredicate((e) => identical(e, ctx)),
    matching: find.byType(Text),
  );
  if (texts.evaluate().isEmpty) return null;
  return tester.widget<Text>(texts.first).data;
}
