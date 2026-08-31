import 'package:drift/drift.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/database/database_provider.dart';

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  Stream<List<TypedResult>> watchAllTransactions({
    bool includeDeleted = false,
    int? projectId,
    int? personId,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    String? type,
    int? currencyId,
  }) {
    var query = _db.select(_db.transactions).join([
      leftOuterJoin(_db.projects, _db.projects.id.equalsExp(_db.transactions.projectId)),
      leftOuterJoin(_db.currencies, _db.currencies.id.equalsExp(_db.transactions.currencyId)),
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      leftOuterJoin(_db.people, _db.people.id.equalsExp(_db.transactions.personId)),
    ]);

    if (!includeDeleted) {
      query.where(_db.transactions.deletedAt.isNull());
    } else {
      query.where(_db.transactions.deletedAt.isNotNull());
    }

    if (projectId != null) {
      query.where(_db.transactions.projectId.equals(projectId));
    }

    if (personId != null) {
      query.where(_db.transactions.personId.equals(personId));
    }

    if (categoryId != null) {
      query.where(_db.transactions.categoryId.equals(categoryId));
    }

    if (type != null) {
      query.where(_db.transactions.type.equals(type));
    }

    if (currencyId != null) {
      query.where(_db.transactions.currencyId.equals(currencyId));
    }

    if (startDate != null && endDate != null) {
      query.where(_db.transactions.transactionDate.isBetweenValues(startDate, endDate));
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final term = '%$searchQuery%';
      query.where(
        _db.transactions.reason.like(term) | 
        _db.transactions.notes.like(term) |
        _db.projects.name.like(term) |
        _db.people.name.like(term)
      );
    }

    query.orderBy([OrderingTerm.desc(_db.transactions.transactionDate)]);

    return query.watch();
  }

  Future<int> addTransaction(TransactionsCompanion entry) {
    return _db.into(_db.transactions).insert(entry);
  }

  Future<bool> updateTransaction(TransactionsCompanion entry) {
    return _db.update(_db.transactions).replace(entry);
  }

  Future<void> softDeleteTransaction(int id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: Value(DateTime.now())));
  }

  Future<void> restoreTransaction(int id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(const TransactionsCompanion(deletedAt: Value(null)));
  }

  Future<void> hardDeleteTransaction(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<TransactionSummary>> getBalancePerCurrency({
    int? projectId,
    int? personId,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final amount = _db.transactions.amount.sum();
    final query = _db.select(_db.transactions).join([
      innerJoin(_db.currencies, _db.currencies.id.equalsExp(_db.transactions.currencyId)),
    ])
      ..where(_db.transactions.deletedAt.isNull());

    if (projectId != null) {
      query.where(_db.transactions.projectId.equals(projectId));
    }
    if (personId != null) {
      query.where(_db.transactions.personId.equals(personId));
    }
    if (categoryId != null) {
      query.where(_db.transactions.categoryId.equals(categoryId));
    }
    if (startDate != null && endDate != null) {
      query.where(_db.transactions.transactionDate.isBetweenValues(startDate, endDate));
    }

    query..addColumns([amount])
      ..groupBy([_db.transactions.currencyId, _db.transactions.type]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final curr = row.readTable(_db.currencies);
        return TransactionSummary(
          currencyCode: curr.code,
          currencySymbol: curr.symbol,
          type: row.readTable(_db.transactions).type,
          total: row.read(amount) ?? 0,
        );
      }).toList();
    });
  }
}

class TransactionSummary {
  final String currencyCode;
  final String currencySymbol;
  final String type;
  final double total;

  TransactionSummary({
    required this.currencyCode, 
    required this.currencySymbol,
    required this.type, 
    required this.total
  });
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});
