/// Los primeros [max] elementos de una lista que **no se materializa** (un
/// `FileList` del navegador, un `clipData`): solo se llama a [item] para los
/// índices `0..min(length, max)-1`; el resto ni se toca (CA-016-02,
/// CL-016-15). [total] es lo que había, para avisar de que se recortó.
///
/// Dart puro (sin `dart:js_interop`): así se prueba en la VM, y el importador
/// web lo usa tal cual.
({List<T> items, int total}) takeFirst<T>({
  required int length,
  required T? Function(int index) item,
  required int max,
}) {
  final count = length < max ? length : max;
  final items = <T>[];
  for (var i = 0; i < count; i++) {
    final it = item(i);
    if (it != null) items.add(it);
  }
  return (items: items, total: length);
}
