/// Un párrafo de una licencia: su texto y su sangría (0 = ninguna; -1 = centrado,
/// como `LicenseParagraph.centeredIndent` de Flutter).
typedef LicenseParagraph = ({String text, int indent});

/// El texto de una licencia, ya dividido en párrafos (CA-012-03, CA-012-11).
/// Es contenido de terceros, en inglés: se muestra tal cual.
final class LicenseText {
  const LicenseText(this.paragraphs);

  final List<LicenseParagraph> paragraphs;

  @override
  bool operator ==(Object other) =>
      other is LicenseText && _sameParagraphs(other.paragraphs);

  bool _sameParagraphs(List<LicenseParagraph> other) {
    if (other.length != paragraphs.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i] != paragraphs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(paragraphs);
}

/// Un elemento de terceros de la lista de licencias (CA-012-03): un paquete, una
/// fuente, una biblioteca nativa o el grupo de bibliotecas de Android.
final class LicensePackage {
  const LicensePackage({required this.name, required this.texts});

  final String name;

  /// Sus textos de licencia **distintos**, en el orden en que se leyeron.
  final List<LicenseText> texts;

  /// Cuántos textos de licencia distintos tiene (lo que dice la fila de la lista).
  int get licenseCount => texts.length;
}
