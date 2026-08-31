import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/core/utils/pdf_service.dart';
import 'package:drift/drift.dart' show TypedResult;
import 'transactions_notifier.dart';
import 'widgets/transaction_filter_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportFiltered(List<TypedResult> results, TransactionsFilter filter, String currencyCode, AppDatabase db) async {
    final List<Map<String, dynamic>> data = [];
    double income = 0;
    double expense = 0;

    for (var row in results) {
      final tx = row.readTable(db.transactions);
      final curr = row.readTable(db.currencies);
      if (curr.code != currencyCode) continue;

      final proj = row.readTableOrNull(db.projects);
      final cat = row.readTableOrNull(db.categories);
      final person = row.readTableOrNull(db.people);

      if (tx.type == 'income') {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }

      data.add({
        'date': DateFormat('yyyy-MM-dd').format(tx.transactionDate),
        'type': tx.type == 'income' ? 'قبض' : 'صرف',
        'project': proj?.name ?? '-',
        'category': cat?.name ?? '-',
        'reason': tx.reason,
        'person': person?.name ?? '-',
        'amount': '${NumberFormat.decimalPattern().format(tx.amount)} $currencyCode',
        'notes': tx.notes ?? '-',
      });
    }

    String period = 'كافة العمليات';
    if (filter.startDate != null && filter.endDate != null) {
      period = '${DateFormat('yyyy-MM-dd').format(filter.startDate!)} - ${DateFormat('yyyy-MM-dd').format(filter.endDate!)}';
    }

    String title = 'كشف حساب';
    if (filter.personId != null && results.isNotEmpty) {
      final personRow = results.firstWhere(
        (r) => r.readTableOrNull(db.people)?.id == filter.personId,
        orElse: () => results.first,
      );
      final personName = personRow.readTableOrNull(db.people)?.name ?? '';
      if (personName.isNotEmpty) title = 'كشف حساب: $personName';
    } else if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      title = 'نتائج البحث: ${filter.searchQuery}';
    }

    await PdfService.generateFullReport(
      companyName: title,
      period: period,
      currency: currencyCode,
      totalIncome: income,
      totalExpense: expense,
      transactionsData: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(transactionsFilterProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider(filter));
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 18),
                onChanged: (value) {
                  ref.read(transactionsFilterProvider.notifier).state = 
                    filter.copyWith(searchQuery: value);
                },
              )
            : Text(l10n.transactions),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(transactionsFilterProvider.notifier).state = 
                    filter.copyWith(searchQuery: '');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => const TransactionFilterSheet(),
              );
            },
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(l10n.noTransactions),
                ],
              ),
            );
          }

          // Group by Currency for Summary
          final Map<String, List<TypedResult>> groupedResults = {};
          for (var row in results) {
            final currency = row.readTable(db.currencies);
            groupedResults.putIfAbsent(currency.code, () => []).add(row);
          }

          return Column(
            children: [
              // Summary Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: groupedResults.entries.map((entry) {
                    double inc = 0, exp = 0;
                    for (var r in entry.value) {
                      final tx = r.readTable(db.transactions);
                      if (tx.type == 'income') inc += tx.amount;
                      else exp += tx.amount;
                    }
                    return _buildFilterSummary(
                      inc, exp, entry.key, l10n, 
                      () => _exportFiltered(results, filter, entry.key, db)
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final row = results[index];
                    final tx = row.readTable(db.transactions);
                    final project = row.readTableOrNull(db.projects);
                    final currency = row.readTable(db.currencies);
                    final person = row.readTableOrNull(db.people);
                    
                    final isIncome = tx.type == 'income';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome 
                              ? AppTheme.incomeGreen.withOpacity(0.1) 
                              : AppTheme.expenseRed.withOpacity(0.1),
                          child: Icon(
                            isIncome ? Icons.add : Icons.remove,
                            color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                          ),
                        ),
                        title: Text(tx.reason, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${project?.name ?? 'شخصي'} ${person != null ? "• ${person.name}" : ""}'),
                            Text(
                              DateFormat('yyyy-MM-dd — HH:mm').format(tx.transactionDate),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isIncome ? "+" : "-"} ${NumberFormat.decimalPattern().format(tx.amount)}',
                              style: TextStyle(
                                color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(currency.code, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        onTap: () => context.push('/transaction/${tx.id}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
      ),
    );
  }

  Widget _buildFilterSummary(double income, double expense, String currency, AppLocalizations l10n, VoidCallback onExport) {
    final net = income - expense;
    final format = NumberFormat.decimalPattern();
    
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currency, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, size: 20, color: AppTheme.primaryBlue),
                onPressed: onExport,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'تصدير كشف حساب',
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryColumn(l10n.income, format.format(income), AppTheme.incomeGreen),
              _summaryColumn(l10n.expenses, format.format(expense), AppTheme.expenseRed),
              _summaryColumn(l10n.netBalance, format.format(net), net >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
