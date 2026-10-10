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

  /// Flecha hacia una línea arriba: "Hacer actual" (hoja "Mover", DEV-28;
  /// no está en el prototipo).
  static const arrowToTop = UnaIconData(['M5 4h14M12 21V9M6 14l6-6 6 6']);
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

  /// Flecha que da la vuelta hacia la izquierda: "Deshacer" de la card de
  /// deshacer (prototipo, `.undobtn`; spec 014).
  static const arrowUTurnLeft = UnaIconData([
    'M9 14L4 9l5-5',
    'M4 9h10a6 6 0 0 1 0 12h-3',
  ]);
  static const lock = UnaIconData([
    'M5 11h14v10H5z',
    'M8 11V7a4 4 0 0 1 8 0v4',
  ]);

  // Iconos de Ajustes (spec 015, tablero 16; `Main.dc.html`, pantalla de
  // Ajustes). Los círculos del prototipo son arcos de un path, no `<circle>`.

  /// Globo: "Idioma".
  static const globe = UnaIconData([
    'M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0',
    'M3 12h18',
    'M12 3c3 3 3 15 0 18',
    'M12 3c-3 3 -3 15 0 18',
  ]);

  /// Móvil: "Pantalla siempre activa".
  static const phone = UnaIconData(['M7 2h10v20H7z', 'M11 18h2']);

  /// Lupa con un signo menos: "Bloquear zoom" (spec 017, tablero 16).
  static const magnifierMinus = UnaIconData([
    'M3 10a7 7 0 1 0 14 0a7 7 0 1 0 -14 0',
    'M15 15l6 6',
    'M7 10h6',
  ]);

  /// Círculo con una "i": encabezado "Información".
  static const info = UnaIconData([
    'M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0',
    'M12 11v6',
    'M12 7v1',
  ]);

  /// Círculo con una interrogación: "Ayuda".
  static const help = UnaIconData([
    'M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0',
    'M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14',
    'M12 17v1',
  ]);

  /// Hoja con renglones: "Licencias de terceros".
  static const licenseFile = UnaIconData([
    'M6 2h9l4 4v16H6z',
    'M14 2v5h5',
    'M9 12h7',
    'M9 16h7',
  ]);

  /// Flecha que sale de un cuadro: "abre una web" (derecha de las filas).
  static const openWeb = UnaIconData([
    'M14 4h6v6',
    'M20 4l-9 9',
    'M18 14v6H4V6h6',
  ]);

  /// Chevron: la fila abre otro nivel ("Idioma").
  static const chevronRight = UnaIconData(['M9 5l7 7-7 7']);
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
/// comandos que usan los iconos del prototipo: M, L, H, V, C, Z y A.
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
      case 'C':
        final x1 = next(), y1 = next(), x2 = next(), y2 = next();
        final nx = next(), ny = next();
        path.cubicTo(
          rel ? x + x1 : x1,
          rel ? y + y1 : y1,
          rel ? x + x2 : x2,
          rel ? y + y2 : y2,
          rel ? x + nx : nx,
          rel ? y + ny : ny,
        );
        x = rel ? x + nx : nx;
        y = rel ? y + ny : ny;
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
