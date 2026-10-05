// GENERADO por tool/gen_identity.dart desde identity.yaml. No editar a mano.

/// Identidad de la app. El nombre nunca se escribe literal en el código (constitución P7).
abstract final class AppIdentity {
  /// Nombre de la app en el sistema (bajo el icono).
  static const String displayName = 'Una.';

  /// Logotipo que se muestra dentro de la app.
  static const String wordmark = 'una.';

  /// Dirección de la política de privacidad (una sola para ES y EN). Solo `https`; se abre en el
  /// navegador del sistema. Es un marcador hasta que exista la web (spec 012, CA-012-05).
  static const String privacyPolicyUrl = 'https://example.com/privacy';

  /// Dirección de la web de licencias de terceros (una sola para ES y EN; ADR-0026). Marcador
  /// hasta que exista la web (spec 015, CA-015-13a).
  static const String thirdPartyLicensesUrl = 'https://example.com/licenses';

  /// Dirección de la web de ayuda (una sola para ES y EN). Marcador hasta que exista la web
  /// (spec 015, CA-015-13a).
  static const String helpUrl = 'https://example.com/help';
}
