import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';

import '../../domain/entities/locale_choice.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/task.dart';
import '../../domain/ports/notification_gateway.dart';
import '../../domain/services/notification_content.dart';
import 'notification_gateway.dart';

/// Los textos fijos de la notificación en el idioma de la app para una
/// elección de Ajustes (con «Como el sistema», el que resuelve la 010).
typedef NotificationTextsFor = NotificationTexts Function(LocaleChoice choice);

/// [NotificationGateway] de iOS (spec 028, CA-028-15 y 16, ADR-0030,
/// `channel-contract.md` §4): el mismo canal `una/notifications` que Android,
/// salvo `configure`, que en iOS manda los avisos **ya escritos**
/// (`{on, slots: [{hour, minute, title, body, publicBody}]}`): iOS no deja
/// ejecutar código de la app al llegar la hora, así que el texto de la tarea
/// actual se calcula aquí y se programa por adelantado.
///
/// Además de `configure` (encender, apagar, cantidad, idioma y el arranque,
/// que ya llaman Ajustes y `UnaApp`), **reprograma cada vez que cambia la
/// tarea actual** (crear, editar, completar, eliminar, deshacer, reordenar):
/// los cambios seguidos se agrupan en una sola llamada tras [settleDelay]; en
/// segundo plano, sin esperar (iOS puede suspender la app antes de que venza).
/// Con el ajuste apagado no se reprograma nada (ya está todo cancelado).
///
/// Las llamadas al canal van **una tras otra**, cada una con la tarea leída en
/// su momento. Lo único que guarda (en memoria) son los ajustes del último
/// `configure` que salió bien y los avisos enviados, para no repetir una
/// llamada igual. Nunca registra nada ni pasa texto de tareas a un error
/// (CA-019-23).
class IosNotificationGateway extends ChannelNotificationGateway {
  IosNotificationGateway({
    required this._readCurrentTask,
    required Stream<Object?> currentTaskChanges,
    required this._textsFor,
    this.settleDelay = defaultSettleDelay,
  }) {
    _changes = currentTaskChanges.listen(
      (_) => _currentTaskChanged(),
      // Sin registrar el error: el de SQLite puede llevar datos del usuario.
      onError: (Object _) {},
    );
  }

  /// Cuánto se espera a que dejen de llegar cambios de la tarea actual antes
  /// de reprogramar (completar, deshacer y reordenar llegan en ráfagas).
  /// [Suposición] 300 ms: corto para que el texto de una tarea completada o
  /// eliminada salga de la programación «en ese momento» (CA-028-16).
  static const defaultSettleDelay = Duration(milliseconds: 300);

  final Duration settleDelay;
  final Future<Task?> Function() _readCurrentTask;
  final NotificationTextsFor _textsFor;
  late final StreamSubscription<Object?> _changes;

  /// Los ajustes del último `configure` que salió bien; `null` hasta el
  /// primero (el del arranque, tras el primer fotograma).
  ({bool on, NotificationsPerDay perDay, LocaleChoice language})? _settings;

  /// Lo último que aceptó lo nativo (`null` si no se sabe: aún nada o falló).
  ({bool on, List<NotificationSlot> slots})? _lastSent;

  Timer? _settle;
  bool _visible = true;
  bool _closed = false;

  /// Final de la cola de llamadas a `configure`: nunca termina con error.
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> configure({
    required bool on,
    required NotificationsPerDay perDay,
    required LocaleChoice language,
  }) async {
    // Esta llamada ya lee la tarea actual: cubre un cambio pendiente.
    _cancelSettle();
    final settings = (on: on, perDay: perDay, language: language);
    try {
      await _serialized(() async {
        await _send(settings);
        _settings = settings;
      });
    } on MissingPluginException {
      throw const NotificationGatewayException(unsupported: true);
    } on Object {
      // Sin message/details ni el error de la BD (CA-019-23).
      throw const NotificationGatewayException();
    }
  }

  @override
  Future<void> setForeground(bool visible) {
    _visible = visible;
    // Al irse a segundo plano, lo pendiente sale ya.
    if (!visible && _cancelSettle()) _rescheduleNow();
    return super.setForeground(visible);
  }

  @override
  void dispose() {
    _closed = true;
    _cancelSettle();
    unawaited(_changes.cancel());
    super.dispose();
  }

  void _currentTaskChanged() {
    if (_closed || _settings?.on != true) return;
    if (!_visible) {
      _cancelSettle();
      _rescheduleNow();
      return;
    }
    _settle ??= Timer(settleDelay, () {
      _settle = null;
      _rescheduleNow();
    });
  }

  /// `true` si había una reprogramación esperando.
  bool _cancelSettle() {
    final pending = _settle != null;
    _settle?.cancel();
    _settle = null;
    return pending;
  }

  void _rescheduleNow() => unawaited(
    _serialized(() async {
      final settings = _settings;
      if (_closed || settings == null || !settings.on) return;
      try {
        await _send(settings, skipIfSame: true);
      } on Object {
        // Mejor esfuerzo: el siguiente cambio o el arranque lo corrigen.
      }
    }),
  );

  Future<void> _send(
    ({bool on, NotificationsPerDay perDay, LocaleChoice language}) settings, {
    bool skipIfSame = false,
  }) async {
    // Apagado no se lee la tarea: no hace falta su texto para cancelar.
    final task = settings.on ? await _readCurrentTask() : null;
    final slots = notificationSlots(
      on: settings.on,
      perDay: settings.perDay,
      task: task,
      texts: _textsFor(settings.language),
    );
    final last = _lastSent;
    if (skipIfSame &&
        last != null &&
        last.on == settings.on &&
        listEquals(last.slots, slots)) {
      return;
    }
    _lastSent = null;
    await ChannelNotificationGateway.channel.invokeMethod<void>('configure', {
      'on': settings.on,
      'slots': [
        for (final s in slots)
          {
            'hour': s.time.hour,
            'minute': s.time.minute,
            'title': s.title,
            'body': s.body,
            'publicBody': s.publicBody,
          },
      ],
    });
    _lastSent = (on: settings.on, slots: slots);
  }

  Future<void> _serialized(Future<void> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}
