import 'package:app/ui/una_icons.dart';
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

  test('un comando no admitido falla de forma explícita', () {
    expect(() => parseSvgPath('M0 0C1 1 2 2 3 3'), throwsFormatException);
  });
}
