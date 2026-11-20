import Foundation

/// Datos en reposo (CA-028-18, ADR-0032 y ADR-0005).
///
/// - **Copia de seguridad (ADR-0032):** la base de datos va en `Documents/` y **sí** entra en la
///   copia de iCloud o del ordenador; la carpeta de adjuntos, `Application Support/attachments/`
///   (la que Dart abre con `getApplicationSupportDirectory`, `file_attachment_store.dart`), queda
///   **fuera**: como en Android, un iPhone restaurado muestra «Adjunto no disponible».
///   Lo temporal (la preparación de una importación) vive en `Caches/`, que iOS ya excluye.
/// - **Protección de datos (ADR-0005):** este código **no** la toca. Se queda la clase por defecto
///   de iOS («hasta el primer desbloqueo»), la misma para la BD y los adjuntos; bajarla (`none`) o
///   subirla (`complete`) rompería el contrato, y `DataAtRestTests` lo vigila sobre el código y el
///   proyecto.
///
/// Se ejecuta al arrancar el motor, antes del primer fotograma: una carpeta y un atributo, sin leer
/// nada del disco más. Dart solo crea esa carpeta y nunca la borra, así que marcarla en cada
/// arranque basta (si Dart la creó antes, en un primer uso, el siguiente arranque la marca).
enum DataAtRest {
  /// Nombre de la carpeta de adjuntos dentro de «Application Support» (igual que en Dart).
  static let attachmentsName = "attachments"

  /// «Application Support» del contenedor de la app: la misma carpeta que devuelve
  /// `getApplicationSupportDirectory` en iOS (`Library/Application Support`, sin subcarpeta).
  static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL? {
    return try? fileManager.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  }

  /// Crea `attachments/` dentro de [base] si falta y la marca como excluida de la copia de seguridad
  /// (sea nueva o ya existente). No toca lo que haya dentro. Devuelve la carpeta.
  @discardableResult
  static func prepareAttachments(
    in base: URL, fileManager: FileManager = .default
  ) throws -> URL {
    var directory = base.appendingPathComponent(attachmentsName, isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let current = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
    if current.isExcludedFromBackup != true {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try directory.setResourceValues(values)
    }
    return directory
  }

  /// Lo que llama el arranque del motor. Si algo falla (disco lleno, carpeta ilegible) **no** se
  /// detiene el arranque ni se registra nada (P4: sin rutas en registros): la app sigue y el siguiente
  /// arranque lo vuelve a intentar. Devuelve si quedó preparada.
  @discardableResult
  static func prepareAttachmentsAtLaunch(applicationSupport: URL? = nil) -> Bool {
    guard let base = applicationSupport ?? applicationSupportDirectory() else { return false }
    do {
      try prepareAttachments(in: base)
      return true
    } catch {
      return false
    }
  }
}
