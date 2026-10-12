import 'package:app/ui/una_icons.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const all = {
    'plus': UnaIcons.plus,
    'arrowRight': UnaIcons.arrowRight,
    'arrowLeft': UnaIcons.arrowLeft,
    'arrowUp': UnaIcons.arrowUp,
    'arrowDown': UnaIcons.arrowDown,
    'arrowToTop': UnaIcons.arrowToTop,
    'menu': UnaIcons.menu,
    'check': UnaIcons.check,
    'close': UnaIcons.close,
    'edit': UnaIcons.edit,
    'trash': UnaIcons.trash,
    'list': UnaIcons.list,
    'camera': UnaIcons.camera,
    'image': UnaIcons.image,
    'document': UnaIcons.document,
    'link': UnaIcons.link,
    'lock': UnaIcons.lock,
    'globe': UnaIcons.globe,
    'phone': UnaIcons.phone,
    'magnifierMinus': UnaIcons.magnifierMinus,
    'info': UnaIcons.info,
    'help': UnaIcons.help,
    'licenseFile': UnaIcons.licenseFile,
    'openWeb': UnaIcons.openWeb,
    'chevronRight': UnaIcons.chevronRight,
    'bell': UnaIcons.bell,
  };

  test('P12: los iconos del prototipo se dibujan dentro de su caja de 24', () {
    for (final MapEntry(key: name, value: icon) in all.entries) {
      for (final d in icon.paths) {
        final bounds = parseSvgPath(d).getBounds();
        expect(
          bounds.isEmpty && bounds.width == 0 && bounds.height == 0,
          isFalse,
          reason: name,
        );
        expect(bounds.left, greaterThanOrEqualTo(0), reason: name);
        expect(bounds.top, greaterThanOrEqualTo(0), reason: name);
        expect(bounds.right, lessThanOrEqualTo(24), reason: name);
        expect(bounds.bottom, lessThanOrEqualTo(24), reason: name);
      }
    }
  });

  test(
    'CA-017-01: la lupa con el signo menos es la del prototipo (tablero 16)',
    () {
      expect(UnaIcons.magnifierMinus.paths, [
        'M3 10a7 7 0 1 0 14 0a7 7 0 1 0 -14 0',
        'M15 15l6 6',
        'M7 10h6',
      ]);
      // El mango llega a (21, 21) y el signo menos cruza el centro del cristal.
      final handle = parseSvgPath('M15 15l6 6').getBounds();
      expect((handle.right, handle.bottom), (21, 21));
      final minus = parseSvgPath('M7 10h6').getBounds();
      expect((minus.left, minus.right, minus.top), (7, 13, 10));
    },
  );

  test(
    'CA-019-26: la campana es la del tablero 16 y cabe en la caja de 24',
    () {
      expect(UnaIcons.bell.paths, [
        'M6 17V11a6 6 0 0 1 12 0v6l2 2H4z',
        'M10 22h4',
      ]);
      expect(UnaIcons.bell.circles, isEmpty);
      // El badajo llega a y = 22 y el cuerpo ocupa de x = 4 a x = 20.
      final body = parseSvgPath('M6 17V11a6 6 0 0 1 12 0v6l2 2H4z').getBounds();
      expect((body.left, body.right, body.bottom), (4, 20, 19));
      expect(body.top, closeTo(5, 0.01));
      final clapper = parseSvgPath('M10 22h4').getBounds();
      expect((clapper.left, clapper.right, clapper.top), (10, 14, 22));
    },
  );

  testWidgets('CA-019-26: la campana es decorativa (sin nodo ni etiqueta)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: UnaIcon(UnaIcons.bell)),
      ),
    );
    expect(find.byType(UnaIcon), findsOneWidget);
    // La caja se dibuja pero ningún nodo semántico cuelga de ella.
    final root = tester
        .binding
        .renderViews
        .first
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!;
    final labelled = <String>[];
    void walk(SemanticsNode n) {
      final data = n.getSemanticsData();
      if (data.label.isNotEmpty || data.hint.isNotEmpty) {
        labelled.add(data.label);
      }
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(root);
    expect(labelled, isEmpty);
    expect(
      find.descendant(
        of: find.byType(UnaIcon),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  test('comandos relativos y arcos', () {
    final plus = parseSvgPath('M12 4v16M4 12h16').getBounds();
    expect(plus.left, 4);
    expect(plus.right, 20);
    expect(plus.top, 4);
    expect(plus.bottom, 20);
    // Arco del candado: de (8,7) a (16,7) por arriba (y mínima 3).
    final lock = parseSvgPath('M8 11V7a4 4 0 0 1 8 0v4').getBounds();
    expect(lock.top, closeTo(3, 0.01));
  });

  test('CA-015-19: la curva cúbica (C y c) del globo y de "Ayuda"', () {
    // Absoluta y relativa dan el mismo trazado.
    final abs = parseSvgPath('M12 3C15 6 15 18 12 21').getBounds();
    final rel = parseSvgPath('M12 3c3 3 3 15 0 18').getBounds();
    expect(rel, abs);
    expect(rel.bottom, 21);
    // Tras la curva, la posición actual es su punto final: `V14` sale de él.
    final help = parseSvgPath('M0 0c1 1 2 2 3 3V10').getBounds();
    expect(help.bottom, 10);
    expect(help.right, closeTo(3, 0.01));
  });

  test('un comando no admitido falla de forma explícita', () {
    expect(() => parseSvgPath('M0 0Q1 1 3 3'), throwsFormatException);
  });
}
