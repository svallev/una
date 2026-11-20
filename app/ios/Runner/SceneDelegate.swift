import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Vista que tapa la ventana mientras la app no está activa (selector de apps sin contenido,
  /// CA-028-12; contrato §8).
  private let recents = RecentsPrivacy()

  override func sceneWillResignActive(_ scene: UIScene) {
    // Primero la vista (que no se escape ni un fotograma) y después lo de Flutter.
    if let window = SceneDelegate.window(of: scene) { recents.cover(window) }
    super.sceneWillResignActive(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    recents.uncover()
    super.sceneDidBecomeActive(scene)
  }

  /// La ventana de la escena: la de Flutter (`window` de la escena) o, si no, la primera.
  private static func window(of scene: UIScene) -> UIWindow? {
    guard let windowScene = scene as? UIWindowScene else { return nil }
    return windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
  }
}
