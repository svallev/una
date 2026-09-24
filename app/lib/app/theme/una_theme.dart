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
        selectionColor: Color(0x33111111),
        selectionHandleColor: UnaColors.ink,
      ),
    );
  }

  /// Estilo del texto de una nota según su longitud (tokens `noteXL..noteS`).
  static TextStyle noteText(String text) {
    final l = text.characters.length;
    final size = l < unaNoteLengthBreakpoints[0]
        ? UnaFontSizes.noteXL
        : l < unaNoteLengthBreakpoints[1]
        ? UnaFontSizes.noteL
        : l < unaNoteLengthBreakpoints[2]
        ? UnaFontSizes.noteM
        : UnaFontSizes.noteS;
    return TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: size,
      fontWeight: UnaFontWeights.extrabold,
      height: 1.05,
      letterSpacing: UnaLetterSpacing.tighter * size,
      color: UnaColors.ink,
    );
  }

  /// Texto secundario (Space Mono).
  static const TextStyle mono = TextStyle(
    fontFamily: UnaFonts.mono,
    fontSize: UnaFontSizes.caption,
    color: UnaColors.textMuted,
  );
}
