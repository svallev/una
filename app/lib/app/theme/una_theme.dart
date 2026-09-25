import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Tema de la app: Material 3 solo como base; la identidad sale de los tokens (P12).
abstract final class UnaTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: UnaColors.ink,
      onPrimary: UnaColors.onInk,
      secondary: UnaColors.ink,
      onSecondary: UnaColors.onInk,
      surface: UnaColors.paper,
      onSurface: UnaColors.ink,
      error: UnaColors.error,
      onError: UnaColors.onInk,
      outline: UnaColors.ink,
      outlineVariant: UnaColors.line,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: UnaColors.paper,
      fontFamily: UnaFonts.display,
      splashFactory: NoSplash.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: UnaColors.ink,
        displayColor: UnaColors.ink,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: UnaColors.ink,
        selectionColor: UnaColors.selection,
        selectionHandleColor: UnaColors.ink,
      ),
    );
  }

  /// Estilo del texto de una nota según su longitud (tokens `noteXL..noteS`).
  static TextStyle noteText(String text, {double? fontSize}) {
    final l = text.characters.length;
    final size =
        fontSize ??
        (l < unaNoteLengthBreakpoints[0]
            ? UnaFontSizes.noteXL
            : l < unaNoteLengthBreakpoints[1]
            ? UnaFontSizes.noteL
            : l < unaNoteLengthBreakpoints[2]
            ? UnaFontSizes.noteM
            : UnaFontSizes.noteS);
    return TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: size,
      fontWeight: UnaFontWeights.extrabold,
      height: 1.05,
      letterSpacing: UnaLetterSpacing.tighter * size,
      color: UnaColors.ink,
    );
  }

  /// Como [noteText], pero reduce el tamaño lo justo para que la palabra más
  /// larga quepa entera en [maxWidth] (CA-001-07: no se cortan palabras). No
  /// baja de `noteS`: por debajo, las palabras enormes (una URL) se parten
  /// (CL-001-3).
  static TextStyle fitNoteText(
    String text, {
    required double maxWidth,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    final base = noteText(text);
    final size = base.fontSize!;
    if (size <= UnaFontSizes.noteS || !maxWidth.isFinite) return base;
    // Basta con medir las palabras con más caracteres.
    final words = text.split(RegExp(r'\s+')).toSet().toList()
      ..sort((a, b) => b.characters.length.compareTo(a.characters.length));
    var widest = 0.0;
    for (final w in words.take(8)) {
      final painter = TextPainter(
        text: TextSpan(text: w, style: base),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    if (widest <= maxWidth) return base;
    // El ancho es proporcional al tamaño (el interletrado también lo es).
    final fitted = (size * maxWidth / widest * 2).floorToDouble() / 2;
    return noteText(text, fontSize: math.max(fitted, UnaFontSizes.noteS));
  }

  /// Texto secundario (Space Mono).
  static const TextStyle mono = TextStyle(
    fontFamily: UnaFonts.mono,
    fontSize: UnaFontSizes.caption,
    color: UnaColors.textMuted,
  );
}
