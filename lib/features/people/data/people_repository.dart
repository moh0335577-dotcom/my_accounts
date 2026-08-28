import 'package:drift/drift.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/database/database_provider.dart';

class PeopleRepository {
  final AppDatabase _db;
  PeopleRepository(this._db);

  Stream<List<Person>> watchAllPeople() => _db.select(_db.people).watch();
  Future<int> addPerson(PeopleCompanion entry) => _db.into(_db.people).insert(entry);
  Future<bool> updatePerson(PeopleCompanion entry) => _db.update(_db.people).replace(entry);
  Future<int> deletePerson(int id) => (_db.delete(_db.people)..where((t) => t.id.equals(id))).go();
}

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  return PeopleRepository(ref.watch(databaseProvider));
});


