import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/link_target.dart';
import '../../domain/services/link_policy.dart';
import '../../l10n/generated/app_localizations.dart';

/// Texto y enlaces de una página, leídos una vez al abrir el PDF (con 20
/// páginas como máximo caben todos, CA-008-03).
@immutable
class PdfPageContent {
  const PdfPageContent({required this.text, required this.links});

  final String text;
  final List<PdfLink> links;
}

/// Lee el texto y los enlaces de todas las páginas de [document]. Una página
/// que falla se queda sin texto ni enlaces (CL-008-4).
Future<Map<int, PdfPageContent>> loadPdfContent(PdfDocument document) async {
  Future<MapEntry<int, PdfPageContent>> load(PdfPage page) async {
    try {
      final loaded = await page.ensureLoaded();
      final (text, links) = await (loaded.loadText(), loaded.loadLinks()).wait;
      return MapEntry(
        page.pageNumber,
        PdfPageContent(text: text?.fullText.trim() ?? '', links: links),
      );
    } on Object {
      return MapEntry(
        page.pageNumber,
        const PdfPageContent(text: '', links: []),
      );
    }
  }

  return Map.fromEntries(await Future.wait(document.pages.map(load)));
}

/// Qué hace un enlace del PDF según [classifyLink] (CA-008-12).
LinkTarget linkTargetOf(PdfLink link) =>
    classifyLink(url: link.url, destPage: link.dest?.pageNumber);

/// Etiqueta de un enlace para el lector (CA-008-12), o null si no hace nada.
String? linkLabel(AppLocalizations l10n, LinkTarget target) => switch (target) {
  InternalLink(:final page) => l10n.pdfLinkPage(page),
  WebLink(:final host) => l10n.pdfLinkWeb(host),
  MailLink(:final display) => l10n.pdfLinkApp(display),
  PhoneLink(:final display) => l10n.pdfLinkApp(display),
  BlockedLink() => null,
};

/// Capa de accesibilidad del PDF (CA-008-20/22), encima del visor (cuya
/// semántica propia se excluye: dice "Page N" en inglés). Por cada página
/// visible, un nodo "Página n de total" seguido de su texto; por cada enlace
/// que hace algo, un nodo enfocable (lector y Tab) con su etiqueta, que se
/// activa con Enter. No capta toques: los gestos siguen yendo al visor.
class PdfSemanticsLayer extends StatelessWidget {
  const PdfSemanticsLayer({
    super.key,
    required this.controller,
    required this.content,
    required this.onLink,
    required this.ready,
    this.prefix,
  });

  final PdfViewerController controller;

  /// El visor ya tiene su tamaño y su posición. `isReady` del controlador
  /// solo dice que el documento está cargado: puede serlo antes de la primera
  /// maquetación, y entonces `viewSize` falla (visto en el emulador al
  /// rearrancar con un PDF, T-008-22).
  final bool ready;
  final Map<int, PdfPageContent> content;
  final ValueChanged<PdfLink> onLink;

  /// Se lee delante de la primera página visible: "Tarea actual: …" en
  /// horizontal, donde no está la franja (CA-008-20).
  final String? prefix;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      // Sin el texto todavía, cada página se lee al menos "Página n de total".
      if (!ready || !controller.isReady) return const SizedBox.shrink();
      final l10n = AppLocalizations.of(context);
      final m = controller.value;
      final view = Offset.zero & controller.viewSize;
      final pages = controller.pages;
      final layout = controller.layout.pageLayouts;
      final total = pages.length;
      final children = <Widget>[];
      var first = true;
      for (var i = 0; i < pages.length && i < layout.length; i++) {
        final page = pages[i];
        final rect = MatrixUtils.transformRect(m, layout[i]);
        if (!rect.overlaps(view)) continue;
        final data = content[page.pageNumber];
        final text = data?.text ?? '';
        final pageLabel = l10n.pdfPageA11y(page.pageNumber, total);
        final withText = text.isEmpty ? pageLabel : '$pageLabel. $text';
        final lead = first ? prefix : null;
        first = false;
        final label = lead == null ? withText : '$lead. $withText';
        final links = <Widget>[];
        for (final link in data?.links ?? const <PdfLink>[]) {
          final target = linkTargetOf(link);
          final linkText = linkLabel(l10n, target);
          if (linkText == null || link.rects.isEmpty) continue;
          final docRect = link.rects.first.toRectInDocument(
            page: page,
            pageRect: layout[i],
          );
          final r = MatrixUtils.transformRect(m, docRect);
          links.add(
            Positioned.fromRect(
              rect: r.shift(-rect.topLeft),
              child: _LinkNode(label: linkText, onActivate: () => onLink(link)),
            ),
          );
        }
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              sortKey: OrdinalSortKey(page.pageNumber.toDouble()),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    label: label,
                    readOnly: true,
                    child: const SizedBox.expand(),
                  ),
                  ...links,
                ],
              ),
            ),
          ),
        );
      }
      return Stack(fit: StackFit.expand, children: children);
    },
  );
}

/// Un enlace para el lector y el teclado: con foco se ve el anillo (WCAG
/// 2.4.7); Enter o el doble toque del lector lo activan.
class _LinkNode extends StatefulWidget {
  const _LinkNode({required this.label, required this.onActivate});

  final String label;
  final VoidCallback onActivate;

  @override
  State<_LinkNode> createState() => _LinkNodeState();
}

class _LinkNodeState extends State<_LinkNode> {
  var _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode _) => setState(() {});

  // Sin FocusableActionDetector: su MouseRegion es opaca y se quedaba los
  // toques del dedo, que no llegaban al visor (ni al enlace ni al doble toque).
  // Los toques los recibe pdfrx (`onLinkTap`); esta capa es solo para el
  // lector y el teclado.
  @override
  Widget build(BuildContext context) {
    final ring =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onActivate();
              return null;
            },
          ),
        },
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: Semantics(
            link: true,
            label: widget.label,
            onTap: widget.onActivate,
            excludeSemantics: true,
            // El anillo tampoco capta toques (BoxDecoration sí lo haría).
            child: IgnorePointer(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: ring
                      ? Border.all(
                          color: UnaColors.ink,
                          width: UnaBorders.focusWidth,
                        )
                      : null,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
