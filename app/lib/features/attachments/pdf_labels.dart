import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// Nombre del PDF para mostrar y leer: el guardado o, si no hay, "PDF"
/// (CA-008-07).
String pdfName(AppLocalizations l10n, String? name) =>
    (name == null || name.isEmpty) ? l10n.attachmentPdf : name;

/// Tamaño como el prototipo: KB enteros por debajo de 1 MB y MB con un
/// decimal (MB = 10⁶ bytes), con el separador decimal del idioma ("2,4 MB" /
/// "2.4 MB").
String pdfSize(AppLocalizations l10n, int bytes) {
  const mb = 1000 * 1000;
  if (bytes < mb) {
    final kb = (bytes / 1000).ceil().clamp(1, 999);
    return l10n.docSizeKb(kb.toString());
  }
  final format = NumberFormat('0.0', l10n.localeName);
  return l10n.docSizeMb(format.format(bytes / mb));
}
