import '../domain/entities/attachment.dart';
import '../domain/entities/image_type.dart';

/// Máximo de filas de adjuntos que se leen por tarea (spec 016, CA-016-25):
/// el tope del grupo. Lo aplica la consulta en SQL; la memoria hace lo mismo.
const int maxReadAttachments = ImageLimits.maxGroup;

final _validAttachmentId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Un id de adjunto que puede ser nombre de carpeta: solo letras, cifras, `_` y
/// `-`, de 1 a 64. Lo comprueban el almacén de archivos (que lanza si no) y la
/// lectura de filas (que marca la fila como ilegible; CA-016-25, T-7).
bool isValidAttachmentId(String id) => _validAttachmentId.hasMatch(id);

/// Lee una fila de adjunto con tolerancia (spec 016, CA-016-25, T-7): una base
/// de datos restaurada o manipulada puede traer un tipo u origen que esta
/// versión no conoce, medidas absurdas (0, negativas, enormes) o un id que no
/// sirve de nombre de carpeta (`../x`, de más de 64 caracteres). Nunca lanza:
/// la fila se lee como una imagen sin archivos con la marca
/// [Attachment.unreadable] y medidas 1 × 1 (ningún diseño divide por cero), y
/// la tarea entera se ve como "Adjunto no disponible"
/// ([AttachmentGroup.isValidGroup]). Los dos repositorios usan esta función,
/// así que leen igual.
Attachment readAttachment({
  required String id,
  required String kind,
  required String origin,
  required String mime,
  required int byteSize,
  required int? width,
  required int? height,
  required DateTime createdAt,
  String? originalName,
  int? pageCount,
  String? url,
}) {
  final kindValue = AttachmentKind.values.asNameMap()[kind];
  final originValue = AttachmentOrigin.values.asNameMap()[origin];
  final w = width ?? 0;
  final h = height ?? 0;
  final known = kindValue != null && originValue != null;
  // Solo las imágenes tienen medidas que el diseño usa (una web no tiene; las
  // de un PDF son las de su primera página). Cada lado se acota antes de
  // multiplicar: dos lados enormes desbordarían el producto.
  final badSize =
      kindValue == AttachmentKind.image &&
      (w < 1 ||
          h < 1 ||
          w > ImageLimits.maxPixels ||
          h > ImageLimits.maxPixels ||
          w * h > ImageLimits.maxPixels);
  if (!known || badSize || !isValidAttachmentId(id)) {
    return Attachment(
      id: id,
      kind: AttachmentKind.image,
      origin: originValue ?? AttachmentOrigin.gallery,
      mime: mime,
      byteSize: byteSize < 0 ? 0 : byteSize,
      width: 1,
      height: 1,
      createdAt: createdAt,
      unreadable: true,
    );
  }
  return Attachment(
    id: id,
    kind: kindValue,
    origin: originValue,
    mime: mime,
    byteSize: byteSize,
    width: w,
    height: h,
    createdAt: createdAt,
    originalName: originalName,
    pageCount: pageCount,
    url: url,
  );
}
