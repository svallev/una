import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/locale_choice.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/ports/notification_gateway.dart';

/// [NotificationGateway] sobre el canal `una/notifications`
/// (`NotificationsChannel.kt`, spec 019, plan §3.5).
///
/// Cualquier fallo del canal se traduce sin su texto (CA-019-23): el mensaje
/// de un `PlatformException` puede arrastrar contenido y no se lee ni se guarda.
/// Crearlo es barato (registra el manejador de `openCurrentTask`); se crea al
/// primer uso, nunca antes del primer fotograma (P2).
class ChannelNotificationGateway implements NotificationGateway {
  ChannelNotificationGateway() {
    _channel.setMethodCallHandler(_fromNative);
  }

  static const _channel = MethodChannel('una/notifications');

  final StreamController<void> _openRequests =
      StreamController<void>.broadcast();
  bool _disposed = false;

  Future<void> _fromNative(MethodCall call) async {
    if (call.method != 'openCurrentTask') throw MissingPluginException();
    // La orden no lleva datos: se ignoran los argumentos que traiga (CA-019-20).
    if (!_disposed) _openRequests.add(null);
  }

  /// Deja de oír a lo nativo y cierra el Stream.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _channel.setMethodCallHandler(null);
    unawaited(_openRequests.close());
  }

  @override
  Stream<void> get openCurrentTaskRequests => _openRequests.stream;

  @override
  Future<bool> canNotify() async {
    try {
      return await _channel.invokeMethod<Object?>('canNotify') == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<PermissionResult> requestPermission() async {
    const denied = (granted: false, dialogShown: false);
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('requestPermission');
    } on MissingPluginException {
      return denied;
    } on PlatformException {
      return denied;
    }
    // Solo vale un mapa con `granted` booleano; cualquier otra cosa es rechazo.
    if (reply is! Map || reply['granted'] is! bool) return denied;
    return (
      granted: reply['granted'] == true,
      dialogShown: reply['dialogShown'] == true,
    );
  }

  @override
  Future<void> configure({
    required bool on,
    required NotificationsPerDay perDay,
    required LocaleChoice language,
  }) async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'on': on,
        'perDay': perDay.count,
        'lang': language.code,
      });
    } on MissingPluginException {
      throw const NotificationGatewayException(unsupported: true);
    } on PlatformException {
      // Sin message/details: pueden llevar texto (CA-019-23).
      throw const NotificationGatewayException();
    }
  }

  @override
  Future<void> cancelDelivered() => _bestEffort('cancelDelivered');

  @override
  Future<void> setForeground(bool visible) =>
      _bestEffort('setForeground', visible);

  Future<void> _bestEffort(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Plataforma sin el canal: sin efecto.
    } on PlatformException {
      // Sin registrar nada: lo siguiente que haga la app lo corrige.
    }
  }

  @override
  Future<bool> openSystemSettings() async {
    try {
      return await _channel.invokeMethod<Object?>('openSystemSettings') == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Sin canal (web de pruebas e iOS, D17, CA-019-28): no hay permiso ni
/// programador. El bloque de Notificaciones ni siquiera se monta.
class UnsupportedNotificationGateway implements NotificationGateway {
  const UnsupportedNotificationGateway();

  @override
  Future<bool> canNotify() async => false;

  @override
  Future<PermissionResult> requestPermission() async =>
      (granted: false, dialogShown: false);

  @override
  Future<void> configure({
    required bool on,
    required NotificationsPerDay perDay,
    required LocaleChoice language,
  }) async => throw const NotificationGatewayException(unsupported: true);

  @override
  Future<void> cancelDelivered() async {}

  @override
  Future<void> setForeground(bool visible) async {}

  @override
  Future<bool> openSystemSettings() async => false;

  @override
  Stream<void> get openCurrentTaskRequests => const Stream<void>.empty();
}
