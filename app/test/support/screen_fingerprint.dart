import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que se ve y lo que se lee de la pantalla en un momento dado: sirve para
/// comprobar que dos montajes (p. ej. con y sin "Bloquear zoom") son
/// **idénticos** (T-017-07, CA-017-06). Los ids de los nodos semánticos no
/// entran (cambian de un montaje a otro).
class Fingerprint {
  const Fingerprint({required this.reading, required this.pixels});

  /// Todo el árbol semántico: etiqueta, valor, pista, acciones (también las
  /// propias, por su nombre), banderas y rectángulo de cada nodo.
  final String reading;

  /// Los píxeles de la superficie entera (RGBA).
  final Uint8List pixels;
}

/// El árbol semántico actual, sin ids. Hace falta `tester.ensureSemantics()`.
String semanticsReading(WidgetTester tester) {
  final out = StringBuffer();
  void visit(SemanticsNode node, int depth) {
    final d = node.getSemanticsData();
    final f = d.flagsCollection;
    final custom = [
      for (final id in d.customSemanticsActionIds ?? const <int>[])
        CustomSemanticsAction.getAction(id)!.label,
    ];
    out.writeln(
      '${'  ' * depth}${d.label}|${d.value}|${d.hint}|${d.actions}|$custom|'
      '${f.isButton}${f.isImage}${f.isLiveRegion}${f.isHidden}'
      '${f.isFocused}${f.isToggled}|${node.rect}',
    );
    node.visitChildren((child) {
      visit(child, depth + 1);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
    0,
  );
  return out.toString();
}

/// Los píxeles de toda la superficie del test.
Future<Uint8List> screenPixels(WidgetTester tester) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final data = await tester.runAsync(() async {
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData();
    image.dispose();
    return bytes!;
  });
  return data!.buffer.asUint8List();
}

/// Foto fija de la pantalla: lectura y píxeles.
Future<Fingerprint> fingerprintOf(WidgetTester tester) async => Fingerprint(
  reading: semanticsReading(tester),
  pixels: await screenPixels(tester),
);

/// Falla si [a] y [b] no son iguales, con el primer píxel distinto o la
/// primera línea de la lectura que no coincide.
void expectSameFingerprint(Fingerprint a, Fingerprint b, {String? reason}) {
  final tag = reason == null ? '' : ' ($reason)';
  final linesA = a.reading.split('\n');
  final linesB = b.reading.split('\n');
  for (var i = 0; i < linesA.length && i < linesB.length; i++) {
    expect(linesB[i], linesA[i], reason: 'lectura, línea $i$tag');
  }
  expect(linesB.length, linesA.length, reason: 'líneas de lectura$tag');
  expect(b.pixels.length, a.pixels.length, reason: 'tamaño de la imagen$tag');
  var firstDiff = -1;
  var diffs = 0;
  for (var i = 0; i < a.pixels.length; i++) {
    if (a.pixels[i] == b.pixels[i]) continue;
    firstDiff = firstDiff < 0 ? i : firstDiff;
    diffs++;
  }
  expect(
    diffs,
    0,
    reason: 'píxeles distintos: $diffs (el primero, en el byte $firstDiff)$tag',
  );
}
