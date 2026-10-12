import 'package:flutter/foundation.dart' show immutable;

/// Una hora de notificación en hora local del móvil (glosario: «Hora de
/// notificación», CA-019-10).
@immutable
class NotificationTime {
  const NotificationTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// «08:55»: siempre 24 h y dos cifras, sin depender del formato del sistema
  /// (CA-019-04).
  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is NotificationTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Las tres horas **fijas** a las que puede llegar una notificación
/// (D25, CA-019-10). La lógica de horas, despertares y recuperación vive en
/// Kotlin (plan §1): aquí solo están para la ayuda de Ajustes (CA-019-04).
abstract final class NotificationSchedule {
  static const List<NotificationTime> times = [
    NotificationTime(8, 55),
    NotificationTime(13, 55),
    NotificationTime(18, 55),
  ];
}

/// Cuántas notificaciones al día (CA-019-03): 1, 2 o 3; **1 por defecto**.
/// Con 1 llega la primera hora; con 2, las dos primeras; con 3, las tres.
enum NotificationsPerDay {
  one(1),
  two(2),
  three(3);

  const NotificationsPerDay(this.count);

  /// El número que se guarda (`'1'`, `'2'` o `'3'`) y se ve en el botón.
  final int count;

  static const NotificationsPerDay defaultValue = one;

  /// Las horas de este valor (lista no modificable).
  List<NotificationTime> get times =>
      List.unmodifiable(NotificationSchedule.times.take(count));
}
