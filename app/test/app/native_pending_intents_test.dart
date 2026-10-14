import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lo que las pruebas JVM no pueden ver: el cableado del código nativo (spec 020, CA-020-21 y
/// CA-020-28). `IntentSpecsTest` y `PickedItemsTest` prueban las descripciones puras; aquí, que los
/// adaptadores las usan y que no hay otra vía.
const _main = 'android/app/src/main/kotlin/invalid/pending/app';

/// El código sin comentarios ni cadenas de documentación.
String _code(String path) =>
    File(path)
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');

List<File> _kotlinFiles() =>
    Directory(_main)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.kt'))
        .toList();

String _name(File f) => f.path.split('/').last;

void main() {
  group('CA-020-28: las órdenes (PendingIntent) de la app', () {
    const adapters = {'AlarmArm.kt', 'NotificationPoster.kt'};

    test('PendingIntent.get* solo aparece en los adaptadores', () {
      final callers = <String>{};
      for (final file in _kotlinFiles()) {
        final code = _code(file.path);
        if (RegExp(r'PendingIntent\s*\.\s*get\w+\s*\(').hasMatch(code)) {
          callers.add(_name(file));
        }
      }
      expect(callers, adapters);
    });

    test('cada llamada pasa los flags de un IntentSpec, sin otros propios', () {
      for (final file in _kotlinFiles()) {
        final code = _code(file.path);
        final calls = RegExp(r'PendingIntent\s*\.\s*get\w+\s*\(([^)]*)\)')
            .allMatches(code)
            .toList();
        for (final call in calls) {
          final args = call.group(1)!;
          expect(
            args,
            contains('spec.flags'),
            reason: '${_name(file)}: ${call.group(0)}',
          );
          expect(args, isNot(contains('FLAG_')), reason: _name(file));
          expect(args, contains('spec.requestCode'), reason: _name(file));
        }
      }
    });

    test(
      'FLAG_MUTABLE no aparece en ningún archivo nativo (ni de pruebas)',
      () {
        for (final file in _kotlinFiles()) {
          expect(
            _code(file.path),
            isNot(contains('FLAG_MUTABLE')),
            reason: _name(file),
          );
        }
      },
    );

    test('FLAG_IMMUTABLE solo se declara en IntentSpecs', () {
      for (final file in _kotlinFiles()) {
        final has = _code(file.path).contains('FLAG_IMMUTABLE');
        expect(has, _name(file) == 'IntentSpecs.kt', reason: _name(file));
      }
    });

    test('las intenciones de los adaptadores son explícitas', () {
      for (final name in adapters) {
        final code = _code('$_main/notifications/$name');
        final intents = RegExp(r'\bIntent\s*\(([^)]*)\)')
            .allMatches(code)
            .toList();
        expect(intents, isNotEmpty, reason: name);
        for (final intent in intents) {
          // Intent(context, Clase::class.java): nunca solo una acción ni una URI.
          expect(
            intent.group(1),
            matches(RegExp(r'^\s*context\s*,\s*\w+::class\.java\s*$')),
            reason: '$name: ${intent.group(0)}',
          );
        }
        // Ni un destino abierto ni un paquete ajeno.
        for (final banned in ['setPackage', 'setData', 'Uri.parse']) {
          expect(code, isNot(contains(banned)), reason: '$name: $banned');
        }
      }
    });

    test('la acción y el destino salen del IntentSpec, no del adaptador', () {
      final alarm = _code('$_main/notifications/AlarmArm.kt');
      final poster = _code('$_main/notifications/NotificationPoster.kt');
      expect(alarm, contains('setAction(spec.action)'));
      expect(alarm, contains('IntentSpecs.wakeAlarm'));
      expect(poster, contains('setAction(spec.action)'));
      expect(poster, contains('IntentSpecs.openCurrentTask()'));
      // El nonce se pone con el extra que dice el IntentSpec.
      expect(poster, contains('spec.nonceExtra'));
      expect(poster, contains('ActivationNonce.issue()'));
    });
  });

  group('CA-020-21: el tope de fotos del selector', () {
    late String code;
    setUpAll(() => code = _code('$_main/ImageImport.kt'));

    test('pickedMany delega el tope en PickedItems.firstItems', () {
      expect(code, contains('PickedItems.firstItems(total, max)'));
    });

    test('getItemAt solo se llama dentro de ese cierre, una vez', () {
      expect(RegExp(r'\bgetItemAt\b').allMatches(code), hasLength(1));
      expect(
        code,
        matches(
          RegExp(
            r'firstItems\(total,\s*max\)\s*\{[^}]*getItemAt',
            dotAll: true,
          ),
        ),
      );
    });

    test(
      'no se recorre el clip entero (itemCount solo se lee como entero)',
      () {
        expect(code, isNot(contains('until clip.itemCount')));
        expect(code, isNot(contains('clip.itemCount - 1')));
        expect(code, isNot(contains('0 until total')));
      },
    );
  });

  test('CA-020-21: T-16 anota el límite de la cola de limpieza', () {
    final text = File('../docs/security/threat-model.md').readAsStringSync();
    final row = text.split('\n').firstWhere((l) => l.startsWith('| T-16 |'));
    expect(row, contains('falsos vencimientos'));
    expect(row, contains('2 min'));
  });
}
