import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

/// Estilo de las barras con la app abierta (CA-021-09): transparentes, iconos
/// oscuros sobre `paper` y sin el velo de contraste que añade Android 10+.
const systemBarsStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  // Solo lo lee iOS: la barra de estado clara lleva texto oscuro.
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// Lo mismo cuando una pantalla pinta un fondo oscuro a sangre detrás de las barras (la
/// enhorabuena, sobre `ink`): iconos claros, con el mismo contraste de 3:1 o más (CA-021-09).
const systemBarsOnDarkStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  // Solo lo lee iOS: la barra de estado oscura lleva texto claro.
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);
