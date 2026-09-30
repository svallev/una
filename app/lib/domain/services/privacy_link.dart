import '../entities/link_target.dart';
import 'link_policy.dart';

/// La dirección de la política de privacidad como enlace abrible, o null si no
/// se puede abrir (CA-012-04, CL-012-8): solo `https`, y `classifyLink` rechaza
/// las direcciones con usuario (`https://usuario@host`, T-5), sin dominio o mal
/// formadas (también con espacios o caracteres de control).
WebLink? privacyLink(String address) {
  final trimmed = address.trim();
  // Un espacio o un carácter de control dentro de la dirección no es un dominio.
  if (trimmed.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
  final target = classifyLink(url: uri);
  return target is WebLink ? target : null;
}
