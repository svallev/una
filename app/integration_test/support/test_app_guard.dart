// Guarda común de los tests de integración (spec 028, T-028-06, CA-028-02).
//
// Estos tests borran la base de datos y los adjuntos de la app donde corren,
// así que NUNCA deben ejecutarse sobre la app real con tareas de verdad:
//  - Android: la app de pruebas es `.debug`/`.profile` (`applicationIdSuffix`);
//    se mira en la ruta de Documents, como siempre.
//  - iOS: no hay sufijo (la ruta es un UUID); solo vale el **simulador** y
//    fuera de *release*. En un aparato real no se borra nada: lanza. El
//    simulador se reconoce por su ruta (`.../CoreSimulator/Devices/<UDID>/...`,
//    en un aparato es `/var/mobile/...`): `Platform.environment` llega VACÍO
//    en iOS, así que `SIMULATOR_UDID` (la suposición del plan) no sirve.
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Marca de la ruta de cualquier archivo de una app dentro del simulador.
const _simulatorPathMark = '/CoreSimulator/Devices/';

/// ¿Es [documentsPath] la de una app de pruebas? Los parámetros se inyectan
/// para poder probar cada plataforma desde `flutter test`.
bool isTestApp({
  required String documentsPath,
  required bool isIOS,
  required bool isRelease,
}) {
  if (isIOS) {
    return !isRelease && documentsPath.contains(_simulatorPathMark);
  }
  return documentsPath.contains('.debug') || documentsPath.contains('.profile');
}

/// Lanza [StateError] si la app no es de pruebas (ver arriba). Antes de borrar
/// cualquier dato.
void assertTestApp(String documentsPath, {bool? isIOS, bool? isRelease}) {
  final ok = isTestApp(
    documentsPath: documentsPath,
    isIOS: isIOS ?? Platform.isIOS,
    isRelease: isRelease ?? kReleaseMode,
  );
  if (!ok) {
    throw StateError(
      'Pruebas de integración fuera de la app de pruebas '
      '(Android: .debug/.profile; iOS: solo simulador y no release): '
      '$documentsPath',
    );
  }
}

/// ¿Estamos en el simulador de iOS? Se mira el ejecutable (síncrono; un
/// `skip:` se evalúa antes de poder esperar a `path_provider`).
bool get isIosSimulator =>
    Platform.isIOS && Platform.resolvedExecutable.contains(_simulatorPathMark);

/// Los `*_perf_test` se ejecutan con `flutter drive --profile`, y el modo
/// *profile* no existe en el simulador de iOS (plan 028 §1.3, R-11, Q-P-1):
/// ahí se saltan (`skip: skipPerfOnIosSimulator`). Lo que miden se mide en el
/// iPad en T-028-23. En Android y en un aparato real de iOS corren como
/// siempre.
final bool skipPerfOnIosSimulator = isIosSimulator;
