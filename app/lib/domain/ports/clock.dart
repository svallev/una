/// Reloj inyectable: todo lo temporal se prueba con relojes falsos (docs/testing.md).
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}
