import 'package:app/app/providers.dart';
import 'package:app/data/db/open_database_native.dart';
import 'package:app/data/drift_task_repository.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/features/settings/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA-015-17, CA-017-16: Ajustes solo escribe las claves `locale`, '
      '`keepScreenOn` y `lockZoom`, y el esquema no cambia', () async {
    final db = openInMemoryDatabase();
    addTearDown(db.close);
    final repo = DriftTaskRepository(db);
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        settingsRepositoryProvider.overrideWithValue(repo),
        bootStateProvider.overrideWithValue(await readBootState(repo, repo)),
      ],
    );
    addTearDown(container.dispose);

    final settings = container.read(settingsProvider.notifier);
    expect(await settings.saveLocale(LocaleChoice.en), SaveResult.saved);
    expect(await settings.setKeepScreenOn(true), SaveResult.saved);
    expect(await settings.saveLocale(LocaleChoice.es), SaveResult.saved);
    expect(await settings.setLockZoom(true), SaveResult.saved);

    final keys = {
      for (final r in await db.select(db.settingEntries).get()) r.key,
    };
    expect(keys, {'locale', 'keepScreenOn', 'lockZoom'});
    expect(db.schemaVersion, 3); // v3: spec 016 (position)
  });

  test(
    'CA-015-17: lo guardado es solo el texto JSON de cada ajuste (T-2)',
    () async {
      final db = openInMemoryDatabase();
      addTearDown(db.close);
      final repo = DriftTaskRepository(db);
      await repo.setLocale(LocaleChoice.es);
      await repo.setKeepScreenOn(true);
      await repo.setLockZoom(true);
      final values = [
        for (final r in await db.select(db.settingEntries).get()) r.value,
      ];
      expect(values, unorderedEquals(['"es"', 'true', 'true']));
    },
  );
}
