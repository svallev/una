import 'db/open_database_native.dart';
import 'drift_task_repository.dart';
import 'repository_factory.dart';

Future<Repositories> openRepositories() async {
  final repo = DriftTaskRepository(await openAppDatabase());
  await repo.currentTask(); // fuerza la apertura: los errores de disco salen aquí (CL-001-6)
  return (tasks: repo, settings: repo);
}
