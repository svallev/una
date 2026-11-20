import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Dependencias de iOS (spec 028, T-028-08; CA-028-03 y 17; threat-model §5, P11).
///
///  - `webview_flutter_wkwebview` (el motor de la WebView de iOS) pasa de transitiva a **directa y
///    fijada** a la versión que ya traía el lock: sin versión nueva y sin tocar Android (el paquete
///    solo declara iOS y macOS).
///  - La [Suposición] del contrato §0.5 (`path_provider_foundation` da `Caches` como temporal y
///    `Application Support` como soporte) se comprueba en el código del paquete: el Swift de la 028
///    (`DataAtRest`, `una/images`) escribe en las mismas carpetas que usa Dart.
///
/// Lo que leen del paquete se busca con `.dart_tool/package_config.json` (`flutter pub get`).
const _pkg = 'webview_flutter_wkwebview';

YamlMap _lock() => loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;

/// La versión de [name] en el lock.
String _lockedVersion(String name) =>
    ((_lock()['packages'] as YamlMap)[name] as YamlMap)['version'] as String;

Directory? _packageDir(String name) {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final data = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  for (final p in (data['packages'] as List).cast<Map<String, dynamic>>()) {
    if (p['name'] == name) {
      final root = p['rootUri'] as String;
      return Directory(
        root.startsWith('file:')
            ? Uri.parse(root).toFilePath()
            : config.parent.uri.resolve(root).toFilePath(),
      );
    }
  }
  return null;
}

/// El cuerpo (hasta el siguiente `@override`) del método [name] de [source].
String _method(String source, String name) {
  final start = source.indexOf(name);
  expect(start, isNonNegative, reason: '$name no está en el paquete');
  final end = source.indexOf('@override', start);
  return source.substring(start, end < 0 ? source.length : end);
}

void main() {
  test('CA-028-03: webview_flutter_wkwebview es dependencia directa y está '
      'fijada a la versión del lock', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final deps = pubspec['dependencies'] as YamlMap;
    final pinned = deps[_pkg] as String?;
    expect(pinned, isNotNull, reason: '$_pkg debe estar en dependencies');
    expect(
      RegExp(r'^\d+\.\d+\.\d+$').hasMatch(pinned!),
      isTrue,
      reason: 'fijada a una versión exacta, sin ^ ni rango (P11): $pinned',
    );
    final entry = (_lock()['packages'] as YamlMap)[_pkg] as YamlMap;
    expect(entry['dependency'], 'direct main');
    expect(entry['version'], pinned, reason: 'sin versión nueva en el lock');
    expect(entry['source'], 'hosted');
  });

  test('CA-028-03: la WebView de Android sigue fijada como antes', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final deps = pubspec['dependencies'] as YamlMap;
    expect(deps['webview_flutter'], '4.14.1');
    expect(deps['webview_flutter_android'], '4.14.1');
  });

  test('CA-028-03: el motor de iOS solo declara iOS y macOS (no entra en '
      'Android)', () {
    final dir = _packageDir(_pkg);
    if (dir == null) {
      markTestSkipped('sin flutter pub get');
      return;
    }
    final pubspec = loadYaml(
      File('${dir.path}/pubspec.yaml').readAsStringSync(),
    ) as YamlMap;
    final flutter = pubspec['flutter'] as YamlMap;
    final plugin = flutter['plugin'] as YamlMap;
    final platforms = plugin['platforms'] as YamlMap;
    expect(platforms.keys.toSet(), {'ios', 'macos'});
    expect(pubspec['version'], _lockedVersion(_pkg));
    expect(Directory('${dir.path}/android').existsSync(), isFalse);
  });

  group('contrato §0.5: carpetas de path_provider_foundation', () {
    late String source;
    late String version;

    setUp(() {
      final dir = _packageDir('path_provider_foundation');
      if (dir == null) {
        markTestSkipped('sin flutter pub get');
        source = '';
        version = '';
        return;
      }
      source = File('${dir.path}/lib/src/path_provider_foundation_real.dart')
          .readAsStringSync();
      version = _lockedVersion('path_provider_foundation');
    });

    test('CA-028-18: lo temporal (import/) es NSCachesDirectory', () {
      if (source.isEmpty) return;
      final body = _method(source, 'getTemporaryPath');
      expect(body, contains('NSSearchPathDirectory.NSCachesDirectory'));
      expect(body, isNot(contains('NSTemporaryDirectory')));
      expect(version, isNotEmpty);
    });

    test('CA-028-18: lo guardado (attachments/) es '
        'NSApplicationSupportDirectory, sin carpeta del bundle en iOS', () {
      if (source.isEmpty) return;
      final body = _method(source, 'getApplicationSupportPath');
      expect(
        body,
        contains('NSSearchPathDirectory.NSApplicationSupportDirectory'),
      );
      // El sufijo con el identificador del bundle solo se añade en macOS.
      final helper = _method(source, 'String? _getDirectoryPath');
      expect(helper, contains('_platformProvider.isMacOS'));
      expect(helper, contains('bundleIdentifier'));
      final iosBranch = helper.substring(0, helper.indexOf('isMacOS'));
      expect(iosBranch, isNot(contains('bundleIdentifier')));
    });
  });

  test('CA-028-18: el contrato §0.5 ya no deja la carpeta temporal como '
      '[Suposición]', () {
    final text = File('../docs/ios/channel-contract.md').readAsStringSync();
    final item = text
        .split('\n')
        .firstWhere((l) => l.contains('preparación: `getTemporaryDirectory()'));
    expect(item, contains('NSCachesDirectory'));
    expect(item, isNot(contains('[Suposición')));
    expect(item, contains('T-028-08'));
  });
}
