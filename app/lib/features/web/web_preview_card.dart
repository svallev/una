import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';

/// La tarea web en la web de pruebas (CL-009-5, ADR-0010): sin WebView, la
/// tarjeta del prototipo (pantalla 11) bajo la barra: el dominio en grande, la
/// dirección entera y "Abrir página ↗", que la abre en una pestaña nueva.
///
/// Si no cabe (texto grande), se desplaza; si sobra sitio, el botón va abajo,
/// como en el prototipo.
class WebPreviewCard extends StatelessWidget {
  const WebPreviewCard({
    super.key,
    required this.host,
    required this.address,
    required this.onOpen,
  });

  /// El dominio, como en la barra.
  final String host;

  /// La dirección guardada, entera.
  final String address;

  /// "Abrir página ↗".
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(UnaSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    host,
                    style: const TextStyle(
                      fontFamily: UnaFonts.display,
                      fontSize: UnaFontSizes.display,
                      fontWeight: UnaFontWeights.extrabold,
                      height: 1.02,
                      letterSpacing:
                          UnaLetterSpacing.tighter * UnaFontSizes.display,
                      color: UnaColors.ink,
                    ),
                  ),
                  const SizedBox(height: UnaSpace.s),
                  Text(
                    address,
                    style: UnaTheme.mono.copyWith(
                      fontSize: UnaFontSizes.tag,
                      height: 1.5,
                      color: UnaColors.ink,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: UnaSpace.l),
                  BrutalButton(
                    label: l10n.urlOpenPageWeb,
                    height: UnaSizes.ghostButton,
                    fontSize: UnaFontSizes.body,
                    onPressed: onOpen,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
