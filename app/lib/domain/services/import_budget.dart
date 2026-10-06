import 'dart:async';

import '../entities/image_type.dart';
import '../ports/clock.dart';

/// Crea un temporizador periódico. Es la firma de `Timer.periodic`: los tests
/// inyectan uno a mano (spec 016, CA-016-04).
typedef PeriodicTimerFactory = Timer Function(
  Duration period,
  void Function(Timer timer) callback,
);

/// Qué límite se ha agotado.
enum BudgetExpiry {
  /// Los 20 s de la foto en curso (CA-007-14).
  photo,

  /// Los 2 minutos de todo el grupo (CA-016-04).
  total,
}

/// Presupuesto de tiempo de una importación (CA-007-14 y CA-016-04): **20 s por
/// foto y 2 minutos en total**, contados como **tiempo activo**.
///
/// Un latido de 1 s suma lo que ha pasado desde el anterior, como mucho 2 s
/// (`min(hueco, 2 s)`): si el proceso estuvo congelado (la app en segundo
/// plano, Doze), el reloj salta pero el presupuesto apenas gasta. Si el hueco
/// pasa de 3 s, además se **reinicia el tiempo de la foto en curso**: el
/// tiempo que se perdió no fue culpa de la foto. El total no se reinicia.
///
/// Un temporizador de Dart nunca vence antes de su periodo, así que el hueco se
/// toma como mínimo el periodo del latido: con un reloj que no avanza (o que
/// retrocede) el presupuesto sigue gastándose, y los tests con tiempo falso
/// vencen cuando toca.
///
/// Se usa para **una foto a la vez** ([runPhoto]); el grupo comparte un solo
/// presupuesto entre todas sus fotos. Dominio puro: el reloj y el temporizador
/// se inyectan.
class ImportBudget {
  ImportBudget({
    this._clock = const SystemClock(),
    PeriodicTimerFactory? periodic,
    this.photoLimit = ImageLimits.timeout,
    this.totalLimit = ImageLimits.groupTimeout,
  }) : _periodic = periodic ?? Timer.periodic;

  /// Cada cuánto late.
  static const heartbeat = Duration(seconds: 1);

  /// Lo máximo que suma un latido.
  static const maxStep = Duration(seconds: 2);

  /// A partir de este hueco entre latidos se da el proceso por congelado.
  static const freezeGap = Duration(seconds: 3);

  final Duration photoLimit;
  final Duration totalLimit;
  final Clock _clock;
  final PeriodicTimerFactory _periodic;

  var _photo = Duration.zero;
  var _total = Duration.zero;
  var _running = false;

  /// Tiempo activo gastado por la foto en curso (o por la última).
  Duration get photoElapsed => _photo;

  /// Tiempo activo gastado entre todas las fotos.
  Duration get totalElapsed => _total;

  bool get totalExpired => _total >= totalLimit;

  /// Ejecuta el trabajo de **una** foto bajo el presupuesto. Devuelve su
  /// resultado, o lo que dé [onExpired] si un límite se agota antes (como el
  /// `onTimeout` de `Future.timeout`). El trabajo no se interrumpe: [onExpired]
  /// debe cancelarlo; lo que acabe después se ignora.
  ///
  /// Con el total ya agotado no se empieza el trabajo. Lanza [StateError] si
  /// ya hay una foto en curso.
  Future<T> runPhoto<T>(
    Future<T> Function() work, {
    required FutureOr<T> Function(BudgetExpiry expiry) onExpired,
  }) {
    if (_running) throw StateError('one photo at a time');
    if (totalExpired) {
      return Future<T>.sync(() => onExpired(BudgetExpiry.total));
    }
    _running = true;
    _photo = Duration.zero;
    var last = _clock.now();
    final done = Completer<T>();
    Timer? timer;

    void stop() {
      timer?.cancel();
      _running = false;
    }

    timer = _periodic(heartbeat, (_) {
      if (done.isCompleted) return;
      final now = _clock.now();
      final gap = now.difference(last);
      last = now;
      final step = gap < heartbeat
          ? heartbeat
          : (gap > maxStep ? maxStep : gap);
      // Tras un hueco largo la foto empieza de cero: lo perdido no es suyo.
      _photo = gap > freezeGap ? Duration.zero : _photo + step;
      _total += step;
      final expiry = totalExpired
          ? BudgetExpiry.total
          : (_photo >= photoLimit ? BudgetExpiry.photo : null);
      if (expiry != null) {
        stop();
        done.complete(Future<T>.sync(() => onExpired(expiry)));
      }
    });

    Future<T>.sync(work).then(
      (value) {
        if (done.isCompleted) return;
        stop();
        done.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (done.isCompleted) return;
        stop();
        done.completeError(error, stack);
      },
    );
    return done.future;
  }
}
