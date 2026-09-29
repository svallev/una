import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fugas de idioma en lo que ve el lector de pantalla (spec 010, CA-010-07).
///
/// Lee los dos ARB y construye, para cada idioma, los **fragmentos literales
/// del otro** (los trozos de texto que quedan entre placeholders y sintaxis
/// ICU). Un fragmento solo cuenta si tiene al menos [minFragmentLength]
/// caracteres y no aparece en ningún texto del idioma propio: así se
/// descartan "PDF", "MB", "https://" y los textos iguales en los dos idiomas.
/// Las dos comprobaciones van por palabra completa: "Cancel" (EN) no salta
/// dentro de "Cancelar" (ES), pero sí en "Pulsa Cancel".
///
/// Uso en un test de widgets (el árbol semántico está activo por defecto en
/// `testWidgets`):
///
/// ```dart
/// expectNoL10nLeaks(tester, languageCode: 'es');
/// ```
///
/// Los textos de la tarea que se pinten deben ser neutros (ni ES ni EN) para
/// no provocar falsos positivos: el texto del usuario queda fuera de CA-010-07.
class L10nLeaks {
  L10nLeaks._(this._messages);

  /// Lee `lib/l10n/app_es.arb` y `lib/l10n/app_en.arb` (los tests se ejecutan
  /// desde `app/`).
  factory L10nLeaks.load() => _cache ??= L10nLeaks._({
    for (final lang in languages) lang: _readArb('lib/l10n/app_$lang.arb'),
  });

  static L10nLeaks? _cache;

  /// Idiomas de la app (CA-010-01).
  static const languages = ['es', 'en'];

  /// Longitud mínima de un fragmento para contar como fuga (plan §5 y §7).
  static const minFragmentLength = 4;

  /// Lista blanca explícita: fragmentos que no cuentan como fuga aunque pasen
  /// los filtros. Cada entrada, con su motivo. Vacía de momento.
  static const allowlist = <String>{};

  final Map<String, Map<String, String>> _messages;
  final Map<String, Set<String>> _foreign = {};

  /// Mensajes del ARB de [languageCode] (sin `@@locale` ni metadatos).
  Map<String, String> messages(String languageCode) => _messages[languageCode]!;

  /// Fragmentos del otro idioma que delatan una fuga en [languageCode].
  Set<String> foreignFragments(String languageCode) =>
      _foreign.putIfAbsent(languageCode, () {
        final own = messages(languageCode).values.toList();
        final other = languages.singleWhere((l) => l != languageCode);
        return {
          for (final fragment in messages(
            other,
          ).values.expand(arbLiteralFragments))
            if (fragment.length >= minFragmentLength &&
                !own.any((m) => _containsWord(m, fragment)))
              fragment,
        };
      });

  /// Una descripción por cada texto de [texts] que contiene algún fragmento
  /// del otro idioma (con los fragmentos encontrados). Vacía si no hay fugas.
  List<String> leaksIn(
    Iterable<String> texts, {
    required String languageCode,
    Set<String> allowed = const {},
  }) {
    final fragments = foreignFragments(languageCode)
        .difference({...allowlist, ...allowed});
    return [
      for (final text in texts)
        if ([
              for (final f in fragments)
                if (_containsWord(text, f)) '"$f"',
            ]
            case final hits when hits.isNotEmpty)
          '"$text" (${hits.join(', ')})',
    ];
  }

  static Map<String, String> _readArb(String path) {
    final json = jsonDecode(File(path).readAsStringSync()) as Map;
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (!(key as String).startsWith('@')) key: value as String,
    };
  }
}

/// Fragmentos literales de un mensaje ARB: el texto que queda al quitar los
/// placeholders (`{text}`) y la sintaxis ICU (`{count, plural, =1{…}
/// other{…}}`), sin espacios en los extremos y sin los vacíos.
List<String> arbLiteralFragments(String message) {
  final fragments = <String>[];
  _IcuScanner(message, fragments).parseMessage(topLevel: true);
  return [
    for (final f in fragments)
      if (f.trim().isNotEmpty) f.trim(),
  ];
}

/// Recorre un mensaje ICU sin `'` de escape (`l10n.yaml` no activa
/// `use-escaping`).
class _IcuScanner {
  _IcuScanner(this.source, this.out);

  final String source;
  final List<String> out;
  int pos = 0;

  /// Lee texto hasta el final o hasta la `}` que cierra la rama actual.
  void parseMessage({required bool topLevel}) {
    final buffer = StringBuffer();
    while (pos < source.length) {
      final char = source[pos];
      if (char == '}' && !topLevel) break;
      if (char == '{') {
        out.add(buffer.toString());
        buffer.clear();
        _parseArgument();
      } else {
        buffer.write(char);
        pos++;
      }
    }
    out.add(buffer.toString());
  }

  /// `{name}` o `{name, plural|select, sel{…} sel{…}}`, desde la `{`.
  void _parseArgument() {
    pos++; // {
    final end = source.indexOf(RegExp('[,}]'), pos);
    pos = end;
    if (source[pos] == '}') {
      pos++;
      return;
    }
    pos = source.indexOf(',', pos + 1) + 1; // salta el tipo
    while (true) {
      while (source[pos] == ' ') {
        pos++;
      }
      if (source[pos] == '}') {
        pos++;
        return;
      }
      pos = source.indexOf('{', pos) + 1; // salta el selector
      parseMessage(topLevel: false);
      pos++; // }
    }
  }
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// [fragment] aparece en [text] sin letras ni números pegados por delante
/// (si empieza por una) ni por detrás (si termina por una).
bool _containsWord(String text, String fragment) {
  final checkStart = _wordChar.hasMatch(fragment[0]);
  final checkEnd = _wordChar.hasMatch(fragment[fragment.length - 1]);
  for (
    var i = text.indexOf(fragment);
    i >= 0;
    i = text.indexOf(fragment, i + 1)
  ) {
    final end = i + fragment.length;
    final startOk = !checkStart || i == 0 || !_wordChar.hasMatch(text[i - 1]);
    final endOk =
        !checkEnd || end == text.length || !_wordChar.hasMatch(text[end]);
    if (startOk && endOk) return true;
  }
  return false;
}

/// Todos los textos que el árbol semántico expone al lector de pantalla:
/// `label`, `hint`, `value`, `increasedValue`, `decreasedValue`, `tooltip`,
/// y los nombres y pistas de las acciones personalizadas (Flutter guarda ahí
/// también las pistas de toque y pulsación larga, `onTapHint`).
List<String> semanticsTexts(WidgetTester tester) {
  final texts = <String>[];
  bool visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    texts.addAll([
      data.label,
      data.hint,
      data.value,
      data.increasedValue,
      data.decreasedValue,
      data.tooltip,
      for (final id in data.customSemanticsActionIds ?? const <int>[])
        if (CustomSemanticsAction.getAction(id) case final action?) ...[
          ?action.label,
          ?action.hint,
        ],
    ]);
    node.visitChildren(visit);
    return true;
  }

  for (final RenderView view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return [
    for (final t in texts)
      if (t.isNotEmpty) t,
  ];
}

/// Fugas de idioma en el árbol semántico y en los anuncios. Si no se pasan
/// [announcements], se toman con `tester.takeAnnouncements()` (y se vacían).
List<String> findL10nLeaks(
  WidgetTester tester, {
  required String languageCode,
  List<CapturedAccessibilityAnnouncement>? announcements,
  Set<String> allowed = const {},
}) {
  final leaks = L10nLeaks.load();
  final said = announcements ?? tester.takeAnnouncements();
  return [
    for (final leak in leaks.leaksIn(
      semanticsTexts(tester),
      languageCode: languageCode,
      allowed: allowed,
    ))
      'semántica: $leak',
    for (final leak in leaks.leaksIn(
      said.map((a) => a.message),
      languageCode: languageCode,
      allowed: allowed,
    ))
      'anuncio: $leak',
  ];
}

/// Falla si el árbol semántico o los anuncios contienen textos del otro
/// idioma (CA-010-07). Ver [findL10nLeaks].
void expectNoL10nLeaks(
  WidgetTester tester, {
  required String languageCode,
  List<CapturedAccessibilityAnnouncement>? announcements,
  Set<String> allowed = const {},
}) {
  final found = findL10nLeaks(
    tester,
    languageCode: languageCode,
    announcements: announcements,
    allowed: allowed,
  );
  expect(
    found,
    isEmpty,
    reason: 'Fugas de idioma en la app en "$languageCode" (CA-010-07)',
  );
}
