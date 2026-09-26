import 'dart:ui';

import 'package:app/features/delete/crumple_keyframes.dart';
import 'package:flutter/rendering.dart' show Matrix4, MatrixUtils;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA-004-04: arrugado igual que el prototipo (@keyframes crumple)', () {
    test('al empezar, la nota está entera, sin sombra ni facetas', () {
      final f = CrumpleFrame(0);
      expect(f.clip.first, Offset.zero);
      expect(f.clip[6], const Offset(1, 1));
      expect(f.transform, const CrumpleTransform());
      expect(f.shadow.alpha, 0);
      expect(f.facetsOpacity, 0);
      expect(f.shadeOpacity, 0);
      expect(f.trash.opacity, 0);
    });

    test('en el 22 % tiene los valores exactos del fotograma', () {
      final f = CrumpleFrame(0.22);
      expect(f.clip.first.dx, closeTo(0.11, 1e-9));
      expect(f.clip.first.dy, closeTo(0.10, 1e-9));
      expect(f.transform.rotateDeg, closeTo(-3, 1e-9));
      expect(f.transform.scaleX, closeTo(0.86, 1e-9));
      expect(f.transform.scaleY, closeTo(0.56, 1e-9));
    });

    test('en el 55 % ya es una bola y el sombreado está al máximo', () {
      final f = CrumpleFrame(0.55);
      expect(f.clip.first.dx, closeTo(0.31, 1e-9));
      expect(f.transform.rotateDeg, closeTo(-18, 1e-9));
      expect(f.shadeOpacity, 1);
      expect(f.shadow.offset, const Offset(4, 5));
    });

    test('la sombra llega a 6,8 en el 14 %', () {
      expect(CrumpleFrame(0.14).shadow.offset, const Offset(6, 8));
    });

    test('las facetas llegan a 0,55 en el 25 % de sus 1,2 s', () {
      expect(
        CrumpleFrame(0.25 * 1200 / 2200).facetsOpacity,
        closeTo(0.55, 1e-9),
      );
      expect(CrumpleFrame(1200 / 2200).facetsOpacity, closeTo(1, 1e-9));
    });

    test('cae hasta la papelera y desaparece al 91 %', () {
      final f = CrumpleFrame(0.91);
      expect(f.transform.translateY, closeTo(354, 1e-9));
      expect(f.transform.opacity, closeTo(0, 1e-9));
      expect(CrumpleFrame(0.88).transform.opacity, closeTo(1, 1e-9));
      expect(CrumpleFrame(1).transform.opacity, 0);
    });

    test('la papelera aparece a los 30 %, abre la tapa y se va al final', () {
      expect(CrumpleFrame(0.18).trash.opacity, 0);
      expect(CrumpleFrame(0.30).trash.opacity, closeTo(1, 1e-9));
      expect(CrumpleFrame(0.30).trash.dy, closeTo(0, 1e-9));
      expect(CrumpleFrame(0.70).trash.lidDeg, closeTo(38, 1e-9));
      expect(CrumpleFrame(0.91).trash.canScaleY, closeTo(0.92, 1e-9));
      expect(CrumpleFrame(1).trash.opacity, 0);
    });

    test('la transformación gira y escala alrededor del centro', () {
      const size = Size(390, 844);
      const t = CrumpleTransform(rotateDeg: -18, scaleX: 0.47, scaleY: 0.22);
      final m = Matrix4.fromFloat64List(t.matrix(size));
      final center = MatrixUtils.transformPoint(m, const Offset(195, 422));
      expect(center.dx, closeTo(195, 1e-9));
      expect(center.dy, closeTo(422, 1e-9));
      const drop = CrumpleTransform(translateY: 354);
      final moved = MatrixUtils.transformPoint(
        Matrix4.fromFloat64List(drop.matrix(const Size(390, 422))),
        const Offset(195, 211),
      );
      // Con la mitad de alto, la caída también es la mitad.
      expect(moved.dy, closeTo(211 + 177, 1e-9));
    });

    test('la malla de facetas tiene 6 × 11 celdas de 2 triángulos', () {
      expect(crumpleFacets, hasLength(6 * 11 * 2));
      for (final f in crumpleFacets) {
        for (final p in f.points) {
          expect(p.dx, inInclusiveRange(-0.1, 1.1));
          expect(p.dy, inInclusiveRange(-0.1, 1.1));
        }
      }
    });
  });
}
