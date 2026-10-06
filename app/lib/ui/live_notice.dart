import 'package:flutter/material.dart';

import '../app/theme/tokens.g.dart';

/// Aviso de error en una región viva (spec 015, CA-015-12 "Los avisos" y
/// CA-015-25): "No se pudo guardar el ajuste.", "No hay ninguna app para abrir
/// este enlace.".
///
/// - **Región viva con la marca de idioma de la app** (`appFrame` la pone sobre
///   todo el contenido; el aviso la hereda): su texto se lee con la voz del
///   idioma de la app. No se usan los anuncios del sistema (`sendAnnouncement`).
/// - **Una vez por intento:** una región viva con el mismo texto no se vuelve a
///   anunciar, así que cada intento fallido lleva su [attempt] como clave: el
///   aviso se retira y se vuelve a insertar, sin duplicar el nodo.
/// - **A la vista:** al aparecer se desplaza hasta él (`ensureVisible`), porque
///   el árbol semántico no incluye lo que queda fuera del área visible
///   (también con el texto al 200 %).
/// - Texto de color `error` (≥ 4,5:1 sobre el papel): no depende solo del color.
///
/// Quien lo usa decide cuándo se ve (se quita con la siguiente acción con
/// éxito o al salir del nivel) y su sangría lateral.
class LiveNotice extends StatelessWidget {
  const LiveNotice({
    super.key,
    required this.text,
    required this.attempt,
    this.padding = const EdgeInsets.only(top: UnaSpace.s),
  });

  final String text;

  /// Número del intento fallido; cada fallo lo cambia (también con el mismo
  /// texto).
  final int attempt;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey<int>(attempt),
    child: _Notice(text: text, padding: padding),
  );
}

class _Notice extends StatefulWidget {
  const _Notice({required this.text, required this.padding});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // `ensureVisible` con `keepVisibleAtEnd` solo desplaza hacia delante:
      // con el aviso por encima de la ventana hace falta también el otro
      // sentido.
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: widget.padding,
    child: Semantics(
      liveRegion: true,
      container: true,
      label: widget.text,
      excludeSemantics: true,
      child: Text(
        widget.text,
        style: const TextStyle(
          fontFamily: UnaFonts.mono,
          fontSize: UnaFontSizes.caption,
          fontWeight: UnaFontWeights.bold,
          height: 1.4,
          color: UnaColors.error,
        ),
      ),
    ),
  );
}
