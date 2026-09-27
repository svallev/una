import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/boxed_icon_button.dart';
import '../../ui/focus_ring.dart';
import '../../ui/full_width.dart';
import '../../ui/una_icons.dart';
import 'keep_screen_on_controller.dart';

/// Visor a pantalla completa (CA-007-09/10/11, DEV-37): la imagen al ancho de
/// la pantalla sobre papel, desplazamiento vertical, zoom opcional hasta ×8 y
/// "Cerrar". Es la única pantalla que gira.
class ImageViewerScreen extends ConsumerStatefulWidget {
  const ImageViewerScreen({super.key, required this.attachment});

  final Attachment attachment;

  /// Fundido de entrada (con reducir movimiento, el de 400 ms, CA-007-23).
  static Route<void> route(BuildContext context, Attachment attachment) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced ? UnaMotion.reducedMotionFade : UnaMotion.sheetIn;
    return PageRouteBuilder<void>(
      transitionDuration: duration,
      reverseTransitionDuration: reduced
          ? UnaMotion.reducedMotionFade
          : UnaMotion.sheetOut,
      pageBuilder: (_, _, _) => ImageViewerScreen(attachment: attachment),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: UnaMotion.easeCurve),
        child: child,
      ),
    );
  }

  /// Pasos del doble toque (CA-007-10).
  static const levels = [
    1.0,
    UnaMotion.viewerZoomStep,
    UnaMotion.viewerZoomMax,
  ];

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(
    vsync: this,
    duration: UnaMotion.viewerZoom,
  );
  Animation<Matrix4>? _tween;
  Offset? _doubleTapAt;
  Size _viewport = Size.zero;
  final _imageSemantics = GlobalKey();

  /// Foco de la pantalla (la imagen): recibe los atajos de teclado, también
  /// cuando el foco está en "Cerrar", y muestra el anillo con teclado.
  final _screenFocus = FocusNode(debugLabel: 'viewer');
  bool _ringVisible = false;

  double get _scale => _transform.value.getMaxScaleOnAxis();
  bool get _zoomed => _scale > 1.001;

  @override
  void initState() {
    super.initState();
    // Fuera de la fase de construcción: el marco de la app lo escucha.
    _afterFrame(() => fullWidthRequests.value++);
    // Solo aquí se gira; el resto de la app queda en vertical (CA-007-11).
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    _transform.addListener(_onTransform);
    _screenFocus.addListener(_updateRing);
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
    _animation
      ..addListener(() {
        final tween = _tween;
        if (tween != null) _transform.value = tween.value;
      })
      // El valor y las acciones del lector se actualizan al acabar.
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() {});
      });
    // Foco del lector en la imagen al abrir (CA-007-22).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _imageSemantics.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  @override
  void dispose() {
    _afterFrame(() => fullWidthRequests.value--);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    _screenFocus.dispose();
    _transform.dispose();
    _animation.dispose();
    super.dispose();
  }

  static void _afterFrame(VoidCallback f) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => f())
      ..scheduleFrame();
  }

  var _wasZoomed = false;

  void _onTransform() {
    // El eje de desplazamiento cambia al ampliar o volver a ×1.
    if (_zoomed != _wasZoomed) setState(() => _wasZoomed = _zoomed);
  }

  /// Alto de la imagen a ×1 (al ancho de la pantalla).
  double _contentHeight(double width) =>
      width * widget.attachment.height / widget.attachment.width;

  /// Transformación a [scale] que lleva el punto [scene] (coordenadas de la
  /// imagen a ×1) a [target] (coordenadas de la pantalla), sin salirse.
  Matrix4 _matrixFor(double scale, Offset scene, Offset target) {
    final w = _viewport.width;
    final h = _viewport.height;
    final childH = math.max(_contentHeight(w), h);
    double clamp(double t, double extent, double view) =>
        extent <= view ? (view - extent) / 2 : t.clamp(view - extent, 0);
    final tx = clamp(target.dx - scene.dx * scale, w * scale, w);
    final ty = clamp(target.dy - scene.dy * scale, childH * scale, h);
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _goTo(Matrix4 next) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _transform.value = next;
      setState(() {});
      return;
    }
    _tween = Matrix4Tween(begin: _transform.value, end: next).animate(
      CurvedAnimation(parent: _animation, curve: UnaMotion.standardCurve),
    );
    unawaited(_animation.forward(from: 0));
  }

  /// Ampliación [scale] centrada en [focus] (punto de la pantalla).
  void _zoomTo(double scale, {Offset? focus, bool announce = false}) {
    final center = _viewport.center(Offset.zero);
    final scene = _transform.toScene(focus ?? center);
    _goTo(_matrixFor(scale, scene, center));
    if (announce) _announceLevel(scale);
  }

  void _announceLevel(double scale) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(context).a11yZoomLevel(scale),
        Directionality.of(context),
      ),
    );
  }

  /// Siguiente paso del doble toque: ×1 → ×2,5 → ×8 → ×1.
  double _nextLevel() {
    final levels = ImageViewerScreen.levels;
    for (final l in levels) {
      if (l > _scale + 0.01) return l;
    }
    return 1;
  }

  double _previousLevel() {
    final levels = ImageViewerScreen.levels.reversed;
    for (final l in levels) {
      if (l < _scale - 0.01) return l;
    }
    return 1;
  }

  void _zoomIn() {
    if (_scale >= UnaMotion.viewerZoomMax - 0.01) return;
    _zoomTo(_nextLevel(), announce: true);
  }

  void _zoomOut() => _zoomTo(_previousLevel(), announce: true);
  void _fit() => _zoomTo(1, announce: true);

  /// Desplaza [dx], [dy] píxeles de pantalla (teclado y lector).
  void _panBy(double dx, double dy) {
    final center = _viewport.center(Offset.zero);
    final scene = _transform.toScene(center - Offset(dx, dy));
    _goTo(_matrixFor(_scale, scene, center));
  }

  bool get _canScrollUp => _transform.value.getTranslation().y < -0.5;
  bool get _canScrollDown {
    final childH = math.max(_contentHeight(_viewport.width), _viewport.height);
    return _transform.value.getTranslation().y >
        _viewport.height - childH * _scale + 0.5;
  }

  bool get _canScrollLeft =>
      _zoomed && _transform.value.getTranslation().x < -0.5;
  bool get _canScrollRight =>
      _zoomed &&
      _transform.value.getTranslation().x >
          _viewport.width - _viewport.width * _scale + 0.5;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final step = _viewport.height * 0.2;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape) {
        _close();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.equal ||
          key == LogicalKeyboardKey.add ||
          key == LogicalKeyboardKey.numpadAdd) {
        _zoomIn();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.minus ||
          key == LogicalKeyboardKey.numpadSubtract) {
        _zoomOut();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.digit0 ||
          key == LogicalKeyboardKey.numpad0) {
        _fit();
        return KeyEventResult.handled;
      }
    }
    // Las flechas también se repiten al mantenerlas.
    final (dx, dy) = switch (key) {
      LogicalKeyboardKey.arrowUp => (0.0, step),
      LogicalKeyboardKey.arrowDown => (0.0, -step),
      LogicalKeyboardKey.arrowLeft when _zoomed => (step, 0.0),
      LogicalKeyboardKey.arrowRight when _zoomed => (-step, 0.0),
      _ => (0.0, 0.0),
    };
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    _panBy(dx, dy);
    return KeyEventResult.handled;
  }

  /// Al acabar un pellizco cerca de ×1, vuelve exactamente al ancho completo.
  void _onInteractionEnd(ScaleEndDetails _) {
    if (_scale < 1.05 && _scale != 1) {
      _zoomTo(1);
    } else {
      setState(() {});
    }
  }

  void _close() => Navigator.of(context).maybePop();

  /// Las acciones del lector (doble toque o gestos de TalkBack) son toques en
  /// la pantalla: reinician los 10 minutos (CA-007-12). Las teclas, no.
  VoidCallback _used(VoidCallback action) => () {
    ref.read(keepScreenOnProvider.notifier).touched();
    action();
  };

  void _onHighlightMode(FocusHighlightMode _) => _updateRing();

  /// Anillo en la imagen solo con teclado y con el foco en ella (no en
  /// "Cerrar").
  void _updateRing() {
    final visible =
        _screenFocus.hasPrimaryFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (visible != _ringVisible && mounted) {
      setState(() => _ringVisible = visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final attachment = widget.attachment;
    final images = ref.watch(attachmentImagesProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return KeepScreenOnWhileVisible(
      enabled: true,
      child: Scaffold(
        backgroundColor: UnaColors.paper,
        body: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: l10n.viewerTitle,
          child: Focus(
            focusNode: _screenFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: FocusRing(
              visible: _ringVisible,
              inside: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      if (size != _viewport) {
                        // Al girar, vuelve el ancho completo (CA-007-11).
                        final rotated =
                            _viewport != Size.zero &&
                            size.width != _viewport.width;
                        _viewport = size;
                        if (rotated) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            _animation.stop();
                            _transform.value = Matrix4.identity();
                            setState(() {});
                          });
                        }
                      }
                      final width = size.width;
                      final contentH = _contentHeight(width);
                      final level = _scale;
                      return Semantics(
                        // La imagen se lee antes que "Cerrar", sea cual sea su
                        // posición en pantalla.
                        container: true,
                        sortKey: const OrdinalSortKey(0),
                        child: GestureDetector(
                          onDoubleTapDown: (d) =>
                              _doubleTapAt = d.localPosition,
                          onDoubleTap: () =>
                              _zoomTo(_nextLevel(), focus: _doubleTapAt),
                          child: InteractiveViewer(
                            transformationController: _transform,
                            constrained: false,
                            minScale: 1,
                            maxScale: UnaMotion.viewerZoomMax,
                            // A ×1, solo en vertical (CA-007-09); ampliada, libre.
                            panAxis: _zoomed ? PanAxis.free : PanAxis.vertical,
                            onInteractionStart: (_) => _animation.stop(),
                            onInteractionEnd: _onInteractionEnd,
                            child: SizedBox(
                              width: width,
                              height: math.max(contentH, size.height),
                              child: Center(
                                child: Semantics(
                                  key: _imageSemantics,
                                  label: attachment.isPhoto
                                      ? l10n.attachmentPhoto
                                      : l10n.attachmentImage,
                                  value: l10n.a11yZoomLevel(
                                    double.parse(level.toStringAsFixed(1)),
                                  ),
                                  image: attachment.isPhoto,
                                  excludeSemantics: true,
                                  customSemanticsActions: {
                                    if (level < UnaMotion.viewerZoomMax - 0.01)
                                      CustomSemanticsAction(label: l10n.zoomIn):
                                          _used(_zoomIn),
                                    if (_zoomed)
                                      CustomSemanticsAction(
                                        label: l10n.zoomOut,
                                      ): _used(
                                        _zoomOut,
                                      ),
                                    if (_zoomed)
                                      CustomSemanticsAction(
                                        label: l10n.zoomFit,
                                      ): _used(
                                        _fit,
                                      ),
                                  },
                                  onScrollUp: _canScrollDown
                                      ? _used(
                                          () => _panBy(0, -size.height * 0.8),
                                        )
                                      : null,
                                  onScrollDown: _canScrollUp
                                      ? _used(
                                          () => _panBy(0, size.height * 0.8),
                                        )
                                      : null,
                                  onScrollLeft: _canScrollRight
                                      ? _used(
                                          () => _panBy(-size.width * 0.8, 0),
                                        )
                                      : null,
                                  onScrollRight: _canScrollLeft
                                      ? _used(() => _panBy(size.width * 0.8, 0))
                                      : null,
                                  child: _Tiles(
                                    attachment: attachment,
                                    width: width,
                                    height: contentH,
                                    // Decodifica al tamaño con que se ve, por pasos:
                                    // a ×1, al ancho de la pantalla.
                                    decodeScale: dpr * _bucket(level),
                                    image: images.stored,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(UnaSpace.s),
                        child: Semantics(
                          container: true,
                          sortKey: const OrdinalSortKey(1),
                          child: BoxedIconButton(
                            label: l10n.viewerClose,
                            icon: UnaIcons.close,
                            dimension: UnaSizes.viewerClose,
                            iconSize: UnaSizes.iconS,
                            iconStroke: UnaSizes.iconStrokeBold,
                            onPressed: _close,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Paso de decodificación: 1, 2,5 u 8 (no se vuelve a decodificar en cada
  /// fotograma del pellizco).
  static double _bucket(double level) {
    for (final l in ImageViewerScreen.levels) {
      if (level <= l + 0.01) return l;
    }
    return UnaMotion.viewerZoomMax;
  }
}

/// La versión completa, en teselas de 4096 px como máximo (plan §7).
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.attachment,
    required this.width,
    required this.height,
    required this.decodeScale,
    required this.image,
  });

  final Attachment attachment;
  final double width;
  final double height;
  final double decodeScale;
  final ImageProvider Function(String relPath) image;

  @override
  Widget build(BuildContext context) {
    final tiles = attachment.tiles;
    final k = width / attachment.width;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          for (var r = 0; r < tiles.rows; r++)
            for (var c = 0; c < tiles.columns; c++)
              Builder(
                builder: (context) {
                  final rect = tiles.rect(r, c);
                  final w = rect.width * k;
                  // Nunca por encima del tamaño real de la tesela.
                  final cacheWidth = math.min(
                    rect.width,
                    (w * decodeScale).ceil(),
                  );
                  return Positioned(
                    left: rect.left * k,
                    top: rect.top * k,
                    width: w,
                    height: rect.height * k,
                    child: Image(
                      image: ResizeImage(
                        image('${attachment.dir}/${ImageTiles.fileName(r, c)}'),
                        width: math.max(1, cacheWidth),
                        policy: ResizeImagePolicy.fit,
                      ),
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
