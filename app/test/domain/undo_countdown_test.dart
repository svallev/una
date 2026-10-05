import 'package:app/domain/ports/clock.dart';
import 'package:app/domain/services/undo_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock implements Clock {
  DateTime value = DateTime.utc(2026, 10, 4, 9);

  void advance(Duration d) => value = value.add(d);

  @override
  DateTime now() => value;
}

void main() {
  late _Clock clock;
  late UndoCountdown countdown;

  setUp(() {
    clock = _Clock();
    countdown = UndoCountdown(clock: clock, total: const Duration(seconds: 4));
  });

  test('CA-014-17: empieza parada y llena (con el lector, no corre hasta '
      'el primer foco)', () {
    clock.advance(const Duration(minutes: 5));
    expect(countdown.running, isFalse);
    expect(countdown.remaining, const Duration(seconds: 4));
    expect(countdown.fraction, 1);
    expect(countdown.expired, isFalse);
  });

  test('CA-014-06: 4 s exactos (3,99 s sigue, 4 s se acaba)', () {
    countdown.resume();
    clock.advance(const Duration(milliseconds: 3990));
    expect(countdown.expired, isFalse);
    expect(countdown.remaining, const Duration(milliseconds: 10));
    clock.advance(const Duration(milliseconds: 10));
    expect(countdown.expired, isTrue);
    expect(countdown.remaining, Duration.zero);
    expect(countdown.fraction, 0);
    clock.advance(const Duration(seconds: 1));
    expect(countdown.remaining, Duration.zero, reason: 'nunca negativo');
  });

  test('CA-014-03: la fracción baja de forma lineal de 1 a 0', () {
    countdown.resume();
    for (final (ms, f) in [(0, 1.0), (1000, 0.75), (2000, 0.5), (3000, 0.25)]) {
      clock.value = DateTime.utc(
        2026,
        10,
        4,
        9,
      ).add(Duration(milliseconds: ms));
      expect(countdown.fraction, closeTo(f, 1e-9), reason: '$ms ms');
    }
  });

  test('CA-014-17: pausar detiene el tiempo y reanudar sigue desde donde se '
      'quedó', () {
    countdown.resume();
    clock.advance(const Duration(seconds: 1));
    countdown.pause();
    clock.advance(const Duration(minutes: 3));
    expect(countdown.remaining, const Duration(seconds: 3));
    expect(countdown.running, isFalse);
    countdown
      ..pause() // dos veces no cambia nada
      ..resume();
    clock.advance(const Duration(seconds: 1));
    countdown.resume(); // ya corría: no reinicia
    clock.advance(const Duration(seconds: 1));
    expect(countdown.remaining, const Duration(seconds: 1));
  });

  test('CA-014-06: ampliar el total en marcha (llega el "Tiempo para actuar" '
      'del sistema); un total menor no acorta', () {
    countdown.resume();
    clock.advance(const Duration(seconds: 1));
    countdown.extendTo(const Duration(seconds: 10));
    expect(countdown.total, const Duration(seconds: 10));
    expect(countdown.remaining, const Duration(seconds: 9));
    expect(countdown.fraction, closeTo(0.9, 1e-9));
    countdown.extendTo(const Duration(seconds: 2));
    expect(countdown.total, const Duration(seconds: 10));
    clock.advance(const Duration(seconds: 8, milliseconds: 999));
    expect(countdown.expired, isFalse);
    clock.advance(const Duration(milliseconds: 1));
    expect(countdown.expired, isTrue);
  });

  test('CA-014-06: si el reloj del sistema va hacia atrás, no suma tiempo', () {
    countdown.resume();
    clock.advance(const Duration(seconds: 1));
    countdown.pause();
    countdown.resume();
    clock.advance(const Duration(seconds: -30));
    expect(countdown.remaining, const Duration(seconds: 3));
    expect(countdown.fraction, lessThanOrEqualTo(1));
  });
}
