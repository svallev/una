import 'package:app/features/attachments/pdf_labels.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formatos de números y plurales por idioma (spec 010, CA-010-04). Los pares
/// son los de la spec, copiados tal cual.
void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('CA-010-04: formatos ES/EN', () {
    test('CA-010-04: tamaño de un PDF con el separador decimal del idioma', () {
      expect(pdfSize(es, 2400000), '2,4 MB');
      expect(pdfSize(en, 2400000), '2.4 MB');
    });

    test('CA-010-04: por debajo de 1 MB, "3 KB" en los dos idiomas', () {
      expect(pdfSize(es, 3000), '3 KB');
      expect(pdfSize(en, 3000), '3 KB');
    });

    test('CA-010-04: "Todas mis tareas" en singular y en plural', () {
      expect(es.menuAllTasksCount(1), '1 tarea');
      expect(es.menuAllTasksCount(3), '3 tareas');
      expect(en.menuAllTasksCount(1), '1 task');
      expect(en.menuAllTasksCount(3), '3 tasks');
    });

    test('CA-010-04: caracteres restantes del editor', () {
      expect(es.editorCharsLeft(1), 'Queda 1 carácter');
      expect(es.editorCharsLeft(5), 'Quedan 5 caracteres');
      expect(en.editorCharsLeft(1), '1 character left');
      expect(en.editorCharsLeft(5), '5 characters left');
    });

    test('CA-010-04: anuncio de eliminar desde el listado', () {
      expect(es.a11yDeletedFromList(1), 'Tarea eliminada. Queda 1');
      expect(es.a11yDeletedFromList(3), 'Tarea eliminada. Quedan 3');
      expect(en.a11yDeletedFromList(1), 'Task deleted. 1 left');
      expect(en.a11yDeletedFromList(3), 'Task deleted. 3 left');
    });
  });
}
