import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CA-021-08: la WebView de la tarea web no se oscurece por su cuenta. Prueba de fuente (como
/// `native_no_logging_test`): el efecto real (la página en claro con el sistema en oscuro) se mide
/// en el emulador (casilla C-021-6) y `integration_test/webview_hardening_test.dart` lee la clave
/// `noDarkening` de vuelta. Aquí se fija que `harden` apaga el oscurecimiento por versión, que
/// `state()` lo comprueba y que no cambia nada más de `harden` (ADR-0017) ni entra `androidx.webkit`.
const _kotlin =
    'android/app/src/main/kotlin/invalid/pending/app/WebViewHardening.kt';
const _integration = 'integration_test/webview_hardening_test.dart';

/// El código sin comentarios (las cadenas se conservan: se busca la clave `"noDarkening"`).
String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '"') {
      final end = source.indexOf('"', i + 1);
      out.write(source.substring(i, end + 1));
      i = end + 1;
    } else if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (c == '/' && next == '*') {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// Texto entre las llaves que abre [opening] (que debe terminar en `{`), sin ellas.
String _block(String code, Pattern opening) {
  final matches = opening.allMatches(code).toList();
  if (matches.isEmpty) return ''; // la prueba que lo usa falla con su motivo
  final m = matches.single;
  var depth = 1;
  var i = m.end;
  while (i < code.length && depth > 0) {
    if (code[i] == '{') depth++;
    if (code[i] == '}') depth--;
    i++;
  }
  return code.substring(m.end, i - 1);
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  late String code;
  late String harden;
  late String applyBlock;
  late String state;
  late String noDarkening;

  setUpAll(() {
    code = _stripComments(File(_kotlin).readAsStringSync());
    harden = _block(code, RegExp(r'private fun harden\([^)]*\): Boolean \{'));
    applyBlock = _block(harden, 'view.settings.apply {');
    state = _block(
      code,
      RegExp(r'private fun state\([^)]*\): Map<String, Boolean> \{'),
    );
    noDarkening = _block(
      code,
      RegExp(r'private fun noDarkening\([^)]*\): Boolean = when \{'),
    );
  });

  test('CA-021-08: harden apaga el oscurecimiento algorítmico (API 33+) y '
      'forceDark (API 29-32) dentro de settings.apply', () {
    const tiramisu =
        r'Build\.VERSION\.SDK_INT\s*>=\s*Build\.VERSION_CODES\.TIRAMISU';
    const q = r'Build\.VERSION\.SDK_INT\s*>=\s*Build\.VERSION_CODES\.Q';
    final pattern = RegExp(
      'if\\s*\\($tiramisu\\)\\s*\\{\\s*isAlgorithmicDarkeningAllowed\\s*=\\s*false\\s*\\}'
      '\\s*else if\\s*\\($q\\)\\s*\\{\\s*(@Suppress\\("DEPRECATION"\\)\\s*)?'
      'forceDark\\s*=\\s*WebSettings\\.FORCE_DARK_OFF\\s*\\}',
    );
    expect(
      applyBlock,
      matches(pattern),
      reason:
          'API 33+: isAlgorithmicDarkeningAllowed = false; API 29-32: '
          'forceDark = FORCE_DARK_OFF (y nada en API < 29)',
    );
    // Nunca se enciende.
    expect(code, isNot(contains('isAlgorithmicDarkeningAllowed = true')));
    expect(code, isNot(contains('FORCE_DARK_ON')));
    expect(code, isNot(contains('FORCE_DARK_AUTO')));
  });

  test('CA-021-08: state() lleva la clave noDarkening y la comprueba por '
      'versión (true en API < 29)', () {
    expect(_squash(state), contains('"noDarkening" to noDarkening(s)'));
    expect(
      _squash(noDarkening),
      _squash('''
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> !s.isAlgorithmicDarkeningAllowed
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> s.forceDark == WebSettings.FORCE_DARK_OFF
        else -> true
      '''),
      reason: 'un when con tres ramas: API 33+, API 29-32 y el resto',
    );
  });

  test('CA-021-08: harden sigue devolviendo falso si algo de state() no queda '
      'puesto (ADR-0017: no se carga la página)', () {
    expect(_squash(harden), endsWith('return state(view).values.all { it }'));
  });

  test('CA-021-08 / ADR-0017: el resto de harden no cambia: los seis ajustes '
      'de siempre y el mismo orden', () {
    // Los ajustes de antes siguen en el apply, en su orden, y el oscurecimiento va después.
    final order = [
      'allowFileAccess = false',
      'allowContentAccess = false',
      'saveFormData = false',
      'mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW',
      'safeBrowsingEnabled = true',
      'setSupportMultipleWindows(false)',
      'isAlgorithmicDarkeningAllowed = false',
      'forceDark = WebSettings.FORCE_DARK_OFF',
    ].map(applyBlock.indexOf).toList();
    expect(order, everyElement(isNonNegative));
    expect(order, orderedEquals([...order]..sort()));

    // Y el orden de los pasos de harden: ajustes, descargas, depuración, envoltorio, relectura.
    final steps = [
      'view.settings.apply {',
      'view.setDownloadListener {',
      'WebView.setWebContentsDebuggingEnabled(false)',
      'view.webViewClient = RenderGoneClient(',
      'return state(view).values.all { it }',
    ].map(harden.indexOf).toList();
    expect(steps, everyElement(isNonNegative));
    expect(steps, orderedEquals([...steps]..sort()));

    // Las siete comprobaciones de antes siguen, en su orden (la nueva, entre ellas).
    final keys = RegExp(r'"(\w+)" to ')
        .allMatches(state)
        .map((m) => m.group(1))
        .toList();
    expect(keys, [
      'noFileAccess',
      'noContentAccess',
      'noFormData',
      'noMixedContent',
      'safeBrowsing',
      'noMultipleWindows',
      'noDarkening',
      'wrapped',
    ]);
  });

  test('CA-021-08 / P11: sin androidx.webkit (API de la plataforma)', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(code, isNot(contains('androidx.webkit')));
    expect(gradle, isNot(contains('androidx.webkit')));
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('webkit')));
  });

  test('CA-021-08: el mapa exacto de webview_hardening_test.dart lleva las '
      'mismas claves que state(), todas en true', () {
    final kotlinKeys = RegExp(r'"(\w+)" to ')
        .allMatches(state)
        .map((m) => m.group(1)!)
        .toList();
    final source = File(_integration).readAsStringSync();
    final map = _block(
      source,
      RegExp(r'expect\(await hardening\.state\(h\.id\), \{'),
    );
    final entries = RegExp(r"'(\w+)': (\w+)")
        .allMatches(map)
        .map((m) => (m.group(1)!, m.group(2)!))
        .toList();
    expect(entries.map((e) => e.$1), kotlinKeys);
    expect(entries.map((e) => e.$2), everyElement('true'));
  });
}
