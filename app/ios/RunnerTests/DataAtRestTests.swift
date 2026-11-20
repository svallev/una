import XCTest

@testable import Runner

/// Datos en reposo (CA-028-18, ADR-0032 y ADR-0005): `attachments/` fuera de la copia de seguridad
/// y la protección de datos por defecto, sin bajar.
class DataAtRestTests: XCTestCase {
  private var base: URL!

  override func setUpWithError() throws {
    // Un «Application Support» de mentira, nuevo en cada prueba.
    base = FileManager.default.temporaryDirectory
      .appendingPathComponent("una-data-at-rest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: base)
  }

  private func isExcluded(_ url: URL) throws -> Bool {
    // Un `URL` guarda en caché los valores ya leídos: se lee desde uno nuevo, como lo haría el sistema.
    let fresh = URL(fileURLWithPath: url.path, isDirectory: true)
    return try fresh.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false
  }

  private func isDirectory(_ url: URL) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
  }

  func testCreatesTheAttachmentsFolderAndExcludesItFromTheBackup() throws {
    // CA-028-18: la carpeta que Dart usa (`<Application Support>/attachments`) nace excluida.
    let dir = try DataAtRest.prepareAttachments(in: base)
    XCTAssertEqual(dir.lastPathComponent, "attachments")
    XCTAssertEqual(dir.deletingLastPathComponent().standardizedFileURL, base.standardizedFileURL)
    XCTAssertTrue(isDirectory(dir))
    XCTAssertTrue(try isExcluded(dir))
  }

  func testMarksAFolderThatAlreadyExistsWithoutTouchingWhatIsInside() throws {
    // CA-028-18: si Dart la creó antes (primer uso), el siguiente arranque la marca y respeta sus adjuntos.
    let dir = base.appendingPathComponent("attachments", isDirectory: true)
    let photo = dir.appendingPathComponent("abc/screen.jpg")
    try FileManager.default.createDirectory(
      at: photo.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: photo)
    XCTAssertFalse(try isExcluded(dir))

    try DataAtRest.prepareAttachments(in: base)

    XCTAssertTrue(try isExcluded(dir))
    XCTAssertEqual(try Data(contentsOf: photo), Data([1, 2, 3]))
  }

  func testIsIdempotentAndKeepsTheMarkOnEveryLaunch() throws {
    // CA-028-18: «al crearla y al arrancar»: repetirlo no falla ni cambia nada.
    let first = try DataAtRest.prepareAttachments(in: base)
    let second = try DataAtRest.prepareAttachments(in: base)
    XCTAssertEqual(first, second)
    XCTAssertTrue(try isExcluded(second))
  }

  func testRestoresTheMarkIfSomethingClearedIt() throws {
    // CA-028-18: aunque otra cosa la quitase (restauración, copia a mano), cada arranque la repone.
    let dir = try DataAtRest.prepareAttachments(in: base)
    var values = URLResourceValues()
    values.isExcludedFromBackup = false
    var mutable = dir
    try mutable.setResourceValues(values)
    XCTAssertFalse(try isExcluded(dir))

    try DataAtRest.prepareAttachments(in: base)

    XCTAssertTrue(try isExcluded(dir))
  }

  func testOnlyTheAttachmentsFolderIsExcluded() throws {
    // CA-028-18: lo demás de «Application Support» (y la BD, que va en Documents) sigue en la copia.
    let other = base.appendingPathComponent("web-data", isDirectory: true)
    try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
    try DataAtRest.prepareAttachments(in: base)
    XCTAssertFalse(try isExcluded(base))
    XCTAssertFalse(try isExcluded(other))
  }

  func testFailsWithoutCrashingWhenTheFolderCannotBeCreated() throws {
    // CA-028-18: si «Application Support» es un archivo, falla con un error y el arranque sigue.
    let notAFolder = base.appendingPathComponent("file")
    try Data([0]).write(to: notAFolder)
    XCTAssertThrowsError(try DataAtRest.prepareAttachments(in: notAFolder))
    XCTAssertFalse(DataAtRest.prepareAttachmentsAtLaunch(applicationSupport: notAFolder))
  }

  func testTheRealApplicationSupportFolderIsTheOneDartUses() throws {
    // CA-028-18: `getApplicationSupportDirectory` de Dart = `Library/Application Support` del contenedor.
    let support = try XCTUnwrap(DataAtRest.applicationSupportDirectory())
    XCTAssertEqual(support.lastPathComponent, "Application Support")
    XCTAssertEqual(support.deletingLastPathComponent().lastPathComponent, "Library")
  }

  func testAtLaunchItPreparesTheRealFolderAndReportsSuccess() throws {
    // CA-028-18: lo que llama el arranque del motor funciona de verdad en el simulador.
    XCTAssertTrue(DataAtRest.prepareAttachmentsAtLaunch())
    let support = try XCTUnwrap(DataAtRest.applicationSupportDirectory())
    XCTAssertTrue(try isExcluded(support.appendingPathComponent("attachments", isDirectory: true)))
  }

  func testTheFolderItCreatesKeepsTheDefaultProtectionClass() throws {
    // CA-028-18, ADR-0005: [Suposición] el simulador no aplica Data Protection; aun así, nada de `.none`.
    let dir = try DataAtRest.prepareAttachments(in: base)
    let attributes = try FileManager.default.attributesOfItem(atPath: dir.path)
    if let protection = attributes[.protectionKey] as? FileProtectionType {
      XCTAssertNotEqual(protection, .none)
    }
  }

  func testTheEngineStartupCallsIt() throws {
    // CA-028-18: el arranque del motor prepara la carpeta (el cableado no se puede lanzar en un
    // XCTest sin abrir la app entera: se lee de `AppDelegate.swift`).
    let source = code(try read("Runner/AppDelegate.swift"))
    let start = try XCTUnwrap(source.range(of: "func didInitializeImplicitFlutterEngine"))
    XCTAssertTrue(source[start.upperBound...].contains("DataAtRest.prepareAttachmentsAtLaunch()"))
  }

  // MARK: - Protección por defecto (se lee del código, no se puede bajar sin que falle esto)

  /// Raíz de `app/ios/`, a partir de la ruta de este archivo (el simulador lee el disco del Mac).
  private var iosRoot: URL {
    return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
  }

  private func read(_ relative: String) throws -> String {
    let url = iosRoot.appendingPathComponent(relative)
    return try String(contentsOf: url, encoding: .utf8)
  }

  /// Sin los comentarios de línea, para que explicar qué no se hace no cuente como hacerlo.
  private func code(_ source: String) -> String {
    return source.split(separator: "\n", omittingEmptySubsequences: false)
      .map { line -> String in
        if let range = line.range(of: "//") { return String(line[..<range.lowerBound]) }
        return String(line)
      }
      .joined(separator: "\n")
  }

  func testNoSwiftSourceChangesTheDataProtectionClass() throws {
    // CA-028-18, ADR-0005: la clase por defecto («hasta el primer desbloqueo») no se toca en el
    // Swift propio: ni `.none`/`noFileProtection` ni ninguna otra clase explícita.
    let runner = iosRoot.appendingPathComponent("Runner", isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(atPath: runner.path)
      .filter { $0.hasSuffix(".swift") }
    XCTAssertTrue(files.contains("DataAtRest.swift"), "no se encontraron las fuentes de Runner")
    let forbidden = try NSRegularExpression(
      pattern: #"[Ff]ileProtection|protectionKey|NSFileProtection|dataProtection"#)
    for file in files {
      let text = code(try read("Runner/\(file)"))
      let range = NSRange(text.startIndex..., in: text)
      XCTAssertNil(
        forbidden.firstMatch(in: text, range: range), "\(file) toca la protección de datos")
    }
  }

  func testNoEntitlementLowersTheDefaultProtection() throws {
    // CA-028-18, ADR-0005: sin archivo de entitlements ni `CODE_SIGN_ENTITLEMENTS` en el proyecto
    // (el entitlement `default-data-protection` solo puede venir de ahí).
    let runner = iosRoot.appendingPathComponent("Runner", isDirectory: true)
    let names = try FileManager.default.contentsOfDirectory(atPath: runner.path)
    XCTAssertTrue(names.filter { $0.hasSuffix(".entitlements") }.isEmpty)
    let project = try read("Runner.xcodeproj/project.pbxproj")
    XCTAssertFalse(project.contains("CODE_SIGN_ENTITLEMENTS"))
    XCTAssertFalse(project.contains("default-data-protection"))
    XCTAssertFalse(try read("Runner/Info.plist").contains("NSFileProtection"))
  }
}
