import '../entities/link_target.dart';

/// Abre un enlace externo de un PDF, ya confirmado por el usuario (CA-008-12):
/// la web en el navegador, el correo en su app (sin enviar) y el teléfono en
/// el marcador (sin llamar). Devuelve false si no hay ninguna app para él.
abstract interface class LinkOpener {
  Future<bool> open(LinkTarget target);
}
