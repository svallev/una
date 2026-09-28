import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/theme/tokens.g.dart';
import '../../data/attachments/attachment_images.dart';
import '../../domain/entities/link_target.dart';
import '../../domain/entities/pdf_position.dart';
import '../../l10n/generated/app_localizations.dart';
import 'pdf_semantics.dart';

/// Lo que la pantalla principal le da al visor del PDF (CA-008-08/09).
@immutable
class TaskPdfArgs {
  const TaskPdfArgs({
    required this.source,
    required this.screen,
    required this.captionColor,
    required this.initialPosition,
    required this.onPosition,
    this.onLeave,
    this.caption,
    this.actions = const {},
    this.onLink,
    this.taskLabel,
  });

  final PdfSource source;

  /// La versión de pantalla: la página de [initialPosition], dibujada al
  /// ancho. Se ve en el primer fotograma, antes que el visor (CA-008-08).
  final ImageProvider screen;

  /// Texto de la tarea: la banda del color de la nota encima de la primera
  /// página, que se desplaza con ellas. Null o vacío: sin banda.
  final String? caption;
  final Color captionColor;

  /// Dónde se dejó de ver (CA-008-09); null mientras se lee del disco.
  final PdfPosition? initialPosition;

  /// Cada vez que cambia la posición visible.
  final ValueChanged<PdfPosition> onPosition;

  /// Se deja de ver el PDF (segundo plano, otra pantalla encima o se quita):
  /// la pantalla guarda [PdfPosition] en el disco (CA-008-09).
  final ValueChanged<PdfPosition>? onLeave;

  /// Acciones de la tarea (completar, eliminar) que también lleva el PDF para
  /// el lector, antes que las suyas (CA-008-20).
  final Map<CustomSemanticsAction, VoidCallback> actions;

  /// Un enlace externo del PDF (web, correo, teléfono), ya clasificado: la
  /// pantalla pide confirmación (CA-008-12). Los internos los resuelve el
  /// visor y los bloqueados no llegan.
  final ValueChanged<LinkTarget>? onLink;

  /// En horizontal, sin franja ni texto, la página visible se lee con este
  /// prefijo: "Tarea actual: {texto o nombre}" (CA-008-20). Null en vertical.
  final String? taskLabel;
}

/// El visor del PDF de la tarea actual. Se sustituye en los tests de widgets:
/// el motor de verdad se prueba aparte y en el emulador.
typedef TaskPdfBuilder = Widget Function(TaskPdfArgs args);

final taskPdfBuilderProvider = Provider<TaskPdfBuilder>(
  (ref) =>
      (args) => TaskPdfView(args: args),
);

/// Estilo del texto de la tarea en la banda (prototipo: 24 px, 800, 1.08).
const captionStyle = TextStyle(
  fontFamily: UnaFonts.display,
  fontSize: UnaFontSizes.attachmentText,
  fontWeight: UnaFontWeights.extrabold,
  height: 1.08,
  letterSpacing: UnaLetterSpacing.tight * UnaFontSizes.attachmentText,
  color: UnaColors.ink,
);

/// Banda del texto de la tarea (prototipo `nx.hasCaption`): color de la nota,
/// relleno 16/24 y borde inferior de 3 px. Decorativa para el lector: la
/// lectura la hace la tarea (CA-008-20).
class PdfCaptionBand extends StatelessWidget {
  const PdfCaptionBand({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  /// Alto de la banda con [text] a [width] px.
  static double heightFor(
    String text,
    double width,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: captionStyle),
      textScaler: scaler,
      textDirection: direction,
    )..layout(maxWidth: math.max(1, width - 2 * UnaSpace.l));
    final h = painter.height;
    painter.dispose();
    return h + 2 * UnaSpace.m + UnaBorders.strongWidth;
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: const Border(
          bottom: BorderSide(
            color: UnaColors.ink,
            width: UnaBorders.strongWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.m,
          UnaSpace.l,
          UnaSpace.m,
        ),
        child: Text(text, style: captionStyle),
      ),
    ),
  );
}

/// Zoom al ancho (CA-008-10): el mínimo y el inicial son "ajustar al ancho"
/// (×1) y el máximo, ×4 sobre ese ancho. El resto, como pdfrx.
class FitWidthSizing extends PdfViewerSizeDelegateProvider {
  const FitWidthSizing();

  @override
  PdfViewerSizeDelegate create() => _FitWidthDelegate();

  @override
  bool operator ==(Object other) => other is FitWidthSizing;

  @override
  int get hashCode => (FitWidthSizing).hashCode;
}

class _FitWidthDelegate implements PdfViewerSizeDelegate {
  final _legacy = PdfViewerSizeDelegateLegacy(
    maxScale: 8,
    minScale: 0.1,
    useAlternativeFitScaleAsMinScale: false,
    onePassRenderingScaleThreshold: 200 / 72,
    calculateInitialZoom: null,
  );
  PdfViewerController? _controller;

  static double fitWidth(Size view, PdfPageLayout? layout) =>
      layout == null || layout.documentSize.width <= 0
      ? 1
      : view.width / layout.documentSize.width;

  @override
  void init(PdfViewerController controller) {
    _controller = controller;
    _legacy.init(controller);
  }

  @override
  void dispose() {
    _controller = null;
    _legacy.dispose();
  }

  @override
  PdfViewerLayoutMetrics calculateMetrics({
    required Size viewSize,
    required PdfPageLayout? layout,
    required int? pageNumber,
    required double pageMargin,
    required EdgeInsets? boundaryMargin,
  }) {
    final fit = fitWidth(viewSize, layout);
    return PdfViewerLayoutMetrics(
      minScale: fit,
      maxScale: fit * UnaMotion.pdfZoomMax,
      coverScale: fit,
      alternativeFitScale: fit,
    );
  }

  @override
  double get onePassRenderingScaleThreshold =>
      _legacy.onePassRenderingScaleThreshold;

  @override
  void onLayoutInitialized({
    required PdfViewerLayoutSnapshot state,
    required int initialPageNumber,
    required double coverScale,
    required double? alternativeFitScale,
    required PdfPageLayout layout,
    required PdfDocument document,
  }) {
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller.setZoom(
        Offset.zero,
        fitWidth(state.viewSize, layout),
        duration: Duration.zero,
      ),
    );
  }

  @override
  void onLayoutUpdate({
    required PdfViewerLayoutSnapshot oldState,
    required PdfViewerLayoutSnapshot newState,
    required double currentZoom,
    required Rect oldVisibleRect,
    required int? anchorPageNumber,
    required bool isLayoutChanged,
    required bool isViewSizeChanged,
  }) => _legacy.onLayoutUpdate(
    oldState: oldState,
    newState: newState,
    currentZoom: currentZoom,
    oldVisibleRect: oldVisibleRect,
    anchorPageNumber: anchorPageNumber,
    isLayoutChanged: isLayoutChanged,
    isViewSizeChanged: isViewSizeChanged,
  );
}

/// Niveles de zoom sobre el ancho para "Ampliar" y "Reducir" (acción o tecla,
/// CA-008-10): ×1 → ×1,5 → ×2,5 → ×4.
const pdfZoomLevels = [
  1.0,
  UnaMotion.pdfZoomStep,
  UnaMotion.pdfZoomDoubleTap,
  UnaMotion.pdfZoomMax,
];

const _zoomEpsilon = 0.01;

/// El nivel siguiente a [relative] (zoom sobre el ancho), o null en ×4.
double? zoomInStep(double relative) {
  for (final l in pdfZoomLevels) {
    if (l > relative + _zoomEpsilon) return l;
  }
  return null;
}

/// El nivel anterior a [relative], o null en ×1.
double? zoomOutStep(double relative) {
  for (final l in pdfZoomLevels.reversed) {
    if (l < relative - _zoomEpsilon) return l;
  }
  return null;
}

/// Posición de la parte de arriba de [visible] en [layout] (CA-008-09): la
/// página que la ocupa y cuánto se ha desplazado dentro de ella. Por encima de
/// la primera página (la banda), el principio.
PdfPosition positionIn(PdfPageLayout layout, Rect visible) {
  final y = visible.top;
  final pages = layout.pageLayouts;
  if (pages.isEmpty || y <= pages.first.top) return PdfPosition.start;
  for (var i = 0; i < pages.length; i++) {
    final r = pages[i];
    final next = i + 1 < pages.length ? pages[i + 1].top : double.infinity;
    if (y < next) {
      return PdfPosition(
        page: i + 1,
        offset: ((y - r.top) / r.height).clamp(0.0, 1.0),
      );
    }
  }
  return PdfPosition(page: pages.length, offset: 1);
}

/// Páginas al 100 % del ancho, una debajo de otra, con desplazamiento vertical
/// y zoom (CA-008-08/10). Hasta que el visor está listo se ve la versión de
/// pantalla en la última posición, así que el primer fotograma no espera al
/// motor.
class TaskPdfView extends StatefulWidget {
  const TaskPdfView({super.key, required this.args});

  final TaskPdfArgs args;

  @override
  State<TaskPdfView> createState() => _TaskPdfViewState();
}

class _TaskPdfViewState extends State<TaskPdfView> {
  final _controller = PdfViewerController();
  late final AppLifecycleListener _lifecycle;
  var _ready = false;
  var _restored = false;
  double _width = 0;
  double _bandPx = 0;
  PdfPosition? _visible;
  PdfPosition? _left;
  bool _covered = false;
  final _focus = FocusNode(debugLabel: 'pdf');
  Map<int, PdfPageContent> _content = const {};

  @override
  void initState() {
    super.initState();
    _visible = widget.args.initialPosition;
    _controller.addListener(_onMatrix);
    _lifecycle = AppLifecycleListener(onHide: _leave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Otra pantalla encima (menú, editor, listado): se guarda al taparse.
    final covered = !(ModalRoute.isCurrentOf(context) ?? true);
    if (covered && !_covered) _leave();
    _covered = covered;
  }

  @override
  void dispose() {
    _leave();
    _lifecycle.dispose();
    _controller.removeListener(_onMatrix);
    _focus.dispose();
    super.dispose();
  }

  /// Guarda la posición si ha cambiado desde la última vez.
  void _leave() {
    final visible = _visible;
    if (visible == null || visible == _left) return;
    _left = visible;
    widget.args.onLeave?.call(visible);
  }

  String get _caption => widget.args.caption ?? '';

  Future<void> _loadContent(PdfDocument document) async {
    final content = await loadPdfContent(document);
    if (mounted) setState(() => _content = content);
  }

  /// Un enlace tocado o activado con el lector o el teclado (CA-008-12).
  void _onLink(PdfLink link) {
    switch (linkTargetOf(link)) {
      case InternalLink(:final page):
        _goToPage(page);
      case BlockedLink():
        break; // No hace nada.
      case final target:
        widget.args.onLink?.call(target);
    }
  }

  // --- Zoom y desplazamiento sin gestos (CA-008-10, CA-008-22) --------------

  Duration get _duration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : UnaMotion.pdfZoom;

  double get _fit => _controller.minScale;

  /// Zoom actual sobre el ancho (×1 … ×4).
  double get _relative =>
      _controller.isReady && _fit > 0 ? _controller.currentZoom / _fit : 1;

  Future<void> _zoomTo(double relative, {Offset? around}) async {
    if (!_controller.isReady) return;
    await _controller.setZoom(
      around ?? _controller.centerPosition,
      _fit * relative,
      duration: _duration,
    );
    _announceZoom(relative);
  }

  void _announceZoom(double relative) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.a11yZoomLevel((relative * 100).round()),
        Directionality.of(context),
      ),
    );
  }

  void _zoomIn() {
    final next = zoomInStep(_relative);
    if (next != null) unawaited(_zoomTo(next));
  }

  void _zoomOut() {
    final next = zoomOutStep(_relative);
    if (next != null) unawaited(_zoomTo(next));
  }

  void _zoomFit() {
    if (_relative > 1 + _zoomEpsilon) unawaited(_zoomTo(1));
  }

  /// Doble toque: alterna ×1 y ×2,5 alrededor del punto tocado.
  bool _onGeneralTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (details.type != PdfViewerGeneralTapType.doubleTap) return false;
    unawaited(
      _zoomTo(
        _relative > 1 + _zoomEpsilon ? 1 : UnaMotion.pdfZoomDoubleTap,
        around: details.documentPosition,
      ),
    );
    return true;
  }

  /// Desplaza lo que se ve [dx], [dy] píxeles de la vista (positivo: hacia
  /// abajo y a la derecha del documento), sin salir de él.
  void _scrollBy(double dx, double dy) {
    if (!_controller.isReady) return;
    final m = _controller.value.clone();
    final t = m.getTranslation();
    m.setTranslationRaw(t.x - dx, t.y - dy, t.z);
    unawaited(
      _controller.goTo(
        _controller.makeMatrixInSafeRange(m, forceClamp: true),
        duration: _duration,
      ),
    );
  }

  Size get _view => _controller.viewSize;

  bool _canScroll(double dx, double dy) {
    if (!_controller.isReady) return false;
    final r = _controller.visibleRect;
    final doc = _controller.documentSize;
    const e = 0.5;
    if (dy > 0) return r.bottom < doc.height - e;
    if (dy < 0) return r.top > e;
    if (dx > 0) return r.right < doc.width - e;
    if (dx < 0) return r.left > e;
    return false;
  }

  int get _page => _visible?.page ?? 1;

  void _goToPage(int page) {
    if (!_controller.isReady) return;
    if (page < 1 || page > _controller.pageCount) return;
    unawaited(
      _controller.goToPage(
        pageNumber: page,
        anchor: PdfPageAnchor.top,
        duration: _duration,
      ),
    );
    final l10n = AppLocalizations.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.pdfPageA11y(page, _controller.pageCount),
        Directionality.of(context),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final view = _controller.isReady ? _view : Size.zero;
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      _zoomIn();
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _zoomOut();
    } else if (key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0) {
      _zoomFit();
    } else if (key == LogicalKeyboardKey.pageDown) {
      _scrollBy(0, view.height * 0.8);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _scrollBy(0, -view.height * 0.8);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _scrollBy(0, view.height * 0.1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _scrollBy(0, -view.height * 0.1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _scrollBy(view.width * 0.1, 0);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _scrollBy(-view.width * 0.1, 0);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Acciones del lector y de Switch Access sobre el PDF: solo las que se
  /// pueden hacer ahora (CA-008-10, CA-008-20).
  Widget _accessible(Widget child) => ListenableBuilder(
    // Solo escucha: leer `value` antes de que el visor esté listo falla.
    listenable: _controller,
    builder: (context, child) {
      final l10n = AppLocalizations.of(context);
      final ready = _controller.isReady && _ready;
      final r = _relative;
      final page = _page;
      final pages = ready ? _controller.pageCount : 0;
      final view = ready ? _view : Size.zero;
      return Semantics(
        container: true,
        onScrollUp: ready && _canScroll(0, 1)
            ? () => _scrollBy(0, view.height * 0.8)
            : null,
        onScrollDown: ready && _canScroll(0, -1)
            ? () => _scrollBy(0, -view.height * 0.8)
            : null,
        onScrollLeft: ready && _canScroll(1, 0)
            ? () => _scrollBy(view.width * 0.8, 0)
            : null,
        onScrollRight: ready && _canScroll(-1, 0)
            ? () => _scrollBy(-view.width * 0.8, 0)
            : null,
        customSemanticsActions: !ready
            ? null
            : {
                ...widget.args.actions,
                if (page < pages)
                  CustomSemanticsAction(label: l10n.pdfNextPage): () =>
                      _goToPage(page + 1),
                if (page > 1)
                  CustomSemanticsAction(label: l10n.pdfPrevPage): () =>
                      _goToPage(page - 1),
                if (zoomInStep(r) != null)
                  CustomSemanticsAction(label: l10n.pdfZoomIn): _zoomIn,
                if (zoomOutStep(r) != null)
                  CustomSemanticsAction(label: l10n.pdfZoomOut): _zoomOut,
                if (r > 1 + _zoomEpsilon)
                  CustomSemanticsAction(label: l10n.pdfZoomFit): _zoomFit,
              },
        child: child,
      );
    },
    child: Focus(focusNode: _focus, onKeyEvent: _onKey, child: child),
  );

  void _onMatrix() {
    if (!_controller.isReady || !_restored) return;
    final position = positionIn(_controller.layout, _controller.visibleRect);
    _visible = position;
    widget.args.onPosition(position);
  }

  /// Hueco arriba (en unidades del documento) para la banda del texto.
  PdfPageLayout _layout(List<PdfPage> pages, PdfViewerParams params) {
    final docWidth = pages.fold<double>(0, (w, p) => math.max(w, p.width));
    final scale = _width <= 0 || docWidth <= 0 ? 1.0 : docWidth / _width;
    var y = _bandPx * scale;
    final rects = <Rect>[];
    for (final p in pages) {
      final h = p.height * docWidth / p.width;
      rects.add(Rect.fromLTWH(0, y, docWidth, h));
      // Separación de 3 px entre páginas (prototipo `border-bottom`).
      y += h + UnaBorders.strongWidth * scale;
    }
    return PdfPageLayout(pageLayouts: rects, documentSize: Size(docWidth, y));
  }

  Future<void> _restore(PdfViewerController controller) async {
    final position = widget.args.initialPosition;
    final pages = controller.layout.pageLayouts;
    // pdfrx empieza con la página 1 arriba, sin la banda: se va siempre a la
    // posición guardada o, sin ella, al principio del documento.
    var y = 0.0;
    if (position != null && position != PdfPosition.start) {
      final p = position.clampTo(pages.length);
      final r = pages[p.page - 1];
      y = r.top + p.offset * r.height;
    }
    await controller.goToPosition(
      documentOffset: Offset(0, y),
      zoom: controller.minScale,
    );
    _restored = true;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final band = _caption.isEmpty
            ? 0.0
            : PdfCaptionBand.heightFor(
                _caption,
                width,
                MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: UnaSizes.imageCaptionMaxTextScale),
                Directionality.of(context),
              );
        if (width != _width || band != _bandPx) {
          _width = width;
          _bandPx = band;
        }
        final params = PdfViewerParams(
          backgroundColor: UnaColors.surface,
          margin: 0,
          pageDropShadow: null,
          sizeDelegateProvider: const FitWidthSizing(),
          layoutPages: _layout,
          textSelectionParams: const PdfTextSelectionParams(enabled: false),
          // Las teclas las lleva la app (pasos de zoom propios, CA-008-10).
          enableKeyboardNavigation: false,
          onGeneralTap: _onGeneralTap,
          pagePaintCallbacks: [_paintSeparator],
          onViewerReady: (document, controller) {
            unawaited(_restore(controller));
            unawaited(_loadContent(document));
          },
          linkHandlerParams: PdfLinkHandlerParams(
            onLinkTap: _onLink,
            // Los enlaces no se marcan: el PDF se ve tal cual (propietario,
            // 2026-09-28). Sin esto pdfrx los pinta de azul, también los
            // bloqueados, que no hacen nada.
            linkColor: Colors.transparent,
          ),
          viewerOverlayBuilder: _caption.isEmpty
              ? null
              : (context, size, _) => [
                  ValueListenableBuilder<Matrix4>(
                    valueListenable: _controller,
                    builder: (context, m, _) => _bandOverlay(m, args),
                  ),
                ],
          loadingBannerBuilder: (_, _, _) => const SizedBox.shrink(),
          errorBannerBuilder: (_, _, _, _) => const SizedBox.shrink(),
        );
        final source = args.source;
        final path = source.path;
        final bytes = source.bytes;
        final viewer = path != null
            ? PdfViewer.file(
                path,
                key: ValueKey(source.key),
                // Con 20 páginas como máximo, todas de una vez (CA-008-03).
                useProgressiveLoading: false,
                controller: _controller,
                params: params,
              )
            : bytes != null
            ? PdfViewer.data(
                bytes,
                sourceName: source.key,
                key: ValueKey(source.key),
                // Con 20 páginas como máximo, todas de una vez (CA-008-03).
                useProgressiveLoading: false,
                controller: _controller,
                params: params,
              )
            : const SizedBox.expand();
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _accessible(
                Stack(
                  fit: StackFit.expand,
                  children: [
                    // Su semántica dice "Page N" en inglés: se usa la nuestra.
                    ExcludeSemantics(child: viewer),
                    PdfSemanticsLayer(
                      controller: _controller,
                      content: _content,
                      onLink: _onLink,
                      prefix: args.taskLabel,
                    ),
                  ],
                ),
              ),
              if (!_ready) TaskPdfFace(args: args),
            ],
          ),
        );
      },
    );
  }

  static void _paintSeparator(ui.Canvas canvas, Rect pageRect, PdfPage page) {
    final paint = Paint()..color = UnaColors.ink;
    canvas.drawRect(
      Rect.fromLTWH(
        pageRect.left,
        pageRect.bottom,
        pageRect.width,
        UnaBorders.strongWidth * pageRect.width / page.width,
      ),
      paint,
    );
  }

  /// La banda sigue al documento: su borde de arriba es el del documento y
  /// se amplía con él.
  Widget _bandOverlay(Matrix4 m, TaskPdfArgs args) {
    if (!_controller.isReady || _width <= 0) return const SizedBox.shrink();
    final zoom = m.zoom;
    final fit = _controller.minScale;
    final t = m.getTranslation();
    return Positioned(
      left: t.x,
      top: t.y,
      child: Transform.scale(
        scale: fit <= 0 ? 1 : zoom / fit,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _width,
          height: _bandPx,
          child: PdfCaptionBand(text: _caption, color: args.captionColor),
        ),
      ),
    );
  }
}

/// Primer fotograma (y la cara que se rompe o se arruga al completar o
/// eliminar): la banda (si se empieza por arriba) y la versión de pantalla de
/// la página, colocada en la fracción guardada.
class TaskPdfFace extends StatelessWidget {
  const TaskPdfFace({super.key, required this.args});

  final TaskPdfArgs args;

  @override
  Widget build(BuildContext context) {
    final caption = args.caption ?? '';
    final position = args.initialPosition ?? PdfPosition.start;
    final atStart = position == PdfPosition.start;
    return ColoredBox(
      color: UnaColors.surface,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (atStart && caption.isNotEmpty)
                PdfCaptionBand(text: caption, color: args.captionColor),
              FractionalTranslation(
                translation: Offset(0, atStart ? 0 : -position.offset),
                child: Image(
                  image: args.screen,
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
