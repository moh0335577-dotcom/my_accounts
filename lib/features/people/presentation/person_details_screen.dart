import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/core/utils/pdf_service.dart';
import 'package:drift/drift.dart' as drift;

class PersonDetailsScreen extends ConsumerWidget {
  final int personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    
    final personStream = (db.select(db.people)..where((t) => t.id.equals(personId))).watchSingleOrNull();
    
    final transactionsStream = db.select(db.transactions).join([
      drift.innerJoin(db.currencies, db.currencies.id.equalsExp(db.transactions.currencyId)),
      drift.leftOuterJoin(db.projects, db.projects.id.equalsExp(db.transactions.projectId)),
      drift.leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
      drift.leftOuterJoin(db.people, db.people.id.equalsExp(db.transactions.personId)),
    ])..where(db.transactions.personId.equals(personId) & db.transactions.deletedAt.isNull())
      ..orderBy([drift.OrderingTerm.desc(db.transactions.transactionDate)]);

    return StreamBuilder<Person?>(
      stream: personStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final person = snapshot.data;
        if (person == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('الشخص غير موجود')));

        return Scaffold(
          appBar: AppBar(title: Text(person.name)),
          body: StreamBuilder<List<drift.TypedResult>>(
            stream: transactionsStream.watch(),
            builder: (context, txSnapshot) {
              final rows = txSnapshot.data ?? [];
              
              // Group rows by currency
              final Map<String, List<drift.TypedResult>> groupedByCurrency = {};
              for (var row in rows) {
                final curr = row.readTable(db.currencies);
                groupedByCurrency.putIfAbsent(curr.code, () => []).add(row);
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPersonCard(person),
                          const SizedBox(height: 24),
                          Text('كشف حساب إجمالي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ...groupedByCurrency.entries.map((entry) {
                            double income = 0;
                            double expense = 0;
                            for (var row in entry.value) {
                              final tx = row.readTable(db.transactions);
                              if (tx.type == 'income') income += tx.amount;
                              else expense += tx.amount;
                            }
                            return _buildCurrencyBalanceCard(
                              entry.key, 
                              income, 
                              expense,
                              l10n,
                              () => _exportPersonStatement(person.name, entry.key, entry.value, db),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('حركة العمليات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = rows[index].readTable(db.transactions);
                        final curr = rows[index].readTable(db.currencies);
                        final isIncome = tx.type == 'income';
                        return _buildTransactionTile(context, tx, curr, isIncome);
                      },
                      childCount: rows.length,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _exportPersonStatement(String personName, String currencyCode, List<drift.TypedResult> rows, AppDatabase db) async {
    final List<Map<String, dynamic>> data = [];
    double income = 0;
    double expense = 0;

    for (var row in rows) {
      final tx = row.readTable(db.transactions);
      final proj = row.readTableOrNull(db.projects);
      final cat = row.readTableOrNull(db.categories);

      if (tx.type == 'income') income += tx.amount;
      else expense += tx.amount;

      data.add({
        'date': DateFormat('yyyy-MM-dd').format(tx.transactionDate),
        'type': tx.type == 'income' ? 'قبض' : 'صرف',
        'project': proj?.name ?? '-',
        'category': cat?.name ?? '-',
        'reason': tx.reason,
        'person': personName,
        'amount': '${NumberFormat.decimalPattern().format(tx.amount)} $currencyCode',
        'notes': tx.notes ?? '-',
      });
    }

    await PdfService.generateFullReport(
      companyName: 'كشف حساب: $personName',
      period: 'كافة العمليات',
      currency: currencyCode,
      totalIncome: income,
      totalExpense: expense,
      transactionsData: data,
    );
  }

  Widget _buildPersonCard(Person person) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(person.phone ?? 'لا يوجد هاتف'),
      ),
    );
  }

  Widget _buildCurrencyBalanceCard(String code, double income, double expense, AppLocalizations l10n, VoidCallback onExport) {
    final net = income - expense;
    final format = NumberFormat.decimalPattern();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue)),
              Row(
                children: [
                  Text('الصافي: ${format.format(net)}', style: TextStyle(color: net >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryBlue),
                    onPressed: onExport,
                    tooltip: 'تصدير كشف حساب',
                  ),
                ],
              ),
            ]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _amountItem(l10n.income, format.format(income), Colors.green),
              _amountItem(l10n.expenses, format.format(expense), Colors.red),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _amountItem(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildTransactionTile(BuildContext context, Transaction tx, Currency curr, bool isIncome) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(tx.reason),
        subtitle: Text(DateFormat('yyyy-MM-dd').format(tx.transactionDate)),
        trailing: Text(
          '${isIncome ? "+" : "-"} ${NumberFormat.decimalPattern().format(tx.amount)} ${curr.code}',
          style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
        ),
        onTap: () => context.push('/transaction/${tx.id}'),
      ),
    );
  }
}
