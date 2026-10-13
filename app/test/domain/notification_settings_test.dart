import 'package:app/domain/entities/notification_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA-019-05: la cantidad vale 1, 2 o 3 y por defecto es 1 (D25)', () {
    expect(NotificationsPerDay.values.map((v) => v.count), [1, 2, 3]);
    expect(NotificationsPerDay.defaultValue, NotificationsPerDay.one);
  });

  test(
    'CA-019-04, CA-019-10: las tres horas fijas, en 24 h con dos cifras',
    () {
      expect(NotificationSchedule.times.map((t) => t.label), [
        '08:55',
        '13:55',
        '18:55',
      ]);
      expect(NotificationSchedule.times.map((t) => (t.hour, t.minute)), [
        (8, 55),
        (13, 55),
        (18, 55),
      ]);
    },
  );

  test('CA-019-10: con 1, la primera hora; con 2, las dos primeras; con 3, '
      'las tres', () {
    expect(NotificationsPerDay.one.times.map((t) => t.label), ['08:55']);
    expect(NotificationsPerDay.two.times.map((t) => t.label), [
      '08:55',
      '13:55',
    ]);
    expect(NotificationsPerDay.three.times.map((t) => t.label), [
      '08:55',
      '13:55',
      '18:55',
    ]);
  });

  test('CA-019-05: la lista de horas no se puede modificar desde fuera', () {
    expect(
      () => NotificationSchedule.times.add(const NotificationTime(1, 0)),
      throwsUnsupportedError,
    );
    expect(
      () => NotificationsPerDay.three.times.clear(),
      throwsUnsupportedError,
    );
  });
}
