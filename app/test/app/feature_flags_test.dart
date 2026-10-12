import 'package:app/app/feature_flags.dart';
import 'package:app/app/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('CA-019-28: el indicador `notifications` está apagado por defecto '
      '(P10, durante el desarrollo)', () {
    expect(FeatureFlags.notifications, isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(notificationsFlagProvider), isFalse);
    expect(container.read(notificationsAvailableProvider), isFalse);
  });

  test('CA-019-28: solo Android admite las notificaciones; iOS y otras '
      'plataformas, no', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      defaultTargetPlatform,
      TargetPlatform.android,
      reason: 'los tests corren como Android por defecto',
    );
    expect(container.read(notificationsPlatformProvider), isTrue);
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(
        fresh.read(notificationsPlatformProvider),
        isFalse,
        reason: '$platform',
      );
    }
  });

  test('CA-019-28: la fila solo se ofrece con plataforma admitida Y el '
      'indicador encendido', () {
    for (final (flag, platform, expected) in [
      (true, true, true),
      (true, false, false),
      (false, true, false),
      (false, false, false),
    ]) {
      final container = ProviderContainer(
        overrides: [
          notificationsFlagProvider.overrideWithValue(flag),
          notificationsPlatformProvider.overrideWithValue(platform),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(notificationsAvailableProvider),
        expected,
        reason: 'indicador $flag, plataforma $platform',
      );
    }
  });
}
