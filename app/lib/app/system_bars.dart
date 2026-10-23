import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'theme/tokens.g.dart';

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

/// Lo mismo mientras se ve la card de deshacer (CA-024-01): es negra y llega al borde
/// inferior, así que los iconos de la barra de navegación son claros. La barra de estado
/// no cambia (iconos oscuros, como [systemBarsStyle]); Flutter solo lee de la región de
/// abajo los campos de la barra de navegación.
const systemBarsOnDarkNavStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

/// Lo mismo mientras hay una hoja con velo abierta (CA-024-02): el velo (`scrim`) oscurece
/// lo que queda tras la barra de estado, así que sus iconos son claros; la barra de
/// navegación queda sobre la hoja (`paper`) y sigue con iconos oscuros, como [systemBarsStyle].
const systemBarsUnderScrimStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  // Solo lo lee iOS: la barra de estado oscura lleva texto claro.
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// Hojas con velo a la vista (CA-024-02): `showUnaSheet` lo sube antes de abrirlas y lo baja
/// cuando la ruta termina de irse. `appFrame` pide con él [systemBarsUnderScrimStyle] para la
/// barra de estado: la región de la propia hoja no llega a ella, porque la ruta recorta su
/// contenido por debajo de la barra de estado (`useSafeArea`) y Flutter lee el estilo de
/// arriba en el centro de esa barra (T-024-04, H-024-A).
final scrimSheetsOpen = ValueNotifier<int>(0);

/// Si el velo de una hoja cubre la pantalla de lado a lado: el marco de la app limita el
/// ancho del contenido (y del velo) salvo que haya una pantalla a ancho completo
/// ([fullWidthCount], `fullWidthRequests`); si el velo es más estrecho, la hora y la
/// batería quedan sobre `paper` y siguen con iconos oscuros.
bool scrimSpansScreen(BuildContext context, int fullWidthCount) =>
    fullWidthCount > 0 ||
    MediaQuery.sizeOf(context).width <= UnaSizes.contentMaxWidth;
