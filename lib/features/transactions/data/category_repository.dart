import 'package:drift/drift.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/database/database_provider.dart';

class CategoryRepository {
  final AppDatabase _db;
  CategoryRepository(this._db);

  Stream<List<Category>> watchCategories(String type) {
    return (_db.select(_db.categories)..where((t) => t.type.equals(type))).watch();
  }

  Future<int> addCategory(CategoriesCompanion entry) => _db.into(_db.categories).insert(entry);
  Future<bool> updateCategory(CategoriesCompanion entry) => _db.update(_db.categories).replace(entry);
  Future<int> deleteCategory(int id) => (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});


