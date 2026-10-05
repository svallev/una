import '../ports/clock.dart';

/// Cuenta atrás de la card de deshacer (CA-014-06, CA-014-17), medida con un
/// [Clock] inyectable y no con una animación: "Quitar animaciones" acorta las
/// animaciones, pero no esto. Empieza parada y llena; quien la usa la reanuda
/// cuando la card se ve (con el lector, tras su primer foco) y la para
/// mientras la card tiene el foco. No programa nada: el controlador pone un
/// temporizador por lo que queda ([remaining]).
class UndoCountdown {
  UndoCountdown({required this.clock, required this._total});

  final Clock clock;
  Duration _total;

  /// Tiempo corrido hasta la última pausa.
  Duration _spent = Duration.zero;

  /// Desde cuándo corre, o null si está parada.
  DateTime? _since;

  Duration get total => _total;

  bool get running => _since != null;

  /// Tiempo corrido. Si el reloj del sistema va hacia atrás, no resta.
  Duration get elapsed {
    final since = _since;
    if (since == null) return _spent;
    final run = clock.now().difference(since);
    return run.isNegative ? _spent : _spent + run;
  }

  /// Lo que queda, nunca negativo.
  Duration get remaining {
    final left = _total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Fracción que queda, de 1 (llena) a 0: la barra de tiempo.
  double get fraction => _total <= Duration.zero
      ? 0
      : remaining.inMicroseconds / _total.inMicroseconds;

  bool get expired => remaining == Duration.zero;

  /// Empieza o sigue desde donde se quedó.
  void resume() => _since ??= clock.now();

  /// Se detiene sin perder lo corrido.
  void pause() {
    if (_since == null) return;
    _spent = elapsed;
    _since = null;
  }

  /// Amplía el total (el "Tiempo para actuar" del sistema llega después de
  /// empezar). Solo alarga: un total menor no acorta (CA-014-06).
  void extendTo(Duration total) {
    if (total > _total) _total = total;
  }
}
