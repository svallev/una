import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_identity.g.dart';
import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/services/privacy_link.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/request_focus.dart';
import '../../ui/sheet_row.dart';
import '../../ui/una_icons.dart';
import '../attachments/link_confirm_sheet.dart';
import 'licenses_screen.dart';
import 'settings_page.dart';
import 'settings_route.dart';

/// Abre el nivel 1 de "Configuración y perfil" desde el menú (spec 012,
/// CA-012-01). La ruta se empuja desde el contexto de la hoja: al cerrarla, el
/// menú sigue debajo tal como estaba (CA-012-02). Termina al cerrarse.
Future<void> openSettings(BuildContext context) =>
    Navigator.of(context)
        .push(settingsRoute<void>(context, (_) => const SettingsScreen()));

/// Nivel 1: "Configuración y perfil" (spec 012, pantalla temporal). Dos
/// opciones: las licencias de código abierto y la política de privacidad, que
/// se abre en el navegador tras confirmar (CA-012-04).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.privacyUrl = AppIdentity.privacyPolicyUrl,
  });

  /// La dirección de la política (CA-012-05). Solo se cambia en los tests: la
  /// app usa siempre la de la identidad.
  final String privacyUrl;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _licensesFocus = FocusNode(debugLabel: 'settings licenses');
  final _licensesKey = GlobalKey();
  final _privacyFocus = FocusNode(debugLabel: 'settings privacy');
  final _privacyKey = GlobalKey();

  /// Una opción se está abriendo: un segundo toque no hace nada (CL-012-2).
  bool _busy = false;

  /// "No hay ninguna app para abrir este enlace." (CA-012-04).
  bool _noApp = false;

  @override
  void dispose() {
    _licensesFocus.dispose();
    _privacyFocus.dispose();
    super.dispose();
  }

  Future<void> _openLicenses() async {
    if (_busy) return;
    _busy = true;
    final back = settingsTransition(context);
    await Navigator.of(context)
        .push(settingsRoute<void>(context, (_) => const LicensesScreen()));
    if (!mounted) return;
    // Al volver, el foco es la opción que se tocó (tabla de niveles).
    requestFocusAfter(
      after: back,
      isMounted: () => mounted,
      node: _licensesFocus,
      semantics: _licensesKey,
    );
    _busy = false;
  }

  /// Comprueba que hay una app que abra la dirección, pregunta y abre en el
  /// navegador solo si se confirma. Sin app, o si falla al abrir, el aviso.
  Future<void> _openPrivacy() async {
    if (_busy) return;
    _busy = true;
    try {
      final link = privacyLink(widget.privacyUrl);
      final opener = ref.read(linkOpenerProvider);
      // Se pregunta en cada toque, sin guardar la respuesta.
      if (link == null || !await opener.canOpen(link)) return _showNoApp();
      if (!mounted) return;
      // La tarea de debajo no debe girar mientras se pregunta.
      final open = await showLinkConfirmSheet(
        context,
        link,
        allowRotation: false,
      );
      if (!mounted) return;
      if (open != true) {
        // Cancelar: el foco vuelve a la opción, cuando la hoja ya se fue.
        return requestFocusAfter(
          after: UnaMotion.sheetOut,
          isMounted: () => mounted,
          node: _privacyFocus,
          semantics: _privacyKey,
        );
      }
      if (!await opener.open(link)) return _showNoApp();
      if (mounted) setState(() => _noApp = false);
    } finally {
      _busy = false;
    }
  }

  /// El aviso bajo las opciones; se anuncia una vez por intento y no mueve el
  /// foco (CA-012-04, CA-012-11).
  void _showNoApp() {
    if (!mounted) return;
    setState(() => _noApp = true);
    final l10n = AppLocalizations.of(context);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.errNoAppForLink,
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsPage(
      title: l10n.menuSettings,
      root: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.m,
          UnaSpace.l,
          UnaSpace.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              sortKey: const OrdinalSortKey(SettingsOrder.content),
              child: SheetRow(
                icon: UnaIcons.document,
                label: l10n.settingsLicenses,
                focusNode: _licensesFocus,
                semanticsKey: _licensesKey,
                onTap: _openLicenses,
              ),
            ),
            Semantics(
              sortKey: const OrdinalSortKey(SettingsOrder.content),
              child: SheetRow(
                icon: UnaIcons.lock,
                label: l10n.settingsPrivacy,
                hint: l10n.settingsPrivacyHint,
                divider: true,
                focusNode: _privacyFocus,
                semanticsKey: _privacyKey,
                onTap: _openPrivacy,
              ),
            ),
            // Bajo las opciones, pero el lector lo lee antes (plan §8).
            if (_noApp)
              Semantics(
                container: true,
                sortKey: const OrdinalSortKey(SettingsOrder.status),
                child: Padding(
                  padding: const EdgeInsets.only(top: UnaSpace.m),
                  child: Text(
                    l10n.errNoAppForLink,
                    style: UnaTheme.mono.copyWith(
                      color: UnaColors.ink,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
