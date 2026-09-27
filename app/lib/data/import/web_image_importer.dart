import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/entities/attachment.dart';
import '../../domain/entities/image_type.dart';
import '../../domain/ports/image_importer.dart';
import '../attachments/memory_attachment_store.dart';
import 'image_geometry.dart';

/// Importador de la web de pruebas (CL-007-12, ADR-0010): el selector del
/// navegador (`<input type=file>`, con `capture` para "Hacer foto") y la
/// limpieza con `createImageBitmap` + `canvas` a JPEG. Todo queda en memoria,
/// como las tareas. Sin paquetes: solo `dart:js_interop`.
///
/// Igual que en Android: el tipo se decide por el contenido, las dimensiones
/// se leen de la cabecera antes de decodificar, el original no se guarda
/// (solo los píxeles recodificados, sin metadatos) y la transparencia queda
/// sobre blanco (CL-007-4).
class WebImageImporter implements ImageImporter {
  WebImageImporter(this.store);

  final MemoryAttachmentStore store;

  static const _source = 'source';
  static const _fullQuality = 0.9;
  static const _screenQuality = 0.85;
  static const _thumbQuality = 0.8;

  /// Si el navegador no avisa de la cancelación (evento `cancel`), se da por
  /// cancelada este tiempo después de que la ventana recupere el foco.
  static const _focusGrace = Duration(seconds: 1);

  final _files = <String, _File>{};
  final _cancelled = <String>{};
  var _nextToken = 0;

  /// Los navegadores no decodifican HEIC (salvo Safari): no se admite.
  @override
  bool get heicSupported => false;

  @override
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) async {
    final input = _document.createElement('input') as _Input
      ..type = 'file'
      ..accept = 'image/*';
    if (origin == AttachmentOrigin.camera) {
      input.setAttribute('capture', 'environment');
    }
    input.style.display = 'none';
    _document.body?.appendChild(input);

    final done = Completer<_File?>();
    void finish(_File? file) {
      if (!done.isCompleted) done.complete(file);
    }

    final onChange = ((JSAny _) {
      final files = input.files;
      finish(files != null && files.length > 0 ? files.item(0) : null);
    }).toJS;
    final onCancel = ((JSAny _) => finish(null)).toJS;
    Timer? grace;
    final onFocus = ((JSAny _) {
      grace?.cancel();
      grace = Timer(_focusGrace, () => finish(null));
    }).toJS;
    input
      ..addEventListener('change', onChange)
      ..addEventListener('cancel', onCancel);
    _window.addEventListener('focus', onFocus);
    try {
      input.click();
      final file = await done.future;
      if (file == null) return null;
      final token = 'web:${_nextToken++}';
      _files[token] = file;
      return (token: token, origin: origin);
    } finally {
      grace?.cancel();
      _window.removeEventListener('focus', onFocus);
      input.remove();
    }
  }

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) async {
    final file = _files.remove(picked.token);
    if (file == null) {
      throw const ImageImportFailure(ImageImportError.unreadable);
    }
    if (file.size > maxBytes) {
      throw const ImageImportFailure(ImageImportError.tooLarge);
    }
    final bytes = await _guard(() => _bytes(file));
    _checkCancelled(id);
    if (bytes.length > maxBytes) {
      throw const ImageImportFailure(ImageImportError.tooLarge);
    }
    store.putStaging(id, _source, bytes);
    return (
      byteSize: bytes.length,
      head: bytes.sublist(0, math.min(bytes.length, ImageLimits.headBytes)),
    );
  }

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) async {
    final bytes = store.stagingBytes(id, _source);
    if (bytes == null) {
      throw const ImageImportFailure(ImageImportError.unreadable);
    }
    try {
      final header = readImageSize(bytes, type);
      if (header == null) {
        throw const ImageImportFailure(ImageImportError.unreadable);
      }
      if (header.width * header.height > maxPixels) {
        throw const ImageImportFailure(ImageImportError.tooManyPixels);
      }
      final bitmap = await _guard(() => _decode(bytes, type));
      try {
        _checkCancelled(id);
        // Ya orientada (EXIF): puede tener los lados cambiados.
        final stored = storedImageSize(
          bitmap.width,
          bitmap.height,
          storedMaxPixels,
        );
        final k = stored.width / bitmap.width;
        final tiles = ImageTiles(stored.width, stored.height);
        var byteSize = 0;
        for (var r = 0; r < tiles.rows; r++) {
          for (var c = 0; c < tiles.columns; c++) {
            final t = tiles.rect(r, c);
            final jpeg = await _guard(
              () => _encode(
                t.width,
                t.height,
                _fullQuality,
                (ctx) => ctx.drawImage(
                  bitmap,
                  t.left / k,
                  t.top / k,
                  t.width / k,
                  t.height / k,
                  0,
                  0,
                  t.width,
                  t.height,
                ),
              ),
            );
            _checkCancelled(id);
            store.putStaging(id, ImageTiles.fileName(r, c), jpeg);
            byteSize += jpeg.length;
          }
        }
        Future<Uint8List> derived(
          int w,
          int h,
          double quality, {
          bool fitWidth = false,
        }) {
          final out = (fitWidth ? fitWidthCrop : coverCrop)(
            stored.width,
            stored.height,
            w,
            h,
          );
          final crop = out.crop;
          return _guard(
            () => _encode(
              out.width,
              out.height,
              quality,
              (ctx) => ctx.drawImage(
                bitmap,
                crop.left / k,
                crop.top / k,
                crop.width / k,
                crop.height / k,
                0,
                0,
                out.width,
                out.height,
              ),
            ),
          );
        }

        final screen = _screenSize();
        final screenJpeg = await derived(
          screen.width,
          screen.height,
          _screenQuality,
          fitWidth: true,
        );
        final thumbJpeg = await derived(
          ImageLimits.thumbShortSide,
          ImageLimits.thumbShortSide,
          _thumbQuality,
        );
        _checkCancelled(id);
        store
          ..putStaging(id, 'screen.jpg', screenJpeg)
          ..putStaging(id, 'thumb.jpg', thumbJpeg);
        return StagedImage(
          id: id,
          origin: origin,
          width: stored.width,
          height: stored.height,
          byteSize: byteSize,
        );
      } finally {
        bitmap.close();
      }
    } finally {
      // No se conserva ningún byte del original.
      store.removeStaging(id, _source);
    }
  }

  @override
  Future<void> regenerateDerived(Attachment attachment) async {
    final tiles = attachment.tiles;
    final decoded = <(PixelRect, _ImageBitmap)>[];
    try {
      for (var r = 0; r < tiles.rows; r++) {
        for (var c = 0; c < tiles.columns; c++) {
          final bytes = store.bytes(
            '${attachment.dir}/${ImageTiles.fileName(r, c)}',
          );
          if (bytes == null || bytes.isEmpty) {
            throw const ImageImportFailure(ImageImportError.unreadable);
          }
          final bitmap = await _guard(() => _decode(bytes, ImageType.jpeg));
          decoded.add((tiles.rect(r, c), bitmap));
        }
      }
      Future<Uint8List> derived(
        int w,
        int h,
        double quality, {
        bool fitWidth = false,
      }) {
        final out = (fitWidth ? fitWidthCrop : coverCrop)(
          tiles.width,
          tiles.height,
          w,
          h,
        );
        final crop = out.crop;
        final s = out.width / crop.width;
        return _guard(
          () => _encode(out.width, out.height, quality, (ctx) {
            for (final (t, bitmap) in decoded) {
              ctx.drawImage(
                bitmap,
                0,
                0,
                t.width,
                t.height,
                (t.left - crop.left) * s,
                (t.top - crop.top) * s,
                t.width * s,
                t.height * s,
              );
            }
          }),
        );
      }

      final screen = _screenSize();
      final screenJpeg = await derived(
        screen.width,
        screen.height,
        _screenQuality,
        fitWidth: true,
      );
      final thumbJpeg = await derived(
        ImageLimits.thumbShortSide,
        ImageLimits.thumbShortSide,
        _thumbQuality,
      );
      store
        ..putStored(attachment.id, 'screen.jpg', screenJpeg)
        ..putStored(attachment.id, 'thumb.jpg', thumbJpeg);
    } finally {
      for (final (_, bitmap) in decoded) {
        bitmap.close();
      }
    }
  }

  @override
  Future<void> cancel(String id) async {
    _cancelled.add(id);
    await store.deleteStaging(id);
  }

  void _checkCancelled(String id) {
    if (_cancelled.remove(id)) throw const ImageImportCancelled();
  }

  /// Pantalla en vertical, en píxeles físicos (como en Android).
  static ({int width, int height}) _screenSize() {
    final dpr = _window.devicePixelRatio;
    final a = (_window.screen.width * dpr).round();
    final b = (_window.screen.height * dpr).round();
    return (
      width: math.max(1, math.min(a, b)),
      height: math.max(1, math.max(a, b)),
    );
  }

  static Future<Uint8List> _bytes(_Blob blob) async =>
      (await blob.arrayBuffer().toDart).toDart.asUint8List();

  /// Decodifica aplicando la orientación EXIF. Si el navegador no entiende la
  /// opción (anteriores a 2023, que ya la aplicaban), sin ella.
  static Future<_ImageBitmap> _decode(Uint8List bytes, ImageType type) async {
    final blob = _Blob(
      <JSAny>[bytes.toJS].toJS,
      _BlobOptions(type: 'image/${type.name}'),
    );
    try {
      return await _createImageBitmap(
        blob,
        _BitmapOptions(imageOrientation: 'from-image'),
      ).toDart;
    } on Object {
      return _createImageBitmap(blob).toDart;
    }
  }

  /// Dibuja en un `canvas` blanco de [width] × [height] y lo codifica a JPEG
  /// (sin metadatos).
  static Future<Uint8List> _encode(
    int width,
    int height,
    double quality,
    void Function(_Context2D ctx) draw,
  ) async {
    final canvas = _document.createElement('canvas') as _Canvas
      ..width = width
      ..height = height;
    final ctx = canvas.getContext('2d');
    if (ctx == null) throw StateError('Sin canvas 2D');
    ctx
      ..fillStyle = 'white'
      ..fillRect(0, 0, width, height)
      ..imageSmoothingQuality = 'high';
    draw(ctx);
    final blob = Completer<_Blob?>();
    canvas.toBlob(
      ((_Blob? b) => blob.complete(b)).toJS,
      'image/jpeg',
      quality.toJS,
    );
    final out = await blob.future;
    // Libera la memoria del canvas enseguida.
    canvas
      ..width = 0
      ..height = 0;
    if (out == null) throw StateError('toBlob sin resultado');
    return _bytes(out);
  }

  /// Lo que falle en el navegador (decodificar, memoria, canvas) es una
  /// imagen que no se puede leer.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ImageImportFailure {
      rethrow;
    } on ImageImportCancelled {
      rethrow;
    } on Object {
      throw const ImageImportFailure(ImageImportError.unreadable);
    }
  }
}

// ---------------------------------------------------------------------------
// Lo mínimo del DOM, sin `package:web` (sin dependencias nuevas).

@JS('document')
external _Document get _document;

@JS('window')
external _Window get _window;

@JS('createImageBitmap')
external JSPromise<_ImageBitmap> _createImageBitmap(
  _Blob image, [
  _BitmapOptions options,
]);

extension type _Document._(JSObject _) implements JSObject {
  external _Element createElement(String tag);
  external _Element? get body;
}

extension type _Window._(JSObject _) implements _EventTarget {
  external double get devicePixelRatio;
  external _Screen get screen;
}

extension type _Screen._(JSObject _) implements JSObject {
  external int get width;
  external int get height;
}

extension type _EventTarget._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _Element._(JSObject _) implements _EventTarget {
  external void setAttribute(String name, String value);
  external void appendChild(_Element child);
  external void remove();
  external void click();
  external _Style get style;
}

extension type _Style._(JSObject _) implements JSObject {
  external set display(String value);
}

extension type _Input._(JSObject _) implements _Element {
  external set type(String value);
  external set accept(String value);
  external _FileList? get files;
}

extension type _FileList._(JSObject _) implements JSObject {
  external int get length;
  external _File? item(int index);
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, [_BlobOptions options]);
  external int get size;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _File._(JSObject _) implements _Blob {}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

extension type _BitmapOptions._(JSObject _) implements JSObject {
  external factory _BitmapOptions({String imageOrientation});
}

extension type _ImageBitmap._(JSObject _) implements JSObject {
  external int get width;
  external int get height;
  external void close();
}

extension type _Canvas._(JSObject _) implements _Element {
  external set width(int value);
  external set height(int value);
  external _Context2D? getContext(String type);
  external void toBlob(JSFunction callback, String type, JSNumber quality);
}

extension type _Context2D._(JSObject _) implements JSObject {
  external set fillStyle(String value);
  external set imageSmoothingQuality(String value);
  external void fillRect(num x, num y, num width, num height);
  external void drawImage(
    _ImageBitmap image,
    num sx,
    num sy,
    num sw,
    num sh,
    num dx,
    num dy,
    num dw,
    num dh,
  );
}
