import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/theme/tokens.g.dart';
import '../../data/attachments/attachment_images.dart';

/// Páginas de un PDF, una debajo de otra y al ancho (spec 008). Se sustituye
/// en los tests de widgets ([pdfPreviewBuilderProvider]): el motor de verdad
/// se prueba aparte (`pdf_engine_test`, integración).
typedef PdfPreviewBuilder = Widget Function(PdfSource source);

/// Vista previa del editor (CA-008-04): las páginas desplazables, sin zoom
/// ni enlaces. Un único elemento para el lector (lo lee el recuadro).
final pdfPreviewBuilderProvider = Provider<PdfPreviewBuilder>(
  (ref) =>
      (source) => ExcludeSemantics(child: _PreviewPages(source)),
);

class _PreviewPages extends StatelessWidget {
  const _PreviewPages(this.source);

  final PdfSource source;

  static const _params = PdfViewerParams(
    backgroundColor: UnaColors.surface,
    margin: 0,
    pageDropShadow: null,
    scaleEnabled: false,
    panAxis: PanAxis.vertical,
    enableKeyboardNavigation: false,
  );

  @override
  Widget build(BuildContext context) {
    final path = source.path;
    final bytes = source.bytes;
    if (path != null) {
      return PdfViewer.file(path, key: ValueKey(source.key), params: _params);
    }
    if (bytes != null) {
      return PdfViewer.data(
        bytes,
        sourceName: source.key,
        key: ValueKey(source.key),
        params: _params,
      );
    }
    return const SizedBox.expand();
  }
}
