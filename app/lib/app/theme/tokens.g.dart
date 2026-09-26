// GENERADO por tool/gen_tokens.dart desde design/tokens.json. No editar a mano.
// ignore_for_file: public_member_api_docs

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

abstract final class UnaColors {
  /// Tinta: texto, bordes, sombras duras y rellenos de mantener pulsado
  static const Color ink = Color(0xFF111111);

  /// Fondo de la app (papel)
  static const Color paper = Color(0xFFF4F1EA);

  /// Líneas y separadores
  static const Color line = Color(0xFFD8D4CA);

  /// Fondo del texto seleccionado (ink al 20 %)
  static const Color selection = Color(0x33111111);

  /// Botones, hojas inferiores y fondo tras adjuntos
  static const Color surface = Color(0xFFFFFFFF);

  /// Texto secundario (Space Mono)
  static const Color textMuted = Color(0xFF55534E);

  /// Elementos deshabilitados, sin contenido esencial
  static const Color disabled = Color(0xFFC7C4BF);

  /// Texto de error (p. ej. URL no válida)
  static const Color error = Color(0xFFB3241A);

  /// Relleno del botón Eliminar; el texto es ink
  static const Color dangerFill = Color(0xFFFF5A4E);

  /// Sombra dura de las mitades rotas (drop-shadow del prototipo)
  static const Color tearShadow = Color(0xD9111111);

  /// Fibra del papel roto al completar
  static const Color paperFiber = Color(0xFFFFFDF3);

  /// Texto sobre ink (etiquetas, pantalla de enhorabuena)
  static const Color onInk = Color(0xFFFFFFFF);

  /// Velo bajo las hojas inferiores
  static const Color scrim = Color(0x8C111111);

  /// Placeholder del editor. El prototipo usa 0.42 (contraste 2.5:1, falla AA); se sube a 0.66 (>= 4.59:1 en todas las notas). Ver docs/design/prototype-deviations.md
  static const Color placeholder = Color(0xA8111111);

  /// Fondo de una fila de menú pulsada
  static const Color pressed = Color(0x0F111111);
}

abstract final class UnaPalettes {
  static const List<Color> classic = [
    Color(0xFFFFE55C),
    Color(0xFFFF9EC4),
    Color(0xFF8FD3F4),
    Color(0xFFA6E88F),
    Color(0xFFFFB870),
  ];
  static const List<Color> neon = [
    Color(0xFFF4FF3A),
    Color(0xFFFF6FAE),
    Color(0xFF45E0FF),
    Color(0xFF63FF84),
    Color(0xFFFF9D3F),
  ];
  static const List<Color> mono = [
    Color(0xFFFFE55C),
    Color(0xFFFFE55C),
    Color(0xFFFFE55C),
    Color(0xFFFFE55C),
    Color(0xFFFFE55C),
  ];
}

abstract final class UnaFonts {
  static const String display = 'Archivo';
  static const String mono = 'Space Mono';
}

abstract final class UnaFontWeights {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;
}

abstract final class UnaFontSizes {
  /// Texto de tarea < 40 caracteres
  static const double noteXL = 50.0;

  /// 40–89 caracteres
  static const double noteL = 40.0;

  /// 90–159 caracteres
  static const double noteM = 31.0;

  /// >= 160 caracteres
  static const double noteS = 26.0;

  /// Estados vacíos (Todo hecho.)
  static const double hero = 56.0;

  /// Texto de la bienvenida
  static const double intro = 52.0;

  /// ¡Enhorabuena! Tarea completada.
  static const double success = 38.0;

  /// ¿Dónde la pones?
  static const double sheetTitle = 32.0;

  /// Título de cada opción de la hoja
  static const double option = 18.0;

  /// Enlaces subrayados en monoespaciada
  static const double link = 14.0;

  /// {value: 34, unit: px}
  static const double display = 34.0;

  /// {value: 26, unit: px}
  static const double title = 26.0;

  /// {value: 22, unit: px}
  static const double heading = 22.0;

  /// Botón de completar
  static const double button = 20.0;

  /// Filas de menú y botones
  static const double bodyL = 19.0;

  /// {value: 17, unit: px}
  static const double body = 17.0;

  /// {value: 15, unit: px}
  static const double bodyS = 15.0;

  /// {value: 13, unit: px}
  static const double caption = 13.0;

  /// Texto de la primera fila del listado (tarea actual)
  static const double listFirst = 20.0;

  /// Texto de las demás filas del listado
  static const double listItem = 16.0;

  /// {value: 12, unit: px}
  static const double tag = 12.0;

  /// {value: 11, unit: px}
  static const double micro = 11.0;
}

/// Interletrado en em (multiplicar por el tamaño de fuente).
abstract final class UnaLetterSpacing {
  static const double tightest = -0.04;
  static const double intro = -0.035;
  static const double tighter = -0.03;
  static const double tight = -0.02;
  static const double snug = -0.01;
  static const double tagWide = 0.08;
}

/// Longitud del texto (caracteres) a partir de la cual la nota usa un tamaño menor.
const List<int> unaNoteLengthBreakpoints = [40, 90, 160];

abstract final class UnaSpace {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double sm = 12.0;
  static const double m = 16.0;
  static const double ml = 20.0;
  static const double l = 24.0;
  static const double xl = 28.0;
  static const double xxl = 40.0;
}

abstract final class UnaSizes {
  static const double minTouchTarget = 44.0;
  static const double frameWidth = 390.0;
  static const double frameHeight = 844.0;
  static const double contentMaxWidth = 600.0;
  static const double icon = 22.0;
  static const double iconM = 24.0;
  static const double iconL = 26.0;
  static const double iconStroke = 2.4;
  static const double iconStrokeBold = 3.0;
  static const double iconButton = 46.0;
  static const double button = 64.0;
  static const double holdButton = 72.0;
  static const double caretWidth = 6.0;
  static const double stamp = 88.0;
  static const double stampIcon = 50.0;
  static const double stampIconStroke = 3.2;
  static const double emptyButton = 68.0;
  static const double menuRow = 58.0;
  static const double confirmButton = 62.0;
  static const double ghostButton = 56.0;
  static const double trashWidth = 64.0;
  static const double trashHeight = 76.0;
  static const double trashStroke = 3.2;
  static const double iconS = 16.0;
  static const double listIcon = 20.0;
  static const double listGrip = 18.0;
  static const double listHeader = 68.0;
  static const double linkButton = 44.0;
  static const double bodyMaxWidth = 300.0;
  static const double confettiBorder = 2.0;
}

abstract final class UnaBorders {
  static const double strongWidth = 3.0;
  static const double focusWidth = 3.0;
  static const double sectionWidth = 4.0;
  static const double hairlineWidth = 1.0;
  static const double noneRadius = 0.0;
}

abstract final class UnaShadows {
  static const BoxShadow button = BoxShadow(
    color: Color(0xFF111111),
    offset: Offset(5.0, 5.0),
    blurRadius: 0.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow buttonPressed = BoxShadow(
    color: Color(0xFF111111),
    offset: Offset(1.0, 1.0),
    blurRadius: 0.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow iconButton = BoxShadow(
    color: Color(0xFF111111),
    offset: Offset(3.0, 3.0),
    blurRadius: 0.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow stamp = BoxShadow(
    color: Color(0xFFFFFFFF),
    offset: Offset(6.0, 6.0),
    blurRadius: 0.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow listItem = BoxShadow(
    color: Color(0xFF111111),
    offset: Offset(4.0, 4.0),
    blurRadius: 0.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow listItemDragging = BoxShadow(
    color: Color(0xFF111111),
    offset: Offset(10.0, 10.0),
    blurRadius: 0.0,
    spreadRadius: 0.0,
  );
  static const BoxShadow listItemFlash = BoxShadow(
    color: Color(0xFF111111),
    offset: Offset(9.0, 9.0),
    blurRadius: 0.0,
    spreadRadius: 0.0,
  );
}

abstract final class UnaMotion {
  /// {value: 80, unit: ms}
  static const Duration press = Duration(milliseconds: 80);

  /// {value: 200, unit: ms}
  static const Duration sheetIn = Duration(milliseconds: 200);

  /// {value: 160, unit: ms}
  static const Duration sheetOut = Duration(milliseconds: 160);

  /// {value: 450, unit: ms}
  static const Duration enter = Duration(milliseconds: 450);

  /// Tiempo de mantener pulsado para completar
  static const Duration holdToComplete = Duration(milliseconds: 1200);

  /// Retroceso del relleno al soltar antes de tiempo
  static const Duration holdRelease = Duration(milliseconds: 280);

  /// La nota se rompe en dos
  static const Duration tear = Duration(milliseconds: 1250);

  /// Tiempo visible de ¡Enhorabuena!
  static const Duration successHold = Duration(milliseconds: 2100);

  /// {value: 700, unit: ms}
  static const Duration successFade = Duration(milliseconds: 700);

  /// Arrugar y tirar a la papelera
  static const Duration crumple = Duration(milliseconds: 2200);

  /// Con 'reducir movimiento', la nota eliminada se desvanece (prototipo: fadeOut .6s)
  static const Duration crumpleReducedFade = Duration(milliseconds: 600);

  /// Máquina de escribir de la bienvenida
  static const Duration introCharStep = Duration(milliseconds: 62);

  /// Parpadeo del cursor de la bienvenida (steps(1))
  static const Duration caretBlink = Duration(milliseconds: 1000);

  /// {value: 800, unit: ms}
  static const Duration introFade = Duration(milliseconds: 800);

  /// {value: 900, unit: ms}
  static const Duration listFlash = Duration(milliseconds: 900);

  /// Las demás filas se apartan al arrastrar (prototipo: .li transition transform .2s ease)
  static const Duration listShift = Duration(milliseconds: 200);

  /// La sombra crece al levantar una fila (.li.dragging box-shadow .15s)
  static const Duration listLift = Duration(milliseconds: 150);

  /// Tras soltar, las filas se colocan sin transición (.li.still)
  static const Duration listDropFreeze = Duration(milliseconds: 60);

  /// {value: 350, unit: ms}
  static const Duration doubleTapWindow = Duration(milliseconds: 350);

  /// Sustituto con 'reducir movimiento'
  static const Duration reducedMotionFade = Duration(milliseconds: 400);

  /// Pausa entre completar (relleno lleno) y la rotura
  static const Duration holdDonePause = Duration(milliseconds: 140);

  /// Retraso del sello ✓
  static const Duration stampDelay = Duration(milliseconds: 300);

  /// Aparición del sello ✓
  static const Duration stamp = Duration(milliseconds: 550);

  /// Retraso de "¡Enhorabuena! Tarea completada."
  static const Duration riseDelay = Duration(milliseconds: 450);

  /// Retraso de "Ahora a por la siguiente →"
  static const Duration riseDelaySecond = Duration(milliseconds: 650);

  /// Subida de los textos de la enhorabuena
  static const Duration rise = Duration(milliseconds: 500);

  /// Retraso del confeti
  static const Duration confettiDelay = Duration(milliseconds: 380);

  /// Vuelo del confeti
  static const Duration confetti = Duration(milliseconds: 1100);
  static const Cubic standardCurve = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Cubic sheetCurve = Cubic(0.2, 0.9, 0.3, 1.0);
  static const Cubic sheetOutCurve = Cubic(0.5, 0.0, 0.8, 0.4);
  static const Cubic tearCurve = Cubic(0.3, 0.0, 0.2, 1.0);
  static const Cubic fallCurve = Cubic(0.55, 0.0, 1.0, 0.45);
  static const Cubic stampCurve = Cubic(0.2, 1.6, 0.4, 1.0);
  static const Cubic confettiCurve = Cubic(0.15, 0.7, 0.3, 1.0);
  static const Cubic easeOutCurve = Cubic(0.0, 0.0, 0.58, 1.0);
  static const Cubic easeCurve = Cubic(0.25, 0.1, 0.25, 1.0);
  static const double dragThreshold = 6.0;
  static const double dragTilt = -1.5;
}
