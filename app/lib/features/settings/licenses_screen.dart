import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'settings_page.dart';

/// Nivel 2 de la Configuración: la lista de licencias de código abierto (spec
/// 012, CA-012-03). De momento solo el marco (título y Volver); la lista, sus
/// estados de carga y error y el nivel 3 llegan en T-012-06.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsPage(
      title: l10n.licensesTitle,
      root: false,
      child: const SizedBox.shrink(),
    );
  }
}
