import Foundation

/// El tope de un grupo de fotos (spec 016, CA-016-24; CA-020-21 y CA-028-11). Espejo de
/// `PickedItems.kt`: Swift puro, sin UIKit ni PhotosUI, para comprobar con un contador de accesos
/// que el trabajo no crece con lo que devuelva el selector (T-3 y T-16 del modelo de amenazas).
enum PickedItems {
  /// Los primeros `max` elementos de un selector que dice tener `count`, en su orden, con `at`
  /// (índice → elemento, o `nil` si no tiene dirección, que se salta). **Solo se llama a `at` para
  /// los índices `0 ..< min(count, max)`**: los demás elementos ni se abren, ni se consultan, ni se
  /// copian, lleguen miles o `Int.max`. Un `count` o un `max` no positivo no toca nada.
  static func firstItems<T>(count: Int, max: Int, at: (Int) -> T?) -> [T] {
    let limit = Swift.min(count, max)
    if limit <= 0 { return [] }
    var items: [T] = []
    items.reserveCapacity(limit)
    for index in 0..<limit {
      if let item = at(index) { items.append(item) }
    }
    return items
  }
}
