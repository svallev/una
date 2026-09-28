import 'package:app/features/attachments/pdf_labels.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  test(
    'CA-008-08: el tamaño, como el prototipo, con el separador del idioma',
    () {
      expect(pdfSize(es, 2400000), '2,4 MB');
      expect(pdfSize(en, 2400000), '2.4 MB');
      expect(pdfSize(es, 10000000), '10,0 MB');
      expect(pdfSize(es, 3000), '3 KB');
      expect(pdfSize(es, 1), '1 KB');
      expect(pdfSize(es, 999999), '999 KB');
      expect(pdfSize(es, 1000000), '1,0 MB');
    },
  );

  test('CA-008-07: sin nombre, "PDF"', () {
    expect(pdfName(es, 'Programa.pdf'), 'Programa.pdf');
    expect(pdfName(es, null), 'PDF');
    expect(pdfName(es, ''), 'PDF');
  });
}
