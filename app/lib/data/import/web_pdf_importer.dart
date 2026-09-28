import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'memory_pdf_importer.dart';
import 'pdf_engine.dart';

/// Importador de PDF de la web de pruebas (CL-008-12, ADR-0010): el selector
/// del navegador (`<input type=file>`, solo PDF) y la versión de pantalla con
/// un `canvas` a JPEG. PDFium es el WASM de los assets del paquete (nunca de un
/// CDN; T-008-01) y todo queda en memoria, como las tareas. Sin paquetes: solo
/// `dart:js_interop`, como `WebImageImporter`.
class WebPdfImporter extends MemoryPdfImporter {
  WebPdfImporter(super.store)
    : super(pickFile: _pick, encodeJpeg: _encode, screenWidthPx: _screenWidth);

  static const _screenQuality = 0.85;

  /// Si el navegador no avisa de la cancelación (evento `cancel`), se da por
  /// cancelada este tiempo después de que la ventana recupere el foco.
  static const _focusGrace = Duration(seconds: 1);

  static Future<PickedBytes?> _pick() async {
    final input = _document.createElement('input') as _Input
      ..type = 'file'
      ..accept = 'application/pdf,.pdf';
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
      return (name: file.name, size: file.size, read: () => _bytes(file));
    } finally {
      grace?.cancel();
      _window.removeEventListener('focus', onFocus);
      input.remove();
    }
  }

  /// Ancho de la pantalla en vertical, en píxeles físicos (como en Android).
  static int _screenWidth() {
    final dpr = _window.devicePixelRatio;
    final a = (_window.screen.width * dpr).round();
    final b = (_window.screen.height * dpr).round();
    return math.max(1, math.min(a, b));
  }

  static Future<Uint8List> _bytes(_Blob blob) async =>
      (await blob.arrayBuffer().toDart).toDart.asUint8List();

  /// Los píxeles BGRA de PDFium, a RGBA en un `canvas` y de ahí a JPEG (sin
  /// metadatos). El fondo ya es blanco.
  static Future<Uint8List> _encode(RenderedPage page) async {
    final rgba = Uint8ClampedList(page.bgra.length);
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      rgba[i] = page.bgra[i + 2];
      rgba[i + 1] = page.bgra[i + 1];
      rgba[i + 2] = page.bgra[i];
      rgba[i + 3] = page.bgra[i + 3];
    }
    final canvas = _document.createElement('canvas') as _Canvas
      ..width = page.width
      ..height = page.height;
    try {
      final ctx = canvas.getContext('2d');
      if (ctx == null) throw StateError('Sin canvas 2D');
      ctx.putImageData(_ImageData(rgba.toJS, page.width, page.height), 0, 0);
      final blob = Completer<_Blob?>();
      canvas.toBlob(
        ((_Blob? b) => blob.complete(b)).toJS,
        'image/jpeg',
        _screenQuality.toJS,
      );
      final out = await blob.future;
      if (out == null) throw StateError('toBlob sin resultado');
      return await _bytes(out);
    } finally {
      // Libera la memoria del canvas enseguida.
      canvas
        ..width = 0
        ..height = 0;
    }
  }
}

// ---------------------------------------------------------------------------
// Lo mínimo del DOM, sin `package:web` (sin dependencias nuevas).

@JS('document')
external _Document get _document;

@JS('window')
external _Window get _window;

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

extension type _Blob._(JSObject _) implements JSObject {
  external int get size;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _File._(JSObject _) implements _Blob {
  external String get name;
}

@JS('ImageData')
extension type _ImageData._(JSObject _) implements JSObject {
  external factory _ImageData(JSUint8ClampedArray data, int width, int height);
}

extension type _Canvas._(JSObject _) implements _Element {
  external set width(int value);
  external set height(int value);
  external _Context2D? getContext(String type);
  external void toBlob(JSFunction callback, String type, JSNumber quality);
}

extension type _Context2D._(JSObject _) implements JSObject {
  external void putImageData(_ImageData data, num dx, num dy);
}
