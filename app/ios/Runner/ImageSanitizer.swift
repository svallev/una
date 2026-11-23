import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Resultado de limpiar una imagen: dimensiones y bytes de la versión completa.
struct SanitizedImage: Equatable {
  let width: Int
  let height: Int
  let byteSize: Int64
}

/// Recodifica una imagen **desde los píxeles** (spec 007, CA-007-07; espejo de `ImageSanitizer.kt`;
/// contrato §2): cada JPEG se escribe con `CGImageDestination` y **solo** la calidad como propiedad
/// (y sin los segmentos de metadatos que ImageIO añade por su cuenta, `stripMetadata`), así que no
/// sobrevive ningún byte del original (EXIF, GPS, XMP, miniatura interna, la parte de
/// vídeo de una Live Photo, la *gainmap* HDR ni datos tras el final). Escribe en la carpeta:
///
/// - `full-<fila>-<col>.jpg`: la versión completa en teselas de ≤ 4096 px (reducida solo si pasa de
///   `storedMaxPixels`, sin límite de lado), calidad 0,90;
/// - `screen.jpg`: al ancho de la pantalla en vertical, sin perder los lados; si es más alta que la
///   pantalla, solo la parte de arriba (I-2), calidad 0,85;
/// - `thumb.jpg`: cuadrada, de 176 px, recortada, calidad 0,80.
///
/// Solo ImageIO y Core Graphics (sin UIKit): se prueba sin pantalla. Nunca registra nada.
final class ImageSanitizer {
  static let tile = 4096
  static let thumb = 176
  static let fullQuality = 0.90
  static let screenQuality = 0.85
  static let thumbQuality = 0.80

  /// Escribe un archivo entero. Por defecto, **atómico** (a un temporal y luego se renombra): nunca
  /// queda una versión a medias. Los tests lo sustituyen para simular un disco lleno.
  typealias Writer = (Data, URL) throws -> Void
  static let atomicWriter: Writer = { data, url in try data.write(to: url, options: .atomic) }

  private let maxPixels: Int64
  private let storedMaxPixels: Int64
  private let screenWidth: Int
  private let screenHeight: Int
  private let cancelled: CancelFlag
  private let writer: Writer

  init(
    maxPixels: Int64,
    storedMaxPixels: Int64,
    screenWidth: Int,
    screenHeight: Int,
    cancelled: CancelFlag = CancelFlag(),
    writer: @escaping Writer = ImageSanitizer.atomicWriter
  ) {
    self.maxPixels = maxPixels
    self.storedMaxPixels = storedMaxPixels
    self.screenWidth = Swift.max(1, screenWidth)
    self.screenHeight = Swift.max(1, screenHeight)
    self.cancelled = cancelled
    self.writer = writer
  }

  // MARK: - Limpiar

  /// Limpia `source` y deja sus versiones en `outDir`. No borra `source` (lo hace quien llama).
  func sanitize(source: URL, outDir: URL) throws -> SanitizedImage {
    // CL-007-4: transparencia sobre blanco
    let image = try flattenOnWhite(try decode(source))
    try checkCancelled()
    do {
      try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    } catch {
      throw ImageSanitizer.code(for: error)
    }
    let byteSize = try writeTiles(image, outDir)
    try checkCancelled()
    let screen = ImageSanitizer.fitWidthCrop(image.width, image.height, screenWidth, screenHeight)
    try write(
      try ImageSanitizer.cut(image, screen.scale, screen.crop), ImageSanitizer.screenQuality,
      outDir.appendingPathComponent("screen.jpg"))
    let thumb = ImageSanitizer.coverCrop(
      image.width, image.height, ImageSanitizer.thumb, ImageSanitizer.thumb)
    try write(
      try ImageSanitizer.cut(image, thumb.scale, thumb.crop), ImageSanitizer.thumbQuality,
      outDir.appendingPathComponent("thumb.jpg"))
    return SanitizedImage(width: image.width, height: image.height, byteSize: byteSize)
  }

  private func checkCancelled() throws {
    if cancelled.isSet { throw ImageImportCode.cancelled }
  }

  private func tooMany(_ width: Int, _ height: Int) -> Bool {
    return width <= 0 || height <= 0 || Int64(width) * Int64(height) > maxPixels
  }

  /// Factor de reducción para quedar en ≤ `storedMaxPixels`.
  private func scaleFor(_ width: Int, _ height: Int) -> Double {
    let pixels = Int64(width) * Int64(height)
    return pixels <= storedMaxPixels ? 1 : (Double(storedMaxPixels) / Double(pixels)).squareRoot()
  }

  /// Lee la cabecera **antes** de reservar memoria para los píxeles (`tooManyPixels` sin decodificar)
  /// y decodifica ya reducida y con la orientación EXIF aplicada (las 8, CA-007-07). Diferencia con
  /// Android [Hecho, T-028-14]: ImageIO no avisa de una imagen **cortada** (su estado sigue
  /// «completa» y la parte que falta sale gris), así que, a diferencia de `setOnPartialImageListener`,
  /// se acepta lo que decodifica (contrato §2).
  private func decode(_ source: URL) throws -> CGImage {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, options),
      CGImageSourceGetCount(imageSource) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
    else {
      // ImageIO no da las dimensiones de un PNG enorme (60 000 × 60 000, [Hecho, T-028-14]): como
      // `inJustDecodeBounds` en Android, se miran en su IHDR para responder `tooManyPixels`.
      if let (width, height) = ImageSanitizer.pngHeaderSize(source), tooMany(width, height) {
        throw ImageImportCode.tooManyPixels
      }
      throw ImageImportCode.unreadable
    }
    if tooMany(width, height) { throw ImageImportCode.tooManyPixels }
    let factor = scaleFor(width, height)
    let longest =
      factor < 1
      ? Swift.max(
        Swift.max(1, Int((Double(width) * factor).rounded(.down))),
        Swift.max(1, Int((Double(height) * factor).rounded(.down))))
      : Swift.max(width, height)
    let thumbnail: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: longest,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnail as CFDictionary)
    else {
      throw ImageImportCode.unreadable
    }
    return image
  }

  /// Dibuja en un lienzo sRGB opaco **blanco**: la transparencia queda sobre blanco, el color pasa a
  /// sRGB y a 8 bits (fuera la *gainmap* HDR y los 16 bits). Además garantiza ancho × alto ≤
  /// `storedMaxPixels` [Hecho, T-028-14]: ImageIO redondea **hacia arriba** el lado corto de la
  /// miniatura (8000 × 7990 a 24 MP salía en 4902 × 4896 = 24 000 192), así que, si se pasa, el lado
  /// corto se queda en `storedMaxPixels / lado largo` (menos de 1 px de diferencia de proporción).
  private func flattenOnWhite(_ image: CGImage) throws -> CGImage {
    var width = image.width
    var height = image.height
    if Int64(width) * Int64(height) > storedMaxPixels {
      if width >= height {
        height = Swift.max(1, Int(storedMaxPixels / Int64(width)))
      } else {
        width = Swift.max(1, Int(storedMaxPixels / Int64(height)))
      }
    }
    let context = try ImageSanitizer.canvas(width, height)
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let flat = context.makeImage() else { throw ImageImportCode.unreadable }
    return flat
  }

  private func writeTiles(_ image: CGImage, _ outDir: URL) throws -> Int64 {
    let tile = ImageSanitizer.tile
    let rows = (image.height + tile - 1) / tile
    let cols = (image.width + tile - 1) / tile
    var bytes: Int64 = 0
    for row in 0..<rows {
      for col in 0..<cols {
        try checkCancelled()
        let part: CGImage
        if rows == 1 && cols == 1 {
          part = image
        } else {
          let left = col * tile
          let top = row * tile
          let rect = CGRect(
            x: left, y: top, width: Swift.min(tile, image.width - left),
            height: Swift.min(tile, image.height - top))
          guard let cropped = image.cropping(to: rect) else { throw ImageImportCode.unreadable }
          part = cropped
        }
        let data = try ImageSanitizer.jpeg(part, ImageSanitizer.fullQuality)
        try save(data, outDir.appendingPathComponent("full-\(row)-\(col).jpg"))
        bytes += Int64(data.count)
      }
    }
    return bytes
  }

  private func write(_ image: CGImage, _ quality: Double, _ url: URL) throws {
    try save(try ImageSanitizer.jpeg(image, quality), url)
  }

  private func save(_ data: Data, _ url: URL) throws {
    try ImageSanitizer.save(data, url, writer)
  }

  // MARK: - Regenerar

  /// Rehace `screen.jpg` y `thumb.jpg` de un adjunto guardado en `dir` a partir de sus teselas
  /// (CA-007-19). Solo decodifica, reducida, cada tesela que toca la zona recortada, así que una
  /// captura larga no ocupa memoria de más. Lanza `unreadable` si falta o no se lee alguna tesela.
  func regenerateDerived(dir: URL, width: Int, height: Int) throws {
    guard ImageSanitizer.isRegenerableSize(width: width, height: height) else {
      throw ImageImportCode.unreadable
    }
    let screen = ImageSanitizer.fitWidthCrop(width, height, screenWidth, screenHeight)
    try writeDerived(
      dir, width, height, screen.scale, screen.crop, "screen.jpg", ImageSanitizer.screenQuality)
    let thumb = ImageSanitizer.coverCrop(width, height, ImageSanitizer.thumb, ImageSanitizer.thumb)
    try writeDerived(
      dir, width, height, thumb.scale, thumb.crop, "thumb.jpg", ImageSanitizer.thumbQuality)
  }

  private func writeDerived(
    _ dir: URL, _ width: Int, _ height: Int, _ scale: Double, _ crop: CGRect, _ name: String,
    _ quality: Double
  ) throws {
    let s = Swift.min(1, scale)
    let outW = Swift.max(1, Int((crop.width * s).rounded()))
    let outH = Swift.max(1, Int((crop.height * s).rounded()))
    let context = try ImageSanitizer.canvas(outW, outH)
    let tile = ImageSanitizer.tile
    let rows = (height + tile - 1) / tile
    let cols = (width + tile - 1) / tile
    for row in 0..<rows {
      for col in 0..<cols {
        let tileRect = CGRect(
          x: col * tile, y: row * tile, width: Swift.min(tile, width - col * tile),
          height: Swift.min(tile, height - row * tile))
        guard tileRect.intersects(crop) else { continue }
        let file = dir.appendingPathComponent("full-\(row)-\(col).jpg")
        let image = try ImageSanitizer.decodeTile(file, scale: s)
        // La tesela entera, ya reducida, en su sitio: el lienzo recorta lo que cae fuera.
        let target = CGRect(
          x: (tileRect.minX - crop.minX) * s, y: (tileRect.minY - crop.minY) * s,
          width: tileRect.width * s, height: tileRect.height * s)
        ImageSanitizer.draw(image, at: target, in: context, height: outH)
      }
    }
    guard let out = context.makeImage() else { throw ImageImportCode.unreadable }
    try write(out, quality, dir.appendingPathComponent(name))
  }

  /// Una tesela decodificada a `scale` (≤ 1): nunca a más resolución de la que se va a dibujar.
  private static func decodeTile(_ file: URL, scale: Double) throws -> CGImage {
    let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    guard size > 0,
      let source = CGImageSourceCreateWithURL(
        file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
      CGImageSourceGetCount(source) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
    else {
      throw ImageImportCode.unreadable
    }
    let longest = Swift.max(1, Int((Double(Swift.max(width, height)) * scale).rounded(.up)))
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: longest,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw ImageImportCode.unreadable
    }
    return image
  }

  /// Tope de lo que se regenera (I-4 de la 028): lo guardado ya está reducido a `storedMaxPixels`
  /// (24 MP); se admite hasta el tope de la imagen original (64 MP, `ImageLimits.maxPixels`).
  static let regenerateMaxPixels = 64_000_000

  /// Ancho y alto de un adjunto guardado que se pueden regenerar: ≥ 1 cada lado y `ancho × alto`
  /// sin desbordar y ≤ `regenerateMaxPixels` (así `alto + tesela - 1` tampoco desborda).
  static func isRegenerableSize(width: Int, height: Int) -> Bool {
    guard width > 0, height > 0 else { return false }
    let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
    return !overflow && pixels <= regenerateMaxPixels
  }

  // MARK: - Codificar (página de un PDF)

  /// Escribe `screen.jpg` (calidad 0,85) desde píxeles RGBA o BGRA (spec 008: la página de un PDF que
  /// dibuja pdfrx en Dart), sin copiar los píxeles. Tamaño fuera de rango o `pixels` que no mide
  /// `width × height × 4` → `unreadable`. Si `dir` ya no existe (el adjunto se completó o se canceló
  /// mientras tanto), no hace nada.
  static func encodeScreen(
    width: Int, height: Int, bgra: Bool, pixels: Data, dir: URL,
    writer: @escaping Writer = ImageSanitizer.atomicWriter
  ) throws {
    guard (1...8192).contains(width), (1...16384).contains(height),
      pixels.count == width * height * 4
    else {
      throw ImageImportCode.unreadable
    }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return
    }
    let info =
      bgra
      ? CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
      : CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    guard let provider = CGDataProvider(data: pixels as CFData),
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let image = CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: info),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    else {
      throw ImageImportCode.unreadable
    }
    try save(try jpeg(image, screenQuality), dir.appendingPathComponent("screen.jpg"), writer)
  }

  // MARK: - Utilidades

  /// Ancho y alto del IHDR de un PNG (solo los 24 primeros bytes); `nil` si no es un PNG.
  static func pngHeaderSize(_ file: URL) -> (Int, Int)? {
    guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
    defer { try? handle.close() }
    guard let head = try? handle.read(upToCount: 24), head.count == 24 else { return nil }
    let bytes = [UInt8](head)
    let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    guard Array(bytes[0..<8]) == signature, Array(bytes[12..<16]) == Array("IHDR".utf8) else {
      return nil
    }
    func int(_ at: Int) -> Int { bytes[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) } }
    return (int(16), int(20))
  }

  /// Lienzo sRGB de 8 bits, opaco y relleno de blanco.
  private static func canvas(_ width: Int, _ height: Int) throws -> CGContext {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else {
      throw ImageImportCode.unreadable
    }
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .high
    return context
  }

  /// Dibuja con `rect` medido desde **arriba** a la izquierda (Core Graphics mide desde abajo).
  private static func draw(_ image: CGImage, at rect: CGRect, in context: CGContext, height: Int) {
    context.draw(
      image,
      in: CGRect(
        x: rect.minX, y: CGFloat(height) - rect.maxY, width: rect.width, height: rect.height))
  }

  /// Recorta `crop` y reduce a `scale`, sin ampliar nunca.
  private static func cut(_ image: CGImage, _ scale: Double, _ crop: CGRect) throws -> CGImage {
    let s = Swift.min(1, scale)
    let outW = Swift.max(1, Int((crop.width * s).rounded()))
    let outH = Swift.max(1, Int((crop.height * s).rounded()))
    let context = try canvas(outW, outH)
    draw(
      image,
      at: CGRect(
        x: -crop.minX * s, y: -crop.minY * s, width: CGFloat(image.width) * s,
        height: CGFloat(image.height) * s),
      in: context, height: outH)
    guard let out = context.makeImage() else { throw ImageImportCode.unreadable }
    return out
  }

  /// Escala y zona centrada que llenan `targetW` × `targetH` (miniatura).
  static func coverCrop(_ width: Int, _ height: Int, _ targetW: Int, _ targetH: Int) -> (
    scale: Double, crop: CGRect
  ) {
    let scale = Swift.max(Double(targetW) / Double(width), Double(targetH) / Double(height))
    let cropW = Swift.min(width, Swift.max(1, Int((Double(targetW) / scale).rounded())))
    let cropH = Swift.min(height, Swift.max(1, Int((Double(targetH) / scale).rounded())))
    let x = (width - cropW) / 2
    let y = (height - cropH) / 2
    return (scale, CGRect(x: x, y: y, width: cropW, height: cropH))
  }

  /// Escala y zona al ancho de `targetW`: todo el ancho y, si al ancho es más alta que `targetH`,
  /// solo la parte de arriba (versión de pantalla).
  static func fitWidthCrop(_ width: Int, _ height: Int, _ targetW: Int, _ targetH: Int) -> (
    scale: Double, crop: CGRect
  ) {
    let scale = Double(targetW) / Double(width)
    let cropH = Swift.min(height, Swift.max(1, Int((Double(targetH) / scale).rounded())))
    return (scale, CGRect(x: 0, y: 0, width: width, height: cropH))
  }

  /// JPEG con la calidad como **única** propiedad: sin EXIF, GPS, XMP ni miniatura.
  static func jpeg(_ image: CGImage, _ quality: Double) throws -> Data {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data, UTType.jpeg.identifier as CFString, 1, nil)
    else {
      throw ImageImportCode.unreadable
    }
    let properties = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
    CGImageDestinationAddImage(destination, image, properties)
    guard CGImageDestinationFinalize(destination), data.length > 0 else {
      throw ImageImportCode.unreadable
    }
    return try stripMetadata(data as Data)
  }

  /// Quita los segmentos de metadatos que ImageIO añade **por su cuenta** a todo JPEG, aunque no se le
  /// pase ninguna propiedad [Hecho, T-028-14]: un APP1 «Exif» mínimo (también desde un PNG sin EXIF)
  /// y un APP13 «Photoshop». Deja SOI, APP0 (JFIF), el perfil ICC (APP2 `ICC_PROFILE`) si lo hay, las
  /// tablas y, desde SOS, el resto tal cual. Fuera: APP1, APP2 que no sea ICC, APP13 y comentarios
  /// (como en Android y como comprueba `image_import_test`).
  static func stripMetadata(_ jpeg: Data) throws -> Data {
    let bytes = [UInt8](jpeg)
    guard bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else {
      throw ImageImportCode.unreadable
    }
    var out = Data(bytes[0..<2])
    var i = 2
    while true {
      guard i + 3 < bytes.count, bytes[i] == 0xFF else { throw ImageImportCode.unreadable }
      let marker = bytes[i + 1]
      if marker == 0xDA {
        out.append(contentsOf: bytes[i...])
        return out
      }
      let end = i + 2 + (Int(bytes[i + 2]) << 8 | Int(bytes[i + 3]))
      guard end <= bytes.count, end > i + 3 else { throw ImageImportCode.unreadable }
      let isIcc =
        marker == 0xE2 && i + 15 <= end
        && Array(bytes[(i + 4)..<(i + 15)]) == Array("ICC_PROFILE".utf8)
      let isMetadata =
        marker == 0xE1 || marker == 0xED || marker == 0xFE || (marker == 0xE2 && !isIcc)
      if !isMetadata { out.append(contentsOf: bytes[i..<end]) }
      i = end
    }
  }

  private static func save(_ data: Data, _ url: URL, _ writer: Writer) throws {
    do {
      try writer(data, url)
    } catch {
      throw code(for: error)
    }
  }

  /// Disco lleno → `noSpace`; cualquier otro fallo de escritura → `unreadable`.
  static func code(for error: Error) -> ImageImportCode {
    if let code = error as? ImageImportCode { return code }
    return Images.isNoSpace(error) ? .noSpace : .unreadable
  }
}
