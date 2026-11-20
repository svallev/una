import UIKit

/// Selector de apps sin contenido (contrato §8; espejo de `RecentsPrivacy.kt`; spec 011 CA-011-01
/// a 04 y spec 028 CA-028-12). Sin canal, sin ajuste y sin Dart.
///
/// Al pasar la escena a inactiva (`sceneWillResignActive`) se pone sobre la ventana una vista
/// opaca de color `paper` a pantalla completa; al volver a activa (`sceneDidBecomeActive`) se quita
/// **sin animación**. La miniatura del selector de apps sale entonces solo en `paper`.
///
/// No bloquea nada: ni `isSecureTextEntry` ni escuchar capturas, así que las capturas y grabaciones
/// con la app delante siguen permitidas (CA-011-04, regla de desempate de la 011: mandan las
/// capturas). Nada se guarda ni se registra.
final class RecentsPrivacy {
  private var cover: UIView?

  /// El color de la vista: el `LaunchBackground.colorset` que genera `gen_tokens.dart` desde el token
  /// `paper` (T-028-04), el mismo del arranque, así que no hay destello de otro color (CA-021-12).
  /// Fijo en claro: la app no se oscurece con el sistema (CA-028-04). Si el recurso faltara, blanco
  /// (también tapa el contenido).
  static var paper: UIColor {
    return UIColor(
      named: "LaunchBackground", in: Bundle(for: RecentsPrivacy.self),
      compatibleWith: UITraitCollection(userInterfaceStyle: .light)) ?? .white
  }

  var isCovering: Bool { return cover != nil }

  /// Pone la vista sobre `window`, por encima de todo lo demás (también de lo presentado). Si ya
  /// estaba puesta en esa ventana no hace nada (un diálogo del sistema puede dar dos «inactiva»);
  /// si estaba en otra, la pasa a esta.
  func cover(_ window: UIWindow) {
    if let current = cover, current.superview === window { return }
    uncover()
    let view = UIView(frame: window.bounds)
    view.backgroundColor = RecentsPrivacy.paper
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // Solo un velo: ni VoiceOver ni toques (la app está inactiva).
    view.isAccessibilityElement = false
    window.addSubview(view)
    cover = view
  }

  /// Quita la vista en el acto y sin animación (CA-011-03: nada de fundido ni de otro color al
  /// volver). `removeFromSuperview` no anima, y se desactivan las acciones de capa por si Dart o el
  /// sistema tienen una transición en curso.
  func uncover() {
    guard let view = cover else { return }
    cover = nil
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    view.removeFromSuperview()
    CATransaction.commit()
  }
}
