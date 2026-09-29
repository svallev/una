import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../ui/una_icons.dart';

/// Barra negra de la tarea web (prototipo, pantalla 11; CA-009-06): el
/// candado, el dominio real (CA-009-14) y la insignia "WEB". Decorativa para
/// el lector: la lectura, con el dominio entero, la hace el nodo de la tarea
/// (CA-009-18).
///
/// Si el dominio no cabe, se recorta **por el principio** ("…ejemplo.com"),
/// para que siempre se vea su final (CA-009-14).
class WebBar extends StatelessWidget {
  const WebBar({super.key, required this.host, required this.badge});

  /// El dominio, ya saneado (`displayHost`).
  final String host;

  /// "WEB".
  final String badge;

  @override
  Widget build(BuildContext context) {
    final style = UnaTheme.mono.copyWith(
      fontSize: UnaFontSizes.micro,
      color: UnaColors.onInk,
    );
    return ExcludeSemantics(
      child: ColoredBox(
        color: UnaColors.ink,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnaSpace.l,
            vertical: UnaSpace.s,
          ),
          child: Row(
            children: [
              const UnaIcon(
                UnaIcons.lock,
                size: UnaSizes.webBarIcon,
                strokeWidth: UnaSizes.iconStrokeBold,
                color: UnaColors.onInk,
              ),
              const SizedBox(width: UnaSpace.s),
              Expanded(child: HeadEllipsisText(host, style: style)),
              const SizedBox(width: UnaSpace.s),
              Text(
                badge,
                style: style.copyWith(fontWeight: UnaFontWeights.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una línea de texto que, si no cabe, se recorta por el principio con "…"
/// delante (CA-009-14). Siempre de izquierda a derecha: es un dominio.
class HeadEllipsisText extends StatelessWidget {
  const HeadEllipsisText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        headEllipsis(
          text,
          style: style,
          maxWidth: constraints.maxWidth,
          textScaler: scaler,
        ),
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

/// El carácter que marca el recorte (tipográfico, no un texto de la interfaz).
const headEllipsisMark = '…';

/// [text] tal cual si cabe en [maxWidth]; si no, "…" seguido del final más
/// largo de [text] que quepa (por grafemas: nunca parte un carácter).
String headEllipsis(
  String text, {
  required TextStyle style,
  required double maxWidth,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  bool fits(String candidate) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width <= maxWidth;
  }

  if (!maxWidth.isFinite || fits(text)) return text;
  final chars = text.characters.toList();
  String tail(int from) => headEllipsisMark + chars.skip(from).join();
  // El menor inicio con el que cabe: búsqueda binaria.
  var low = 1;
  var high = chars.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (fits(tail(mid))) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }
  return tail(low);
}
