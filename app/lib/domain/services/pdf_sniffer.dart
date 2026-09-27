/// Límites de la importación de PDF (spec 008, CA-008-03 y D18).
abstract final class PdfLimits {
  /// 10 MB, contados mientras se copia (CA-008-14).
  static const int maxBytes = 10 * 1000 * 1000;
  static const int maxBytesInMb = 10;

  /// Consulta rápida, no documentos largos (propietario, 2026-09-27).
  static const int maxPages = 20;

  /// Tiempo máximo de copia + comprobación (CA-008-14).
  static const Duration timeout = Duration(seconds: 20);

  /// Bytes de cabecera que necesita [isPdf].
  static const int headBytes = 1024;
}

const _signature = [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-

/// ¿Es un PDF por el contenido (CA-008-02)? Como PDFium, busca `%PDF-` en los
/// primeros [PdfLimits.headBytes] bytes; la extensión y el tipo declarado no
/// cuentan. Que se pueda abrir se comprueba después, con el motor.
bool isPdf(List<int> head) {
  final end = head.length < PdfLimits.headBytes
      ? head.length
      : PdfLimits.headBytes;
  outer:
  for (var i = 0; i + _signature.length <= end; i++) {
    for (var j = 0; j < _signature.length; j++) {
      if (head[i + j] != _signature[j]) continue outer;
    }
    return true;
  }
  return false;
}
