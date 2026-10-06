import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/theme/tokens.g.dart';

/// Desplazamiento de la imagen de la tarea actual: por pasos del 80 % de la
/// pantalla, sin animar con reducir movimiento. Lo usan las acciones del
/// lector y Av Pág / Re Pág (CA-007-09, WCAG 2.1.1).
///
/// Con varias fotos (spec 016) cada una tiene su controlador: [controller] es
/// el de la que se ve y se intercambia al cambiar de foto.
class ImageScroll {
  ImageScroll(this.controller, this._reduced);

  /// El controlador de la foto que se ve.
  ScrollController controller;
  final bool Function() _reduced;

  /// La posición de la foto que se ve, si ya se ha medido (con un grupo, la
  /// de una foto recién montada aún no tiene dimensiones).
  ScrollPosition? get _position =>
      controller.hasClients && controller.position.hasContentDimensions
      ? controller.position
      : null;

  bool get canForward {
    final p = _position;
    return p != null && p.pixels < p.maxScrollExtent - 0.5;
  }

  bool get canBack {
    final p = _position;
    return p != null && p.pixels > p.minScrollExtent + 0.5;
  }

  void forward() => _by(1);
  void back() => _by(-1);

  void _by(int direction) {
    final p = _position;
    if (p == null) return;
    final to = (p.pixels + direction * p.viewportDimension * 0.8).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (_reduced()) {
      p.jumpTo(to);
    } else {
      unawaited(
        p.animateTo(
          to,
          duration: UnaMotion.imageZoomBack,
          curve: UnaMotion.standardCurve,
        ),
      );
    }
  }
}
