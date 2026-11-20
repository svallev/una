import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Muestra el aviso de la cámara sin permiso (solo iOS, spec 028, CA-028-10):
/// el texto `errCameraDenied` y el botón `errCameraDeniedOpenSettings`, que
/// abre los Ajustes de la app con [openAppSettings] y cierra el aviso.
///
/// Es accesible como los demás avisos de error (CA-007-22): el `SnackBar` es
/// una región viva (se anuncia solo al aparecer), el foco del lector va al
/// aviso, que es **un solo nodo** con su botón (se lee entero), y con teclado o
/// lector también el foco de entrada. Con un lector o con teclado no caduca
/// (hay que tener tiempo de llegar al botón, WCAG 2.2.1); sin ellos dura lo que
/// los demás avisos. [onClosed] se llama al cerrarse, por lo que sea.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
showCameraDeniedNotice(
  BuildContext context, {
  required Future<bool> Function() openAppSettings,
  required EdgeInsets margin,
  VoidCallback? onClosed,
}) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final keyboard =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
  final persist = keyboard || MediaQuery.accessibleNavigationOf(context);
  var opening = false;
  final controller = messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: margin,
      persist: persist,
      content: CameraDeniedNotice(
        message: l10n.errCameraDenied,
        buttonLabel: l10n.errCameraDeniedOpenSettings,
        color: Theme.of(context).colorScheme.inversePrimary,
        onOpen: () {
          // Una petición por toque.
          if (opening) return;
          opening = true;
          messenger.hideCurrentSnackBar();
          // Si no se abren, no hay nada más que hacer (nunca se registra).
          unawaited(openAppSettings().catchError((Object _) => false));
        },
      ),
    ),
  );
  if (onClosed != null) unawaited(controller.closed.then((_) => onClosed()));
  return controller;
}

/// El contenido del aviso: el texto y, debajo, el botón (cabe siempre, también
/// con el texto al 200 %). Lleva su propio foco y su propia clave: el
/// `ScaffoldMessenger` lo muestra en todos los `Scaffold` (también en el de la
/// pantalla de debajo) y solo el que se ve pide el foco.
class CameraDeniedNotice extends StatefulWidget {
  const CameraDeniedNotice({
    super.key,
    required this.message,
    required this.buttonLabel,
    required this.color,
    required this.onOpen,
  });

  final String message;
  final String buttonLabel;
  final Color color;
  final VoidCallback onOpen;

  @override
  State<CameraDeniedNotice> createState() => _CameraDeniedNoticeState();
}

class _CameraDeniedNoticeState extends State<CameraDeniedNotice> {
  final _focus = FocusNode(debugLabel: 'camera-denied-open-settings');
  final _semantics = GlobalKey();

  Timer? _wait;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Sale justo al cerrarse la hoja "Añadir": mientras baja, el editor sigue
      // oculto al lector y el aviso de foco se perdería (como en Ajustes,
      // T-015-09). Se espera a que baje, con margen; sin animación, nada.
      final after = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _afterSheet;
      _wait = Timer(after, () {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => _takeFocus());
        WidgetsBinding.instance.scheduleFrame();
      });
    });
  }

  /// Lo que tarda en irse la hoja de "Añadir" (`sheetOut`) y otro tanto de
  /// margen para que su ruta termine de quitarse.
  static final _afterSheet = UnaMotion.sheetOut * 2;

  void _takeFocus() {
    if (!mounted) return;
    // La copia de una pantalla tapada no cuenta.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (keyboard || MediaQuery.accessibleNavigationOf(context)) {
      _focus.requestFocus();
    }
    _semantics.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  @override
  void dispose() {
    _wait?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      key: _semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              focusNode: _focus,
              style: TextButton.styleFrom(
                foregroundColor: widget.color,
                // ≥ 44 en los dos lados (CA-028-10).
                minimumSize: const Size.square(UnaSizes.minTouchTarget),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: widget.onOpen,
              child: Text(widget.buttonLabel),
            ),
          ),
        ],
      ),
    ),
  );
}
