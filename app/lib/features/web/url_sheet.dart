import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/services/web_address.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/sheet_row.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';

/// Abre la hoja "Cargar URL" (CA-009-01; prototipo "HOJA: cargar una URL").
/// Devuelve la dirección ya validada y normalizada (CA-009-02), o null si se
/// cierra sin abrir nada.
Future<String?> showUrlSheet(BuildContext context) =>
    showUnaSheet<String>(context, builder: (_) => const UrlSheet());

/// Hoja "Cargar URL": título con la X, un campo, la ayuda y "Abrir". La
/// validación y el error viven aquí; crear la tarea es cosa del editor.
class UrlSheet extends StatefulWidget {
  const UrlSheet({super.key});

  @override
  State<UrlSheet> createState() => _UrlSheetState();
}

class _UrlSheetState extends State<UrlSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  WebAddressError? _error;

  /// Ya se ha entregado una dirección válida: un segundo toque en "Abrir"
  /// mientras la hoja baja no cierra nada más (CA-009-03).
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _message(AppLocalizations l10n, WebAddressError error) =>
      switch (error) {
        WebAddressError.empty => l10n.urlErrEmpty,
        WebAddressError.scheme => l10n.urlErrScheme,
        WebAddressError.invalid => l10n.urlErrInvalid,
      };

  void _submit() {
    if (_done) return;
    switch (validateWebAddress(_controller.text)) {
      case ValidWebAddress(:final url):
        _done = true;
        Navigator.of(context).pop(url);
      case InvalidWebAddress(:final error):
        setState(() => _error = error);
        // El foco y el texto se quedan en el campo (CA-009-02).
        _focus.requestFocus();
        // Un único anuncio, también si el mismo error se repite.
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            _message(AppLocalizations.of(context), error),
            Directionality.of(context),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    const fieldStyle = TextStyle(
      fontFamily: UnaFonts.mono,
      fontSize: UnaFontSizes.urlField,
      color: UnaColors.ink,
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.urlSheetTitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.sm,
          UnaSpace.l,
          UnaSpace.xxl - UnaSpace.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              label: l10n.urlSheetTitle,
              closeLabel: l10n.attachSheetClose,
            ),
            const SizedBox(height: UnaSpace.sm),
            // Como el campo del prototipo: borde de 3 px, fondo blanco.
            Container(
              constraints: const BoxConstraints(minHeight: UnaSizes.urlField),
              padding: const EdgeInsets.symmetric(
                horizontal: UnaSizes.urlFieldPadX,
              ),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                color: UnaColors.surface,
                border: Border.fromBorderSide(
                  BorderSide(
                    color: UnaColors.ink,
                    width: UnaBorders.strongWidth,
                  ),
                ),
              ),
              child: MergeSemantics(
                child: Semantics(
                  label: l10n.urlSheetTitle,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    // El teclado no aprende de lo que se escribe
                    // (MASVS-STORAGE-2).
                    enableIMEPersonalizedLearning: false,
                    style: fieldStyle,
                    cursorColor: UnaColors.ink,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onEditingComplete: _submit,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: l10n.urlPlaceholder,
                      hintStyle: fieldStyle.copyWith(
                        color: UnaColors.placeholder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: UnaSpace.sm),
              Text(
                _message(l10n, error),
                style: const TextStyle(
                  fontFamily: UnaFonts.mono,
                  fontSize: UnaFontSizes.tag,
                  color: UnaColors.error,
                ),
              ),
            ],
            const SizedBox(height: UnaSpace.sm),
            Text(
              l10n.urlHelp,
              style: const TextStyle(
                fontFamily: UnaFonts.mono,
                fontSize: UnaFontSizes.micro,
                height: 1.5,
                color: UnaColors.ink,
              ),
            ),
            const SizedBox(height: UnaSpace.sm + UnaSpace.xs),
            BrutalButton(
              label: l10n.urlOpen,
              trailingIcon: UnaIcons.arrowRight,
              iconSize: UnaSizes.iconM,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
