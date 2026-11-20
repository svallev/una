import AVFoundation
import Flutter
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Códigos de error de `una/images` (contrato §2). Van **solo como código**: nunca un mensaje, una
/// ruta, un nombre ni una dirección (CL-007-10, CL-016-16). `cameraDenied` es solo de iOS (CA-028-10).
enum ImageImportCode: String, Error {
  case busy, noCamera, cameraDenied, unreadable, tooLarge, tooManyPixels, noSpace, cancelled
}

/// Lo que devolvió el selector de fotos. Solo se pide un elemento por índice (el tope de
/// `PickedItems` cuenta los accesos, CA-020-21).
protocol PickedPhotos {
  var count: Int { get }
  func provider(at index: Int) -> NSItemProvider?
}

/// Los selectores del sistema. Es un protocolo para probar el canal sin abrir nada de verdad. Cada
/// método devuelve `false` si no hay desde dónde presentar (como `ActivityNotFoundException`).
/// Las respuestas llegan en el hilo principal.
protocol ImagePickerPresenting: AnyObject {
  /// Cámara: la foto hecha, o `nil` si el usuario canceló.
  func presentCamera(_ completion: @escaping (UIImage?) -> Void) -> Bool
  /// Selector de fotos con `limit` como mucho (en el orden elegido si `limit > 1`).
  func presentPhotos(limit: Int, _ completion: @escaping (PickedPhotos) -> Void) -> Bool
  /// Selector de documentos (solo PDF, con copia): la copia elegida, o `nil`.
  func presentDocument(_ completion: @escaping (URL?) -> Void) -> Bool
}

/// La cámara y su permiso (CA-028-10). Protocolo para probar todos los estados en el simulador.
protocol CameraAuthorizing {
  var isCameraAvailable: Bool { get }
  var authorizationStatus: AVAuthorizationStatus { get }
  /// El diálogo del sistema; la respuesta puede llegar en cualquier hilo.
  func requestAccess(_ completion: @escaping (Bool) -> Void)
}

/// Destino de una copia acotada. Protocolo para simular un disco lleno en los tests.
protocol ByteSink {
  func write(_ data: Data) throws
  /// Vuelca a disco y cierra.
  func finish() throws
  /// Cierra sin más (tras un fallo).
  func close()
}

/// Archivo real: lo crea vacío y escribe por bloques.
final class FileSink: ByteSink {
  private let handle: FileHandle

  init(url: URL) throws {
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    handle = try FileHandle(forWritingTo: url)
  }

  func write(_ data: Data) throws {
    try handle.write(contentsOf: data)
  }

  func finish() throws {
    try handle.synchronize()
    try handle.close()
  }

  func close() {
    try? handle.close()
  }
}

/// Canal `una/images` (contrato §2; espejo de `ImageImport.kt`; spec 007, 008 y 016; spec 028
/// CA-028-10 y CA-028-11): selección, copia, limpieza (`sanitize`, `regenerate`) y codificación de la
/// página de un PDF (`encodeJpeg`), estas tres con `ImageSanitizer` (ImageIO y Core Graphics).
///
/// - Sin permisos para la galería ni para los PDF (selectores del sistema); la cámara sí lo pide,
///   porque iOS no deja abrirla sin él (CA-028-10): denegado o restringido → `cameraDenied`.
/// - Los tokens son **opacos** (`camera:<id>`, `picker:<uuid>`, `document:<uuid>`) y apuntan a lo que
///   eligió el usuario en esta sesión; ninguna ruta ni dirección se acepta como token (equivale a
///   `isForeignContent` de Kotlin). Cada token de galería o de PDF se usa una sola vez.
/// - Todo lo que escribe va a `Caches/import/` (la misma carpeta que `getTemporaryDirectory()/import`
///   de Dart) o, para `regenerate` y `encodeJpeg` sobre lo guardado, a
///   `Application Support/attachments/<id>/`; nunca a la fototeca ni a archivos compartidos.
/// - Nunca registra rutas, nombres ni metadatos (CL-007-10).
final class Images {
  /// Tope de fotos de un grupo (CA-016-02); Dart pide el suyo y aquí se acota.
  static let maxGroup = 10
  private static let headBytes = 64
  /// Cabecera máxima que se devuelve (el PDF busca `%PDF-` en 1024, spec 008).
  private static let maxHeadBytes = 1024
  /// Nombre visible más largo que se devuelve (Dart lo recorta a 120).
  private static let maxName = 1024
  private static let buffer = 64 * 1024
  /// Tras cancelar, cuánto se espera como mucho a que el sistema suelte una foto que carga.
  private static let cancelGrace: TimeInterval = 2

  private let importRoot: URL
  private let fixtures: URL
  private let presenter: ImagePickerPresenting
  private let camera: CameraAuthorizing
  private let settings: LinkApplication
  private let freeSpaceProvider: () -> Int64?
  private let makeSink: (URL) throws -> ByteSink
  private let applicationSupport: URL?
  private let screenSize: () -> (width: Int, height: Int)
  private let writer: ImageSanitizer.Writer
  /// Solo para los tests: avisa al empezar (`true`) y al acabar (`false`) cada limpieza.
  var sanitizeProbe: ((Bool) -> Void)?

  /// Copias, `regenerate` y `encodeJpeg` (como el `executor` de dos hilos de Kotlin).
  private let work = DispatchQueue(
    label: "una.images.work", qos: .userInitiated, attributes: .concurrent)
  /// Cancelar nunca espera en la cola de `work`: el borrado va por la suya.
  private let cleaner = DispatchQueue(label: "una.images.cleaner", qos: .utility)
  /// La limpieza corre en **una cola serie propia** (spec 016, CA-016-04): nunca hay dos a la vez,
  /// aunque Dart dé por agotada una y empiece otra; y una limpieza cancelada mientras esperaba turno
  /// sale sin hacer nada (mira su bandera **antes de empezar**).
  private let sanitizer = DispatchQueue(label: "una.images.sanitize", qos: .userInitiated)
  private let cancelled = LockedMap<CancelFlag>()
  /// Cargas de fotos en curso (`loadFileRepresentation`), para que cancelar las corte.
  private let loads = LockedMap<Progress>()
  /// Lo elegido en esta sesión, por token.
  private let picks = LockedMap<StoredPick>()
  /// Hay un selector abierto (solo se toca en el hilo principal).
  private var pending = false

  private enum StoredPick {
    case photo(NSItemProvider)
    case document(URL)
  }

  init(
    cachesDirectory: URL? = nil,
    presenter: ImagePickerPresenting = SystemImagePickerPresenter(),
    camera: CameraAuthorizing = SystemCamera(),
    settings: LinkApplication = SystemLinkApplication(),
    freeSpace: @escaping () -> Int64? = Images.systemFreeSpace,
    makeSink: @escaping (URL) throws -> ByteSink = { try FileSink(url: $0) },
    applicationSupportDirectory: URL? = nil,
    screenSize: @escaping () -> (width: Int, height: Int) = Images.systemScreenSize,
    writer: @escaping ImageSanitizer.Writer = ImageSanitizer.atomicWriter
  ) {
    let caches =
      cachesDirectory
      ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    importRoot = caches.appendingPathComponent("import", isDirectory: true)
    fixtures = caches.appendingPathComponent("fixtures", isDirectory: true)
    self.presenter = presenter
    self.camera = camera
    self.settings = settings
    freeSpaceProvider = freeSpace
    self.makeSink = makeSink
    applicationSupport = applicationSupportDirectory
    self.screenSize = screenSize
    self.writer = writer
  }

  /// `Application Support/attachments/`: la de `getApplicationSupportDirectory()/attachments` de Dart.
  private var attachmentsRoot: URL? {
    return (applicationSupport ?? DataAtRest.applicationSupportDirectory())?
      .appendingPathComponent(DataAtRest.attachmentsName, isDirectory: true)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      // ImageIO lee HEIC en iOS 16.
      result(["heic": true])
    case "pick":
      pick(call, result)
    case "pickMany":
      pickMany(call, result)
    case "debugPickManyDocuments":
      // Solo existe en Android (el selector de documentos de Android 8–12); su test de integración
      // se salta en iOS y el tope lo prueba `PickedItemsTests` (contrato §9).
      result(FlutterMethodNotImplemented)
    case "freeSpace":
      // 0, negativo o desconocido → `null`: nunca bloquea la importación (CL-016-6).
      if let free = freeSpaceProvider(), free > 0 {
        result(Int(free))
      } else {
        result(nil)
      }
    case "copy":
      copy(call, result)
    case "sanitize":
      sanitize(call, result)
    case "regenerate":
      regenerate(call, result)
    case "encodeJpeg":
      encodeJpeg(call, result)
    case "cancel":
      cancel(call, result)
    case "openAppSettings":
      openAppSettings(result)
    case "debugCopyFile":
      #if DEBUG
        debugCopyFile(call, result)
      #else
        result(FlutterMethodNotImplemented)
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Argumentos

  /// `^[A-Za-z0-9_-]{1,64}$` (contrato §0.3), mirado byte a byte.
  static func isValidId(_ value: String) -> Bool {
    let bytes = value.utf8
    guard (1...64).contains(bytes.count) else { return false }
    return bytes.allSatisfy { byte in
      (0x30...0x39).contains(byte) || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
        || byte == 0x5F || byte == 0x2D
    }
  }

  private static func arguments(_ call: FlutterMethodCall) -> [String: Any] {
    return call.arguments as? [String: Any] ?? [:]
  }

  private static func id(_ arguments: [String: Any]) -> String? {
    guard let id = arguments["id"] as? String, isValidId(id) else { return nil }
    return id
  }

  private static func number(_ value: Any?) -> NSNumber? {
    return value as? NSNumber
  }

  private static func headBytes(_ arguments: [String: Any]) -> Int {
    let asked = number(arguments["headBytes"])?.intValue ?? headBytes
    return Swift.min(Swift.max(asked, 1), maxHeadBytes)
  }

  private static func fail(_ result: FlutterResult, _ code: ImageImportCode) {
    result(FlutterError(code: code.rawValue, message: nil, details: nil))
  }

  // MARK: - Elegir

  private func pick(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = Images.arguments(call)
    guard let origin = arguments["origin"] as? String, let id = Images.id(arguments) else {
      return Images.fail(result, .unreadable)
    }
    if pending { return Images.fail(result, .busy) }
    pending = true
    switch origin {
    case "camera":
      pickFromCamera(id, result)
    case "file":
      // Selector de documentos, solo PDF y con copia (CA-008-01): sin permisos.
      let shown = presenter.presentDocument { url in
        self.pending = false
        guard let url else { return result(nil) }
        // El nombre visible solo se devuelve para un PDF (CA-008-07); Dart lo sanea.
        let name = String(url.lastPathComponent.prefix(Images.maxName))
        result(["token": self.store(.document(url)), "name": name])
      }
      if !shown {
        pending = false
        Images.fail(result, .unreadable)
      }
    default:
      let shown = presenter.presentPhotos(limit: 1) { photos in
        self.pending = false
        let tokens = PickedItems.firstItems(count: photos.count, max: 1) { index in
          photos.provider(at: index).map { self.store(.photo($0)) }
        }
        if let token = tokens.first {
          result(["token": token, "name": NSNull()])
        } else {
          result(nil)
        }
      }
      if !shown {
        pending = false
        Images.fail(result, .unreadable)
      }
    }
  }

  /// Cámara con su permiso (CA-028-10): sin cámara → `noCamera` (el simulador, CL-007-1); denegado
  /// o restringido → `cameraDenied` sin volver a preguntar (CL-028-2, CL-028-3); sin decidir → el
  /// diálogo del sistema y, si dice que no, `cameraDenied`.
  private func pickFromCamera(_ id: String, _ result: @escaping FlutterResult) {
    guard camera.isCameraAvailable else {
      pending = false
      return Images.fail(result, .noCamera)
    }
    switch camera.authorizationStatus {
    case .authorized:
      openCamera(id, result)
    case .notDetermined:
      camera.requestAccess { granted in
        DispatchQueue.main.async {
          if granted {
            self.openCamera(id, result)
          } else {
            self.pending = false
            Images.fail(result, .cameraDenied)
          }
        }
      }
    default:
      pending = false
      Images.fail(result, .cameraDenied)
    }
  }

  private func openCamera(_ id: String, _ result: @escaping FlutterResult) {
    let file = importRoot.appendingPathComponent("\(id).camera")
    let shown = presenter.presentCamera { image in
      self.pending = false
      guard let image else { return result(nil) }
      self.work.async {
        let written = CameraFile.write(image, to: file)
        if !written { try? FileManager.default.removeItem(at: file) }
        DispatchQueue.main.async {
          // Como Kotlin: el token solo si quedó algo escrito; si no, como cancelar.
          result(written ? ["token": "camera:\(id)"] : nil)
        }
      }
    }
    if !shown {
      pending = false
      try? FileManager.default.removeItem(at: file)
      Images.fail(result, .noCamera)
    }
  }

  /// Selector múltiple (CA-016-02), sin permisos. **El tope se aplica antes de abrir ninguna**
  /// (`PickedItems`, CA-016-24): solo se mira el proveedor de las `min(count, max)` primeras; `total`
  /// es lo que devolvió el sistema. Una sola llamada pendiente (`busy`), como `pick`.
  private func pickMany(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let asked = Images.number(Images.arguments(call)["max"])?.intValue ?? Images.maxGroup
    let max = Swift.min(Swift.max(asked, 1), Images.maxGroup)
    if pending { return Images.fail(result, .busy) }
    pending = true
    let shown = presenter.presentPhotos(limit: max) { photos in
      self.pending = false
      let total = photos.count
      let tokens = PickedItems.firstItems(count: total, max: max) { index in
        photos.provider(at: index).map { self.store(.photo($0)) }
      }
      if tokens.isEmpty {
        result(nil)
      } else {
        result(["tokens": tokens, "total": total])
      }
    }
    if !shown {
      pending = false
      Images.fail(result, .unreadable)
    }
  }

  private func store(_ pick: StoredPick) -> String {
    let prefix: String
    switch pick {
    case .photo: prefix = "picker:"
    case .document: prefix = "document:"
    }
    let token = prefix + UUID().uuidString
    picks[token] = pick
    return token
  }

  // MARK: - Copiar

  private func copy(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = Images.arguments(call)
    guard let id = Images.id(arguments), let token = arguments["token"] as? String,
      let maxBytes = Images.number(arguments["maxBytes"])?.int64Value
    else {
      return Images.fail(result, .unreadable)
    }
    let headBytes = Images.headBytes(arguments)
    let flag = CancelFlag()
    cancelled[id] = flag
    background(id, result) {
      if token.hasPrefix("camera:") {
        let cameraId = String(token.dropFirst("camera:".count))
        guard Images.isValidId(cameraId) else { throw ImageImportCode.unreadable }
        let file = self.importRoot.appendingPathComponent("\(cameraId).camera")
        // Ninguna otra copia de lo que escribió la cámara.
        defer { try? FileManager.default.removeItem(at: file) }
        return try self.copyFile(file, id, maxBytes, headBytes, flag)
      }
      // Solo lo que eligió el usuario en esta sesión; cada token, una vez.
      guard let stored = self.picks.removeValue(forKey: token) else {
        throw ImageImportCode.unreadable
      }
      switch stored {
      case .document(let url):
        // La copia del selector (en el `tmp/` de la app) se borra al terminar.
        defer { try? FileManager.default.removeItem(at: url) }
        return try self.copyFile(url, id, maxBytes, headBytes, flag)
      case .photo(let provider):
        return try self.copyPhoto(provider, id, maxBytes, headBytes, flag)
      }
    }
  }

  private func copyFile(
    _ url: URL, _ id: String, _ maxBytes: Int64, _ headBytes: Int, _ flag: CancelFlag
  ) throws -> [String: Any] {
    let input: FileHandle
    do {
      input = try FileHandle(forReadingFrom: url)
    } catch {
      throw ImageImportCode.unreadable
    }
    defer { try? input.close() }
    return try boundedCopy(id, maxBytes, headBytes, flag) {
      try input.read(upToCount: Images.buffer)
    }
  }

  /// Una foto de la galería: **solo la imagen fija** (de una Live Photo, nunca la parte de vídeo) con
  /// `loadFileRepresentation`, copiada mientras el sistema mantiene el archivo. Cancelar corta la
  /// carga (`Progress`; una foto solo en iCloud sin red, CL-028-5).
  private func copyPhoto(
    _ provider: NSItemProvider, _ id: String, _ maxBytes: Int64, _ headBytes: Int,
    _ flag: CancelFlag
  ) throws -> [String: Any] {
    guard let type = Images.stillImageType(provider.registeredTypeIdentifiers) else {
      throw ImageImportCode.unreadable
    }
    let done = DispatchSemaphore(value: 0)
    let outcome = Box<Result<[String: Any], Error>>(.failure(ImageImportCode.unreadable))
    let progress = provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
      defer { done.signal() }
      if flag.isSet {
        outcome.value = .failure(ImageImportCode.cancelled)
      } else if let url, error == nil {
        // El archivo solo existe mientras dura esta llamada.
        outcome.value = Result { try self.copyFile(url, id, maxBytes, headBytes, flag) }
      } else {
        outcome.value = .failure(ImageImportCode.unreadable)
      }
    }
    loads[id] = progress
    defer { _ = loads.removeValue(forKey: id) }
    var cancelledAt: Date?
    while done.wait(timeout: .now() + 0.1) == .timedOut {
      guard flag.isSet else { continue }
      if let since = cancelledAt {
        if Date().timeIntervalSince(since) > Images.cancelGrace { throw ImageImportCode.cancelled }
      } else {
        cancelledAt = Date()
        progress.cancel()
      }
    }
    return try outcome.value.get()
  }

  /// El primer tipo de imagen del proveedor que no sea el paquete de una Live Photo.
  static func stillImageType(_ identifiers: [String]) -> String? {
    return identifiers.first { identifier in
      guard identifier != "com.apple.live-photo-bundle", let type = UTType(identifier) else {
        return false
      }
      return type.conforms(to: .image)
    }
  }

  /// Copia a `import/<id>/source` contando bytes y aborta al pasar de `maxBytes` (CA-007-14). Un
  /// fallo, una cancelación o 0 bytes no dejan nada.
  private func boundedCopy(
    _ id: String, _ maxBytes: Int64, _ headBytes: Int, _ flag: CancelFlag,
    read: () throws -> Data?
  ) throws -> [String: Any] {
    let directory = importRoot.appendingPathComponent(id, isDirectory: true)
    var head = Data()
    var total: Int64 = 0
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let sink = try makeSink(directory.appendingPathComponent("source"))
      do {
        copying: while true {
          if flag.isSet { throw ImageImportCode.cancelled }
          let chunk: Data
          do {
            guard let data = try read(), !data.isEmpty else { break copying }
            chunk = data
          } catch {
            throw flag.isSet ? ImageImportCode.cancelled : ImageImportCode.unreadable
          }
          total += Int64(chunk.count)
          if total > maxBytes { throw ImageImportCode.tooLarge }
          if head.count < headBytes {
            head.append(chunk.prefix(headBytes - head.count))
          }
          try sink.write(chunk)
        }
        try sink.finish()
      } catch {
        sink.close()
        throw error
      }
    } catch let code as ImageImportCode {
      try? FileManager.default.removeItem(at: directory)
      throw code
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw Images.isNoSpace(error) ? ImageImportCode.noSpace : ImageImportCode.unreadable
    }
    if total == 0 {
      try? FileManager.default.removeItem(at: directory)
      throw ImageImportCode.unreadable
    }
    return ["byteSize": Int(total), "head": FlutterStandardTypedData(bytes: head)]
  }

  static func isNoSpace(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) { return true }
    if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
      return true
    }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
      return isNoSpace(underlying)
    }
    return false
  }

  #if DEBUG
    /// Solo en depuración: los tests de integración importan archivos de `Caches/fixtures/` (o un
    /// flujo sin fin, `/dev/zero`) (contrato §9).
    private func debugCopyFile(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
      let arguments = Images.arguments(call)
      guard let id = Images.id(arguments), let path = arguments["path"] as? String,
        let maxBytes = Images.number(arguments["maxBytes"])?.int64Value
      else {
        return Images.fail(result, .unreadable)
      }
      let headBytes = Images.headBytes(arguments)
      let flag = CancelFlag()
      cancelled[id] = flag
      background(id, result) {
        guard self.isAllowedFixture(path) else { throw ImageImportCode.unreadable }
        return try self.copyFile(URL(fileURLWithPath: path), id, maxBytes, headBytes, flag)
      }
    }

    /// `/dev/zero`, `/dev/urandom` o un archivo **dentro** de `Caches/fixtures/`, comparando rutas
    /// canónicas (sin enlaces ni `..`), como `canonicalPath` en Kotlin.
    private func isAllowedFixture(_ path: String) -> Bool {
      if path == "/dev/zero" || path == "/dev/urandom" { return true }
      let base = fixtures.standardizedFileURL.resolvingSymlinksInPath().path + "/"
      let target = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
      return target.hasPrefix(base)
    }
  #endif

  // MARK: - Limpiar, regenerar y codificar

  /// Limpia `import/<id>/source` en la cola serie (contrato §2): `tooManyPixels` sin decodificar,
  /// versión completa en teselas, `screen.jpg` y `thumb.jpg`, sin ningún metadato. Borra `source`
  /// siempre. `type` no hace falta: ImageIO aplica la orientación de cualquier formato.
  private func sanitize(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = Images.arguments(call)
    guard let id = Images.id(arguments),
      let maxPixels = Images.number(arguments["maxPixels"])?.int64Value,
      let storedMaxPixels = Images.number(arguments["storedMaxPixels"])?.int64Value
    else {
      return Images.fail(result, .unreadable)
    }
    let flag = cancelled.getOrInsert(id, CancelFlag())
    let screen = screenSize()
    background(id, result, queue: sanitizer, last: true) {
      // Cancelada mientras esperaba turno: sale sin hacer nada.
      if flag.isSet { throw ImageImportCode.cancelled }
      self.sanitizeProbe?(true)
      defer { self.sanitizeProbe?(false) }
      let directory = self.importRoot.appendingPathComponent(id, isDirectory: true)
      let source = directory.appendingPathComponent("source")
      // No se conserva ningún byte del original.
      defer { try? FileManager.default.removeItem(at: source) }
      guard FileManager.default.fileExists(atPath: source.path) else {
        throw ImageImportCode.unreadable
      }
      let out = try ImageSanitizer(
        maxPixels: maxPixels, storedMaxPixels: storedMaxPixels, screenWidth: screen.width,
        screenHeight: screen.height, cancelled: flag, writer: self.writer
      ).sanitize(source: source, outDir: directory)
      return ["width": out.width, "height": out.height, "byteSize": Int(out.byteSize)]
    }
  }

  /// Rehace `screen.jpg` y `thumb.jpg` de un adjunto **guardado** desde sus teselas (CA-007-19). No
  /// toca las teselas ni la preparación; si falta la carpeta, `unreadable`.
  private func regenerate(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = Images.arguments(call)
    guard let id = Images.id(arguments),
      let width = Images.number(arguments["width"])?.intValue,
      let height = Images.number(arguments["height"])?.intValue
    else {
      return Images.fail(result, .unreadable)
    }
    let screen = screenSize()
    let directory = attachmentsRoot?.appendingPathComponent(id, isDirectory: true)
    respond(result) {
      guard let directory, Images.isDirectory(directory) else { throw ImageImportCode.unreadable }
      try ImageSanitizer(
        maxPixels: Int64.max, storedMaxPixels: Int64.max, screenWidth: screen.width,
        screenHeight: screen.height, writer: self.writer
      ).regenerateDerived(dir: directory, width: width, height: height)
      return nil
    }
  }

  /// `screen.jpg` desde los píxeles de una página de PDF (spec 008), en la preparación o en el
  /// adjunto guardado (al cambiar la última posición, CA-008-08). Escritura atómica; si la carpeta
  /// ya no existe, nada.
  private func encodeJpeg(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let arguments = Images.arguments(call)
    guard let id = Images.id(arguments),
      let width = Images.number(arguments["width"])?.intValue,
      let height = Images.number(arguments["height"])?.intValue,
      let pixels = (arguments["pixels"] as? FlutterStandardTypedData)?.data
    else {
      return Images.fail(result, .unreadable)
    }
    let bgra = (arguments["bgra"] as? Bool) == true
    let directory =
      arguments["target"] as? String == "stored"
      ? attachmentsRoot?.appendingPathComponent(id, isDirectory: true)
      : importRoot.appendingPathComponent(id, isDirectory: true)
    respond(result) {
      guard let directory else { return nil }
      try ImageSanitizer.encodeScreen(
        width: width, height: height, bgra: bgra, pixels: pixels, dir: directory,
        writer: self.writer)
      return nil
    }
  }

  private static func isDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue
  }

  /// Tamaño físico de la pantalla en vertical (ancho < alto), de la escena de la app. Sin escena
  /// (no debería pasar con la app delante), el de un iPhone grande [Suposición]: la versión de
  /// pantalla nunca sale más pequeña de lo que se verá. Se lee en el hilo principal.
  static func systemScreenSize() -> (width: Int, height: Int) {
    let screen = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.screen }
      .first
    let bounds = screen?.nativeBounds ?? CGRect(x: 0, y: 0, width: 1320, height: 2868)
    let a = Int(bounds.width.rounded())
    let b = Int(bounds.height.rounded())
    return (Swift.min(a, b), Swift.max(a, b))
  }

  // MARK: - Cancelar y Ajustes

  /// Marca la cancelación, corta una carga de foto en curso y borra `import/<id>/` e
  /// `import/<id>.camera` en otro hilo (CA-007-16).
  private func cancel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let id = Images.id(Images.arguments(call)) else {
      return Images.fail(result, .unreadable)
    }
    cancelled[id]?.set()
    loads[id]?.cancel()
    let directory = importRoot.appendingPathComponent(id, isDirectory: true)
    let cameraFile = importRoot.appendingPathComponent("\(id).camera")
    cleaner.async {
      try? FileManager.default.removeItem(at: directory)
      try? FileManager.default.removeItem(at: cameraFile)
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// Solo iOS (CA-028-10, Q-028-1): abre los Ajustes de la app en el sistema, donde se da el permiso
  /// de la cámara. Responde si se abrió.
  private func openAppSettings(_ result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return result(false) }
    settings.open(url) { opened in
      if Thread.isMainThread {
        result(opened)
      } else {
        DispatchQueue.main.async { result(opened) }
      }
    }
  }

  // MARK: - Utilidades

  /// Ejecuta `job` fuera del hilo principal y responde en él. Un error o una cancelación (también
  /// si llega mientras terminaba) no dejan nada de esta importación.
  private func background(
    _ id: String, _ result: @escaping FlutterResult, queue: DispatchQueue? = nil,
    last: Bool = false, _ job: @escaping () throws -> Any?
  ) {
    (queue ?? work).async {
      var outcome: Result<Any?, ImageImportCode>
      do {
        outcome = .success(try job())
      } catch let code as ImageImportCode {
        outcome = .failure(code)
      } catch {
        outcome = .failure(.unreadable)
      }
      if case .success = outcome, self.cancelled[id]?.isSet == true {
        outcome = .failure(.cancelled)
      }
      if case .failure = outcome {
        try? FileManager.default.removeItem(
          at: self.importRoot.appendingPathComponent(id, isDirectory: true))
        _ = self.cancelled.removeValue(forKey: id)
      } else if last {
        _ = self.cancelled.removeValue(forKey: id)
      }
      DispatchQueue.main.async {
        switch outcome {
        case .success(let value): result(value)
        case .failure(let code): Images.fail(result, code)
        }
      }
    }
  }

  /// Como `background` pero sin preparación que borrar (`regenerate`, `encodeJpeg`).
  private func respond(_ result: @escaping FlutterResult, _ job: @escaping () throws -> Any?) {
    work.async {
      let outcome: Result<Any?, ImageImportCode>
      do {
        outcome = .success(try job())
      } catch {
        outcome = .failure(ImageSanitizer.code(for: error))
      }
      DispatchQueue.main.async {
        switch outcome {
        case .success(let value): result(value)
        case .failure(let code): Images.fail(result, code)
        }
      }
    }
  }

  /// Bytes que la app puede guardar en su volumen (CL-016-6), o `nil` si no se sabe. API de motivo
  /// obligatorio (`DiskSpace`, `E174.1` en `PrivacyInfo.xcprivacy`, CA-028-17).
  static func systemFreeSpace() -> Int64? {
    guard let base = DataAtRest.applicationSupportDirectory() else { return nil }
    let values = try? base.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values?.volumeAvailableCapacityForImportantUsage
  }
}

/// La foto de la cámara en `import/<id>.camera`: JPEG desde los píxeles, **sin metadatos** salvo la
/// orientación (que la limpieza aplica y descarta). Nada de lo que trae la cámara (EXIF, GPS) pasa.
enum CameraFile {
  static func write(_ image: UIImage, to url: URL) -> Bool {
    guard let cgImage = image.cgImage else { return false }
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { return false }
    let properties: [CFString: Any] = [
      kCGImagePropertyOrientation: orientation(image.imageOrientation).rawValue,
      kCGImageDestinationLossyCompressionQuality: 0.95,
    ]
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return false }
    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    return size > 0
  }

  static func orientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}

// MARK: - Sistema

/// La cámara real y su permiso.
struct SystemCamera: CameraAuthorizing {
  var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
  var authorizationStatus: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }

  func requestAccess(_ completion: @escaping (Bool) -> Void) {
    AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
  }
}

/// Lo elegido en `PHPickerViewController`.
private struct PHPickedPhotos: PickedPhotos {
  let results: [PHPickerResult]
  var count: Int { results.count }

  func provider(at index: Int) -> NSItemProvider? {
    return results.indices.contains(index) ? results[index].itemProvider : nil
  }
}

/// Los selectores reales, presentados sobre la pantalla de arriba de la app. Guarda el delegado
/// mientras el selector está abierto; cada selector responde una sola vez (también si se cierra
/// deslizando).
final class SystemImagePickerPresenter: NSObject, ImagePickerPresenting {
  private var active: NSObject?

  private func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  func presentCamera(_ completion: @escaping (UIImage?) -> Void) -> Bool {
    guard let host = topViewController() else { return false }
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.mediaTypes = [UTType.image.identifier]
    picker.allowsEditing = false
    let delegate = CameraDelegate { [weak self] image in
      self?.active = nil
      completion(image)
    }
    picker.delegate = delegate
    picker.presentationController?.delegate = delegate
    active = delegate
    host.present(picker, animated: true)
    return true
  }

  func presentPhotos(limit: Int, _ completion: @escaping (PickedPhotos) -> Void) -> Bool {
    guard let host = topViewController() else { return false }
    var configuration = PHPickerConfiguration()
    configuration.selectionLimit = limit
    configuration.filter = .images
    configuration.selection = limit > 1 ? .ordered : .default
    // El archivo tal cual (HEIC incluido), sin que el sistema lo convierta.
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    let delegate = PhotosDelegate { [weak self] results in
      self?.active = nil
      completion(PHPickedPhotos(results: results))
    }
    picker.delegate = delegate
    picker.presentationController?.delegate = delegate
    active = delegate
    host.present(picker, animated: true)
    return true
  }

  func presentDocument(_ completion: @escaping (URL?) -> Void) -> Bool {
    guard let host = topViewController() else { return false }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
    picker.allowsMultipleSelection = false
    let delegate = DocumentDelegate { [weak self] url in
      self?.active = nil
      completion(url)
    }
    picker.delegate = delegate
    picker.presentationController?.delegate = delegate
    active = delegate
    host.present(picker, animated: true)
    return true
  }
}

private final class CameraDelegate: NSObject, UIImagePickerControllerDelegate,
  UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate
{
  private var completion: ((UIImage?) -> Void)?

  init(_ completion: @escaping (UIImage?) -> Void) {
    self.completion = completion
  }

  private func finish(_ image: UIImage?) {
    let completion = self.completion
    self.completion = nil
    completion?(image)
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    let image = info[.originalImage] as? UIImage
    picker.dismiss(animated: true)
    finish(image)
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    finish(nil)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finish(nil)
  }
}

private final class PhotosDelegate: NSObject, PHPickerViewControllerDelegate,
  UIAdaptivePresentationControllerDelegate
{
  private var completion: (([PHPickerResult]) -> Void)?

  init(_ completion: @escaping ([PHPickerResult]) -> Void) {
    self.completion = completion
  }

  private func finish(_ results: [PHPickerResult]) {
    let completion = self.completion
    self.completion = nil
    completion?(results)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    finish(results)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finish([])
  }
}

private final class DocumentDelegate: NSObject, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate
{
  private var completion: ((URL?) -> Void)?

  init(_ completion: @escaping (URL?) -> Void) {
    self.completion = completion
  }

  private func finish(_ url: URL?) {
    let completion = self.completion
    self.completion = nil
    completion?(url)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finish(urls.first)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(nil)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finish(nil)
  }
}

// MARK: - Concurrencia

/// Bandera de cancelación compartida entre hilos.
final class CancelFlag {
  private let lock = NSLock()
  private var value = false

  var isSet: Bool {
    lock.lock()
    defer { lock.unlock() }
    return value
  }

  func set() {
    lock.lock()
    value = true
    lock.unlock()
  }
}

/// Diccionario protegido por un cerrojo.
final class LockedMap<Value> {
  private let lock = NSLock()
  private var storage: [String: Value] = [:]

  subscript(key: String) -> Value? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storage[key]
    }
    set {
      lock.lock()
      storage[key] = newValue
      lock.unlock()
    }
  }

  /// El valor de `key` o, si no hay, `value` (que se guarda), de una vez.
  func getOrInsert(_ key: String, _ value: @autoclosure () -> Value) -> Value {
    lock.lock()
    defer { lock.unlock() }
    if let existing = storage[key] { return existing }
    let created = value()
    storage[key] = created
    return created
  }

  func removeValue(forKey key: String) -> Value? {
    lock.lock()
    defer { lock.unlock() }
    return storage.removeValue(forKey: key)
  }
}

/// Caja para un valor que escribe otro hilo (tras un semáforo).
private final class Box<Value> {
  var value: Value

  init(_ value: Value) {
    self.value = value
  }
}
