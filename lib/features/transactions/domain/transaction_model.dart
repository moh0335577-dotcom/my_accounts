import 'package:my_accounts/core/database/app_database.dart';

enum TransactionType { income, expense }

class TransactionModel {
  final int? id;
  final String uuid;
  final TransactionType type;
  final double amount;
  final int currencyId;
  final int? projectId;
  final int? categoryId;
  final int? personId;
  final String reason;
  final String? notes;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime? deletedAt;

  TransactionModel({
    this.id,
    required this.uuid,
    required this.type,
    required this.amount,
    required this.currencyId,
    this.projectId,
    this.categoryId,
    this.personId,
    required this.reason,
    this.notes,
    required this.transactionDate,
    required this.createdAt,
    this.deletedAt,
  });
}


