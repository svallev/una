import 'package:flutter/widgets.dart';

import '../app/theme/tokens.g.dart';

/// Un icono del sistema de diseño: trazados SVG (caja de 24 × 24) dibujados
/// con trazo, puntas cuadradas y uniones en ángulo, como la clase `.ic` del
/// prototipo (`design/prototype/Main.dc.html`). No se usan los iconos de Material.
@immutable
class UnaIconData {
  const UnaIconData(this.paths, {this.circles = const []});

  /// Datos `d` de cada `<path>` (M, L, H, V, Z y A, absolutos o relativos).
  final List<String> paths;

  /// Círculos `(cx, cy, r)`.
  final List<(double, double, double)> circles;
}

/// Iconos del prototipo. El nombre describe el dibujo, no la acción.
abstract final class UnaIcons {
  static const plus = UnaIconData(['M12 4v16M4 12h16']);
  static const arrowRight = UnaIconData(['M4 12h15M13 6l6 6-6 6']);
  static const arrowLeft = UnaIconData(['M20 12H5M11 6l-6 6 6 6']);
  static const arrowUp = UnaIconData(['M12 20V5M6 11l6-6 6 6']);
  static const arrowDown = UnaIconData(['M12 4v15M6 13l6 6 6-6']);
  static const menu = UnaIconData(['M4 7h16M4 12h16M4 17h16']);
  static const check = UnaIconData(['M4 12.5l5 5L20 6.5']);
  static const close = UnaIconData(['M5 5l14 14M19 5L5 19']);
  static const edit = UnaIconData(['M4 20h4L19 9l-4-4L4 16v4z', 'M13 7l4 4']);
  static const trash = UnaIconData([
    'M3 7h18M10 11v6M14 11v6M5 7l1 14h12l1-14M9 7V3h6v4',
  ]);
  static const list = UnaIconData([
    'M9 6h12M9 12h12M9 18h12M3 5h2v2H3zM3 11h2v2H3zM3 17h2v2H3z',
  ]);
  static const camera = UnaIconData(
    ['M3 8h4l2-3h6l2 3h4v12H3z'],
    circles: [(12, 13.5, 3.6)],
  );
  static const image = UnaIconData(
    ['M3 4h18v16H3z', 'M3 16l5-5 4 4 3-3 6 6'],
    circles: [(16, 8.5, 1.6)],
  );
  static const document = UnaIconData([
    'M6 2h9l5 5v15H6z',
    'M14 2v6h6M9 13h8M9 17h8',
  ]);
  static const link = UnaIconData([
    'M10 14l4-4',
    'M9 7l2-2a4 4 0 0 1 6 6l-2 2',
    'M15 17l-2 2a4 4 0 0 1-6-6l2-2',
  ]);
  static const lock = UnaIconData([
    'M5 11h14v10H5z',
    'M8 11V7a4 4 0 0 1 8 0v4',
  ]);
}

/// Dibuja un [UnaIconData]. Es decorativo: el nombre accesible lo pone el botón.
class UnaIcon extends StatelessWidget {
  const UnaIcon(
    this.icon, {
    super.key,
    this.size = UnaSizes.icon,
    this.strokeWidth = UnaSizes.iconStroke,
    this.color = UnaColors.ink,
  });

  final UnaIconData icon;
  final double size;

  /// Grosor del trazo en unidades de la caja de 24 (como `stroke-width` en SVG).
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _UnaIconPainter(icon, strokeWidth, color)),
      ),
    );
  }
}

class _UnaIconPainter extends CustomPainter {
  _UnaIconPainter(this.icon, this.strokeWidth, this.color);

  final UnaIconData icon;
  final double strokeWidth;
  final Color color;

  static const _box = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _box;
    canvas.scale(scale);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..color = color
      ..isAntiAlias = true;
    for (final d in icon.paths) {
      canvas.drawPath(parseSvgPath(d), paint);
    }
    for (final (cx, cy, r) in icon.circles) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_UnaIconPainter old) =>
      old.icon != icon || old.strokeWidth != strokeWidth || old.color != color;
}

/// Convierte el atributo `d` de un `<path>` SVG en un [Path]. Admite los
/// comandos que usan los iconos del prototipo: M, L, H, V, Z y A.
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'[A-Za-z]').hasMatch(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        startX = x;
        startY = y;
        path.moveTo(x, y);
        cmd = rel ? 'l' : 'L'; // Los pares siguientes son líneas.
      case 'L':
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
      case 'H':
        final nx = next();
        x = rel ? x + nx : nx;
        path.lineTo(x, y);
      case 'V':
        final ny = next();
        y = rel ? y + ny : ny;
        path.lineTo(x, y);
      case 'A':
        final rx = next(), ry = next(), rotation = next();
        final largeArc = next() != 0, sweep = next() != 0;
        final nx = next(), ny = next();
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Comando SVG no admitido: $cmd en "$d"');
    }
  }
  return path;
}
