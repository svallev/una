import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.g.dart';
import 'crumple_keyframes.dart';

/// Papelera del arrugado (prototipo `.trash`: SVG de 64 × 76, trazo 3,2, sin
/// relleno, esquinas en inglete). La tapa gira sobre su esquina inferior
/// derecha (`lid`) y el cubo se aplasta sobre su base (`thud`).
class TrashCan extends StatelessWidget {
  const TrashCan({super.key, required this.pose});

  final TrashPose pose;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: pose.opacity,
    child: Transform.translate(
      offset: Offset(0, pose.dy),
      child: CustomPaint(
        size: const Size(UnaSizes.trashWidth, UnaSizes.trashHeight),
        painter: _TrashPainter(pose),
      ),
    ),
  );
}

class _TrashPainter extends CustomPainter {
  _TrashPainter(this.pose);
  final TrashPose pose;

  // Puntos de giro (`transform-box: fill-box`): la tapa, en su esquina
  // inferior derecha (58, 18); el cubo, en el centro de su base (32, 70).
  static const _lidOrigin = Offset(58, 18);
  static const _canOrigin = Offset(32, 70);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / UnaSizes.trashWidth,
      size.height / UnaSizes.trashHeight,
    );
    final paint = Paint()
      ..color = UnaColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = UnaSizes.trashStroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    // Tapa: M6 18h52 · M24 18v-7h16v7 con rotate(deg) translate(x, y).
    canvas.save();
    canvas.translate(_lidOrigin.dx, _lidOrigin.dy);
    canvas.rotate(pose.lidDeg * math.pi / 180);
    canvas.translate(pose.lidShift.dx, pose.lidShift.dy);
    canvas.translate(-_lidOrigin.dx, -_lidOrigin.dy);
    canvas.drawLine(const Offset(6, 18), const Offset(58, 18), paint);
    canvas.drawPath(
      Path()
        ..moveTo(24, 18)
        ..lineTo(24, 11)
        ..lineTo(40, 11)
        ..lineTo(40, 18),
      paint,
    );
    canvas.restore();

    // Cubo: M12 24l4 46h32l4-46z · M26 34v26M38 34v26 con scale(sx, sy).
    canvas.save();
    canvas.translate(_canOrigin.dx, _canOrigin.dy);
    canvas.scale(pose.canScaleX, pose.canScaleY);
    canvas.translate(-_canOrigin.dx, -_canOrigin.dy);
    canvas.drawPath(
      Path()
        ..moveTo(12, 24)
        ..lineTo(16, 70)
        ..lineTo(48, 70)
        ..lineTo(52, 24)
        ..close(),
      paint,
    );
    canvas.drawLine(const Offset(26, 34), const Offset(26, 60), paint);
    canvas.drawLine(const Offset(38, 34), const Offset(38, 60), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrashPainter old) => old.pose != pose;
}
