import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import 'theme/tokens.g.dart';

/// Franja fija de la web de pruebas (ADR-0010): no es un producto y los datos
/// viven en memoria. Solo se usa cuando `kIsWeb`.
class WebPreviewBanner extends StatelessWidget {
  const WebPreviewBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: UnaColors.ink,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnaSpace.m,
                  vertical: UnaSpace.xs,
                ),
                child: Text(
                  AppLocalizations.of(context).webPreviewBanner,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: UnaFonts.mono,
                    fontSize: UnaFontSizes.caption,
                    fontWeight: UnaFontWeights.bold,
                    color: UnaColors.onInk,
                  ),
                ),
              ),
            ),
          ),
        ),
        // El contenido ya no necesita reservar la barra de estado.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
