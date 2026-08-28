import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); 
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
@DataClassName('Person')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()(); // income, expense
  TextColumn get icon => text().nullable()();
}

class Currencies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 3, max: 3)(); 
  TextColumn get symbol => text().withLength(min: 1, max: 5)();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(() => const Uuid().v4())();
  TextColumn get type => text()(); // income, expense
  RealColumn get amount => real()();
  IntColumn get currencyId => integer().references(Currencies, #id)();
  IntColumn get projectId => integer().nullable().references(Projects, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get personId => integer().nullable().references(People, #id)();
  TextColumn get reason => text().withLength(min: 1, max: 255)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get transactionDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  TextColumn get fileType => text()(); // image, pdf, etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Projects, People, Categories, Currencies, Transactions, Attachments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; // Incremented schema version

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(attachments);
        }
      },
      onCreate: (m) async {
        await m.createAll();

        await batch((b) {
          b.insertAll(currencies, [
            CurrenciesCompanion.insert(
              code: 'SYP',
              symbol: 'ل.س',
              isDefault: const Value(true),
            ),
            CurrenciesCompanion.insert(
              code: 'USD',
              symbol: '\$',
            ),
            CurrenciesCompanion.insert(
              code: 'EUR',
              symbol: '€',
            ),
          ]);

          b.insertAll(categories, [
            CategoriesCompanion.insert(
              name: 'دفعة من العميل',
              type: 'income',
            ),
            CategoriesCompanion.insert(
              name: 'سلفة مستلمة',
              type: 'income',
            ),
            CategoriesCompanion.insert(
              name: 'مواد بناء',
              type: 'expense',
            ),
            CategoriesCompanion.insert(
              name: 'أجور عمال',
              type: 'expense',
            ),
          ]);
        });
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'my_accounts.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}


