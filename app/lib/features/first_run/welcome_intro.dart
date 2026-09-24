import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/sticky_note.dart';
import '../../ui/wordmark.dart';

/// Bienvenida del primer uso (R1, CA-001-01): el texto se escribe letra a letra
/// y después se pasa al editor. Se puede saltar (toque, Intro/Espacio o lector de pantalla).
class WelcomeIntro extends StatefulWidget {
  const WelcomeIntro({
    super.key,
    required this.onDone,
    this.onShown,
    this.colorKey = 0,
  });

  /// Color de la primera nota: la bienvenida se funde con el editor del mismo
  /// color (prototipo, `introColor`).
  final int colorKey;

  final VoidCallback onDone;

  /// Se llama una vez, al mostrarse (para marcar el primer uso, CL-001-4).
  final VoidCallback? onShown;

  static const startDelay = Duration(milliseconds: 500);
  static const pauseAtEnd = Duration(milliseconds: 1000);

  @override
  State<WelcomeIntro> createState() => _WelcomeIntroState();
}

class _WelcomeIntroState extends State<WelcomeIntro> {
  Timer? _timer;
  Timer? _blink;
  bool _caretOn = true;
  bool _reduced = false;
  int _typed = 0;
  bool _started = false;
  bool _done = false;
  bool _autoAdvance = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    widget.onShown?.call();
    final total = AppLocalizations.of(context).welcomeTitle.characters.length;
    // Con lector de pantalla no se avanza solo: se espera a que el usuario la
    // salte, para no cortar la lectura (spec 001 §6).
    _autoAdvance = !MediaQuery.accessibleNavigationOf(context);
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!_reduced) {
      // Cursor de bloque que parpadea (CSS `blink 1s steps(1)`).
      _blink = Timer.periodic(UnaMotion.caretBlink ~/ 2, (_) {
        if (mounted) setState(() => _caretOn = !_caretOn);
      });
    }
    if (_reduced) {
      // Reducir movimiento: el texto aparece de golpe.
      _typed = total;
      _scheduleFinish();
      return;
    }
    _timer = Timer(WelcomeIntro.startDelay, () {
      _timer = Timer.periodic(UnaMotion.introCharStep, (t) {
        if (!mounted) return;
        setState(() => _typed++);
        if (_typed >= total) {
          t.cancel();
          _scheduleFinish();
        }
      });
    });
  }

  void _scheduleFinish() {
    if (_autoAdvance) _timer = Timer(WelcomeIntro.pauseAtEnd, _finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    _timer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _blink?.cancel();
    super.dispose();
  }

  /// Texto que se escribe letra a letra con el cursor de bloque detrás.
  Widget _typewriter(BuildContext context, String full) {
    const style = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.intro,
      fontWeight: UnaFontWeights.extrabold,
      height: 1,
      letterSpacing: UnaLetterSpacing.intro * UnaFontSizes.intro,
      color: UnaColors.ink,
    );
    final caretHeight =
        MediaQuery.textScalerOf(context).scale(UnaFontSizes.intro) * 0.8;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: full.characters.take(_typed).toString()),
          if (!_reduced)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              // Sin ancho propio (CSS: margin-right -6px): no mueve el texto.
              child: SizedBox(
                width: 0,
                height: caretHeight,
                child: OverflowBox(
                  maxWidth: UnaSizes.caretWidth,
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: _caretOn ? 1 : 0,
                    child: Container(
                      width: UnaSizes.caretWidth,
                      height: caretHeight,
                      color: UnaColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          // Reserva el espacio del texto aún no escrito para que no salte.
          TextSpan(
            text: full.characters.skip(_typed).toString(),
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final full = l10n.welcomeTitle;
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              (e.logicalKey == LogicalKeyboardKey.enter ||
                  e.logicalKey == LogicalKeyboardKey.space)) {
            _finish();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finish,
          child: StickyNote(
            colorKey: widget.colorKey,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  UnaSpace.l,
                  UnaSpace.l,
                  UnaSpace.l,
                  UnaSpace.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Misma cabecera que el editor: el logotipo no salta.
                    const SizedBox(
                      height: kMinInteractiveDimension,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wordmark(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        // Centrado, un poco por encima del centro (prototipo: 60).
                        padding: const EdgeInsets.only(
                          bottom: UnaSpace.xxl + UnaSpace.ml,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          // Se anuncia el texto completo, no letra a letra (§6).
                          child: Semantics(
                            liveRegion: true,
                            header: true,
                            label: full,
                            onTap: _finish,
                            onTapHint: l10n.skipIntroHint,
                            excludeSemantics: true,
                            child: _typewriter(context, full),
                          ),
                        ),
                      ),
                    ),
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
