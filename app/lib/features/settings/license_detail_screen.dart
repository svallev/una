import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/license_package.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_ring.dart';
import 'license_names.dart';
import 'settings_page.dart';

/// Un párrafo largo se trocea en partes de este tamaño como máximo (plan §6:
/// párrafos largos troceados, para no maquetar miles de caracteres de una vez).
const _maxChunk = 2000;

/// Sangrías que se respetan como máximo (cada nivel, [UnaSpace.m]): con más, el
/// texto no cabría al 200 % a 360 dp (plan §8).
const _maxIndent = 2;

/// El texto de una licencia es contenido de terceros, en inglés (CA-012-07).
const _licenseLocale = Locale('en');

/// Trocea [text] en partes de [maxLength] caracteres como máximo, por saltos de
/// línea si los hay, si no por espacios y, como último recurso, en seco. No
/// pierde nada: unir las partes con el separador usado devuelve el texto.
List<String> splitLicenseParagraph(String text, {int maxLength = _maxChunk}) {
  final chunks = <String>[];
  var rest = text;
  while (rest.length > maxLength) {
    var cut = rest.lastIndexOf('\n', maxLength);
    if (cut <= 0) cut = rest.lastIndexOf(' ', maxLength);
    if (cut <= 0) {
      chunks.add(rest.substring(0, maxLength));
      rest = rest.substring(maxLength);
    } else {
      chunks.add(rest.substring(0, cut));
      rest = rest.substring(cut + 1);
    }
  }
  chunks.add(rest);
  return chunks;
}

/// Lo que se ve en la lista del nivel 3, ya aplanado.
sealed class _Item {
  const _Item();
}

/// "Licencia n de total" (solo si el elemento tiene varias).
final class _Heading extends _Item {
  const _Heading(this.n, this.total);

  final int n;
  final int total;
}

final class _Paragraph extends _Item {
  const _Paragraph(this.text, this.indent);

  final String text;
  final int indent;
}

/// El elemento no tiene texto legible (CL-012-10).
final class _Unreadable extends _Item {
  const _Unreadable();
}

List<_Item> _itemsOf(LicensePackage package) {
  final texts = [
    for (final t in package.texts)
      if (t.paragraphs.any((p) => p.text.trim().isNotEmpty)) t,
  ];
  // Un elemento sin ningún texto legible sale con su error (CL-012-10).
  if (texts.isEmpty) return const [_Unreadable()];
  return [
    for (final (i, text) in texts.indexed) ...[
      // Con una sola licencia, el título del nivel ya es el nombre y no hace
      // falta otro encabezado (propietario, 2026-09-30).
      if (texts.length > 1) _Heading(i + 1, texts.length),
      for (final p in text.paragraphs)
        if (p.text.trim().isNotEmpty)
          for (final chunk in splitLicenseParagraph(p.text))
            _Paragraph(chunk, p.indent),
    ],
  ];
}

/// Nivel 3 de la Configuración: el texto completo de la licencia de un
/// elemento (spec 012, CA-012-03), con desplazamiento vertical. El título (y el
/// foco al llegar) es el nombre del elemento; con varias licencias, cada texto
/// lleva su encabezado "Licencia n de total". El texto es plano: sin enlaces
/// (CA-012-03, CL-012-12) y con la marca de inglés para el lector (CA-012-07).
class LicenseDetailScreen extends StatefulWidget {
  const LicenseDetailScreen({super.key, required this.package});

  final LicensePackage package;

  @override
  State<LicenseDetailScreen> createState() => _LicenseDetailScreenState();
}

class _LicenseDetailScreenState extends State<LicenseDetailScreen> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'license text');
  late final List<_Item> _items = _itemsOf(widget.package);
  bool _focused = false;

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Flechas, AvPág, RePág, Inicio y Fin desplazan el texto (CA-012-12). Sin
  /// animación: así respeta "reducir movimiento".
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_scroll.hasClients) {
      return KeyEventResult.ignored;
    }
    final position = _scroll.position;
    final page = position.viewportDimension * 0.9;
    final double? target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => position.pixels + UnaSizes.minTouchTarget,
      LogicalKeyboardKey.arrowUp => position.pixels - UnaSizes.minTouchTarget,
      LogicalKeyboardKey.pageDown => position.pixels + page,
      LogicalKeyboardKey.pageUp => position.pixels - page,
      LogicalKeyboardKey.home => position.minScrollExtent,
      LogicalKeyboardKey.end => position.maxScrollExtent,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _scroll.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SettingsPage(
      title: licenseDisplayName(l10n, widget.package),
      root: false,
      // Sin nodo accesible propio: sería una parada enfocable sin nombre
      // (CA-013-04). Con teclado sigue enfocándose, con su anillo y sus teclas.
      child: Focus(
        focusNode: _focus,
        includeSemantics: false,
        onKeyEvent: _onKey,
        onFocusChange: (v) => setState(() => _focused = v),
        child: FocusRing(
          inside: true,
          visible: _focused && showsFocusHighlight,
          child: ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
              UnaSpace.l,
              UnaSpace.s,
              UnaSpace.l,
              UnaSpace.xl + bottom,
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) => switch (_items[i]) {
              _Heading(:final n, :final total) => _HeadingText(
                l10n.licensesTextOf(n, total),
              ),
              _Paragraph(:final text, :final indent) => _ParagraphText(
                text,
                indent,
              ),
              _Unreadable() => Padding(
                padding: const EdgeInsets.only(top: UnaSpace.m),
                child: Text(
                  l10n.licensesError,
                  style: UnaTheme.mono.copyWith(
                    color: UnaColors.ink,
                    height: 1.5,
                  ),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// "Licencia n de total": encabezado, en el idioma de la app.
class _HeadingText extends StatelessWidget {
  const _HeadingText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: UnaSpace.l, bottom: UnaSpace.xs),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: UnaFonts.display,
            fontSize: UnaFontSizes.bodyL,
            fontWeight: UnaFontWeights.bold,
            color: UnaColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Un párrafo de la licencia: texto plano, marcado como inglés para el lector,
/// con su sangría (limitada) o centrado (`indent` -1, como en Flutter).
class _ParagraphText extends StatelessWidget {
  const _ParagraphText(this.text, this.indent);

  final String text;
  final int indent;

  @override
  Widget build(BuildContext context) {
    final centered = indent < 0;
    return Semantics(
      localeForSubtree: _licenseLocale,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: UnaSpace.s,
          start: centered ? 0 : UnaSpace.m * math.min(indent, _maxIndent),
        ),
        child: Text(
          text,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: UnaTheme.mono.copyWith(color: UnaColors.ink, height: 1.5),
        ),
      ),
    );
  }
}
