import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';

/// Franja negra del PDF (prototipo `nx.ext`/`nx.name`/`nx.fsize`, CA-008-08):
/// "PDF" en negrita, el nombre en una línea con "…" y el tamaño. Decorativa
/// para el lector: la lectura la hace la tarea (CA-008-20).
class PdfStrip extends StatelessWidget {
  const PdfStrip({
    super.key,
    required this.type,
    required this.name,
    required this.size,
    this.endPadding = UnaSpace.l,
  });

  final String type;
  final String name;
  final String size;

  /// Hueco a la derecha (en el editor, para "Quitar adjunto").
  final double endPadding;

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
          padding: EdgeInsetsDirectional.fromSTEB(
            UnaSpace.l,
            UnaSpace.s,
            endPadding,
            UnaSpace.s,
          ),
          child: Row(
            children: [
              Text(
                type,
                style: style.copyWith(fontWeight: UnaFontWeights.bold),
              ),
              const SizedBox(width: UnaSizes.pdfStripGap),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const SizedBox(width: UnaSizes.pdfStripGap),
              Text(size, style: style),
            ],
          ),
        ),
      ),
    );
  }
}
