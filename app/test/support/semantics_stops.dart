import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las acciones de desplazar: lo único que puede ofrecer, sin nombre, un
/// contenedor de desplazamiento (CA-013-04, P-013-7).
const _scrollActions = {
  SemanticsAction.scrollUp,
  SemanticsAction.scrollDown,
  SemanticsAction.scrollLeft,
  SemanticsAction.scrollRight,
  SemanticsAction.scrollToOffset,
};

/// Descripción de cada "parada sin nombre" del árbol de accesibilidad actual
/// (CA-013-04): un nodo que el lector puede enfocar o activar (indicador de
/// enfocable o de botón, o acción `focus` o `tap`) y que no tiene etiqueta ni
/// valor. Recorre el árbol **entero** (no como `_readingOrder`, que se salta los
/// nodos sin etiqueta) y no mira los nodos ocultos ni los fundidos en su
/// padre (su información ya está en el nodo que los absorbe); las rutas
/// *offstage* no están en el árbol.
///
/// Lista vacía = sin paradas sin nombre. La única excepción son los
/// contenedores de desplazamiento: nodos cuyas **únicas** acciones son de
/// desplazar, sin indicador de enfocable ni de botón; así no se esconde un
/// fallo real (un nodo que además se puede tocar o enfocar sigue contando).
///
/// Hace falta `tester.ensureSemantics()` activo.
List<String> unnamedSemanticsStops(WidgetTester tester) {
  final root = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  final stops = <String>[];

  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent && !node.isInvisible) {
      final data = node.getSemanticsData();
      final flags = data.flagsCollection;
      final unnamed = data.label.isEmpty && data.value.isEmpty;
      final focusable = flags.isFocused != Tristate.none || flags.isButton;
      final interactive =
          focusable ||
          data.hasAction(SemanticsAction.focus) ||
          data.hasAction(SemanticsAction.tap);
      if (unnamed && interactive) {
        stops.add(
          'nodo ${node.id} ${node.rect}: '
          'focusable=${flags.isFocused != Tristate.none} button=${flags.isButton} '
          'focus=${data.hasAction(SemanticsAction.focus)} '
          'tap=${data.hasAction(SemanticsAction.tap)}',
        );
      }
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return stops;
}

/// Falla si hay alguna parada sin nombre (CA-013-04), con la lista de nodos.
void expectNoUnnamedSemanticsStops(WidgetTester tester) {
  expect(
    unnamedSemanticsStops(tester),
    isEmpty,
    reason: 'paradas del lector sin etiqueta ni valor',
  );
}

/// Si algún nodo visible ofrece solo acciones de desplazar (sin nombre, sin
/// enfocable ni botón): el contenedor de desplazamiento que CA-013-04 deja
/// pasar y que debe **conservar** sus acciones (CA-012-12).
bool hasScrollOnlyContainer(WidgetTester tester) {
  final root = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  var found = false;
  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent && !node.isInvisible) {
      final data = node.getSemanticsData();
      final flags = data.flagsCollection;
      final hasScroll = _scrollActions.any(data.hasAction);
      final other = SemanticsAction.values.any(
        (a) => data.hasAction(a) && !_scrollActions.contains(a),
      );
      if (hasScroll &&
          !other &&
          flags.isFocused == Tristate.none &&
          !flags.isButton &&
          data.label.isEmpty) {
        found = true;
      }
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(root);
  return found;
}
