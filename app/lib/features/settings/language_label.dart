import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Etiqueta del lector "[name], [value]" con el idioma propio de [value] sobre
/// su tramo (CA-015-11, camino A del plan §3): "Idioma, Español" lleva `es` en
/// "Español", y "Como el sistema, Español" lo mismo; el resto del texto hereda
/// el idioma de la app que pone `appFrame`.
AttributedString labelWithOwnLanguage(
  String name,
  String value,
  Locale locale,
) {
  final text = '$name, $value';
  return AttributedString(
    text,
    attributes: [
      LocaleStringAttribute(
        range: TextRange(start: name.length + 2, end: text.length),
        locale: locale,
      ),
    ],
  );
}
