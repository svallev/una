import '../entities/attachment.dart';
import '../entities/image_type.dart';

/// Imagen elegida en el selector o hecha con la cámara, aún sin copiar.
/// [token] es opaco: solo lo entiende el importador que lo creó.
typedef PickedImage = ({String token, AttachmentOrigin origin});

/// Archivo copiado a la zona de preparación: tamaño y primeros bytes, para
/// decidir el tipo por el contenido.
typedef CopiedImage = ({int byteSize, List<int> head});

/// Imagen ya limpia en la zona de preparación (versión completa en teselas,
/// versión de pantalla y miniatura), lista para guardarse con la tarea.
typedef StagedImage = ({
  String id,
  AttachmentOrigin origin,
  int width,
  int height,
  int byteSize,
});

/// Por qué no se ha podido importar (spec 007 §5).
enum ImageImportError {
  unsupportedType,
  tooLarge,
  tooManyPixels,
  unreadable,
  noCamera,
  noSpace,
}

class ImageImportFailure implements Exception {
  const ImageImportFailure(this.error);
  final ImageImportError error;
  @override
  String toString() => 'ImageImportFailure(${error.name})';
}

/// Cámara, selector y limpieza de imágenes (canal nativo o navegador). Todo
/// lo que escribe va a la zona de preparación `<id>`; nunca fuera.
abstract interface class ImageImporter {
  /// ¿Se decodifica HEIC en este dispositivo? (Android 9+).
  bool get heicSupported;

  /// Abre la cámara o el selector del sistema, sin pedir permisos
  /// (CA-007-02/03). Lo que escriba la cámara va a la preparación [id].
  /// Devuelve null si el usuario cancela. Lanza [ImageImportFailure]
  /// (`noCamera`).
  Future<PickedImage?> pick(AttachmentOrigin origin, String id);

  /// Copia lo elegido a la preparación `<id>`, contando los bytes y abortando
  /// al pasar de [maxBytes] (CA-007-14). Lanza [ImageImportFailure].
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  });

  /// Recodifica la copia desde los píxeles: sin metadatos, orientada, en sRGB,
  /// reducida a [storedMaxPixels], con versión de pantalla y miniatura
  /// (CA-007-07). Rechaza más de [maxPixels] leyendo solo la cabecera.
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  });

  /// Aborta el trabajo en curso de `<id>` y borra su preparación.
  Future<void> cancel(String id);
}
