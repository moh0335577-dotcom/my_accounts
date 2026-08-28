import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';
import 'package:drift/drift.dart' as drift;

class PersonDetailsScreen extends ConsumerWidget {
  final int personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    
    final personStream = (db.select(db.people)..where((t) => t.id.equals(personId))).watchSingleOrNull();
    
    // Custom logic to get balances for this person
    final transactionsStream = db.select(db.transactions).join([
      drift.innerJoin(db.currencies, db.currencies.id.equalsExp(db.transactions.currencyId)),
    ])..where(db.transactions.personId.equals(personId) & db.transactions.deletedAt.isNull());

    return StreamBuilder<Person?>(
      stream: personStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final person = snapshot.data;
        if (person == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('الشخص غير موجود')));

        return Scaffold(
          appBar: AppBar(title: Text(person.name)),
          body: StreamBuilder(
            stream: transactionsStream.watch(),
            builder: (context, txSnapshot) {
              final rows = txSnapshot.data ?? [];
              
              // Calculate balances per currency
              final Map<String, double> incomePerCurrency = {};
              final Map<String, double> expensePerCurrency = {};
              
              for (var row in rows) {
                final tx = row.readTable(db.transactions);
                final curr = row.readTable(db.currencies);
                if (tx.type == 'income') {
                  incomePerCurrency[curr.code] = (incomePerCurrency[curr.code] ?? 0) + tx.amount;
                } else {
                  expensePerCurrency[curr.code] = (expensePerCurrency[curr.code] ?? 0) + tx.amount;
                }
              }

              final currencies = {...incomePerCurrency.keys, ...expensePerCurrency.keys}.toList();

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
                          ...currencies.map((code) => _buildCurrencyBalanceCard(
                            code, 
                            incomePerCurrency[code] ?? 0, 
                            expensePerCurrency[code] ?? 0,
                            l10n,
                          )),
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

  Widget _buildPersonCard(Person person) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(person.phone ?? 'لا يوجد هاتف'),
      ),
    );
  }

  Widget _buildCurrencyBalanceCard(String code, double income, double expense, AppLocalizations l10n) {
    final net = income - expense;
    final format = NumberFormat.decimalPattern();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('الصافي: ${format.format(net)}', style: TextStyle(color: net >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
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


