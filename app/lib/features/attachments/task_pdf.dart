import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/theme/tokens.g.dart';
import '../../data/attachments/attachment_images.dart';
import '../../domain/entities/pdf_position.dart';

/// Lo que la pantalla principal le da al visor del PDF (CA-008-08/09).
@immutable
class TaskPdfArgs {
  const TaskPdfArgs({
    required this.source,
    required this.screen,
    required this.captionColor,
    required this.initialPosition,
    required this.onPosition,
    this.caption,
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

  /// Cada vez que cambia la posición visible (la pantalla la guarda al salir).
  final ValueChanged<PdfPosition> onPosition;
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
  var _ready = false;
  var _restored = false;
  double _width = 0;
  double _bandPx = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMatrix);
  }

  @override
  void dispose() {
    _controller.removeListener(_onMatrix);
    super.dispose();
  }

  String get _caption => widget.args.caption ?? '';

  void _onMatrix() {
    if (!_controller.isReady || !_restored) return;
    widget.args.onPosition(
      positionIn(_controller.layout, _controller.visibleRect),
    );
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
          pagePaintCallbacks: [_paintSeparator],
          onViewerReady: (_, controller) => unawaited(_restore(controller)),
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
                controller: _controller,
                params: params,
              )
            : bytes != null
            ? PdfViewer.data(
                bytes,
                sourceName: source.key,
                key: ValueKey(source.key),
                controller: _controller,
                params: params,
              )
            : const SizedBox.expand();
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              viewer,
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
