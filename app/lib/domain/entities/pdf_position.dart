import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Última posición vista de un PDF (CA-008-09): la página que ocupaba la parte
/// de arriba de la zona (desde 1) y cuánto se había desplazado dentro de ella
/// (0..1). No depende del ancho, así que sirve al girar o en otro dispositivo.
@immutable
class PdfPosition {
  const PdfPosition({required this.page, required this.offset});

  static const start = PdfPosition(page: 1, offset: 0);

  final int page;
  final double offset;

  /// La misma posición sin pasar de [pageCount] páginas.
  PdfPosition clampTo(int pageCount) => PdfPosition(
    page: page.clamp(1, pageCount < 1 ? 1 : pageCount),
    offset: offset,
  );

  String toJson() => jsonEncode({'page': page, 'offset': offset});

  /// Lee [source]; los valores fuera de rango se acotan y lo ilegible da null
  /// (entonces se empieza por la primera página).
  static PdfPosition? fromJson(String source) {
    try {
      final map = jsonDecode(source);
      if (map is! Map) return null;
      final page = map['page'];
      final offset = map['offset'];
      if (page is! num || offset is! num) return null;
      return PdfPosition(
        page: page.toInt() < 1 ? 1 : page.toInt(),
        offset: offset.toDouble().clamp(0.0, 1.0),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PdfPosition && other.page == page && other.offset == offset;

  @override
  int get hashCode => Object.hash(page, offset);

  @override
  String toString() => 'PdfPosition($page, $offset)';
}
