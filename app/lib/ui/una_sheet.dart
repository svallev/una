import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../app/system_bars.dart';
import '../app/theme/tokens.g.dart';
import 'focus_ring.dart';
import 'full_width.dart';

/// Hoja del prototipo (`.sheetbg` + `.sheetup`): fondo `scrim`, sube en
/// `sheetIn` con la curva `sheet` y baja en `sheetOut`; color papel, borde
/// superior de 3 px, sin esquinas ni asa. Se cierra con la X, tocando fuera,
/// con el gesto atrás o deslizando hacia abajo (DEV-21). La ruta modal atrapa
/// el foco del lector y del teclado.
Future<T?> showUnaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  // Cuenta de hojas con velo para la barra de estado (CA-024-02): sube antes de abrir (el
  // primer fotograma de la hoja ya la lleva clara) y baja en `_SheetBarsScope`.
  final count = _SheetCount();
  final Future<T?> opened;
  try {
    opened = _openSheet<T>(context, builder, reduced, count);
  } catch (_) {
    count.release();
    rethrow;
  }
  // Red de seguridad: si la ruta se cierra sin llegar a construirse, nadie más lo baja.
  return opened.whenComplete(() {
    if (!count.attached) count.release();
  });
}

/// Una hoja contada en [scrimSheetsOpen]: se baja una sola vez.
class _SheetCount {
  _SheetCount() {
    scrimSheetsOpen.value++;
  }

  bool _released = false;

  /// Si la hoja ya se construyó y es `_SheetBarsScope` quien la baja.
  bool attached = false;

  void release() {
    if (_released) return;
    _released = true;
    scrimSheetsOpen.value--;
  }
}

Future<T?> _openSheet<T>(
  BuildContext context,
  WidgetBuilder builder,
  bool reduced,
  _SheetCount count,
) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: UnaColors.paper,
    barrierColor: UnaColors.scrim,
    elevation: 0,
    shape: const Border(
      top: BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
    ),
    // Reducir movimiento: la hoja no se desliza.
    sheetAnimationStyle: reduced
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: UnaMotion.sheetIn,
            reverseDuration: UnaMotion.sheetOut,
            curve: UnaMotion.sheetCurve,
            reverseCurve: UnaMotion.sheetOutCurve,
          ),
    // La hoja sube sobre el teclado: la ruta no lo hace sola, y con Android 15+
    // (a pantalla completa) `adjustResize` tampoco redimensiona la ventana.
    // Y deja libre la barra de navegación del sistema (`padding.bottom`; con el
    // teclado a la vista vale 0): con la navegación de tres botones y el texto
    // al 200 %, el último enlace quedaba a medias bajo ella (spec 015, T-015-14).
    builder: (context) => _SheetBarsScope(
      count: count,
      child: ValueListenableBuilder<int>(
        valueListenable: fullWidthRequests,
        builder: (context, fullWidth, child) =>
            AnnotatedRegion<SystemUiOverlayStyle>(
              // Sin tamaño: vale en cualquier punto de la ruta (CA-024-02). Sirve sobre todo
              // para la barra de navegación (iconos oscuros sobre la hoja, también con la card
              // de deshacer debajo); la de estado queda fuera de la ruta (recorte de
              // `useSafeArea`) y la pide `appFrame` con `scrimSheetsOpen`, con el mismo valor.
              // Al quitarse la ruta vuelve el estilo de `appFrame` (CA-024-03). Solo si el
              // velo llega de lado a lado: `appFrame` limita el contenido a `contentMaxWidth`
              // (salvo el visor, `fullWidthRequests`) y, si es más estrecho, la hora y la
              // batería quedan sobre `paper`.
              sized: false,
              value: scrimSpansScreen(context, fullWidth)
                  ? systemBarsUnderScrimStyle
                  : systemBarsStyle,
              child: child!,
            ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom,
          ),
          child: SingleChildScrollView(child: builder(context)),
        ),
      ),
    ),
  );
}

/// Baja la cuenta de [scrimSheetsOpen] en el fotograma en que la ruta de la hoja termina de
/// irse (`AnimationStatus.dismissed`, el mismo en que el navegador la quita: CA-024-03), no
/// al hacer `pop`, y como último recurso al destruirse (en ese caso, un fotograma después:
/// con el árbol bloqueado no se puede avisar a quien escucha).
class _SheetBarsScope extends StatefulWidget {
  const _SheetBarsScope({required this.count, required this.child});

  final _SheetCount count;
  final Widget child;

  @override
  State<_SheetBarsScope> createState() => _SheetBarsScopeState();
}

class _SheetBarsScopeState extends State<_SheetBarsScope> {
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    widget.count.attached = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation == _animation) return;
    _animation?.removeStatusListener(_onStatus);
    _animation = animation?..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) widget.count.release();
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    final count = widget.count;
    WidgetsBinding.instance.addPostFrameCallback((_) => count.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Enlace subrayado en monoespaciada del prototipo ("Cancelar",
/// "Seguir editando"). Con el foco del teclado o de un
/// interruptor, anillo de foco (WCAG 2.4.7).
class UnaLinkButton extends StatefulWidget {
  const UnaLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = UnaSizes.linkButton,
    this.focusNode,
    this.semanticsKey,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;

  /// Foco de teclado del enlace, para dárselo desde fuera (al volver de la
  /// Configuración al menú, CA-012-02).
  final FocusNode? focusNode;

  /// Clave del nodo accesible del enlace, para enviar desde él el aviso de
  /// foco del lector.
  final GlobalKey? semanticsKey;

  @override
  State<UnaLinkButton> createState() => _UnaLinkButtonState();
}

class _UnaLinkButtonState extends State<UnaLinkButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: widget.semanticsKey,
      button: true,
      focusable: true,
      focused: _focused,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: InkWell(
        onTap: widget.onPressed,
        focusNode: widget.focusNode,
        onFocusChange: (v) => setState(() => _focused = v),
        splashFactory: NoSplash.splashFactory,
        child: FocusRing(
          visible: _focused && showsFocusHighlight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.height,
              minWidth: UnaSizes.minTouchTarget,
            ),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: UnaSpace.s),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: UnaFonts.mono,
                    fontSize: UnaFontSizes.link,
                    fontWeight: UnaFontWeights.bold,
                    color: UnaColors.ink,
                    decoration: TextDecoration.underline,
                    decorationThickness: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
