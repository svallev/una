import '../entities/attachment.dart';
import '../entities/image_type.dart';
import '../entities/staged_attachment.dart';

export '../entities/staged_attachment.dart';

/// Imagen elegida en el selector o hecha con la cámara, aún sin copiar.
/// [token] es opaco: solo lo entiende el importador que lo creó.
typedef PickedImage = ({String token, AttachmentOrigin origin});

/// Lo que devuelve el selector múltiple (spec 016): como mucho `max` imágenes
/// (el tope se aplica **antes** de abrir o copiar ninguna) y [total], lo que
/// devolvió el sistema, para avisar de que se recortó (CA-016-02).
typedef PickedImages = ({List<PickedImage> items, int total});

/// Archivo copiado a la zona de preparación: tamaño y primeros bytes, para
/// decidir el tipo por el contenido.
typedef CopiedImage = ({int byteSize, List<int> head});

/// Por qué no se ha podido importar (spec 007 §5).
enum ImageImportError {
  unsupportedType,
  tooLarge,
  tooManyPixels,
  unreadable,
  noCamera,
  noSpace,
}

/// Un fallo de importación. **Solo lleva el código**: nunca la excepción
/// original ni su pila, que pueden traer rutas, nombres o direcciones de las
/// fotos (CL-016-16).
class ImageImportFailure implements Exception {
  const ImageImportFailure(this.error);
  final ImageImportError error;
  @override
  String toString() => 'ImageImportFailure(${error.name})';
}

/// La importación se canceló (el usuario o el tiempo máximo).
class ImageImportCancelled implements Exception {
  const ImageImportCancelled();
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

  /// Abre el selector del sistema para elegir **varias** imágenes (spec 016,
  /// CA-016-02): [max] como mucho; el resto ni se abre ni se toca. Sin pedir
  /// permisos. Devuelve null si el usuario cancela. Lanza [ImageImportFailure].
  Future<PickedImages?> pickMany({required int max});

  /// Bytes libres en la partición donde se guardan las fotos, o null si no se
  /// sabe (entonces no se bloquea la importación, CL-016-6).
  Future<int?> freeSpace();

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

  /// Rehace la versión de pantalla y la miniatura del adjunto **guardado**
  /// [attachment] desde su versión completa (CA-007-19). Lanza
  /// [ImageImportFailure] si la completa falta o no se puede leer.
  Future<void> regenerateDerived(Attachment attachment);
}
