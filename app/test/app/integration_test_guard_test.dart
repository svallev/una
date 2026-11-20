// CA-028-02: los tests de integración corren también en el simulador de iOS.
// Su guarda («solo en la app de pruebas, nunca borra tareas reales») se lleva
// a un solo sitio: en Android sigue mirando `.debug`/`.profile` en la ruta de
// Documents; en iOS la ruta es un UUID, así que solo vale el simulador (su
// ruta lleva `/CoreSimulator/Devices/`; el entorno llega vacío) y fuera de
// *release*.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/test_app_guard.dart';

const _androidDebug = '/data/user/0/dev.una.app.debug/app_flutter';
const _androidProfile = '/data/user/0/dev.una.app.profile/app_flutter';
const _androidReal = '/data/user/0/dev.una.app/app_flutter';
const _iosSimulator =
    '/Users/x/Library/Developer/CoreSimulator/Devices/ABC/data/Containers/'
    'Data/Application/6F2E1C9A-3B7D-4E55-9C11-0A2B3C4D5E6F/Documents';
const _iosDevice =
    '/var/mobile/Containers/Data/Application/'
    '6F2E1C9A-3B7D-4E55-9C11-0A2B3C4D5E6F/Documents';

bool _ok(String path, {bool ios = false, bool release = false}) =>
    isTestApp(documentsPath: path, isIOS: ios, isRelease: release);

void main() {
  group('CA-028-02: guarda de los tests de integración', () {
    test('Android: acepta las apps .debug y .profile', () {
      expect(_ok(_androidDebug), isTrue);
      expect(_ok(_androidProfile), isTrue);
    });

    test('Android: rechaza la app real, también con ruta de simulador', () {
      expect(_ok(_androidReal), isFalse);
      expect(_ok('$_androidReal/CoreSimulator/Devices/x'), isFalse);
    });

    test('iOS: acepta el simulador (ruta con UUID, sin .debug)', () {
      expect(_ok(_iosSimulator, ios: true), isTrue);
    });

    test('iOS: rechaza un aparato real', () {
      expect(_ok(_iosDevice, ios: true), isFalse);
    });

    test('iOS: rechaza el simulador en release', () {
      expect(_ok(_iosSimulator, ios: true, release: true), isFalse);
    });

    test('iOS: una ruta con .debug no basta sin simulador', () {
      expect(_ok('/var/mobile/x.debug/Documents', ios: true), isFalse);
    });

    test(
      'assertTestApp lanza StateError con la ruta y no hace nada si vale',
      () {
        expect(
          () => assertTestApp(_androidDebug, isIOS: false),
          returnsNormally,
        );
        expect(
          () => assertTestApp(_androidReal, isIOS: false),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'mensaje',
              contains(_androidReal),
            ),
          ),
        );
      },
    );
  });

  group('CA-028-02: los 14 tests usan la guarda común', () {
    final dir = Directory('integration_test');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .toList();
    final guarded = files
        .where((f) => f.readAsStringSync().contains('assertTestApp'))
        .map((f) => f.uri.pathSegments.last)
        .toList();

    test(
      'exactamente los 14 que borraban datos, ninguno con la guarda a mano',
      () {
        // 20 desde T-028-17 (`web_redirect_test`, que no borra datos).
        expect(files.length, 20);
        expect(guarded.length, 14, reason: '$guarded');
        for (final f in files) {
          final text = f.readAsStringSync();
          expect(
            text.contains("contains('.debug')"),
            isFalse,
            reason: '${f.path} aún lleva la guarda a mano',
          );
          if (text.contains('assertTestApp')) {
            expect(
              text,
              contains("import 'support/test_app_guard.dart';"),
              reason: f.path,
            );
          }
        }
      },
    );

    test('los 5 *_perf_test se saltan en el simulador de iOS, con motivo', () {
      final perf = files
          .where((f) => f.path.endsWith('_perf_test.dart'))
          .toList();
      expect(perf.length, 5);
      for (final f in perf) {
        final text = f.readAsStringSync();
        expect(text, contains('skip: skipPerfOnIosSimulator'), reason: f.path);
      }
      // El motivo vive junto a la constante, una sola vez.
      final guard = File('integration_test/support/test_app_guard.dart')
          .readAsStringSync();
      expect(guard, contains('flutter drive --profile'));
      expect(guard, contains('T-028-23'));
    });

    test('los tests de flujo no se saltan en iOS', () {
      for (final f in files.where((f) => f.path.endsWith('_flow_test.dart'))) {
        expect(
          f.readAsStringSync(),
          isNot(contains('skipPerfOnIosSimulator')),
          reason: f.path,
        );
      }
    });
  });
}
