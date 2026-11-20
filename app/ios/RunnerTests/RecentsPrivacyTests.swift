import Flutter
import UIKit
import XCTest

@testable import Runner

/// Selector de apps sin contenido (contrato §8; espejo de `RecentsPrivacy.kt`; CA-028-12, que
/// hereda CA-011-01 a 04). Al pasar a inactiva, una vista `paper` a pantalla completa tapa la
/// ventana; al volver se quita sin animación. Nada de esto bloquea capturas ni grabaciones.
class RecentsPrivacyTests: XCTestCase {

  private func makeWindow(size: CGSize = CGSize(width: 390, height: 844)) -> (UIWindow, UIView) {
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    let root = UIViewController()
    // Contenido «sensible» de un color que no es `paper`, para ver que queda tapado.
    let content = UIView(frame: window.bounds)
    content.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
    content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    root.view.addSubview(content)
    window.rootViewController = root
    window.isHidden = false
    window.layoutIfNeeded()
    return (window, content)
  }

  /// El color `paper` de `design/tokens.json` (el simulador lee el disco del Mac).
  private func paperFromTokens() throws -> (CGFloat, CGFloat, CGFloat) {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()  // RunnerTests, ios
      .deletingLastPathComponent().deletingLastPathComponent()  // app, raíz del repositorio
    let data = try Data(contentsOf: root.appendingPathComponent("design/tokens.json"))
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let colors = try XCTUnwrap(json["color"] as? [String: Any])
    let paper = try XCTUnwrap(colors["paper"] as? [String: Any])
    let hex = try XCTUnwrap(paper["$value"] as? String)
    XCTAssertTrue(hex.hasPrefix("#") && hex.count == 7, "paper debe ser #RRGGBB: \(hex)")
    let value = try XCTUnwrap(UInt32(hex.dropFirst(), radix: 16))
    return (
      CGFloat((value >> 16) & 0xFF) / 255, CGFloat((value >> 8) & 0xFF) / 255,
      CGFloat(value & 0xFF) / 255
    )
  }

  private func rgb(_ color: UIColor) -> (CGFloat, CGFloat, CGFloat) {
    let resolved = color.resolvedColor(
      with: UITraitCollection(userInterfaceStyle: .light))
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    XCTAssertTrue(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
    XCTAssertEqual(a, 1, accuracy: 0.001, "tiene que ser opaco")
    return (r, g, b)
  }

  private func assertSame(
    _ a: (CGFloat, CGFloat, CGFloat), _ b: (CGFloat, CGFloat, CGFloat), _ message: String = "",
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertEqual(a.0, b.0, accuracy: 1.0 / 255, message, file: file, line: line)
    XCTAssertEqual(a.1, b.1, accuracy: 1.0 / 255, message, file: file, line: line)
    XCTAssertEqual(a.2, b.2, accuracy: 1.0 / 255, message, file: file, line: line)
  }

  /// Color del píxel central de la ventana, dibujada tal cual (lo que vería una miniatura).
  private func centerPixel(of window: UIWindow, useLayer: Bool = false) throws -> (
    CGFloat, CGFloat, CGFloat
  ) {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: window.bounds.size, format: format)
    let image = renderer.image { context in
      if useLayer {
        // Una ventana suelta (sin escena) no se dibuja con `drawHierarchy`: se pinta su capa.
        window.layer.render(in: context.cgContext)
      } else {
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
      }
    }
    let cg = try XCTUnwrap(image.cgImage)
    let x = cg.width / 2
    let y = cg.height / 2
    let cropped = try XCTUnwrap(cg.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
    var pixel = [UInt8](repeating: 0, count: 4)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
      data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return (CGFloat(pixel[0]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[2]) / 255)
  }

  // MARK: - La vista que tapa

  func testCoverAppearsOnTopFillingTheWindow() {
    // CA-028-12 y CA-011-01: al pasar a inactiva hay una vista encima de todo, a pantalla completa.
    let (window, content) = makeWindow()
    let recents = RecentsPrivacy()
    XCTAssertFalse(recents.isCovering)
    recents.cover(window)
    XCTAssertTrue(recents.isCovering)
    let cover = window.subviews.last
    XCTAssertNotNil(cover)
    XCTAssertEqual(cover?.frame, window.bounds)
    XCTAssertTrue(cover !== content)
    XCTAssertEqual(cover?.alpha, 1, "opaca desde el primer instante, sin fundido")
    XCTAssertFalse(cover?.isHidden ?? true)
  }

  func testCoverColorIsTheLaunchBackgroundColorSet() throws {
    // CA-028-12, CA-011-02 y CA-021-12: el color es `paper`, el mismo del arranque (colorset de
    // T-028-04, generado desde `design/tokens.json`).
    let (window, _) = makeWindow()
    let recents = RecentsPrivacy()
    recents.cover(window)
    let background = try XCTUnwrap(window.subviews.last?.backgroundColor)
    assertSame(rgb(background), try paperFromTokens(), "debe ser `paper`")
    assertSame(rgb(RecentsPrivacy.paper), try paperFromTokens(), "el color estático también")
  }

  func testCoverLooksTheSameWhateverTheSystemAppearance() throws {
    // CA-021-01 y CA-028-04: la app es siempre clara; la vista no se oscurece con el sistema.
    let (window, _) = makeWindow()
    let recents = RecentsPrivacy()
    window.overrideUserInterfaceStyle = .dark
    recents.cover(window)
    let cover = try XCTUnwrap(window.subviews.last)
    let dark = cover.backgroundColor!.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    assertSame(rgb(dark), try paperFromTokens(), "ni siquiera en oscuro")
  }

  func testWindowThumbnailShowsOnlyPaper() throws {
    // CA-028-12: lo que se dibuja de la ventana (la miniatura del selector) es solo `paper`, aunque
    // detrás haya contenido de otro color.
    let (window, _) = makeWindow()
    assertSame(try centerPixel(of: window, useLayer: true), (1, 0, 0), "sin la vista se ve el contenido")
    let recents = RecentsPrivacy()
    recents.cover(window)
    assertSame(try centerPixel(of: window, useLayer: true), try paperFromTokens(), "con la vista, solo papel")
    recents.uncover()
    assertSame(try centerPixel(of: window, useLayer: true), (1, 0, 0), "al volver, el contenido otra vez")
  }

  func testCoverFollowsTheWindowWhenItResizes() {
    // CA-028-12: si la ventana cambia de tamaño (giro) con la vista puesta, sigue cubriéndola.
    let (window, _) = makeWindow(size: CGSize(width: 390, height: 844))
    let recents = RecentsPrivacy()
    recents.cover(window)
    window.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
    window.layoutIfNeeded()
    XCTAssertEqual(window.subviews.last?.frame, window.bounds)
  }

  // MARK: - Quitarla

  func testUncoverRemovesItAtOnceWithoutAnimation() {
    // CA-028-12, CA-011-03 y CA-021-12: al volver se quita sin animación (nada de fundido, ni siquiera
    // si Dart o el sistema tienen una animación en curso).
    let (window, _) = makeWindow()
    let recents = RecentsPrivacy()
    recents.cover(window)
    let cover = window.subviews.last!
    let animationsWereEnabled = UIView.areAnimationsEnabled
    UIView.animate(withDuration: 5) {
      recents.uncover()
    }
    XCTAssertFalse(recents.isCovering)
    XCTAssertNil(cover.superview, "quitada en el mismo instante")
    XCTAssertNil(cover.layer.animationKeys(), "sin animación en su capa")
    XCTAssertEqual(cover.alpha, 1, "sin fundido")
    XCTAssertEqual(UIView.areAnimationsEnabled, animationsWereEnabled, "no deja las animaciones cambiadas")
  }

  func testCoverAndUncoverTwiceLeaveOneViewAndNoCrash() {
    // CA-028-12: un diálogo del sistema puede dar dos «inactiva» seguidas, o un «activa» sin vista.
    let (window, _) = makeWindow()
    let recents = RecentsPrivacy()
    recents.uncover()  // sin nada puesto: no hace nada
    let before = window.subviews.count
    recents.cover(window)
    recents.cover(window)
    XCTAssertEqual(window.subviews.count, before + 1)
    recents.uncover()
    recents.uncover()
    XCTAssertEqual(window.subviews.count, before)
    XCTAssertFalse(recents.isCovering)
  }

  func testCoverCanBeUsedAgainAfterUncovering() {
    // CA-011-08 en iOS: ciclo completo repetido.
    let (window, _) = makeWindow()
    let recents = RecentsPrivacy()
    for _ in 0..<3 {
      recents.cover(window)
      XCTAssertTrue(recents.isCovering)
      recents.uncover()
      XCTAssertFalse(recents.isCovering)
    }
    XCTAssertEqual(window.subviews.filter { $0.backgroundColor != nil && $0 !== window.rootViewController?.view }.count, 0)
  }

  func testCoverMovesToAnotherWindowWhenAskedOnIt() {
    // Si la ventana de la escena cambia entre «inactiva» y «activa», no queda una vista huérfana.
    let (first, _) = makeWindow()
    let (second, _) = makeWindow()
    let firstBefore = first.subviews.count
    let secondBefore = second.subviews.count
    let recents = RecentsPrivacy()
    recents.cover(first)
    recents.cover(second)
    XCTAssertEqual(first.subviews.count, firstBefore)
    XCTAssertEqual(second.subviews.count, secondBefore + 1)
    recents.uncover()
    XCTAssertEqual(second.subviews.count, secondBefore)
  }

  // MARK: - Lector de pantalla y capturas

  func testCoverIsNotAnAccessibilityElement() {
    // CA-028-12: es solo un velo; no se anuncia ni se enfoca con VoiceOver.
    let (window, _) = makeWindow()
    let recents = RecentsPrivacy()
    recents.cover(window)
    let cover = window.subviews.last!
    XCTAssertFalse(cover.isAccessibilityElement)
    XCTAssertTrue(cover.accessibilityElements?.isEmpty ?? true)
  }

  func testSourcesDoNotBlockScreenshotsOrRecordings() throws {
    // CA-028-12 y CA-011-04: las capturas y grabaciones con la app delante siguen permitidas. Ni
    // `isSecureTextEntry` (el truco que las pone en negro), ni escuchar capturas, ni `isCaptured`.
    let ios = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let forbidden = try NSRegularExpression(
      pattern: #"isSecureTextEntry|secureTextEntry|userDidTakeScreenshot|isCaptured|capturedDidChange|UITextField|makeSecure"#)
    for file in ["Runner/RecentsPrivacy.swift", "Runner/SceneDelegate.swift"] {
      let source = try String(contentsOf: ios.appendingPathComponent(file), encoding: .utf8)
      let text = source.split(separator: "\n", omittingEmptySubsequences: false)
        .map { line -> String in
          if let range = line.range(of: "//") { return String(line[..<range.lowerBound]) }
          return String(line)
        }
        .joined(separator: "\n")
      let range = NSRange(text.startIndex..., in: text)
      XCTAssertNil(forbidden.firstMatch(in: text, range: range), "\(file) bloquea capturas")
    }
  }

  // MARK: - La escena de verdad

  /// La escena y la ventana reales de la app de pruebas (RunnerTests corre dentro de la app).
  private func realScene() throws -> (UIWindowScene, SceneDelegate, UIWindow) {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
      "la app de pruebas no tiene escena")
    let delegate = try XCTUnwrap(scene.delegate as? SceneDelegate, "la escena no usa SceneDelegate")
    let window = try XCTUnwrap(scene.windows.first, "la escena no tiene ventana")
    return (scene, delegate, window)
  }

  func testRealSceneDelegateCoversWhenInactiveAndUncoversWhenActive() throws {
    // CA-028-12: el cableado real. `sceneWillResignActive` pone la vista sobre la ventana de Flutter
    // y `sceneDidBecomeActive` la quita, sin animación.
    let (scene, delegate, window) = try realScene()
    let before = window.subviews.count
    delegate.sceneWillResignActive(scene)
    XCTAssertEqual(window.subviews.count, before + 1)
    XCTAssertEqual(window.subviews.last?.frame, window.bounds)
    assertSame(rgb(try XCTUnwrap(window.subviews.last?.backgroundColor)), try paperFromTokens())
    assertSame(try centerPixel(of: window), try paperFromTokens(), "la miniatura real, solo papel")
    delegate.sceneDidBecomeActive(scene)
    XCTAssertEqual(window.subviews.count, before)
  }
}
