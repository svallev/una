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
    this.onUnreadable,
    this.caption,
    this.actions = const {},
    this.onLink,
    this.taskLabel,
  });

  final PdfSource source;

  /// La versión de pantalla: lo que se ve desde [initialPosition] (la página
  /// desde su fracción y las de debajo), dibujado al ancho. Se ve en el primer
  /// fotograma y hasta que el visor ha dibujado esas páginas (CA-008-08).
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

  /// El motor no puede abrir el PDF: la pantalla muestra "Adjunto no
  /// disponible" (CA-008-18).
  final VoidCallback? onUnreadable;

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

  /// Escala del texto de la banda: la del sistema, hasta
  /// [UnaSizes.imageCaptionMaxTextScale] (como el pie de la imagen, 007). La
  /// misma al medir el alto ([heightFor]) y al dibujarlo: si no, con el texto
  /// grande las páginas tapan las últimas líneas.
  static TextScaler scalerOf(BuildContext context) =>
      MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: UnaSizes.imageCaptionMaxTextScale);

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
        // El borde no aparta al hijo (DecoratedBox): abajo, relleno y borde,
        // como [heightFor] (y el CSS del prototipo). Así la banda del primer
        // fotograma mide lo mismo que la del visor.
        padding: const EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.m,
          UnaSpace.l,
          UnaSpace.m + UnaBorders.strongWidth,
        ),
        child: Text(text, style: captionStyle, textScaler: scalerOf(context)),
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

  /// Cambia el hueco de la banda (se edita el texto) o el tamaño de la vista.
  /// pdfrx conserva lo que se ve respecto a la página de arriba; si se veía la
  /// banda (el principio), la página 1 baja al alargar el texto y la parte de
  /// arriba de la banda quedaba fuera de la vista: se vuelve al principio,
  /// con la banda entera (CA-008-08). A media lectura, como pdfrx: las páginas
  /// no saltan (CA-008-09).
  @override
  void onLayoutUpdate({
    required PdfViewerLayoutSnapshot oldState,
    required PdfViewerLayoutSnapshot newState,
    required double currentZoom,
    required Rect oldVisibleRect,
    required int? anchorPageNumber,
    required bool isLayoutChanged,
    required bool isViewSizeChanged,
  }) {
    final controller = _controller;
    final oldPages = oldState.layout?.pageLayouts ?? const <Rect>[];
    if (controller != null &&
        isLayoutChanged &&
        newState.layout != null &&
        oldPages.isNotEmpty &&
        positionIn(oldState.layout!, oldVisibleRect) == PdfPosition.start) {
      final zoom =
          currentZoom < newState.minScale || currentZoom == oldState.minScale
          ? newState.minScale
          : currentZoom;
      unawaited(
        controller.goToPosition(
          documentOffset: Offset(oldVisibleRect.left, 0),
          zoom: zoom,
        ),
      );
      return;
    }
    _legacy.onLayoutUpdate(
      oldState: oldState,
      newState: newState,
      currentZoom: currentZoom,
      oldVisibleRect: oldVisibleRect,
      anchorPageNumber: anchorPageNumber,
      isLayoutChanged: isLayoutChanged,
      isViewSizeChanged: isViewSizeChanged,
    );
  }
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

/// Si el visor no avisa de que ha dibujado las páginas que se ven (una página
/// que no se puede dibujar, CL-008-4), la versión de pantalla se quita pasado
/// este tiempo. Holgado: en el emulador, el aviso llega hasta 2,8 s después de
/// estar listo, y quitarla antes deja las páginas en blanco (CA-008-08); si
/// se toca, se quita antes.
const pdfFaceTimeout = Duration(seconds: 10);

/// Páginas al 100 % del ancho, una debajo de otra, con desplazamiento vertical
/// y zoom (CA-008-08/10). Hasta que el visor ha dibujado las páginas que se
/// ven en la última posición, encima está la versión de pantalla: el primer
/// fotograma no espera al motor y la página nunca se ve en blanco.
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

  /// El visor ha dibujado las páginas que se ven al empezar (o se ha tocado,
  /// o ha pasado [pdfFaceTimeout]): ya se puede quitar la versión de pantalla.
  var _painted = false;
  Timer? _faceTimer;
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
    // Flutter entrega las acciones al sistema ordenadas por su identificador,
    // que es global y se da la primera vez que se ve cada una: se registran
    // aquí en el orden de CA-008-20, o "Página anterior" (que aparece
    // después) quedaría detrás de las de zoom.
    final l10n = AppLocalizations.of(context);
    widget.args.actions.keys.forEach(CustomSemanticsAction.getIdentifier);
    for (final label in [
      l10n.pdfNextPage,
      l10n.pdfPrevPage,
      l10n.pdfZoomIn,
      l10n.pdfZoomOut,
      l10n.pdfZoomFit,
    ]) {
      CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));
    }
    // Otra pantalla encima (menú, editor, listado): se guarda al taparse.
    final covered = !(ModalRoute.isCurrentOf(context) ?? true);
    if (covered && !_covered) _leave();
    _covered = covered;
  }

  @override
  void dispose() {
    _faceTimer?.cancel();
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

  /// La página de arriba, para "Página siguiente" y "Página anterior". Tras
  /// ir a una página, el borde de arriba puede quedar una fracción de punto
  /// por encima de ella (redondeo): se cuenta con medio punto de margen, o
  /// "Página siguiente" iría una y otra vez a la misma (visto en T-008-23).
  int get _page {
    if (!_controller.isReady || !_restored) return _visible?.page ?? 1;
    return positionIn(
      _controller.layout,
      _controller.visibleRect.translate(0, 0.5),
    ).page;
  }

  void _goToPage(int page) {
    if (!_controller.isReady) return;
    if (page < 1 || page > _controller.pageCount) return;
    // Con la página arriba del todo (la 1, con la banda del texto). No con
    // `goToPage`: si la página cabe entera en la vista, la centra y deja
    // arriba el final de la anterior (visto en T-008-23).
    final top = page == 1 ? 0.0 : _controller.layout.pageLayouts[page - 1].top;
    unawaited(
      _controller.goToPosition(
        documentOffset: Offset(_controller.visibleRect.left, top),
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

  /// Acciones del lector y de Switch Access sobre el PDF, en este orden:
  /// completar, eliminar, página y zoom; solo las que se pueden hacer ahora
  /// (CA-008-10, CA-008-20). Las lleva cada página visible
  /// ([PdfSemanticsLayer]).
  Map<CustomSemanticsAction, VoidCallback> _readerActions() {
    final ready = _controller.isReady && _ready;
    if (!ready) return const {};
    final l10n = AppLocalizations.of(context);
    final r = _relative;
    final page = _page;
    final pages = _controller.pageCount;
    return {
      ...widget.args.actions,
      // En la última pantalla no hay "siguiente", aunque arriba se vea la
      // penúltima página.
      if (page < pages && _canScroll(0, 1))
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
    };
  }

  /// Desplazamiento sin gestos para el lector y Switch Access (CA-008-10):
  /// en el contenedor, que es lo que desplazan sus gestos de desplazamiento.
  Widget _accessible(Widget child) => ListenableBuilder(
    // Solo escucha: leer `value` antes de que el visor esté listo falla.
    listenable: _controller,
    builder: (context, child) {
      final ready = _controller.isReady && _ready;
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
    if (!mounted) return;
    setState(() => _ready = true);
    _faceTimer ??= Timer(pdfFaceTimeout, _showViewer);
  }

  /// Quita la versión de pantalla: se ve el visor.
  void _showViewer() {
    _faceTimer?.cancel();
    if (mounted && !_painted) setState(() => _painted = true);
  }

  /// La última página que se verá al volver a la posición guardada (CA-008-08).
  /// pdfrx avisa de que ha terminado de cargar ([PdfViewerParams
  /// .onDocumentLoadFinished]) cuando tiene dibujada su página inicial, y las
  /// dibuja en orden, así que esa es también la de las de encima: hasta
  /// entonces se ve la versión de pantalla.
  int? _lastVisiblePage(PdfDocument document, PdfViewerController controller) {
    final pages = controller.layout.pageLayouts;
    final view = controller.viewSize;
    if (pages.isEmpty || view.width <= 0) return null;
    final position = widget.args.initialPosition ?? PdfPosition.start;
    var top = 0.0;
    if (position != PdfPosition.start) {
      final p = position.clampTo(pages.length);
      final r = pages[p.page - 1];
      top = r.top + p.offset * r.height;
    }
    // Al ancho: la vista mide su alto en unidades del documento así.
    final bottom =
        top + view.height * controller.layout.documentSize.width / view.width;
    var last = 1;
    for (var i = 0; i < pages.length && pages[i].top < bottom; i++) {
      last = i + 1;
    }
    return last;
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
                PdfCaptionBand.scalerOf(context),
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
          calculateInitialPageNumber: _lastVisiblePage,
          onViewerReady: (document, controller) {
            unawaited(_restore(controller));
            unawaited(_loadContent(document));
          },
          onDocumentLoadFinished: (_, succeeded) {
            // Ya ha dibujado las páginas que se ven (CA-008-08).
            if (succeeded) return _showViewer();
            // No se puede abrir (estropeado tras guardarlo): la pantalla
            // muestra "Adjunto no disponible" (CA-008-18).
            widget.args.onUnreadable?.call();
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
        final initialPage = (args.initialPosition ?? PdfPosition.start).page;
        final path = source.path;
        final bytes = source.bytes;
        final viewer = path != null
            ? PdfViewer.file(
                path,
                key: ValueKey(source.key),
                initialPageNumber: initialPage,
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
                initialPageNumber: initialPage,
                // Con 20 páginas como máximo, todas de una vez (CA-008-03).
                useProgressiveLoading: false,
                controller: _controller,
                params: params,
              )
            : const SizedBox.expand();
        // Al tocar, se quita la versión de pantalla (si el visor aún no ha
        // avisado) y el gesto le llega al visor.
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (_ready) _showViewer();
          },
          child: ClipRect(
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
                        ready: _ready,
                        content: _content,
                        onLink: _onLink,
                        prefix: args.taskLabel,
                        actions: _readerActions,
                      ),
                    ],
                  ),
                ),
                // Solo imagen: el lector ya lee la capa de debajo.
                if (!_ready || !_painted)
                  IgnorePointer(
                    ignoring: _ready,
                    child: ExcludeSemantics(child: TaskPdfFace(args: args)),
                  ),
              ],
            ),
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
/// eliminar): la banda (si se empieza por arriba) y la versión de pantalla,
/// que es lo que se ve desde la posición guardada. Al completar o eliminar, si
/// hay [snapshot] (lo que se veía, CA-008-19), esa imagen.
class TaskPdfFace extends StatelessWidget {
  const TaskPdfFace({super.key, required this.args, this.snapshot});

  final TaskPdfArgs args;

  /// Imagen de lo que se veía al empezar a completar o eliminar.
  final ui.Image? snapshot;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    if (snapshot != null) {
      return ColoredBox(
        color: UnaColors.surface,
        child: ClipRect(
          child: RawImage(
            image: snapshot,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
      );
    }
    final caption = args.caption ?? '';
    final position = args.initialPosition ?? PdfPosition.start;
    final atStart = position == PdfPosition.start;
    // La versión de pantalla ya empieza en la fracción guardada: arriba del
    // todo, sin desplazarla (CA-008-08).
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
              Image(
                image: args.screen,
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
