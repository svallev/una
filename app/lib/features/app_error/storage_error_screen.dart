import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/wordmark.dart';

/// Error recuperable de almacenamiento (CL-001-6). Nunca se borra la BD en silencio.
class StorageErrorScreen extends StatelessWidget {
  const StorageErrorScreen({
    super.key,
    required this.noSpace,
    required this.onRetry,
  });

  final bool noSpace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        // Con texto al 200 % en pantallas pequeñas se desplaza (CL-001-9).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(UnaSpace.l),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - UnaSpace.l * 2,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Wordmark(),
                    ),
                    const Spacer(),
                    Semantics(
                      liveRegion: true,
                      header: true,
                      child: Text(
                        noSpace
                            ? l10n.storageErrorNoSpace
                            : l10n.storageErrorTitle,
                        style: const TextStyle(
                          fontFamily: UnaFonts.display,
                          fontSize: UnaFontSizes.display,
                          fontWeight: UnaFontWeights.black,
                          color: UnaColors.ink,
                        ),
                      ),
                    ),
                    const Spacer(),
                    BrutalButton(label: l10n.retry, onPressed: onRetry),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
