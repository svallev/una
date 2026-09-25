import 'package:flutter/material.dart';

import '../app/app_identity.g.dart';
import '../app/theme/tokens.g.dart';

/// Logotipo (decorativo: excluido de la semántica, spec 001 §6).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Text(
        AppIdentity.wordmark,
        style: TextStyle(
          fontFamily: UnaFonts.display,
          fontSize: UnaFontSizes.title,
          fontWeight: UnaFontWeights.black,
          letterSpacing: UnaLetterSpacing.tightest * UnaFontSizes.title,
          color: UnaColors.ink,
        ),
      ),
    );
  }
}
