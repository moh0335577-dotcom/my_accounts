import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:my_accounts/core/database/app_database.dart';
import '../data/transaction_repository.dart';

class TransactionsFilter {
  final int? projectId;
  final int? personId;
  final int? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final String? type; // income, expense

  TransactionsFilter({
    this.projectId,
    this.personId,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.type,
  });

  TransactionsFilter copyWith({
    int? projectId,
    int? personId,
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    String? type,
    bool clearProjectId = false,
    bool clearPersonId = false,
    bool clearCategoryId = false,
    bool clearType = false,
    bool clearDates = false,
  }) {
    return TransactionsFilter(
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      personId: clearPersonId ? null : (personId ?? this.personId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      searchQuery: searchQuery ?? this.searchQuery,
      type: clearType ? null : (type ?? this.type),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionsFilter &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          personId == other.personId &&
          categoryId == other.categoryId &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          searchQuery == other.searchQuery &&
          type == other.type;

  @override
  int get hashCode =>
      projectId.hashCode ^
      personId.hashCode ^
      categoryId.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      searchQuery.hashCode ^
      type.hashCode;
}

final transactionsStreamProvider = StreamProvider.family<List<TypedResult>, TransactionsFilter>((ref, filter) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchAllTransactions(
    projectId: filter.projectId,
    personId: filter.personId,
    categoryId: filter.categoryId,
    startDate: filter.startDate,
    endDate: filter.endDate,
    searchQuery: filter.searchQuery,
    type: filter.type,
  );
});

final transactionsFilterProvider = StateProvider<TransactionsFilter>((ref) => TransactionsFilter());
