import 'package:app/features/attachments/pdf_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Páginas de mentira: en los tests de widgets no se usa el motor de PDF (se
/// prueba aparte). Muestran la clave del documento para comprobar cuál es.
final fakePdfViews = <Override>[
  pdfPreviewBuilderProvider.overrideWithValue(
    (source) => ColoredBox(
      key: const Key('fake-pdf-pages'),
      color: const Color(0xFFFFFFFF),
      child: Text('pdf:${source.key}'),
    ),
  ),
];
