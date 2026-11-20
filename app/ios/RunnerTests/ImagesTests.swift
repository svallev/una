import AVFoundation
import Flutter
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest

@testable import Runner

// MARK: - Dobles

/// Selectores de mentira: guardan lo que se abrió y el test decide qué devuelve el usuario.
private final class FakePresenter: ImagePickerPresenting {
  var canPresent = true
  private(set) var cameraOpened = 0
  private(set) var photosLimits: [Int] = []
  private(set) var documentsOpened = 0
  private var camera: ((UIImage?) -> Void)?
  private var photos: ((PickedPhotos) -> Void)?
  private var document: ((URL?) -> Void)?

  func presentCamera(_ completion: @escaping (UIImage?) -> Void) -> Bool {
    guard canPresent else { return false }
    cameraOpened += 1
    camera = completion
    return true
  }

  func presentPhotos(limit: Int, _ completion: @escaping (PickedPhotos) -> Void) -> Bool {
    guard canPresent else { return false }
    photosLimits.append(limit)
    photos = completion
    return true
  }

  func presentDocument(_ completion: @escaping (URL?) -> Void) -> Bool {
    guard canPresent else { return false }
    documentsOpened += 1
    document = completion
    return true
  }

  func finishCamera(_ image: UIImage?) {
    camera?(image)
    camera = nil
  }

  func finishPhotos(_ picked: PickedPhotos) {
    photos?(picked)
    photos = nil
  }

  func finishDocument(_ url: URL?) {
    document?(url)
    document = nil
  }
}

/// Cámara de mentira: disponibilidad, estado del permiso y respuesta del diálogo.
private final class FakeCamera: CameraAuthorizing {
  var isCameraAvailable = true
  var authorizationStatus: AVAuthorizationStatus = .authorized
  var grantsWhenAsked = true
  private(set) var asked = 0

  func requestAccess(_ completion: @escaping (Bool) -> Void) {
    asked += 1
    let granted = grantsWhenAsked
    // Como el sistema: la respuesta llega en otro hilo.
    DispatchQueue.global().async { completion(granted) }
  }
}

/// Fotos elegidas que cuentan cuántas se miran (CA-020-21: el tope es de accesos).
private final class CountingPhotos: PickedPhotos {
  let count: Int
  private let make: (Int) -> NSItemProvider?
  private(set) var touched: [Int] = []

  init(count: Int, make: @escaping (Int) -> NSItemProvider? = { _ in NSItemProvider() }) {
    self.count = count
    self.make = make
  }

  func provider(at index: Int) -> NSItemProvider? {
    touched.append(index)
    return make(index)
  }
}

/// Abridor de mentira para `openAppSettings`.
private final class FakeOpener: LinkApplication {
  var result = true
  private(set) var opened: [URL] = []

  func canOpenURL(_ url: URL) -> Bool { true }

  func open(_ url: URL, completion: @escaping (Bool) -> Void) {
    opened.append(url)
    completion(result)
  }
}

/// Destino que se queda sin espacio tras `limit` bytes (como `ENOSPC`).
private final class FullDiskSink: ByteSink {
  private var written = 0
  let limit: Int

  init(limit: Int) {
    self.limit = limit
  }

  func write(_ data: Data) throws {
    written += data.count
    if written > limit { throw POSIXError(.ENOSPC) }
  }

  func finish() throws {}
  func close() {}
}

// MARK: - Tests

/// `una/images`, selección y copia (contrato §2; espejo de `ImageImport.kt`; spec 028 CA-028-10 y
/// CA-028-11; CA-007-02/03/13/14/16, CA-008-01/02/07/14, CA-016-02/24, CA-020-21).
class ImagesTests: XCTestCase {
  private var root: URL!
  private var caches: URL { root.appendingPathComponent("Caches", isDirectory: true) }
  private var importRoot: URL { caches.appendingPathComponent("import", isDirectory: true) }
  private var fixtures: URL { caches.appendingPathComponent("fixtures", isDirectory: true) }
  private var presenter: FakePresenter!
  private var camera: FakeCamera!
  private var opener: FakeOpener!
  private var free: Int64?
  private var sink: ((URL) throws -> ByteSink)?
  private var images: Images!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("images-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
    presenter = FakePresenter()
    camera = FakeCamera()
    opener = FakeOpener()
    free = 1_000_000_000
    sink = nil
    images = makeImages()
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: root)
  }

  private func makeImages() -> Images {
    return Images(
      cachesDirectory: caches,
      presenter: presenter,
      camera: camera,
      settings: opener,
      freeSpace: { [unowned self] in self.free },
      makeSink: { [unowned self] url in try self.sink?(url) ?? FileSink(url: url) })
  }

  /// Llama al canal y espera la respuesta (que puede llegar en otro turno del hilo principal).
  @discardableResult
  private func invoke(
    _ method: String, _ arguments: Any? = nil, on target: Images? = nil,
    file: StaticString = #filePath, line: UInt = #line
  ) -> Any? {
    let answered = expectation(description: method)
    var answer: Any?
    (target ?? images).handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      XCTAssertTrue(Thread.isMainThread, "contrato §0.4: la respuesta, en el hilo principal", file: file, line: line)
      answer = $0
      answered.fulfill()
    }
    wait(for: [answered], timeout: 10)
    return answer
  }

  /// Lanza la llamada sin esperar: devuelve una función que espera y da la respuesta.
  private func start(_ method: String, _ arguments: Any? = nil) -> () -> Any? {
    let answered = expectation(description: method)
    var answer: Any?
    images.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      answer = $0
      answered.fulfill()
    }
    return { [unowned self] in
      self.wait(for: [answered], timeout: 10)
      return answer
    }
  }

  /// Comprueba que la respuesta es un error con **solo** el código (contrato §0.1).
  private func assertError(
    _ answer: Any?, _ code: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    guard let error = answer as? FlutterError else {
      return XCTFail("se esperaba el error \(code) y llegó \(String(describing: answer))", file: file, line: line)
    }
    XCTAssertEqual(error.code, code, file: file, line: line)
    XCTAssertNil(error.message, "sin texto (CL-007-10)", file: file, line: line)
    XCTAssertNil(error.details, "sin detalles (CL-007-10)", file: file, line: line)
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  private func writeFixture(_ name: String, _ data: Data) throws -> URL {
    let url = fixtures.appendingPathComponent(name)
    try data.write(to: url)
    return url
  }

  private func bytes(_ count: Int) -> Data {
    Data((0..<count).map { UInt8($0 % 251) })
  }

  /// Una imagen pequeña para la cámara.
  private func photo(orientation: UIImage.Orientation = .up) -> UIImage {
    let base = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 4)).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 8, height: 4))
    }
    return UIImage(cgImage: base.cgImage!, scale: 1, orientation: orientation)
  }

  /// Un proveedor de galería con un archivo de imagen (como el de `PHPickerResult`).
  private func provider(_ data: Data, type: UTType = .jpeg) -> NSItemProvider {
    let provider = NSItemProvider()
    provider.registerFileRepresentation(
      forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all
    ) { completion in
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("provider-\(UUID().uuidString)")
      do {
        try data.write(to: url)
        completion(url, false, nil)
      } catch {
        completion(nil, false, error)
      }
      return nil
    }
    return provider
  }

  /// Elige una foto en la galería de mentira y devuelve su token.
  private func pickGalleryToken(_ data: Data, id: String = "g1") -> String {
    let answer = start("pick", ["origin": "gallery", "id": id])
    presenter.finishPhotos(CountingPhotos(count: 1) { [unowned self] _ in self.provider(data) })
    let map = answer() as? [String: Any]
    return map?["token"] as? String ?? ""
  }

  // MARK: capabilities, freeSpace, métodos sin implementar

  func testCapabilitiesSayHeicIsSupported() {
    // Contrato §2: ImageIO lee HEIC en iOS 16.
    XCTAssertEqual(invoke("capabilities") as? [String: Bool], ["heic": true])
  }

  func testFreeSpaceIsUnknownWhenZeroOrUnavailable() {
    // CL-016-6: 0 o un fallo → desconocido (`null`), nunca un error.
    free = 123_456
    XCTAssertEqual(invoke("freeSpace") as? Int, 123_456)
    free = 0
    XCTAssertNil(invoke("freeSpace"))
    free = -5
    XCTAssertNil(invoke("freeSpace"))
    free = nil
    XCTAssertNil(invoke("freeSpace"))
  }

  func testTheRealFreeSpaceReadsTheVolumeOfTheApp() {
    // CA-028-17: la API de espacio libre (motivo E174.1 en el manifiesto) responde en el simulador.
    let value = Images.systemFreeSpace()
    XCTAssertNotNil(value)
    XCTAssertGreaterThan(value ?? 0, 0)
  }

  func testDebugPickManyDocumentsIsNotImplementedOnIos() {
    // Contrato §2 y §9: no hay selector de documentos de Android 8–12; `case` explícito.
    var answer: Any? = "sin respuesta"
    images.handle(FlutterMethodCall(methodName: "debugPickManyDocuments", arguments: ["max": 10])) {
      answer = $0
    }
    XCTAssertTrue((answer as AnyObject) === (FlutterMethodNotImplemented as AnyObject))
    XCTAssertTrue(presenter.photosLimits.isEmpty)
  }

  func testUnknownMethodsAreNotImplemented() {
    var answer: Any? = "sin respuesta"
    images.handle(FlutterMethodCall(methodName: "anything", arguments: nil)) { answer = $0 }
    XCTAssertTrue((answer as AnyObject) === (FlutterMethodNotImplemented as AnyObject))
  }

  // MARK: openAppSettings (solo iOS, CA-028-10)

  func testOpenAppSettingsOpensTheSettingsOfTheAppAndSaysIfItWorked() {
    // CA-028-10: el botón del aviso abre los Ajustes de la app.
    XCTAssertEqual(invoke("openAppSettings") as? Bool, true)
    XCTAssertEqual(opener.opened, [URL(string: UIApplication.openSettingsURLString)!])
    opener.result = false
    XCTAssertEqual(invoke("openAppSettings") as? Bool, false)
  }

  // MARK: pick: cámara y su permiso (CA-028-10)

  func testWithoutACameraTheAnswerIsNoCameraAndNothingOpens() {
    // CA-028-10 (sin cámara, el simulador) y CL-007-1: `noCamera`, sin preguntar el permiso.
    camera.isCameraAvailable = false
    camera.authorizationStatus = .notDetermined
    assertError(invoke("pick", ["origin": "camera", "id": "c1"]), "noCamera")
    XCTAssertEqual(camera.asked, 0)
    XCTAssertEqual(presenter.cameraOpened, 0)
  }

  func testDeniedOrRestrictedCameraAnswersCameraDeniedWithoutAsking() {
    // CA-028-10, CL-028-2 (iOS no deja volver a preguntar) y CL-028-3 (restringido = denegado).
    for status in [AVAuthorizationStatus.denied, .restricted] {
      camera.authorizationStatus = status
      assertError(invoke("pick", ["origin": "camera", "id": "c1"]), "cameraDenied")
    }
    XCTAssertEqual(camera.asked, 0)
    XCTAssertEqual(presenter.cameraOpened, 0)
    XCTAssertFalse(exists(importRoot.appendingPathComponent("c1.camera")))
  }

  func testFirstTimeTheSystemAsksAndADenialAnswersCameraDenied() {
    // CA-028-10: «Denegado ahora».
    camera.authorizationStatus = .notDetermined
    camera.grantsWhenAsked = false
    assertError(invoke("pick", ["origin": "camera", "id": "c1"]), "cameraDenied")
    XCTAssertEqual(camera.asked, 1)
    XCTAssertEqual(presenter.cameraOpened, 0)
    // La llamada ya no está pendiente: se puede volver a intentar.
    camera.authorizationStatus = .denied
    assertError(invoke("pick", ["origin": "camera", "id": "c2"]), "cameraDenied")
  }

  func testFirstTimeTheSystemAsksAndAGrantOpensTheCamera() throws {
    // CA-028-10: «Concedido: sigue igual que CA-007-02».
    camera.authorizationStatus = .notDetermined
    camera.grantsWhenAsked = true
    let answer = start("pick", ["origin": "camera", "id": "c1"])
    let opened = expectation(description: "cámara abierta")
    func poll() {
      if presenter.cameraOpened == 1 { return opened.fulfill() }
      DispatchQueue.main.async(execute: poll)
    }
    poll()
    wait(for: [opened], timeout: 5)
    presenter.finishCamera(photo())
    XCTAssertEqual((answer() as? [String: Any])?["token"] as? String, "camera:c1")
    XCTAssertEqual(camera.asked, 1)
  }

  func testTheCameraPhotoIsWrittenWithoutMetadataAndCopiedOnce() throws {
    // CA-007-02 y CA-028-10: la foto va a `import/<id>.camera`, sin metadatos más que la
    // orientación (la limpieza la aplica), y la copia la borra: ninguna otra copia queda.
    let answer = start("pick", ["origin": "camera", "id": "c1"])
    XCTAssertEqual(presenter.cameraOpened, 1)
    presenter.finishCamera(photo(orientation: .right))
    let map = try XCTUnwrap(answer() as? [String: Any])
    XCTAssertEqual(map["token"] as? String, "camera:c1")
    XCTAssertNil(map["name"], "como en Kotlin, la cámara no manda nombre")
    let file = importRoot.appendingPathComponent("c1.camera")
    let source = try XCTUnwrap(CGImageSourceCreateWithURL(file as CFURL, nil))
    XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
    let properties = try XCTUnwrap(
      CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    XCTAssertNil(properties[kCGImagePropertyGPSDictionary], "sin GPS")
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
    XCTAssertNil(tiff[kCGImagePropertyTIFFMake])
    XCTAssertNil(tiff[kCGImagePropertyTIFFModel])
    XCTAssertEqual(
      (properties[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value,
      CGImagePropertyOrientation.right.rawValue)

    let copied = try XCTUnwrap(
      invoke("copy", ["token": "camera:c1", "id": "c1", "maxBytes": 10_000_000]) as? [String: Any])
    XCTAssertGreaterThan(copied["byteSize"] as? Int ?? 0, 0)
    XCTAssertFalse(exists(file), "la copia borra lo que escribió la cámara")
    XCTAssertTrue(exists(importRoot.appendingPathComponent("c1/source")))
  }

  func testCancellingTheCameraAnswersNullAndLeavesNothing() {
    let answer = start("pick", ["origin": "camera", "id": "c1"])
    presenter.finishCamera(nil)
    XCTAssertNil(answer())
    XCTAssertFalse(exists(importRoot.appendingPathComponent("c1.camera")))
  }

  func testWhenTheCameraCannotBeShownTheAnswerIsNoCamera() {
    // Como `ActivityNotFoundException` en Kotlin: sin pantalla desde la que abrirla.
    presenter.canPresent = false
    assertError(invoke("pick", ["origin": "camera", "id": "c1"]), "noCamera")
    assertError(invoke("pick", ["origin": "gallery", "id": "g1"]), "unreadable")
    assertError(invoke("pick", ["origin": "file", "id": "f1"]), "unreadable")
    assertError(invoke("pickMany", ["max": 10]), "unreadable")
  }

  // MARK: pick: una llamada pendiente cada vez

  func testOnlyOnePickerAtATimeTheRestAreBusy() {
    // Contrato §2: una sola llamada pendiente; las demás, `busy`.
    let first = start("pick", ["origin": "gallery", "id": "g1"])
    assertError(invoke("pick", ["origin": "camera", "id": "c1"]), "busy")
    assertError(invoke("pick", ["origin": "file", "id": "f1"]), "busy")
    assertError(invoke("pickMany", ["max": 10]), "busy")
    presenter.finishPhotos(CountingPhotos(count: 0))
    XCTAssertNil(first())
    // Terminada la primera, se puede abrir otra.
    let second = start("pickMany", ["max": 10])
    presenter.finishPhotos(CountingPhotos(count: 0))
    XCTAssertNil(second())
  }

  func testInvalidArgumentsAnswerUnreadableWithoutText() {
    // Contrato §0.1 y §0.3: un `id` inválido o un argumento que falta, `unreadable` sin texto.
    for id in ["", "a/b", "../x", "with space", String(repeating: "a", count: 65), "ñ"] {
      assertError(invoke("pick", ["origin": "gallery", "id": id]), "unreadable")
      assertError(invoke("copy", ["token": "camera:\(id)", "id": id, "maxBytes": 10]), "unreadable")
      assertError(invoke("cancel", ["id": id]), "unreadable")
    }
    assertError(invoke("pick", ["id": "g1"]), "unreadable")
    assertError(invoke("pick", nil), "unreadable")
    assertError(invoke("copy", ["token": "camera:c1", "id": "c1"]), "unreadable")
    assertError(invoke("copy", ["id": "c1", "maxBytes": 10]), "unreadable")
    XCTAssertTrue(presenter.photosLimits.isEmpty)
  }

  // MARK: pick: galería (CA-007-03) y PDF (CA-008-01, CA-008-07)

  func testGalleryReturnsAnOpaqueTokenWithoutName() {
    // CA-028-11: el token no es una ruta ni una dirección; `name` nulo salvo con `file`.
    let answer = start("pick", ["origin": "gallery", "id": "g1"])
    XCTAssertEqual(presenter.photosLimits, [1])
    presenter.finishPhotos(CountingPhotos(count: 1) { [unowned self] _ in self.provider(self.bytes(10)) })
    let map = answer() as? [String: Any]
    let token = map?["token"] as? String ?? ""
    XCTAssertTrue(token.hasPrefix("picker:"), token)
    XCTAssertFalse(token.contains("/"))
    XCTAssertTrue(map?["name"] is NSNull)
  }

  func testCancellingTheGalleryOrTheDocumentPickerAnswersNull() {
    let gallery = start("pick", ["origin": "gallery", "id": "g1"])
    presenter.finishPhotos(CountingPhotos(count: 0))
    XCTAssertNil(gallery())
    let file = start("pick", ["origin": "file", "id": "f1"])
    presenter.finishDocument(nil)
    XCTAssertNil(file())
  }

  func testThePdfPickerReturnsTheVisibleNameAndCopiesTheHeadAskedFor() throws {
    // CA-008-01 (sin permisos), CA-008-07 (nombre visible) y CA-008-02 (`headBytes`).
    let picked = root.appendingPathComponent("Inbox/Factura de marzo.pdf")
    try FileManager.default.createDirectory(
      at: picked.deletingLastPathComponent(), withIntermediateDirectories: true)
    var pdf = Data("%PDF-1.7\n".utf8)
    pdf.append(bytes(3000))
    try pdf.write(to: picked)

    let answer = start("pick", ["origin": "file", "id": "f1"])
    XCTAssertEqual(presenter.documentsOpened, 1)
    presenter.finishDocument(picked)
    let map = try XCTUnwrap(answer() as? [String: Any])
    XCTAssertEqual(map["name"] as? String, "Factura de marzo.pdf")
    let token = try XCTUnwrap(map["token"] as? String)
    XCTAssertTrue(token.hasPrefix("document:"))
    XCTAssertFalse(token.contains("/"), "nunca una ruta como token")

    let copied = try XCTUnwrap(
      invoke("copy", ["token": token, "id": "f1", "maxBytes": 10_000, "headBytes": 1024]) as? [String: Any])
    XCTAssertEqual(copied["byteSize"] as? Int, pdf.count)
    XCTAssertEqual((copied["head"] as? FlutterStandardTypedData)?.data, pdf.prefix(1024))
    XCTAssertEqual(try Data(contentsOf: importRoot.appendingPathComponent("f1/source")), pdf)
    XCTAssertFalse(exists(picked), "la copia del selector se borra al terminar")
    // El token se usa una sola vez.
    assertError(invoke("copy", ["token": token, "id": "f2", "maxBytes": 10_000]), "unreadable")
  }

  func testTheVisibleNameIsCappedAt1024() throws {
    let long = String(repeating: "n", count: 200)
    let picked = root.appendingPathComponent(long + ".pdf")
    try Data("%PDF-".utf8).write(to: picked)
    let answer = start("pick", ["origin": "file", "id": "f1"])
    presenter.finishDocument(picked)
    let name = (answer() as? [String: Any])?["name"] as? String ?? ""
    XCTAssertEqual(name, long + ".pdf")
    XCTAssertLessThanOrEqual(name.count, 1024)
  }

  // MARK: pickMany (CA-016-02, CA-016-24, CA-020-21)

  func testPickManyAppliesTheCapBeforeTouchingAnyPhoto() throws {
    // CA-020-21 y CL-028-4: un selector que devuelve 5000 solo deja mirar las 10 primeras.
    let answer = start("pickMany", ["max": 10])
    XCTAssertEqual(presenter.photosLimits, [10])
    let photos = CountingPhotos(count: 5000)
    presenter.finishPhotos(photos)
    let map = try XCTUnwrap(answer() as? [String: Any])
    XCTAssertEqual(photos.touched, Array(0..<10))
    XCTAssertEqual((map["tokens"] as? [String])?.count, 10)
    XCTAssertEqual(map["total"] as? Int, 5000)
  }

  func testPickManyClampsTheRequestedMaxToOneToTen() {
    // Contrato §2: `max` se acota a 1…10 (por defecto, 10).
    for (asked, limit) in [(50, 10), (3, 3), (0, 1), (-4, 1)] {
      let answer = start("pickMany", ["max": asked])
      let photos = CountingPhotos(count: 20)
      presenter.finishPhotos(photos)
      XCTAssertEqual(((answer() as? [String: Any])?["tokens"] as? [String])?.count, limit, "max=\(asked)")
      XCTAssertEqual(presenter.photosLimits.last, limit)
      XCTAssertEqual(photos.touched.count, limit)
    }
    let answer = start("pickMany", [:])
    presenter.finishPhotos(CountingPhotos(count: 20))
    XCTAssertEqual(((answer() as? [String: Any])?["tokens"] as? [String])?.count, 10)
  }

  func testPickManyKeepsTheOrderAndAnswersNullWithNothing() throws {
    // CA-016-02: en el orden elegido; sin nada elegido (o sin ninguna foto legible), `null`.
    var data: [String: Int] = [:]
    let answer = start("pickMany", ["max": 10])
    presenter.finishPhotos(CountingPhotos(count: 3) { [unowned self] i in self.provider(self.bytes(10 + i)) })
    let tokens = try XCTUnwrap((answer() as? [String: Any])?["tokens"] as? [String])
    for (i, token) in tokens.enumerated() {
      let copied = invoke("copy", ["token": token, "id": "p\(i)", "maxBytes": 1000]) as? [String: Any]
      data[token] = copied?["byteSize"] as? Int
    }
    XCTAssertEqual(tokens.map { data[$0] }, [10, 11, 12])

    let none = start("pickMany", ["max": 10])
    presenter.finishPhotos(CountingPhotos(count: 0))
    XCTAssertNil(none())
    let noAddress = start("pickMany", ["max": 10])
    presenter.finishPhotos(CountingPhotos(count: 3) { _ in nil })
    XCTAssertNil(noAddress())
  }

  // MARK: copy acotada (CA-007-14, CA-008-14)

  func testCopyOfAGalleryPhotoWritesTheSourceAndReturnsSizeAndHead() throws {
    let data = bytes(200_000)
    let token = pickGalleryToken(data)
    let copied = try XCTUnwrap(invoke("copy", ["token": token, "id": "g1", "maxBytes": 300_000]) as? [String: Any])
    XCTAssertEqual(copied["byteSize"] as? Int, 200_000)
    XCTAssertEqual((copied["head"] as? FlutterStandardTypedData)?.data, data.prefix(64), "64 por defecto")
    XCTAssertEqual(try Data(contentsOf: importRoot.appendingPathComponent("g1/source")), data)
  }

  func testAGalleryTokenIsUsedOnlyOnce() {
    // Contrato §2: cada token de galería se retira al copiar; repetirlo no vuelve a leer la foto.
    let token = pickGalleryToken(bytes(100))
    XCTAssertEqual(
      (invoke("copy", ["token": token, "id": "g1", "maxBytes": 1000]) as? [String: Any])?["byteSize"] as? Int,
      100)
    assertError(invoke("copy", ["token": token, "id": "g2", "maxBytes": 1000]), "unreadable")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("g2")))
    // También tras un fallo: un token que ya se intentó no sirve para otro intento.
    let failed = pickGalleryToken(bytes(100))
    assertError(invoke("copy", ["token": failed, "id": "g3", "maxBytes": 10]), "tooLarge")
    assertError(invoke("copy", ["token": failed, "id": "g4", "maxBytes": 1000]), "unreadable")
  }

  func testCopyPastMaxBytesIsTooLargeAndLeavesNothing() {
    // CA-007-14: se cuenta al copiar y se corta al pasar del límite.
    let token = pickGalleryToken(bytes(5000))
    assertError(invoke("copy", ["token": token, "id": "g1", "maxBytes": 4999]), "tooLarge")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("g1")))
  }

  func testCopyOfZeroBytesIsUnreadable() {
    let token = pickGalleryToken(Data())
    assertError(invoke("copy", ["token": token, "id": "g1", "maxBytes": 100]), "unreadable")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("g1")))
  }

  func testAFullDiskIsNoSpaceAndLeavesNothing() {
    // CL-016-6: sin espacio al escribir → `noSpace` y nada a medias.
    sink = { _ in FullDiskSink(limit: 70_000) }
    images = makeImages()
    let token = pickGalleryToken(bytes(200_000))
    assertError(invoke("copy", ["token": token, "id": "g1", "maxBytes": 300_000]), "noSpace")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("g1")))
  }

  func testAPhotoThatCannotBeLoadedIsUnreadable() {
    // CL-028-5: una foto solo en iCloud sin red falla como `unreadable`, sin bloquear.
    let answer = start("pick", ["origin": "gallery", "id": "g1"])
    presenter.finishPhotos(CountingPhotos(count: 1) { _ in
      let provider = NSItemProvider()
      provider.registerFileRepresentation(
        forTypeIdentifier: UTType.heic.identifier, fileOptions: [], visibility: .all
      ) { completion in
        completion(nil, false, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        return nil
      }
      return provider
    })
    let token = (answer() as? [String: Any])?["token"] as? String ?? ""
    assertError(invoke("copy", ["token": token, "id": "g1", "maxBytes": 100]), "unreadable")
  }

  func testAProviderWithoutAnImageIsUnreadable() {
    // Solo la imagen fija: un proveedor sin ningún tipo de imagen no se lee.
    let answer = start("pick", ["origin": "gallery", "id": "g1"])
    presenter.finishPhotos(CountingPhotos(count: 1) { _ in
      NSItemProvider(item: "texto" as NSString, typeIdentifier: UTType.plainText.identifier)
    })
    let token = (answer() as? [String: Any])?["token"] as? String ?? ""
    assertError(invoke("copy", ["token": token, "id": "g1", "maxBytes": 100]), "unreadable")
  }

  func testALivePhotoCopiesOnlyTheStillImage() throws {
    // CA-028-11: de una Live Photo solo la imagen fija, nunca la parte de vídeo.
    let still = bytes(321)
    let answer = start("pick", ["origin": "gallery", "id": "g1"])
    presenter.finishPhotos(CountingPhotos(count: 1) { _ in
      let provider = NSItemProvider()
      provider.registerFileRepresentation(
        forTypeIdentifier: "com.apple.live-photo-bundle", fileOptions: [], visibility: .all
      ) { completion in
        completion(nil, false, NSError(domain: "test", code: 1))
        return nil
      }
      provider.registerFileRepresentation(
        forTypeIdentifier: UTType.quickTimeMovie.identifier, fileOptions: [], visibility: .all
      ) { completion in
        completion(nil, false, NSError(domain: "test", code: 2))
        return nil
      }
      provider.registerFileRepresentation(
        forTypeIdentifier: UTType.heic.identifier, fileOptions: [], visibility: .all
      ) { completion in
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("still-\(UUID().uuidString)")
        try? still.write(to: url)
        completion(url, false, nil)
        return nil
      }
      return provider
    })
    let token = (answer() as? [String: Any])?["token"] as? String ?? ""
    let copied = invoke("copy", ["token": token, "id": "g1", "maxBytes": 1000]) as? [String: Any]
    XCTAssertEqual(copied?["byteSize"] as? Int, 321)
  }

  // MARK: tokens ajenos (contrato §2: nunca una ruta)

  func testForeignTokensAreRefused() throws {
    // Equivale a `isForeignContent`: nada que no haya dado el propio selector se copia.
    let secret = try writeFixture("secret", bytes(100))
    let foreign = [
      secret.path, secret.absoluteString, "file:///etc/hosts", "/etc/hosts", "content://x/1",
      "camera:../x", "camera:", "camera:a/b", "picker:no-such", "document:no-such",
      "picker:" + UUID().uuidString, "document:" + UUID().uuidString, "",
    ]
    for token in foreign {
      assertError(invoke("copy", ["token": token, "id": "x1", "maxBytes": 10_000]), "unreadable")
      XCTAssertFalse(exists(importRoot.appendingPathComponent("x1")), token)
    }
    // Una cámara que no escribió nada tampoco se copia.
    assertError(invoke("copy", ["token": "camera:nope", "id": "x1", "maxBytes": 10_000]), "unreadable")
  }

  // MARK: cancel (CA-007-15/16, CA-008-16)

  func testCancelStopsACopyInFlightAndDeletesEverything() throws {
    // CA-007-16: cancelada a mitad, `cancelled` y sin restos (`import/<id>/` ni `.camera`).
    try FileManager.default.createDirectory(at: importRoot, withIntermediateDirectories: true)
    try Data([1]).write(to: importRoot.appendingPathComponent("z1.camera"))
    let copy = start("debugCopyFile", ["path": "/dev/zero", "id": "z1", "maxBytes": Int64.max])
    let source = importRoot.appendingPathComponent("z1/source")
    let started = expectation(description: "copia empezada")
    func poll() {
      if exists(source) { return started.fulfill() }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: poll)
    }
    poll()
    wait(for: [started], timeout: 5)
    XCTAssertNil(invoke("cancel", ["id": "z1"]))
    assertError(copy(), "cancelled")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("z1")))
    XCTAssertFalse(exists(importRoot.appendingPathComponent("z1.camera")))
  }

  func testCancelAlsoCancelsALoadingGalleryPhoto() throws {
    // Contrato §2: cancelar corta también la `Progress` de `loadFileRepresentation` (CL-028-5).
    let progress = Progress(totalUnitCount: 1)
    var cancelledLoad = false
    let answer = start("pick", ["origin": "gallery", "id": "g1"])
    presenter.finishPhotos(CountingPhotos(count: 1) { _ in
      let provider = NSItemProvider()
      provider.registerFileRepresentation(
        forTypeIdentifier: UTType.jpeg.identifier, fileOptions: [], visibility: .all
      ) { completion in
        progress.cancellationHandler = {
          cancelledLoad = true
          completion(nil, false, NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        }
        return progress
      }
      return provider
    })
    let token = (answer() as? [String: Any])?["token"] as? String ?? ""
    let copy = start("copy", ["token": token, "id": "g1", "maxBytes": 1000])
    // Espera a que la carga esté en curso y la cancela.
    let loading = expectation(description: "cargando")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { loading.fulfill() }
    wait(for: [loading], timeout: 2)
    XCTAssertNil(invoke("cancel", ["id": "g1"]))
    assertError(copy(), "cancelled")
    XCTAssertTrue(cancelledLoad)
  }

  func testCancelWithoutACopyStillDeletesTheStaging() throws {
    try FileManager.default.createDirectory(
      at: importRoot.appendingPathComponent("k1"), withIntermediateDirectories: true)
    try Data([1]).write(to: importRoot.appendingPathComponent("k1/source"))
    try Data([1]).write(to: importRoot.appendingPathComponent("k1.camera"))
    XCTAssertNil(invoke("cancel", ["id": "k1"]))
    XCTAssertFalse(exists(importRoot.appendingPathComponent("k1")))
    XCTAssertFalse(exists(importRoot.appendingPathComponent("k1.camera")))
  }

  // MARK: debugCopyFile (contrato §9: solo depuración, solo `Caches/fixtures/`)

  func testTheDebugHooksOnlyExistInDebugBuilds() throws {
    // Contrato §2 y §9: `debugCopyFile` va en `#if DEBUG`; solo la configuración Debug define
    // `DEBUG` para Swift (Profile y Release, no: en ellas el método es «no implementado»).
    let project = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Runner.xcodeproj/project.pbxproj")
    let text = try String(contentsOf: project, encoding: .utf8)
    let blocks = text.components(separatedBy: "isa = XCBuildConfiguration;").dropFirst()
    var debugWithFlag = 0
    for block in blocks {
      let body = block.components(separatedBy: "\n\t\t};").first ?? block
      let name = body.components(separatedBy: "name = ").last?.prefix { $0 != ";" } ?? ""
      if body.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG") {
        XCTAssertEqual(name, "Debug", "solo Debug define DEBUG")
        debugWithFlag += 1
      }
    }
    XCTAssertGreaterThanOrEqual(debugWithFlag, 1)
    let swift = try String(
      contentsOf: project.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Runner/Images.swift"), encoding: .utf8)
    let hook = try XCTUnwrap(swift.range(of: "private func debugCopyFile("))
    let guardStart = try XCTUnwrap(swift.range(of: "#if DEBUG", options: .backwards, range: swift.startIndex..<hook.lowerBound))
    XCTAssertNil(
      swift.range(of: "#endif", range: guardStart.upperBound..<hook.lowerBound),
      "debugCopyFile, dentro de #if DEBUG")
  }

  func testDebugCopyFileReadsOnlyFromFixturesOrDevZero() throws {
    let fixture = try writeFixture("photo.jpg", bytes(500))
    let copied = invoke("debugCopyFile", ["path": fixture.path, "id": "d1", "maxBytes": 1000]) as? [String: Any]
    XCTAssertEqual(copied?["byteSize"] as? Int, 500)
    assertError(invoke("debugCopyFile", ["path": "/dev/zero", "id": "d2", "maxBytes": 100_000]), "tooLarge")
    assertError(invoke("debugCopyFile", ["path": "/dev/urandom", "id": "d3", "maxBytes": 100_000]), "tooLarge")

    let outside = root.appendingPathComponent("outside.jpg")
    try bytes(10).write(to: outside)
    let link = fixtures.appendingPathComponent("link.jpg")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    for path in [
      outside.path, link.path, fixtures.path + "/../outside.jpg", fixtures.path, "/etc/hosts",
      fixtures.path + "-other/photo.jpg",
    ] {
      assertError(invoke("debugCopyFile", ["path": path, "id": "d4", "maxBytes": 1000]), "unreadable")
      XCTAssertFalse(exists(importRoot.appendingPathComponent("d4")), path)
    }
  }
}
