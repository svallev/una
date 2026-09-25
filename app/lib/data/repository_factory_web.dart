import 'in_memory_task_repository.dart';
import 'repository_factory.dart';

/// Web de pruebas: los datos viven en memoria y se pierden al recargar
/// ("Versión de pruebas · los datos pueden borrarse", ADR-0010).
Future<Repositories> openRepositories() async {
  final repo = InMemoryTaskRepository();
  return (tasks: repo, settings: repo);
}
