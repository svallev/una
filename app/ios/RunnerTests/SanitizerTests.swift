import Flutter
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import Runner

/// Escritor que se queda sin espacio (como `ENOSPC`) para los nombres que se le digan.
private final class FullDiskWriter {
  var failing: (URL) -> Bool = { _ in false }

  func write(_ data: Data, _ url: URL) throws {
    if failing(url) { throw POSIXError(.ENOSPC) }
    try ImageSanitizer.atomicWriter(data, url)
  }
}

/// Un color RGB de 8 bits.
private struct RGB: Equatable, CustomStringConvertible {
  let r: Int
  let g: Int
  let b: Int

  static let red = RGB(r: 255, g: 0, b: 0)
  static let green = RGB(r: 0, g: 255, b: 0)
  static let blue = RGB(r: 0, g: 0, b: 255)
  static let black = RGB(r: 0, g: 0, b: 0)
  static let white = RGB(r: 255, g: 255, b: 255)

  var description: String { "(\(r), \(g), \(b))" }

  func isClose(to other: RGB, tolerance: Int = 48) -> Bool {
    abs(r - other.r) <= tolerance && abs(g - other.g) <= tolerance && abs(b - other.b) <= tolerance
  }
}

/// `una/images`, limpieza y codificación (contrato §2; espejo de `ImageSanitizer.kt` y de
/// `sanitize`/`regenerate`/`encodeJpeg` de `ImageImport.kt`; spec 028 CA-028-11; CA-007-07, 14, 15,
/// 16 y 19, CA-008-08/15/16/18, CA-016-04/14/16/18, CL-007-4 y CL-007-10). Todas las imágenes se
/// generan aquí (EXIF y GPS, las 8 orientaciones, HEIC, PNG con alfa, más píxeles que `maxPixels`,
/// BGRA).
class SanitizerTests: XCTestCase {
  private static let secrets = ["UNA-SECRET-MAKE", "UNA-SECRET-MODEL", "UNA-SECRET-COMMENT"]

  private var root: URL!
  private var caches: URL { root.appendingPathComponent("Caches", isDirectory: true) }
  private var importRoot: URL { caches.appendingPathComponent("import", isDirectory: true) }
  private var support: URL { root.appendingPathComponent("Support", isDirectory: true) }
  private var attachments: URL { support.appendingPathComponent("attachments", isDirectory: true) }
  private var writer: FullDiskWriter!
  private var screen = (width: 100, height: 200)
  private var images: Images!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("sanitizer-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: importRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
    writer = FullDiskWriter()
    screen = (width: 100, height: 200)
    images = Images(
      cachesDirectory: caches,
      applicationSupportDirectory: support,
      screenSize: { [unowned self] in self.screen },
      writer: { [unowned self] data, url in try self.writer.write(data, url) })
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: root)
  }

  // MARK: - Ayudas

  @discardableResult
  private func invoke(
    _ method: String, _ arguments: Any?, file: StaticString = #filePath, line: UInt = #line
  ) -> Any? {
    let answered = expectation(description: method)
    var answer: Any?
    images.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      XCTAssertTrue(Thread.isMainThread, "contrato §0.4", file: file, line: line)
      answer = $0
      answered.fulfill()
    }
    wait(for: [answered], timeout: 30)
    return answer
  }

  private func start(_ method: String, _ arguments: Any?) -> () -> Any? {
    let answered = expectation(description: method)
    var answer: Any?
    images.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
      answer = $0
      answered.fulfill()
    }
    return { [unowned self] in
      self.wait(for: [answered], timeout: 30)
      return answer
    }
  }

  /// Error con **solo** el código (contrato §0.1, CL-007-10).
  private func assertError(
    _ answer: Any?, _ code: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    guard let error = answer as? FlutterError else {
      return XCTFail(
        "se esperaba el error \(code) y llegó \(String(describing: answer))", file: file, line: line)
    }
    XCTAssertEqual(error.code, code, file: file, line: line)
    XCTAssertNil(error.message, file: file, line: line)
    XCTAssertNil(error.details, file: file, line: line)
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
  }

  private func sanitizeArguments(
    _ id: String, maxPixels: Int64 = 64_000_000, storedMaxPixels: Int64 = 24_000_000
  ) -> [String: Any] {
    ["id": id, "type": "jpeg", "maxPixels": maxPixels, "storedMaxPixels": storedMaxPixels]
  }

  /// Deja `data` como `import/<id>/source` (lo que dejaría `copy`).
  private func stage(_ id: String, _ data: Data) throws {
    let directory = importRoot.appendingPathComponent(id, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: directory.appendingPathComponent("source"))
  }

  /// Imagen de `width` × `height` en cuatro cuadrantes (arriba a la izquierda, arriba a la derecha,
  /// abajo a la izquierda, abajo a la derecha), con alfa si `alpha` < 1 en el de arriba a la izquierda.
  private func quadrants(
    _ width: Int, _ height: Int, _ colors: [RGB] = [.red, .green, .blue, .black],
    topLeftAlpha: CGFloat = 1, hasAlpha: Bool = false
  ) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let info =
      hasAlpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
      bitmapInfo: info)!
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    let w = CGFloat(width) / 2
    let h = CGFloat(height) / 2
    // Core Graphics mide desde abajo: «arriba» es y = h.
    let rects = [
      CGRect(x: 0, y: h, width: w, height: h), CGRect(x: w, y: h, width: w, height: h),
      CGRect(x: 0, y: 0, width: w, height: h), CGRect(x: w, y: 0, width: w, height: h),
    ]
    for (index, rect) in rects.enumerated() {
      let c = colors[index]
      let alpha = index == 0 ? topLeftAlpha : 1
      context.setFillColor(
        CGColor(
          srgbRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255,
          alpha: alpha))
      context.fill(rect)
    }
    return context.makeImage()!
  }

  /// Codifica con ImageIO, con las propiedades que se le den (EXIF, GPS, orientación…).
  private func encode(_ image: CGImage, _ type: UTType, _ properties: [CFString: Any] = [:]) throws
    -> Data
  {
    let data = NSMutableData()
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil),
      "ImageIO no sabe escribir \(type.identifier)")
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  /// Metadatos de la cámara que no pueden sobrevivir: fabricante, modelo, comentario, fecha y GPS.
  private func cameraMetadata(orientation: Int = 1) -> [CFString: Any] {
    [
      kCGImagePropertyOrientation: orientation,
      kCGImagePropertyTIFFDictionary: [
        kCGImagePropertyTIFFMake: SanitizerTests.secrets[0],
        kCGImagePropertyTIFFModel: SanitizerTests.secrets[1],
        kCGImagePropertyTIFFOrientation: orientation,
      ],
      kCGImagePropertyExifDictionary: [
        kCGImagePropertyExifUserComment: SanitizerTests.secrets[2],
        kCGImagePropertyExifDateTimeOriginal: "2001:02:03 04:05:06",
      ],
      kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 40.4168, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 3.7038, kCGImagePropertyGPSLongitudeRef: "W",
      ],
    ]
  }

  private func properties(_ url: URL) throws -> [CFString: Any] {
    let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }

  private func size(_ url: URL) throws -> (Int, Int) {
    let p = try properties(url)
    return (
      (p[kCGImagePropertyPixelWidth] as? Int) ?? -1, (p[kCGImagePropertyPixelHeight] as? Int) ?? -1
    )
  }

  /// El color del píxel (`x`, `y`), medido desde arriba a la izquierda.
  private func pixel(_ url: URL, _ x: Int, _ y: Int) throws -> RGB {
    let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var bytes = [UInt8](repeating: 0, count: 4)
    let context = CGContext(
      data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.draw(
      image,
      in: CGRect(
        x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
    return RGB(r: Int(bytes[0]), g: Int(bytes[1]), b: Int(bytes[2]))
  }

  private func assertColor(
    _ url: URL, _ x: Int, _ y: Int, _ expected: RGB, _ what: String = "",
    file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let got = try pixel(url, x, y)
    XCTAssertTrue(
      got.isClose(to: expected), "\(what) (\(x), \(y)): \(got), se esperaba \(expected)", file: file,
      line: line)
  }

  /// Comprueba que un JPEG escrito no lleva nada del original: ni GPS, ni fabricante, ni fecha, ni
  /// orientación distinta de la normal, ni los textos de la cámara en ningún byte (CA-007-07).
  private func assertClean(_ url: URL, file: StaticString = #filePath, line: UInt = #line) throws {
    let data = try Data(contentsOf: url)
    XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8], "es un JPEG", file: file, line: line)
    for secret in SanitizerTests.secrets {
      XCTAssertNil(
        data.range(of: Data(secret.utf8)), "\(url.lastPathComponent) lleva \(secret)", file: file,
        line: line)
    }
    let p = try properties(url)
    XCTAssertNil(p[kCGImagePropertyGPSDictionary], "sin GPS", file: file, line: line)
    let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
    XCTAssertNil(tiff[kCGImagePropertyTIFFMake], file: file, line: line)
    XCTAssertNil(tiff[kCGImagePropertyTIFFModel], file: file, line: line)
    let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    XCTAssertNil(exif[kCGImagePropertyExifDateTimeOriginal], file: file, line: line)
    XCTAssertNil(exif[kCGImagePropertyExifUserComment], file: file, line: line)
    let orientation = (p[kCGImagePropertyOrientation] as? Int) ?? 1
    XCTAssertEqual(orientation, 1, "orientación ya aplicada", file: file, line: line)
    try assertNoMetadataSegments(url, file: file, line: line)
  }

  /// Como `_expectClean` del IT `image_import_test` (y como Android): entre SOI y SOS no hay ningún
  /// segmento de metadatos (APP1 EXIF/XMP, APP13, comentario ni APP2 que no sea el perfil ICC), aunque
  /// no lleve ninguna clave; y nada tras el final.
  private func assertNoMetadataSegments(
    _ url: URL, file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let bytes = [UInt8](try Data(contentsOf: url))
    XCTAssertEqual(Array(bytes.suffix(2)), [0xFF, 0xD9], "nada tras el final", file: file, line: line)
    var i = 2
    while i + 3 < bytes.count, bytes[i] == 0xFF {
      let marker = bytes[i + 1]
      if marker == 0xDA { break }
      let length = Int(bytes[i + 2]) << 8 | Int(bytes[i + 3])
      let isIcc =
        marker == 0xE2 && i + 15 <= bytes.count
        && String(decoding: bytes[(i + 4)..<(i + 15)], as: UTF8.self) == "ICC_PROFILE"
      XCTAssertTrue(
        isIcc || ![0xE1, 0xE2, 0xED, 0xFE].contains(marker),
        "\(url.lastPathComponent): segmento 0x\(String(marker, radix: 16))", file: file, line: line)
      i += 2 + length
    }
  }

  private func files(_ directory: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
  }

  // MARK: - sanitize

  func testExifGpsAndCameraDataNeverReachAnyVersion() throws {
    // CA-007-07 y CA-028-11: se recodifica desde los píxeles; ningún byte del original sobrevive.
    let original = try encode(quadrants(400, 300), .jpeg, cameraMetadata())
    XCTAssertNotNil(original.range(of: Data(SanitizerTests.secrets[0].utf8)), "el original sí lo lleva")
    try stage("e1", original)
    let answer = invoke("sanitize", sanitizeArguments("e1")) as? [String: Any]
    XCTAssertEqual(answer?["width"] as? Int, 400)
    XCTAssertEqual(answer?["height"] as? Int, 300)
    let directory = importRoot.appendingPathComponent("e1")
    XCTAssertEqual(files(directory), ["full-0-0.jpg", "screen.jpg", "thumb.jpg"], "sin `source`")
    for name in ["full-0-0.jpg", "screen.jpg", "thumb.jpg"] {
      try assertClean(directory.appendingPathComponent(name))
    }
    let full = try Data(contentsOf: directory.appendingPathComponent("full-0-0.jpg"))
    XCTAssertEqual(answer?["byteSize"] as? Int, full.count)
  }

  func testAPngWithoutMetadataGivesJpegsWithoutAnyApp1() throws {
    // CA-007-07: ImageIO añade por su cuenta un APP1 «Exif» mínimo a todo JPEG; no debe quedar.
    try stage("m1", encode(quadrants(400, 300), .png))
    XCTAssertNotNil(invoke("sanitize", sanitizeArguments("m1")) as? [String: Any])
    let directory = importRoot.appendingPathComponent("m1")
    for name in ["full-0-0.jpg", "screen.jpg", "thumb.jpg"] {
      try assertNoMetadataSegments(directory.appendingPathComponent(name))
    }
  }

  func testTheEightExifOrientationsAreApplied() throws {
    // CA-007-07: las 8 orientaciones. Qué esquina del original queda arriba a la izquierda y arriba
    // a la derecha (rojo, verde, azul y negro: arriba izq., arriba der., abajo izq., abajo der.).
    let expected: [Int: (RGB, RGB, Bool)] = [
      1: (.red, .green, false), 2: (.green, .red, false), 3: (.black, .blue, false),
      4: (.blue, .black, false), 5: (.red, .blue, true), 6: (.blue, .red, true),
      7: (.black, .green, true), 8: (.green, .black, true),
    ]
    for orientation in 1...8 {
      let id = "o\(orientation)"
      try stage(id, encode(quadrants(80, 40), .jpeg, cameraMetadata(orientation: orientation)))
      let answer = invoke("sanitize", sanitizeArguments(id)) as? [String: Any]
      let (topLeft, topRight, swapped) = try XCTUnwrap(expected[orientation])
      let w = swapped ? 40 : 80
      let h = swapped ? 80 : 40
      XCTAssertEqual(answer?["width"] as? Int, w, "orientación \(orientation)")
      XCTAssertEqual(answer?["height"] as? Int, h, "orientación \(orientation)")
      let full = importRoot.appendingPathComponent("\(id)/full-0-0.jpg")
      try assertColor(full, w / 4, h / 4, topLeft, "orientación \(orientation), arriba izq.")
      try assertColor(full, 3 * w / 4, h / 4, topRight, "orientación \(orientation), arriba der.")
      try assertClean(full)
    }
  }

  func testHeicIsReadAndWrittenAsAPlainJpeg() throws {
    // CA-028-11: HEIC se admite (también con orientación y metadatos) y sale JPEG limpio.
    let heic = try encode(quadrants(64, 48), .heic, cameraMetadata(orientation: 6))
    try stage("h1", heic)
    let answer = invoke("sanitize", sanitizeArguments("h1")) as? [String: Any]
    XCTAssertEqual(answer?["width"] as? Int, 48)
    XCTAssertEqual(answer?["height"] as? Int, 64)
    let full = importRoot.appendingPathComponent("h1/full-0-0.jpg")
    try assertClean(full)
    try assertColor(full, 12, 16, .blue, "arriba izq. tras girar")
  }

  func testTransparencyIsFlattenedOnWhite() throws {
    // CL-007-4: un PNG con alfa queda sobre blanco (nunca negro).
    let png = try encode(
      quadrants(40, 40, [.red, .green, .blue, .red], topLeftAlpha: 0, hasAlpha: true), .png)
    try stage("a1", png)
    XCTAssertNotNil(invoke("sanitize", sanitizeArguments("a1")) as? [String: Any])
    let directory = importRoot.appendingPathComponent("a1")
    try assertColor(directory.appendingPathComponent("full-0-0.jpg"), 10, 10, .white, "transparente")
    try assertColor(directory.appendingPathComponent("full-0-0.jpg"), 30, 10, .green, "opaco")
    try assertColor(directory.appendingPathComponent("thumb.jpg"), 10, 10, .white, "miniatura")
  }

  func testMorePixelsThanMaxPixelsIsTooManyPixelsAndLeavesNothing() throws {
    // CA-007-14: `w × h > maxPixels` → `tooManyPixels`, sin restos (ni `source`).
    try stage("p1", encode(quadrants(100, 100), .png))
    assertError(invoke("sanitize", sanitizeArguments("p1", maxPixels: 9_999)), "tooManyPixels")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("p1")))
    // Justo en el límite, sí.
    try stage("p2", encode(quadrants(100, 100), .png))
    let answer = invoke("sanitize", sanitizeArguments("p2", maxPixels: 10_000)) as? [String: Any]
    XCTAssertEqual(answer?["width"] as? Int, 100)
  }

  func testAPngHeaderTooLargeForImageIOIsTooManyPixels() throws {
    // CA-007-13: ImageIO no da las dimensiones de un PNG de 60 000 × 60 000 (`fake_dims_huge.png` del
    // IT, 69 bytes); se leen de su IHDR y es `tooManyPixels`, no `unreadable`.
    let hex =
      "89504e470d0a1a0a0000000d494844520000ea600000ea6008020000000fb0e2150000000c49444154789c63"
      + "6818e2000032dd60019074be810000000049454e44ae426082"
    var bytes = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      bytes.append(UInt8(hex[index..<next], radix: 16)!)
      index = next
    }
    try stage("h1", bytes)
    assertError(invoke("sanitize", sanitizeArguments("h1")), "tooManyPixels")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("h1")))
  }

  func testAboveStoredMaxPixelsTheFullVersionIsReduced() throws {
    // Contrato §2: se reduce a ≤ `storedMaxPixels` (aquí, a la mitad de lado).
    try stage("r1", encode(quadrants(200, 100), .png))
    let answer =
      invoke("sanitize", sanitizeArguments("r1", storedMaxPixels: 5_000)) as? [String: Any]
    let width = try XCTUnwrap(answer?["width"] as? Int)
    let height = try XCTUnwrap(answer?["height"] as? Int)
    XCTAssertLessThanOrEqual(width * height, 5_000)
    XCTAssertEqual(width, 100)
    XCTAssertEqual(height, 50)
    XCTAssertEqual(try size(importRoot.appendingPathComponent("r1/full-0-0.jpg")).0, 100)
  }

  func testTheReducedSizeNeverExceedsStoredMaxPixels() throws {
    // CA-007-13: ImageIO redondea hacia arriba el lado corto (8000 × 7990 a 24 MP salía en
    // 4902 × 4896 = 24 000 192); aquí, la misma proporción en pequeño: 93 × 86 > 7 980.
    try stage("r2", encode(quadrants(152, 140), .png))
    let answer =
      invoke("sanitize", sanitizeArguments("r2", storedMaxPixels: 7_980)) as? [String: Any]
    let width = try XCTUnwrap(answer?["width"] as? Int)
    let height = try XCTUnwrap(answer?["height"] as? Int)
    XCTAssertLessThanOrEqual(width * height, 7_980, "\(width) × \(height)")
    XCTAssertGreaterThan(width * height, 7_980 * 95 / 100, "sin reducir de más")
    let full = try size(importRoot.appendingPathComponent("r2/full-0-0.jpg"))
    XCTAssertTrue(full == (width, height))
  }

  func testWideImagesAreWrittenInTilesOf4096() throws {
    // Contrato §2: `full-<fila>-<col>.jpg` de ≤ 4096; `byteSize` es la suma de las teselas.
    try stage("t1", encode(quadrants(4100, 8), .png))
    let answer = invoke("sanitize", sanitizeArguments("t1")) as? [String: Any]
    XCTAssertEqual(answer?["width"] as? Int, 4100)
    let directory = importRoot.appendingPathComponent("t1")
    XCTAssertEqual(
      files(directory), ["full-0-0.jpg", "full-0-1.jpg", "screen.jpg", "thumb.jpg"])
    XCTAssertTrue(try size(directory.appendingPathComponent("full-0-0.jpg")) == (4096, 8))
    XCTAssertTrue(try size(directory.appendingPathComponent("full-0-1.jpg")) == (4, 8))
    let total = try ["full-0-0.jpg", "full-0-1.jpg"].reduce(0) {
      $0 + (try Data(contentsOf: directory.appendingPathComponent($1)).count)
    }
    XCTAssertEqual(answer?["byteSize"] as? Int, total)
    try assertColor(directory.appendingPathComponent("full-0-1.jpg"), 2, 2, .green, "segunda tesela")
  }

  func testScreenIsAtScreenWidthOnlyTheTopAndThumbIs176Square() throws {
    // I-2: al ancho de la pantalla en vertical; si es más alta, solo la parte de arriba.
    screen = (width: 100, height: 200)
    try stage("s1", encode(quadrants(400, 1000), .png))
    XCTAssertNotNil(invoke("sanitize", sanitizeArguments("s1")))
    let directory = importRoot.appendingPathComponent("s1")
    XCTAssertTrue(try size(directory.appendingPathComponent("screen.jpg")) == (100, 200))
    // Fila 110 de 200 = fila 440 de 1000 (la mitad de arriba, roja); la 190 = 760 (azul).
    try assertColor(directory.appendingPathComponent("screen.jpg"), 25, 110, .red, "parte de arriba")
    try assertColor(directory.appendingPathComponent("screen.jpg"), 25, 190, .blue, "sin deformar")
    XCTAssertTrue(try size(directory.appendingPathComponent("thumb.jpg")) == (176, 176))
    // Más pequeña que la pantalla: nunca se amplía.
    try stage("s2", encode(quadrants(50, 60), .png))
    XCTAssertNotNil(invoke("sanitize", sanitizeArguments("s2")))
    let small = importRoot.appendingPathComponent("s2")
    XCTAssertTrue(try size(small.appendingPathComponent("screen.jpg")) == (50, 60))
    XCTAssertTrue(try size(small.appendingPathComponent("thumb.jpg")) == (50, 50))
  }

  func testTheScreenSizeIsReadInPortrait() {
    // Contrato §2: ancho < alto, sea cual sea la orientación del aparato.
    let size = Images.systemScreenSize()
    XCTAssertGreaterThan(size.width, 0)
    XCTAssertLessThanOrEqual(size.width, size.height)
  }

  func testUnreadableImagesAreUnreadableAndLeaveNothing() throws {
    // CA-007-14: lo que no es una imagen → `unreadable`, sin restos. (Una imagen **cortada** no se
    // detecta en iOS: ImageIO la da por completa; diferencia anotada en el contrato §2.)
    try stage("u1", Data("no es una imagen".utf8))
    assertError(invoke("sanitize", sanitizeArguments("u1")), "unreadable")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("u1")))
    let jpeg = try encode(quadrants(300, 300), .jpeg)
    try stage("u2", jpeg.prefix(40))
    assertError(invoke("sanitize", sanitizeArguments("u2")), "unreadable")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("u2")))
    // Sin `source` (nada copiado).
    assertError(invoke("sanitize", sanitizeArguments("u3")), "unreadable")
  }

  func testAFullDiskIsNoSpaceAndLeavesNothing() throws {
    // CA-016-16: sin espacio → `noSpace`, sin restos.
    writer.failing = { $0.lastPathComponent == "screen.jpg" }
    try stage("n1", encode(quadrants(40, 40), .png))
    assertError(invoke("sanitize", sanitizeArguments("n1")), "noSpace")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("n1")))
  }

  func testACancelledSanitizeAnswersCancelledAndLeavesNothing() throws {
    // CA-007-16: cancelar antes de empezar o mientras espera turno → `cancelled`, sin restos.
    try stage("c1", encode(quadrants(40, 40), .png))
    let blocker = DispatchSemaphore(value: 0)
    images.sanitizeProbe = { started in if started { blocker.wait() } }
    try stage("c2", encode(quadrants(40, 40), .png))
    let first = start("sanitize", sanitizeArguments("c2"))
    let second = start("sanitize", sanitizeArguments("c1"))
    // `c1` espera turno detrás de `c2`; se cancela ahí.
    XCTAssertNil(invoke("cancel", ["id": "c1"]))
    images.sanitizeProbe = nil
    blocker.signal()
    XCTAssertNotNil(first() as? [String: Any])
    assertError(second(), "cancelled")
    XCTAssertFalse(exists(importRoot.appendingPathComponent("c1")))
  }

  func testAFinishedSanitizeForgetsItsCancelFlag() throws {
    // `ImageImport.kt` (`last = true`): al terminar bien se olvida la bandera; un `cancel` posterior
    // del mismo id no deja «cancelada» la siguiente limpieza.
    try stage("f1", encode(quadrants(40, 40), .png))
    XCTAssertNotNil(invoke("sanitize", sanitizeArguments("f1")) as? [String: Any])
    XCTAssertNil(invoke("cancel", ["id": "f1"]))
    try stage("f1", encode(quadrants(40, 40), .png))
    XCTAssertNotNil(invoke("sanitize", sanitizeArguments("f1")) as? [String: Any])
  }

  func testNeverTwoSanitizesAtOnce() throws {
    // CA-016-04: una sola limpieza a la vez (cola serie), aunque Dart pida varias seguidas.
    let lock = NSLock()
    var running = 0
    var peak = 0
    images.sanitizeProbe = { started in
      lock.lock()
      running += started ? 1 : -1
      peak = max(peak, running)
      lock.unlock()
      if started { Thread.sleep(forTimeInterval: 0.05) }
    }
    var answers: [() -> Any?] = []
    for index in 0..<4 {
      try stage("q\(index)", encode(quadrants(40, 40), .png))
      answers.append(start("sanitize", sanitizeArguments("q\(index)")))
    }
    for answer in answers { XCTAssertNotNil(answer() as? [String: Any]) }
    XCTAssertEqual(peak, 1)
  }

  func testInvalidArgumentsAnswerUnreadableWithoutText() {
    // Contrato §0.1: sin `id` válido o sin números → `unreadable`, sin texto.
    assertError(invoke("sanitize", ["id": "../x", "maxPixels": 1, "storedMaxPixels": 1]), "unreadable")
    assertError(invoke("sanitize", ["id": "x1"]), "unreadable")
    assertError(invoke("regenerate", ["id": "x1", "width": "a", "height": 1]), "unreadable")
    assertError(invoke("regenerate", nil), "unreadable")
    assertError(
      invoke("encodeJpeg", ["id": "x1", "target": "staging", "width": 1, "height": 1]), "unreadable")
    assertError(invoke("encodeJpeg", ["id": "a/b", "width": 1, "height": 1]), "unreadable")
  }

  // MARK: - regenerate

  /// Limpia una imagen y la pasa a `attachments/<id>/` (como al guardar), sin las derivadas.
  private func storedAttachment(_ id: String, _ image: CGImage) throws -> (Int, Int) {
    try stage(id, encode(image, .png))
    let answer = try XCTUnwrap(invoke("sanitize", sanitizeArguments(id)) as? [String: Any])
    try FileManager.default.moveItem(
      at: importRoot.appendingPathComponent(id), to: attachments.appendingPathComponent(id))
    return (answer["width"] as! Int, answer["height"] as! Int)
  }

  func testRegenerateRebuildsScreenAndThumbFromTheTilesOnly() throws {
    // CA-007-19: rehace las dos derivadas desde las teselas, con los mismos tamaños, sin tocarlas.
    screen = (width: 100, height: 200)
    let (w, h) = try storedAttachment("g1", quadrants(400, 1000))
    let directory = attachments.appendingPathComponent("g1")
    let sizes = try (size(directory.appendingPathComponent("screen.jpg")),
      size(directory.appendingPathComponent("thumb.jpg")))
    let tile = try Data(contentsOf: directory.appendingPathComponent("full-0-0.jpg"))
    try FileManager.default.removeItem(at: directory.appendingPathComponent("screen.jpg"))
    try FileManager.default.removeItem(at: directory.appendingPathComponent("thumb.jpg"))
    XCTAssertNil(invoke("regenerate", ["id": "g1", "width": w, "height": h]))
    XCTAssertTrue(try size(directory.appendingPathComponent("screen.jpg")) == sizes.0)
    XCTAssertTrue(try size(directory.appendingPathComponent("thumb.jpg")) == sizes.1)
    try assertColor(directory.appendingPathComponent("screen.jpg"), 25, 50, .red)
    try assertColor(directory.appendingPathComponent("screen.jpg"), 75, 50, .green)
    try assertClean(directory.appendingPathComponent("screen.jpg"))
    try assertClean(directory.appendingPathComponent("thumb.jpg"))
    XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("full-0-0.jpg")), tile)
    XCTAssertEqual(files(directory), ["full-0-0.jpg", "screen.jpg", "thumb.jpg"], "sin temporales")
  }

  func testRegenerateJoinsSeveralTiles() throws {
    // CA-007-19: una imagen de dos teselas; la derivada lleva las dos.
    screen = (width: 4200, height: 8000)
    let (w, h) = try storedAttachment("g2", quadrants(4200, 20))
    let directory = attachments.appendingPathComponent("g2")
    try FileManager.default.removeItem(at: directory.appendingPathComponent("screen.jpg"))
    XCTAssertNil(invoke("regenerate", ["id": "g2", "width": w, "height": h]))
    let screenFile = directory.appendingPathComponent("screen.jpg")
    XCTAssertTrue(try size(screenFile) == (4200, 20))
    try assertColor(screenFile, 100, 5, .red, "primera tesela")
    try assertColor(screenFile, 4150, 5, .green, "segunda tesela")
    try assertColor(screenFile, 4150, 15, .black, "segunda tesela, abajo")
  }

  func testRegenerateWithoutTheFolderOrATileIsUnreadable() throws {
    // CA-007-19 y CA-016-18: falta la carpeta o una tesela → `unreadable`, sin texto.
    assertError(invoke("regenerate", ["id": "nope", "width": 10, "height": 10]), "unreadable")
    let (w, h) = try storedAttachment("g3", quadrants(40, 40))
    let tile = attachments.appendingPathComponent("g3/full-0-0.jpg")
    try Data().write(to: tile)
    assertError(invoke("regenerate", ["id": "g3", "width": w, "height": h]), "unreadable")
    try FileManager.default.removeItem(at: tile)
    assertError(invoke("regenerate", ["id": "g3", "width": w, "height": h]), "unreadable")
  }

  func testRegenerateRefusesSizesOutOfRangeOrNotIntegers() throws {
    // I-4 (028, revisores): un ancho o alto de una BD manipulada responde `unreadable` sin texto y
    // sin tocar nada; con `Int.max` la cuenta de teselas desbordaba y la app se cerraba.
    let (w, h) = try storedAttachment("g4", quadrants(40, 40))
    let directory = attachments.appendingPathComponent("g4")
    let before = try (files(directory), Data(contentsOf: directory.appendingPathComponent("screen.jpg")))
    let bad: [(Any, Any)] = [
      (Int.max, h), (w, Int.max), (Int.max, Int.max), (Int64.max, 1), (Int.min, h), (w, Int.min),
      (0, h), (w, 0), (-1, h), (w, -40), (64_000_001, 1), (8001, 8000), (1 << 32, 1 << 32),
      (40.0, h), (w, 40.5), (true, h), (w, false), ("40", h), (NSNull(), h), (w, [40]),
    ]
    for (width, height) in bad {
      assertError(invoke("regenerate", ["id": "g4", "width": width, "height": height]), "unreadable")
    }
    XCTAssertEqual(files(directory), before.0, "ni temporales ni derivadas nuevas")
    XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("screen.jpg")), before.1)
    // El tope admite lo que de verdad se guarda.
    XCTAssertNil(invoke("regenerate", ["id": "g4", "width": w, "height": h]))
  }

  func testTheRegenerableSizeIsBoundedWithoutOverflowing() {
    // I-4: también si se llama directamente (sin el canal).
    XCTAssertTrue(ImageSanitizer.isRegenerableSize(width: 1, height: 1))
    XCTAssertTrue(ImageSanitizer.isRegenerableSize(width: 8000, height: 8000))
    XCTAssertTrue(ImageSanitizer.isRegenerableSize(width: 1, height: 64_000_000))
    XCTAssertFalse(ImageSanitizer.isRegenerableSize(width: 1, height: 64_000_001))
    XCTAssertFalse(ImageSanitizer.isRegenerableSize(width: Int.max, height: 2))
    XCTAssertFalse(ImageSanitizer.isRegenerableSize(width: Int.max, height: Int.max))
    XCTAssertFalse(ImageSanitizer.isRegenerableSize(width: 0, height: 10))
    XCTAssertFalse(ImageSanitizer.isRegenerableSize(width: 10, height: -1))
    let sanitizer = ImageSanitizer(
      maxPixels: Int64.max, storedMaxPixels: Int64.max, screenWidth: 100, screenHeight: 200)
    XCTAssertThrowsError(
      try sanitizer.regenerateDerived(dir: attachments, width: 1, height: Int.max))
    XCTAssertThrowsError(
      try sanitizer.regenerateDerived(dir: attachments, width: Int.max, height: Int.max))
  }

  // MARK: - encodeJpeg

  private func pixels(_ width: Int, _ height: Int, _ bytes: [UInt8]) -> FlutterStandardTypedData {
    FlutterStandardTypedData(
      bytes: Data((0..<(width * height)).flatMap { _ in bytes }))
  }

  func testEncodeJpegReadsBgraAndRgba() throws {
    // CA-008-15: la página que dibuja pdfrx llega en BGRA; también se admite RGBA.
    let directory = importRoot.appendingPathComponent("j1")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let blueInBgra = pixels(20, 30, [255, 0, 0, 255])
    XCTAssertNil(
      invoke(
        "encodeJpeg",
        ["id": "j1", "target": "staging", "width": 20, "height": 30, "bgra": true,
         "pixels": blueInBgra]))
    let file = directory.appendingPathComponent("screen.jpg")
    XCTAssertTrue(try size(file) == (20, 30))
    try assertColor(file, 10, 10, .blue, "BGRA")
    try assertClean(file)
    XCTAssertNil(
      invoke(
        "encodeJpeg",
        ["id": "j1", "target": "staging", "width": 20, "height": 30, "bgra": false,
         "pixels": blueInBgra]))
    try assertColor(file, 10, 10, .red, "los mismos bytes, como RGBA")
    XCTAssertEqual(files(directory), ["screen.jpg"], "sin `screen.tmp`")
  }

  func testEncodeJpegOnTheStoredAttachment() throws {
    // CA-008-08: al cambiar la última posición se reescribe la del adjunto guardado.
    let directory = attachments.appendingPathComponent("j2")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    XCTAssertNil(
      invoke(
        "encodeJpeg",
        ["id": "j2", "target": "stored", "width": 8, "height": 8, "bgra": true,
         "pixels": pixels(8, 8, [0, 255, 0, 255])]))
    try assertColor(directory.appendingPathComponent("screen.jpg"), 4, 4, .green)
    XCTAssertFalse(exists(importRoot.appendingPathComponent("j2")))
  }

  func testEncodeJpegWithoutTheFolderDoesNothing() throws {
    // Contrato §2: el adjunto se completó o se canceló mientras tanto → éxito sin escribir nada.
    for target in ["staging", "stored"] {
      XCTAssertNil(
        invoke(
          "encodeJpeg",
          ["id": "j3", "target": target, "width": 2, "height": 2, "bgra": true,
           "pixels": pixels(2, 2, [0, 0, 0, 255])]))
    }
    XCTAssertFalse(exists(importRoot.appendingPathComponent("j3")))
    XCTAssertFalse(exists(attachments.appendingPathComponent("j3")))
  }

  func testEncodeJpegRefusesSizesOutOfRange() throws {
    // `ImageImport.kt`: 1…8192 × 1…16384 y `pixels` = w × h × 4; si no, `unreadable`.
    let directory = importRoot.appendingPathComponent("j4")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let cases: [(Int, Int, Int)] = [(0, 1, 0), (8193, 1, 8193 * 4), (1, 16385, 16385 * 4), (2, 2, 15)]
    for (w, h, count) in cases {
      assertError(
        invoke(
          "encodeJpeg",
          ["id": "j4", "target": "staging", "width": w, "height": h, "bgra": true,
           "pixels": FlutterStandardTypedData(bytes: Data(count: count))]), "unreadable")
    }
    XCTAssertEqual(files(directory), [])
    // Los extremos válidos.
    XCTAssertNil(
      invoke(
        "encodeJpeg",
        ["id": "j4", "target": "staging", "width": 8192, "height": 1, "bgra": true,
         "pixels": FlutterStandardTypedData(bytes: Data(count: 8192 * 4))]))
  }

  func testEncodeJpegIsAtomicAndAFullDiskKeepsThePreviousVersion() throws {
    // CA-008-08: nunca una versión a medias; sin espacio → `noSpace` y la anterior sigue.
    let directory = attachments.appendingPathComponent("j5")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let previous = Data([0xFF, 0xD8, 0x01])
    try previous.write(to: directory.appendingPathComponent("screen.jpg"))
    writer.failing = { _ in true }
    assertError(
      invoke(
        "encodeJpeg",
        ["id": "j5", "target": "stored", "width": 4, "height": 4, "bgra": true,
         "pixels": pixels(4, 4, [0, 0, 255, 255])]), "noSpace")
    XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("screen.jpg")), previous)
    XCTAssertEqual(files(directory), ["screen.jpg"])
  }

  func testTheDefaultWriterIsAtomic() throws {
    // Contrato §2: escritura atómica; un archivo que ya existe se sustituye entero.
    let url = root.appendingPathComponent("atomic.jpg")
    try Data(repeating: 1, count: 1000).write(to: url)
    try ImageSanitizer.atomicWriter(Data([2, 2]), url)
    XCTAssertEqual(try Data(contentsOf: url), Data([2, 2]))
    let source = try String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Runner/ImageSanitizer.swift"),
      encoding: .utf8)
    XCTAssertTrue(source.contains("options: .atomic"))
  }

  // MARK: - El canal

  func testTheChannelAnswersTheThreeMethods() {
    // CA-028-20: `sanitize`, `regenerate` y `encodeJpeg` ya no son «no implementado».
    let messenger = RecordingMessenger()
    UnaChannels.register(
      messenger: messenger,
      images: Images(cachesDirectory: caches, applicationSupportDirectory: support))
    for method in ["sanitize", "regenerate", "encodeJpeg"] {
      XCTAssertNotNil(messenger.call("una/images", method: method, arguments: nil), method)
    }
  }
}
