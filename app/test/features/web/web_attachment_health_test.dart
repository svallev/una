import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/features/attachments/attachment_health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CA-009-04: una tarea web no tiene archivos que falten: su salud es '
      'ok (nunca "Adjunto no disponible")', () async {
    final store = MemoryAttachmentStore();
    final container = ProviderContainer(
      overrides: [attachmentStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final web = await store.commit(
      const StagedWeb(id: 'web', url: 'https://congreso.example.org/'),
      DateTime.utc(2026, 9, 28),
    );
    final provider = attachmentHealthProvider(web);
    container.listen(provider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(provider).health, AttachmentHealth.ok);
  });
}
