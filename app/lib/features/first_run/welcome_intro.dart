import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/wordmark.dart';

/// Bienvenida del primer uso (R1, CA-001-01): el texto se escribe letra a letra
/// y después se pasa al editor. Se puede saltar (toque, Intro/Espacio o lector de pantalla).
class WelcomeIntro extends StatefulWidget {
  const WelcomeIntro({super.key, required this.onDone});

  final VoidCallback onDone;

  static const startDelay = Duration(milliseconds: 500);
  static const pauseAtEnd = Duration(milliseconds: 1000);

  @override
  State<WelcomeIntro> createState() => _WelcomeIntroState();
}

class _WelcomeIntroState extends State<WelcomeIntro> {
  Timer? _timer;
  int _typed = 0;
  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final total = AppLocalizations.of(context).welcomeTitle.characters.length;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reducir movimiento: el texto aparece de golpe.
      _typed = total;
      _timer = Timer(WelcomeIntro.pauseAtEnd, _finish);
      return;
    }
    _timer = Timer(WelcomeIntro.startDelay, () {
      _timer = Timer.periodic(UnaMotion.introCharStep, (t) {
        if (!mounted) return;
        setState(() => _typed++);
        if (_typed >= total) {
          t.cancel();
          _timer = Timer(WelcomeIntro.pauseAtEnd, _finish);
        }
      });
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final full = l10n.welcomeTitle;
    final shown = full.characters.take(_typed).toString();
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(UnaSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(),
                  const Spacer(),
                  // Se anuncia el texto completo, no letra a letra (spec 001 §6).
                  Semantics(
                    liveRegion: true,
                    header: true,
                    label: full,
                    hint: l10n.skipIntroHint,
                    onTap: _finish,
                    excludeSemantics: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: shown),
                          // Reserva el espacio del texto aún no escrito para que no salte.
                          TextSpan(
                            text: full.characters.skip(_typed).toString(),
                            style: const TextStyle(color: Color(0x00000000)),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontFamily: UnaFonts.display,
                        fontSize: UnaFontSizes.display,
                        fontWeight: UnaFontWeights.black,
                        height: 1.05,
                        letterSpacing:
                            UnaLetterSpacing.tighter * UnaFontSizes.display,
                        color: UnaColors.ink,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
