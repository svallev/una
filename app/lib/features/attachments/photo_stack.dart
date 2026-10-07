import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'photo_missing_box.dart';

/// Una foto de la pila: su versión de pantalla ([image], o null si falta y se
/// ve "Foto no disponible") y su proporción (ancho / alto), que da la altura de
/// la tarjeta como en el prototipo (`height: auto`, tope del 84 % del hueco).
@immutable
class StackPhoto {
  const StackPhoto({this.image, this.aspectRatio = 3 / 4});

  final ImageProvider? image;
  final double aspectRatio;
}

/// La vista previa de un grupo de fotos en el editor (CA-016-06, tablero 14,
/// prototipo `da.stack`): **como mucho 3 fotos** una sobre otra, giradas (de
/// arriba abajo -1°, 4° y -5°; con dos, -1° y 4°) y con la **primera arriba**,
/// y la etiqueta "{n} fotos" abajo a la izquierda, blanco sobre tinta opaca
/// (≥ 4,5:1 sea cual sea la foto, DEV-53).
///
/// Fija: no se anima nunca (con reducir movimiento tampoco). Para el lector es
/// **un solo nodo**, "Vista previa: {n} fotos"; las fotos, la etiqueta y los
/// recuadros "Foto no disponible" quedan fuera de la lectura.
///
/// [photos] son las fotos a la vista (solo se pintan las 3 primeras) y
/// [count] el total del grupo (lo que dice la etiqueta).
class PhotoStack extends StatelessWidget {
  const PhotoStack({super.key, required this.photos, required this.count});

  final List<StackPhoto> photos;
  final int count;

  /// Máximo de fotos a la vista (prototipo: `ims.slice(0, 3)`).
  static const maxVisible = 3;

  /// La tarjeta de la foto [index] (0 = la primera del grupo, arriba).
  static Key cardKey(int index) => ValueKey('photo-stack-card-$index');

  // Giro y desplazamiento de atrás hacia delante (prototipo: `rots`).
  static const _poses = <({double degrees, Offset offset})>[
    (
      degrees: UnaMotion.photoStackTiltBack,
      offset: Offset(UnaSizes.photoStackBackDx, UnaSizes.photoStackBackDy),
    ),
    (
      degrees: UnaMotion.photoStackTiltMiddle,
      offset: Offset(UnaSizes.photoStackMiddleDx, UnaSizes.photoStackMiddleDy),
    ),
    (degrees: UnaMotion.photoStackTiltTop, offset: Offset.zero),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = photos.take(maxVisible).toList();
    return Semantics(
      label: l10n.a11yPhotoStack(count),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * UnaMotion.photoStackWidthFactor;
          // Con la misma regla que el prototipo: altura según la foto, sin
          // pasar del 84 % del hueco.
          final maxHeight =
              constraints.maxHeight * UnaMotion.photoStackMaxHeightFactor;
          return Stack(
            children: [
              // De atrás hacia delante: la última a la vista, primero; la
              // primera del grupo se pinta la última, encima.
              for (var i = shown.length - 1; i >= 0; i--)
                Positioned.fill(
                  child: Center(
                    child: _card(
                      index: i,
                      photo: shown[i],
                      pose: _poses[_poses.length - 1 - i],
                      width: width,
                      height: math.min(width / shown[i].aspectRatio, maxHeight),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                bottom: 0,
                child: ColoredBox(
                  color: UnaColors.photoCountFill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UnaSpace.sm - UnaSpace.xxs,
                      vertical: UnaSpace.s - UnaSpace.xxs,
                    ),
                    child: Text(
                      l10n.photoCount(count),
                      style: UnaTheme.mono.copyWith(
                        fontSize: UnaFontSizes.photoCount,
                        fontWeight: UnaFontWeights.bold,
                        color: UnaColors.photoCountText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card({
    required int index,
    required StackPhoto photo,
    required ({double degrees, Offset offset}) pose,
    required double width,
    required double height,
  }) {
    final image = photo.image;
    // `translate(dx, dy) rotate(r)` sobre el centro, como el prototipo.
    final matrix = Matrix4.translationValues(pose.offset.dx, pose.offset.dy, 0)
      ..rotateZ(pose.degrees * math.pi / 180);
    return Transform(
      key: cardKey(index),
      alignment: Alignment.center,
      transform: matrix,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: UnaColors.surface,
            border: Border.fromBorderSide(
              BorderSide(
                color: UnaColors.ink,
                width: UnaBorders.photoStackWidth,
              ),
            ),
            boxShadow: [UnaShadows.photoStack],
          ),
          child: image == null
              ? const PhotoMissingBox(framed: false)
              : Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // Sin la versión de pantalla, la tarjeta queda en blanco (la
                  // salud del grupo decide "Foto no disponible", T-016-13).
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                ),
        ),
      ),
    );
  }
}
