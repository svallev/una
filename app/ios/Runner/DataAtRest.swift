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
/// - **Datos de la WebView (R2 de la 028, opción (b), propietario, 2026-11-23):** el paquete
///   `webview_flutter_wkwebview` no deja usar un almacén no persistente sin *swizzling*, así que la
///   WebView usa `WKWebsiteDataStore.default()` (desviación de ADR-0007 y ADR-0016, contrato §3).
///   Lo que guarda (`Library/WebKit/`: almacenamiento web, IndexedDB, estadísticas…; y
///   `Library/Cookies/`) queda **fuera** de la copia de seguridad: las dos carpetas se crean si
///   faltan (para marcarlas antes de que WebKit escriba nada; WebKit usa la que encuentra) y se
///   marcan al arrancar y antes de cada carga web (`WebViewHardening`), por si WebKit las recrea.
///   Marcar una carpeta excluye todo lo que tiene dentro. La caché ya va en `Caches/`.
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

  /// Carpetas de `Library/` donde WebKit guarda los datos de las páginas con el almacén por defecto.
  static let webDataNames = ["WebKit", "Cookies"]

  /// `Library/` del contenedor de la app.
  static func libraryDirectory(fileManager: FileManager = .default) -> URL? {
    return try? fileManager.url(
      for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  }

  /// Crea `WebKit/` y `Cookies/` dentro de [library] si faltan y las marca como excluidas de la
  /// copia de seguridad (sean nuevas o ya existentes). No toca lo que haya dentro. Devuelve las
  /// carpetas.
  @discardableResult
  static func prepareWebData(
    in library: URL, fileManager: FileManager = .default
  ) throws -> [URL] {
    return try webDataNames.map { name in
      try excludedDirectory(
        library.appendingPathComponent(name, isDirectory: true), fileManager: fileManager)
    }
  }

  /// Lo que llaman el arranque y la WebView antes de cargar. Si falla, ni detiene nada ni registra
  /// nada (P4); se vuelve a intentar en la siguiente carga. Devuelve si quedaron preparadas.
  @discardableResult
  static func prepareWebDataNow(library: URL? = nil) -> Bool {
    guard let base = library ?? libraryDirectory() else { return false }
    do {
      try prepareWebData(in: base)
      return true
    } catch {
      return false
    }
  }

  /// Crea [url] si falta y la marca como excluida de la copia de seguridad si aún no lo está.
  private static func excludedDirectory(_ url: URL, fileManager: FileManager) throws -> URL {
    // Un `URL` guarda en caché los valores ya leídos: se lee siempre desde uno nuevo.
    var directory = URL(fileURLWithPath: url.path, isDirectory: true)
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
