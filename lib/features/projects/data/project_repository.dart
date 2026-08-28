import 'package:drift/drift.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/database/database_provider.dart';

class ProjectRepository {
  final AppDatabase _db;

  ProjectRepository(this._db);

  Stream<List<Project>> watchAllProjects() {
    return _db.select(_db.projects).watch();
  }

  Future<int> addProject(ProjectsCompanion entry) {
    return _db.into(_db.projects).insert(entry);
  }

  Future<bool> updateProject(ProjectsCompanion entry) {
    return _db.update(_db.projects).replace(entry);
  }

  Future<int> deleteProject(int id) {
    return (_db.delete(_db.projects)..where((t) => t.id.equals(id))).go();
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});


