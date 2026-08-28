import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  // ============================================================
  // EXPORT BACKUP
  // ============================================================

  Future<void> exportBackup() async {
    final projects = await db.select(db.projects).get();
    final people = await db.select(db.people).get();
    final categories = await db.select(db.categories).get();
    final currencies = await db.select(db.currencies).get();
    final transactions = await db.select(db.transactions).get();
    final attachments = await db.select(db.attachments).get();

    final Map<String, dynamic> backupData = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),

      // ----------------------------------------------------------
      // PROJECTS
      // ----------------------------------------------------------

      'projects': projects.map((row) {
        return {
          'id': row.id,
          'uuid': row.uuid,
          'name': row.name,
          'description': row.description,
          'status': row.status,
          'startDate': row.startDate?.toIso8601String(),
          'endDate': row.endDate?.toIso8601String(),
          'createdAt': row.createdAt.toIso8601String(),
        };
      }).toList(),

      // ----------------------------------------------------------
      // PEOPLE
      // ----------------------------------------------------------

      'people': people.map((row) {
        return {
          'id': row.id,
          'uuid': row.uuid,
          'name': row.name,
          'phone': row.phone,
          'notes': row.notes,
          'createdAt': row.createdAt.toIso8601String(),
        };
      }).toList(),

      // ----------------------------------------------------------
      // CATEGORIES
      // ----------------------------------------------------------

      'categories': categories.map((row) {
        return {
          'id': row.id,
          'uuid': row.uuid,
          'name': row.name,
          'type': row.type,
          'icon': row.icon,
        };
      }).toList(),

      // ----------------------------------------------------------
      // CURRENCIES
      // ----------------------------------------------------------

      'currencies': currencies.map((row) {
        return {
          'id': row.id,
          'code': row.code,
          'symbol': row.symbol,
          'isDefault': row.isDefault,
        };
      }).toList(),

      // ----------------------------------------------------------
      // TRANSACTIONS
      // ----------------------------------------------------------

      'transactions': transactions.map((row) {
        return {
          'id': row.id,
          'uuid': row.uuid,
          'type': row.type,
          'amount': row.amount,
          'currencyId': row.currencyId,
          'projectId': row.projectId,
          'categoryId': row.categoryId,
          'personId': row.personId,
          'reason': row.reason,
          'notes': row.notes,
          'transactionDate': row.transactionDate.toIso8601String(),
          'createdAt': row.createdAt.toIso8601String(),
          'updatedAt': row.updatedAt.toIso8601String(),
          'deletedAt': row.deletedAt?.toIso8601String(),
        };
      }).toList(),

      // ----------------------------------------------------------
      // ATTACHMENTS
      // ----------------------------------------------------------

      'attachments': attachments.map((row) {
        return {
          'id': row.id,
          'transactionId': row.transactionId,
          'fileName': row.fileName,
          'filePath': row.filePath,
          'fileType': row.fileType,
          'createdAt': row.createdAt.toIso8601String(),
        };
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(
      backupData,
    );

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/my_accounts_backup_'
          '${DateTime.now().millisecondsSinceEpoch}.json',
    );

    await file.writeAsString(
      jsonString,
      encoding: utf8,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'نسخة احتياطية من تطبيق حساباتي',
    );
  }

  // ============================================================
  // IMPORT BACKUP
  // ============================================================

  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);

      final jsonString = await file.readAsString(
        encoding: utf8,
      );

      final decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'ملف النسخة الاحتياطية غير صالح.',
        );
      }

      final backupData = decoded;

      await db.transaction(() async {
        // ========================================================
        // 1. CURRENCIES
        // ========================================================

        final currenciesData = backupData['currencies'];

        if (currenciesData is List) {
          for (final raw in currenciesData) {
            if (raw is! Map) continue;

            final item = Map<String, dynamic>.from(raw);

            await db.into(db.currencies).insert(
              CurrenciesCompanion(
                id: Value(
                  _intValue(item['id']),
                ),
                code: Value(
                  _stringValue(item['code']),
                ),
                symbol: Value(
                  _stringValue(item['symbol']),
                ),
                isDefault: Value(
                  _boolValue(item['isDefault']),
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // ========================================================
        // 2. PROJECTS
        // ========================================================

        final projectsData = backupData['projects'];

        if (projectsData is List) {
          for (final raw in projectsData) {
            if (raw is! Map) continue;

            final item = Map<String, dynamic>.from(raw);

            await db.into(db.projects).insert(
              ProjectsCompanion(
                id: Value(
                  _intValue(item['id']),
                ),
                uuid: Value(
                  _stringValue(item['uuid']),
                ),
                name: Value(
                  _stringValue(item['name']),
                ),
                description: Value(
                  _nullableString(item['description']),
                ),
                status: Value(
                  _stringValue(
                    item['status'],
                    defaultValue: 'active',
                  ),
                ),
                startDate: Value(
                  _dateTime(item['startDate']),
                ),
                endDate: Value(
                  _dateTime(item['endDate']),
                ),
                createdAt: Value(
                  _dateTime(
                    item['createdAt'],
                    fallback: DateTime.now(),
                  )!,
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // ========================================================
        // 3. PEOPLE
        // ========================================================

        final peopleData = backupData['people'];

        if (peopleData is List) {
          for (final raw in peopleData) {
            if (raw is! Map) continue;

            final item = Map<String, dynamic>.from(raw);

            await db.into(db.people).insert(
              PeopleCompanion(
                id: Value(
                  _intValue(item['id']),
                ),
                uuid: Value(
                  _stringValue(item['uuid']),
                ),
                name: Value(
                  _stringValue(item['name']),
                ),
                phone: Value(
                  _nullableString(item['phone']),
                ),
                notes: Value(
                  _nullableString(item['notes']),
                ),
                createdAt: Value(
                  _dateTime(
                    item['createdAt'],
                    fallback: DateTime.now(),
                  )!,
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // ========================================================
        // 4. CATEGORIES
        // ========================================================

        final categoriesData = backupData['categories'];

        if (categoriesData is List) {
          for (final raw in categoriesData) {
            if (raw is! Map) continue;

            final item = Map<String, dynamic>.from(raw);

            await db.into(db.categories).insert(
              CategoriesCompanion(
                id: Value(
                  _intValue(item['id']),
                ),
                uuid: Value(
                  _stringValue(item['uuid']),
                ),
                name: Value(
                  _stringValue(item['name']),
                ),
                type: Value(
                  _stringValue(item['type']),
                ),
                icon: Value(
                  _nullableString(item['icon']),
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // ========================================================
        // 5. TRANSACTIONS
        // ========================================================

        final transactionsData = backupData['transactions'];

        if (transactionsData is List) {
          for (final raw in transactionsData) {
            if (raw is! Map) continue;

            final item = Map<String, dynamic>.from(raw);

            await db.into(db.transactions).insert(
              TransactionsCompanion(
                id: Value(
                  _intValue(item['id']),
                ),
                uuid: Value(
                  _stringValue(item['uuid']),
                ),
                type: Value(
                  _stringValue(item['type']),
                ),
                amount: Value(
                  _doubleValue(item['amount']),
                ),
                currencyId: Value(
                  _intValue(item['currencyId']),
                ),
                projectId: Value(
                  _nullableInt(item['projectId']),
                ),
                categoryId: Value(
                  _nullableInt(item['categoryId']),
                ),
                personId: Value(
                  _nullableInt(item['personId']),
                ),
                reason: Value(
                  _stringValue(item['reason']),
                ),
                notes: Value(
                  _nullableString(item['notes']),
                ),
                transactionDate: Value(
                  _dateTime(
                    item['transactionDate'],
                    fallback: DateTime.now(),
                  )!,
                ),
                createdAt: Value(
                  _dateTime(
                    item['createdAt'],
                    fallback: DateTime.now(),
                  )!,
                ),
                updatedAt: Value(
                  _dateTime(
                    item['updatedAt'],
                    fallback: DateTime.now(),
                  )!,
                ),
                deletedAt: Value(
                  _dateTime(item['deletedAt']),
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }

        // ========================================================
        // 6. ATTACHMENTS
        // ========================================================

        final attachmentsData = backupData['attachments'];

        if (attachmentsData is List) {
          for (final raw in attachmentsData) {
            if (raw is! Map) continue;

            final item = Map<String, dynamic>.from(raw);

            await db.into(db.attachments).insert(
              AttachmentsCompanion(
                id: Value(
                  _intValue(item['id']),
                ),
                transactionId: Value(
                  _intValue(item['transactionId']),
                ),
                fileName: Value(
                  _stringValue(item['fileName']),
                ),
                filePath: Value(
                  _stringValue(item['filePath']),
                ),
                fileType: Value(
                  _stringValue(item['fileType']),
                ),
                createdAt: Value(
                  _dateTime(
                    item['createdAt'],
                    fallback: DateTime.now(),
                  )!,
                ),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
      });

      return true;
    } catch (e) {
      // لا نجعل التطبيق ينهار إذا كان ملف النسخة الاحتياطية غير صالح.
      return false;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static int _intValue(
      dynamic value, {
        int defaultValue = 0,
      }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        defaultValue;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static double _doubleValue(
      dynamic value, {
        double defaultValue = 0,
      }) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        defaultValue;
  }

  static bool _boolValue(
      dynamic value, {
        bool defaultValue = false,
      }) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final stringValue = value?.toString().toLowerCase();

    if (stringValue == 'true' || stringValue == '1') {
      return true;
    }

    if (stringValue == 'false' || stringValue == '0') {
      return false;
    }

    return defaultValue;
  }

  static String _stringValue(
      dynamic value, {
        String defaultValue = '',
      }) {
    if (value == null) {
      return defaultValue;
    }

    return value.toString();
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }

  static DateTime? _dateTime(
      dynamic value, {
        DateTime? fallback,
      }) {
    if (value == null) {
      return fallback;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    ) ??
        fallback;
  }
}