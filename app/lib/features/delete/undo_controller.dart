import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/task.dart';
import '../../domain/ports/accessibility_timeouts.dart';
import '../../domain/services/attachment_janitor.dart';
import '../../domain/services/undo_countdown.dart';
import '../../domain/services/undo_duration.dart';

/// Pantalla en la que se eliminó, que es donde se ve la card (CA-014-07): la
/// principal (tarea actual o "Todo hecho.") o el listado.
enum UndoHost { home, list }

/// Estados de una eliminación que se puede deshacer (plan §4):
/// - `none`: no hay ninguna;
/// - `crumpling`: guardada, con la nota arrugándose; la card aún no se ve
///   (solo la pantalla principal);
/// - `visible`: se ve la card;
/// - `restoring`: se está recuperando;
/// - `failed`: no se pudo recuperar; se ve el aviso con "Reintentar".
enum UndoPhase { none, crumpling, visible, restoring, failed }

/// Qué foco detiene el tiempo (CA-014-17): el del lector o el del teclado.
enum UndoFocus { reader, keyboard }

@immutable
class UndoState {
  const UndoState.none({this.serial = 0})
    : phase = UndoPhase.none,
      task = null,
      host = null,
      returnTo = null;

  const UndoState._(
    this.phase, {
    required Task this.task,
    required UndoHost this.host,
    required this.returnTo,
    required this.serial,
  });

  final UndoPhase phase;

  /// La tarea eliminada, tal como estaba en la BD (etiqueta y color de la
  /// card). Null sin eliminación pendiente.
  final Task? task;

  /// Dónde se ve la card.
  final UndoHost? host;

  /// Al deshacer desde "Todo hecho." tras eliminar la última desde el
  /// listado, se vuelve a él (CA-014-10).
  final UndoHost? returnTo;

  /// Número de la eliminación: cambia con cada una (CA-014-08). La card lo
  /// devuelve en [UndoController.cardShown] y [UndoController.focusChanged]
  /// para que no cuente lo que llega tarde de la anterior.
  final int serial;

  bool get cardVisible => phase == UndoPhase.visible;

  UndoState _copyWith(UndoPhase phase) => UndoState._(
    phase,
    task: task!,
    host: host!,
    returnTo: returnTo,
    serial: serial,
  );
}

/// Resultado de [UndoController.undo].
sealed class UndoOutcome {
  const UndoOutcome();
}

/// La tarea ha vuelto a su sitio (CA-014-09): quien la muestra lleva el foco y
/// hace el anuncio (CA-014-18).
final class Restored extends UndoOutcome {
  const Restored(this.task, {required this.host, this.returnTo});

  final Task task;
  final UndoHost host;
  final UndoHost? returnTo;
}

/// No se pudo recuperar (CA-014-23): el aviso dice si fue por falta de
/// espacio. El error no se guarda: su texto puede llevar el de la tarea.
final class UndoFailed extends UndoOutcome {
  const UndoFailed({required this.noSpace});

  final bool noSpace;
}

/// La única eliminación que se puede deshacer (spec 014, ADR-0021). Sin
/// `autoDispose`: vive lo que la app. Ninguna lógica de UI: la card, su
/// sitio y el foco son de las pantallas.
final undoProvider = NotifierProvider<UndoController, UndoState>(
  UndoController.new,
);

/// Cuántas tareas se han recuperado con "Deshacer" (CA-014-10): la pantalla
/// principal lo añade a la clave de su `AnimatedSwitcher` para que la tarea
/// recuperada aparezca **sin fundido**, como el arrugado con `generation`.
final undoRestorationsProvider = NotifierProvider<UndoRestorations, int>(
  UndoRestorations.new,
);

class UndoRestorations extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// La fila de la tarea sale de la BD al guardar la eliminación y sus archivos
/// esperan retenidos ([AttachmentJanitor.hold]); la eliminación es
/// **definitiva** cuando la card desaparece por cualquier causa ([commit]):
/// entonces se borran. Si la app muere, el barrido del siguiente arranque los
/// recoge (CA-014-13).
///
/// Nada de lo que hace lanza ni registra: el texto de un error (de SQLite, del
/// disco) puede llevar el de la tarea (P5).
class UndoController extends Notifier<UndoState> {
  /// La eliminada y el servicio que borra sus archivos (se guarda con ella:
  /// al cerrar la app no se puede leer ningún proveedor).
  Task? _task;
  AttachmentJanitor? _janitor;
  int _serial = 0;

  /// Aumenta cada vez que la app pasa a segundo plano ([appHidden]).
  int _epoch = 0;

  UndoCountdown? _countdown;
  Timer? _timer;

  /// Desde cuándo se ve la card: guarda de 350 ms (CL-014-3).
  DateTime? _visibleSince;

  // Estado del foco, de cero con cada eliminación (plan §4).
  bool _shown = false;
  bool _screenReader = false;
  bool _readerSeen = false;
  bool _readerFocused = false;
  bool _keyboardFocused = false;
  bool _listeningHighlight = false;

  bool _restoring = false;
  bool _commitPending = false;

  /// Guarda de navegación de un solo uso ([guardNavigation]).
  Route<dynamic>? _guarded;

  @override
  UndoState build() {
    ref.onDispose(_dispose);
    return const UndoState.none();
  }

  /// Se lee al empezar una eliminación y se pasa a [hold]: si la app pasa a
  /// segundo plano mientras se guarda, la eliminación es definitiva sin card
  /// (CA-014-11, CL-014-15).
  int get epoch => _epoch;

  /// Lo que queda de la card, de 1 (llena) a 0: la barra de tiempo
  /// (CA-014-03). Se lee en cada fotograma; no forma parte del estado.
  double get fraction => _countdown?.fraction ?? 0;

  /// La eliminación de [task] ya está guardada: sus archivos siguen retenidos
  /// hasta que sea definitiva. Hace antes definitiva la anterior, si la hay
  /// (CA-014-08). [epoch] es el de antes de guardar: si la app ha pasado a
  /// segundo plano desde entonces o está oculta ahora, es definitiva al
  /// momento, sin card (devuelve false).
  ///
  /// Desde la pantalla principal ([UndoHost.home] sin [returnTo]), la card
  /// espera al final del arrugado ([show]); desde el listado (o al ir a "Todo
  /// hecho." tras eliminar allí la última), se ve ya.
  bool hold(
    Task task, {
    required UndoHost host,
    required int epoch,
    UndoHost? returnTo,
  }) {
    commit();
    final janitor = ref.read(attachmentJanitorProvider);
    if (epoch != _epoch || _appHidden) {
      _discard(task, janitor);
      return false;
    }
    // Una recuperación en curso de la anterior sigue con sus propios datos
    // (ver [undo]).
    _timer?.cancel();
    _timer = null;
    _restoring = false;
    _commitPending = false;
    _resetFocus();
    _serial++;
    _task = task;
    _janitor = janitor;
    _countdown = UndoCountdown(
      clock: ref.read(clockProvider),
      total: UnaMotion.undoWindow,
    );
    final crumple = host == UndoHost.home && returnTo == null;
    _visibleSince = crumple ? null : _now();
    state = UndoState._(
      crumple ? UndoPhase.crumpling : UndoPhase.visible,
      task: task,
      host: host,
      returnTo: returnTo,
      serial: _serial,
    );
    unawaited(_readDuration(_serial));
    return true;
  }

  /// Fin del arrugado: se ve la card (CA-014-01). Si algo la hizo definitiva
  /// mientras tanto, ya no aparece.
  void show() {
    if (state.phase != UndoPhase.crumpling) return;
    _visibleSince = _now();
    state = state._copyWith(UndoPhase.visible);
  }

  /// La card número [serial] ya se ha dibujado (tras su primer fotograma).
  /// Con el lector ([screenReader]), el tiempo espera a su primer foco; si
  /// no, empieza (CA-014-17). Solo cuenta la primera vez.
  void cardShown(int serial, {required bool screenReader}) {
    if (!_isCurrent(serial) || _shown) return;
    _shown = true;
    _screenReader = screenReader;
    _sync();
  }

  /// El foco del lector o el del teclado entra en la card número [serial] o
  /// sale de ella: mientras está, el tiempo no corre (CA-014-17). El del
  /// teclado solo cuenta mientras se ve (modo tradicional): tocar la pantalla
  /// lo reanuda aunque siga ahí.
  void focusChanged(int serial, UndoFocus source, {required bool focused}) {
    if (!_isCurrent(serial)) return;
    switch (source) {
      case UndoFocus.reader:
        _readerFocused = focused;
        if (focused) _readerSeen = true;
      case UndoFocus.keyboard:
        _keyboardFocused = focused;
        if (focused) _listenHighlight();
    }
    _sync();
  }

  /// El lector se ha apagado con la card a la vista: el aviso de que pierde el
  /// foco puede no llegar, así que el tiempo sigue (o empieza, si esperaba su
  /// primer foco).
  void screenReaderChanged({required bool enabled}) {
    if (enabled || state.phase != UndoPhase.visible) return;
    _screenReader = false;
    _readerFocused = false;
    _sync();
  }

  /// La eliminación pasa a ser definitiva (CA-014-11, CA-014-15): la card
  /// desaparece **ya**, se suelta la tarea y sus archivos se borran aparte,
  /// sin esperar al disco. Idempotente. Durante una recuperación solo se
  /// anota: si falla, será definitiva sin aviso.
  void commit() {
    switch (state.phase) {
      case UndoPhase.none:
        return;
      case UndoPhase.restoring:
        _commitPending = true;
      case UndoPhase.crumpling || UndoPhase.visible || UndoPhase.failed:
        _finalize();
        state = UndoState.none(serial: _serial);
    }
  }

  /// "Deshacer" o "Reintentar" (CA-014-09, CA-014-23): vuelve a guardar la
  /// tarea en su sitio. Solo con la card a la vista (pasados 350 ms desde que
  /// apareció, CL-014-3) o con el aviso de error, y una sola vez a la vez.
  /// Devuelve null si no hace nada o si algo la hizo definitiva mientras
  /// tanto.
  Future<UndoOutcome?> undo() async {
    final phase = state.phase;
    if (phase != UndoPhase.visible && phase != UndoPhase.failed) return null;
    if (phase == UndoPhase.visible && _tooEarly) return null;
    final task = _task!;
    final janitor = _janitor!;
    final serial = _serial;
    final host = state.host!;
    final returnTo = state.returnTo;
    _timer?.cancel();
    _timer = null;
    _countdown?.pause();
    _restoring = true;
    _commitPending = false;
    state = state._copyWith(UndoPhase.restoring);
    Object? error;
    try {
      await ref.read(restoreDeletedTaskProvider).call(task);
    } on Object catch (e) {
      error = e;
    }
    if (!ref.mounted) return null;
    final restored = Restored(task, host: host, returnTo: returnTo);
    if (serial != _serial) {
      // Otra eliminación ha llegado mientras se recuperaba: esta ya no tiene
      // card ni aviso.
      if (error != null) _discard(task, janitor);
      return error == null ? restored : null;
    }
    _restoring = false;
    if (error == null) {
      _clear();
      state = UndoState.none(serial: serial);
      return restored;
    }
    if (_commitPending) {
      _finalize();
      state = UndoState.none(serial: serial);
      return null;
    }
    state = state._copyWith(UndoPhase.failed);
    return UndoFailed(noSpace: isNoSpaceError(error));
  }

  /// La app pasa a segundo plano (`hidden`; `inactive` no cuenta, CA-014-12):
  /// la eliminación es definitiva, también la que aún se está guardando
  /// (CA-014-11).
  void appHidden() {
    _epoch++;
    commit();
  }

  /// Navegación propia que no hace definitiva la eliminación: ir a "Todo
  /// hecho." al eliminar la última desde el listado, o volver a él al
  /// deshacer (CA-014-10). La guarda vale solo para [route] y para una vez;
  /// se quita al acabar [navigate], aunque falle.
  T guardNavigation<T>(Route<dynamic> route, T Function() navigate) {
    _guarded = route;
    try {
      return navigate();
    } finally {
      if (identical(_guarded, route)) _guarded = null;
    }
  }

  /// Se ha ido a otra pantalla (`UndoNavigationObserver`): definitiva
  /// (CA-014-07), salvo la navegación guardada.
  void pageNavigated(Route<dynamic> route) {
    if (identical(route, _guarded)) {
      _guarded = null;
      return;
    }
    commit();
  }

  bool _isCurrent(int serial) =>
      serial == _serial && state.phase == UndoPhase.visible;

  DateTime _now() => ref.read(clockProvider).now();

  bool get _tooEarly {
    final since = _visibleSince;
    return since != null &&
        _now().difference(since) < UnaMotion.doubleTapWindow;
  }

  static bool get _appHidden =>
      switch (WidgetsBinding.instance.lifecycleState) {
        AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached => true,
        _ => false,
      };

  /// El "Tiempo para actuar" del sistema llega después de empezar: solo
  /// alarga (CA-014-06). Sin canal o con un error, 4 s.
  Future<void> _readDuration(int serial) async {
    final SystemTimeouts timeouts;
    try {
      timeouts = await ref.read(accessibilityTimeoutsProvider).read();
    } on Object {
      return;
    }
    if (!ref.mounted || serial != _serial) return;
    const rule = UndoDuration(
      base: UnaMotion.undoWindow,
      legacyA11y: UnaMotion.undoWindowLegacyA11y,
      max: UnaMotion.undoWindowMax,
    );
    _countdown?.extendTo(rule(timeouts));
    _sync();
  }

  /// Pone en marcha o detiene la cuenta según la card y el foco.
  void _sync() {
    _timer?.cancel();
    _timer = null;
    final countdown = _countdown;
    if (countdown == null || state.phase != UndoPhase.visible) return;
    final waitsForReader = _screenReader && !_readerSeen;
    final run =
        _shown && !waitsForReader && !_readerFocused && !_keyboardPauses;
    if (!run) {
      countdown.pause();
      return;
    }
    countdown.resume();
    _timer = Timer(countdown.remaining, _onTimer);
  }

  void _onTimer() {
    _timer = null;
    final countdown = _countdown;
    if (countdown == null || state.phase != UndoPhase.visible) return;
    if (countdown.expired) {
      commit();
    } else {
      _sync();
    }
  }

  bool get _keyboardPauses =>
      _keyboardFocused &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _listenHighlight() {
    if (_listeningHighlight) return;
    _listeningHighlight = true;
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  void _onHighlightModeChanged(FocusHighlightMode _) {
    if (_keyboardFocused) _sync();
  }

  void _resetFocus() {
    _shown = false;
    _screenReader = false;
    _readerSeen = false;
    _readerFocused = false;
    _keyboardFocused = false;
  }

  /// Suelta la tarea sin borrar nada (recuperada).
  void _clear() {
    _timer?.cancel();
    _timer = null;
    _task = null;
    _janitor = null;
    _countdown = null;
    _visibleSince = null;
    _restoring = false;
    _commitPending = false;
    _resetFocus();
  }

  /// Suelta la tarea y borra sus archivos: definitiva.
  void _finalize() {
    final task = _task;
    final janitor = _janitor;
    _clear();
    if (task != null && janitor != null) _discard(task, janitor);
  }

  /// Borra los archivos retenidos de [task], aparte y sin lanzar (si falla,
  /// los recoge el barrido del siguiente arranque).
  static void _discard(Task task, AttachmentJanitor janitor) {
    final attachment = task.attachment;
    if (attachment == null) return;
    unawaited(_discardQuietly(janitor, attachment.id));
  }

  static Future<void> _discardQuietly(
    AttachmentJanitor janitor,
    String id,
  ) async {
    try {
      await janitor.discardHeld(id);
    } on Object {
      // Sin registro: lo recoge el barrido.
    }
  }

  /// La app se cierra: una eliminación pendiente es definitiva (sin tocar el
  /// estado, que ya no se puede cambiar). Durante una recuperación, no: puede
  /// que la fila ya esté de vuelta; si no, el barrido del siguiente arranque
  /// recoge los archivos.
  void _dispose() {
    _timer?.cancel();
    _timer = null;
    if (_listeningHighlight) {
      FocusManager.instance.removeHighlightModeListener(
        _onHighlightModeChanged,
      );
    }
    if (_restoring) {
      _clear();
    } else {
      _finalize();
    }
  }
}

/// Ir a otra pantalla hace definitiva la eliminación (CA-014-07, CA-014-11):
/// cualquier `push`, `pop`, `remove` o `replace` de una [PageRoute] (listado,
/// editor, "Configuración y perfil" y la vuelta desde el listado). Las hojas
/// (`PopupRoute`: el menú, "Mover", la confirmación de un enlace) no cuentan.
/// Así no hay que acordarse de llamar a `commit` en cada pantalla nueva.
class UndoNavigationObserver extends NavigatorObserver {
  UndoNavigationObserver(this._undo);

  final UndoController Function() _undo;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // La primera ruta, al montar la app, no es ir a otra pantalla.
    if (previousRoute != null) _navigated(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _navigated(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _navigated(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _navigated(newRoute is PageRoute ? newRoute : oldRoute);

  void _navigated(Route<dynamic>? route) {
    if (route is PageRoute) _undo().pageNavigated(route);
  }
}
