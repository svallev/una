import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/una_icons.dart';
import '../../ui/wordmark.dart';

/// "Todo hecho." (R12, spec 003, CA-003-05): no queda nada pendiente.
/// Prototipo: estado `vacio` con `allDone` (fondo papel, texto de 56 px).
class AllDoneScreen extends StatefulWidget {
  const AllDoneScreen({super.key, required this.onCreate});

  /// Abre el editor para crear una tarea (CA-003-10).
  final VoidCallback onCreate;

  @override
  State<AllDoneScreen> createState() => _AllDoneScreenState();
}

class _AllDoneScreenState extends State<AllDoneScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: UnaMotion.enter,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enter.isAnimating && _enter.value == 0) _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// Prototipo: `enter` sube 20 px (con reducir movimiento, solo fundido).
  static const _rise = UnaSpace.ml;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    const titleStyle = TextStyle(
      fontFamily: UnaFonts.display,
      fontSize: UnaFontSizes.hero,
      fontWeight: UnaFontWeights.extrabold,
      height: 0.98,
      letterSpacing: UnaLetterSpacing.tightest * UnaFontSizes.hero,
      color: UnaColors.ink,
    );
    return Scaffold(
      backgroundColor: UnaColors.paper,
      body: SafeArea(
        child: LayoutBuilder(
          // Con texto grande se desplaza en lugar de cortarse (CL-001-9).
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
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
                      const SizedBox(
                        height: kMinInteractiveDimension,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wordmark(),
                        ),
                      ),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _enter,
                          builder: (context, child) {
                            final v = UnaMotion.standardCurve.transform(
                              _enter.value,
                            );
                            return Opacity(
                              opacity: v,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  reduced ? 0 : _rise * (1 - v),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Se lee como un solo texto (CA-003-07).
                              Semantics(
                                header: true,
                                label:
                                    '${l10n.emptyDoneTitle1} ${l10n.emptyDoneTitle2}',
                                excludeSemantics: true,
                                child: Text(
                                  '${l10n.emptyDoneTitle1}\n${l10n.emptyDoneTitle2}',
                                  style: titleStyle,
                                ),
                              ),
                              const SizedBox(height: UnaSpace.ml),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: UnaSizes.bodyMaxWidth,
                                ),
                                child: Text(
                                  l10n.emptyDoneBody,
                                  style: const TextStyle(
                                    fontFamily: UnaFonts.mono,
                                    fontSize: UnaFontSizes.bodyS,
                                    height: 1.5,
                                    color: UnaColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      BrutalButton(
                        label: l10n.emptyCreate,
                        icon: UnaIcons.plus,
                        iconSize: UnaSizes.icon,
                        iconStroke: UnaSizes.iconStroke,
                        height: UnaSizes.emptyButton,
                        onPressed: widget.onCreate,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
