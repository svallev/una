import 'dart:async';
import 'dart:io';

/// Borra las cookies, el almacenamiento web y la caché de la WebView
/// (`ChannelWebViewHardening`). `true` si se ha borrado.
abstract interface class WebDataCleaner {
  Future<bool> clearWebData({int? webViewId});
}

/// Nada de la página se queda en el móvil (CA-009-13, ADR-0016):
///
/// - [clearOnLeave]: al salir de la tarea web (otra pantalla, otra tarea,
///   completar, eliminar) se borran cookies, almacenamiento web y caché;
/// - [markUsed]: antes de cargar una página se escribe la marca
///   `files/web_used`, vacía;
/// - [clearAfterLaunch]: si la app se cerró sin borrar, **después del primer
///   fotograma** del arranque siguiente se borra lo mismo, solo si existe la
///   marca (no cuesta nada a quien no usa la web), y se quita la marca.
///
/// La marca no se quita al salir de la tarea: el borrado de la WebView es
/// asíncrono y podría no haber llegado al disco si la app se cierra justo
/// después; el arranque siguiente lo repite una vez.
///
/// Todo va de uno en uno y en orden: una página no empieza a usarse hasta que
/// acaba la limpieza del arranque. Nada lanza ni se registra (CL-009-9): si un
/// borrado falla, la marca se queda y se repite en el siguiente arranque.
class WebDataJanitor {
  WebDataJanitor({
    required Future<Directory> Function() this._filesDir,
    required WebDataCleaner this._cleaner,
  });

  /// Sin WebView (web de pruebas, CL-009-5): no hace nada.
  WebDataJanitor.inactive() : _filesDir = null, _cleaner = null;

  /// En `files/` (`getApplicationSupportDirectory`): fuera de la copia en la
  /// nube, sin contenido.
  static const markerName = 'web_used';

  final Future<Directory> Function()? _filesDir;
  final WebDataCleaner? _cleaner;
  Future<void> _last = Future.value();

  /// Escribe la marca (si no estaba). Se espera antes de cargar una página.
  Future<void> markUsed() => _serial(() async {
    final marker = await _marker();
    if (marker != null && !marker.existsSync()) {
      await marker.create(recursive: true);
    }
  });

  /// Borra los datos de todas las páginas; [webViewId], la WebView que se
  /// estaba viendo, si sigue viva. `true` si se ha borrado (o no hay WebView).
  Future<bool> clearOnLeave({int? webViewId}) async {
    var cleared = true;
    await _serial(() async {
      cleared = await _clear(webViewId);
    });
    return cleared;
  }

  /// Con la marca: borra y, si ha ido bien, quita la marca.
  Future<void> clearAfterLaunch() => _serial(() async {
    final marker = await _marker();
    if (marker == null || !marker.existsSync()) return;
    if (await _clear(null)) await marker.delete();
  });

  Future<bool> _clear(int? webViewId) async {
    final cleaner = _cleaner;
    if (cleaner == null) return true;
    try {
      return await cleaner.clearWebData(webViewId: webViewId);
    } on Object {
      return false;
    }
  }

  Future<File?> _marker() async {
    final filesDir = _filesDir;
    if (filesDir == null) return null;
    try {
      return File('${(await filesDir()).path}/$markerName');
    } on Object {
      return null;
    }
  }

  /// Encadena [task] tras la anterior; sus errores no se propagan.
  Future<void> _serial(Future<void> Function() task) {
    final next = _last.then((_) async {
      try {
        await task();
      } on Object {
        // Sin registrar nada: con la marca, se repite en el siguiente arranque.
      }
    });
    _last = next;
    return next;
  }
}
