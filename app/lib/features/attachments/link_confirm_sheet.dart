import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OrdinalSortKey;
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/link_target.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/una_sheet.dart';

/// Pregunta antes de abrir un enlace de un PDF (CA-008-12): "¿Abrir {host} en
/// el navegador?" o "¿Abrir {destino} con otra app?". Devuelve true solo con
/// "Abrir"; "Cancelar", tocar fuera, atrás, deslizar o Esc devuelven null.
Future<bool?> showLinkConfirmSheet(BuildContext context, LinkTarget target) =>
    showUnaSheet<bool>(
      context,
      builder: (_) => LinkConfirmSheet(target: target),
    );

class LinkConfirmSheet extends StatefulWidget {
  const LinkConfirmSheet({super.key, required this.target});

  final LinkTarget target;

  /// La pregunta: el destino real y entero (saneado por `LinkPolicy`).
  static String question(AppLocalizations l10n, LinkTarget target) =>
      switch (target) {
        WebLink(:final host) => l10n.openInBrowserConfirm(host),
        MailLink(:final display) => l10n.openInAppConfirm(display),
        PhoneLink(:final display) => l10n.openInAppConfirm(display),
        InternalLink() || BlockedLink() => '',
      };

  @override
  State<LinkConfirmSheet> createState() => _LinkConfirmSheetState();
}

class _LinkConfirmSheetState extends State<LinkConfirmSheet> {
  bool _chosen = false;

  void _close(bool? open) {
    if (_chosen) return;
    _chosen = true;
    Navigator.of(context).pop(open);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final question = LinkConfirmSheet.question(l10n, widget.target);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _close(null),
      },
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: question,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            UnaSpace.l,
            UnaSpace.ml + UnaSpace.xxs,
            UnaSpace.l,
            UnaSpace.xxl - UnaSpace.xxs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReadOrder(
                1,
                child: Semantics(
                  header: true,
                  // Entero, con saltos de línea si no cabe (CA-008-12).
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontFamily: UnaFonts.display,
                      fontSize: UnaFontSizes.heading,
                      fontWeight: UnaFontWeights.extrabold,
                      color: UnaColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _gap + UnaSpace.s),
              _ReadOrder(
                2,
                child: BrutalButton(
                  label: l10n.linkConfirmOpen,
                  height: UnaSizes.confirmButton,
                  fontSize: UnaFontSizes.option,
                  onPressed: () => _close(true),
                ),
              ),
              const SizedBox(height: _gap + UnaSpace.xs),
              // La acción segura, primera para el lector y con el foco del
              // teclado (CA-008-21).
              _ReadOrder(
                0,
                child: BrutalButton(
                  label: l10n.linkConfirmCancel,
                  height: UnaSizes.ghostButton,
                  fontSize: UnaFontSizes.body,
                  ghost: true,
                  autofocus: true,
                  onPressed: () => _close(null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _gap = UnaSpace.sm + UnaSpace.xxs;
}

class _ReadOrder extends StatelessWidget {
  const _ReadOrder(this.order, {required this.child});
  final double order;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, sortKey: OrdinalSortKey(order), child: child);
}
