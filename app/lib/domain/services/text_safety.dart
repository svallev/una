/// Caracteres que no se muestran nunca en un nombre o un destino que viene de
/// fuera (T-3, T-5): C0, DEL, C1 y los de dirección del texto (LRM, RLM, ALM,
/// LRE a RLO, LRI a PDI), que permiten disfrazar "gnp.exe" como "exe.png".
final _unsafe = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069]',
);

/// [text] sin caracteres de control ni de cambio de dirección.
String stripUnsafeChars(String text) => text.replaceAll(_unsafe, '');
