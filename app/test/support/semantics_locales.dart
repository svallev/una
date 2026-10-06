import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los nombres de idioma que llevan **su propio** idioma, sea cual sea el de la
/// app (CA-015-11, la única excepción).
const ownLanguageNames = {'Español', 'English'};

/// Los datos de todos los nodos del árbol semántico actual que no se funden en
/// un padre (su información ya está en el que los absorbe). Hace falta
/// `tester.ensureSemantics()` activo.
List<SemanticsData> allSemanticsData(WidgetTester tester) {
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent && !node.isInvisible) {
      out.add(node.getSemanticsData());
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return out;
}

bool _hasText(SemanticsData d) =>
    d.label.isNotEmpty || d.value.isNotEmpty || d.hint.isNotEmpty;

bool _isOwnName(SemanticsData d) =>
    ownLanguageNames.any((name) => d.label.contains(name));

/// Las marcas de idioma de [data] que no son el idioma de la app
/// ([languageCode], CA-015-11): `locale` del nodo (los nodos con texto) y los
/// `LocaleStringAttribute` de sus etiquetas. **Se saltan** los nodos que
/// contienen "Español" o "English" como nombre o valor (llevan su propio
/// idioma, o dos marcas: se comprueban con [localeOfName]).
///
/// Lista vacía = todo lo que se recorre lleva el idioma de la app.
List<String> localeMarksOutsideApp(WidgetTester tester, String languageCode) {
  final found = <String>[];
  for (final d in allSemanticsData(tester)) {
    if (!_hasText(d) || _isOwnName(d)) continue;
    if (d.locale == null || d.locale!.languageCode != languageCode) {
      found.add('locale ${d.locale}: "${d.label}"');
    }
    for (final attributed in [d.attributedLabel, d.attributedValue]) {
      for (final attribute in attributed.attributes) {
        if (attribute is LocaleStringAttribute &&
            attribute.locale.languageCode != languageCode) {
          found.add('${attribute.locale}: "${attributed.string}"');
        }
      }
    }
  }
  return found;
}

/// El idioma con el que el lector dice [name] dentro de la etiqueta de [data]:
/// el `LocaleStringAttribute` que cubre ese tramo o, si no hay ninguno, el
/// `locale` del nodo. `null` si la etiqueta no lo contiene.
Locale? localeOfName(SemanticsData data, String name) {
  final text = data.attributedLabel.string;
  final start = text.indexOf(name);
  if (start < 0) return null;
  for (final attribute in data.attributedLabel.attributes) {
    if (attribute is LocaleStringAttribute &&
        attribute.range.start <= start &&
        attribute.range.end >= start + name.length) {
      return attribute.locale;
    }
  }
  return data.locale;
}

/// El nodo cuya etiqueta es exactamente [label].
SemanticsData semanticsLabelled(WidgetTester tester, String label) =>
    allSemanticsData(tester).singleWhere((d) => d.label == label);
