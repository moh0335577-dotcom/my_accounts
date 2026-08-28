import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';
import 'package:intl/intl.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/core/utils/pdf_service.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:drift/drift.dart' show TypedResult;
import 'package:my_accounts/core/database/app_database.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.watch(transactionRepositoryProvider);
    final db = ref.watch(databaseProvider);

    // جلب كافة العمليات التفصيلية لضمان فصلها حسب العملة بدقة عند التصدير
    final transactionsStream = repository.watchAllTransactions(
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
              }
            },
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDateRange = null),
            ),
        ],
      ),
      body: StreamBuilder<List<TypedResult>>(
        stream: transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allTransactions = snapshot.data ?? [];
          if (allTransactions.isEmpty) {
            return Center(child: Text(l10n.noTransactions));
          }

          // تجميع العمليات حسب العملة (Currency Code) لمنع الاختلاط في التقارير
          final Map<String, List<TypedResult>> groupedByCurrency = {};
          for (var row in allTransactions) {
            final currency = row.readTable(db.currencies);
            groupedByCurrency.putIfAbsent(currency.code, () => []).add(row);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_selectedDateRange != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Chip(
                      label: Text(
                        '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}',
                      ),
                    ),
                  ),
                ),
              // عرض بطاقة منفصلة لكل عملة مع زر تصدير خاص بها فقط
              ...groupedByCurrency.entries.map((entry) => _buildCurrencyCard(
                    context,
                    entry.key,
                    entry.value,
                    l10n,
                    db,
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrencyCard(
    BuildContext context,
    String currencyCode,
    List<TypedResult> transactions,
    AppLocalizations l10n,
    AppDatabase db,
  ) {
    double totalIncome = 0;
    double totalExpense = 0;
    String symbol = '';

    // معالجة وتصفية بيانات العملة المحددة فقط وتجهيزها للتصدير
    final List<Map<String, dynamic>> transactionsData = [];
    
    for (var row in transactions) {
      final tx = row.readTable(db.transactions);
      final curr = row.readTable(db.currencies);
      final proj = row.readTableOrNull(db.projects);
      final cat = row.readTableOrNull(db.categories);
      final person = row.readTableOrNull(db.people);

      symbol = curr.symbol;
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
      }

      transactionsData.add({
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

    final net = totalIncome - totalExpense;
    final numberFormat = NumberFormat.decimalPattern();

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(currencyCode,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(symbol,
                    style: const TextStyle(fontSize: 22, color: Colors.blueGrey)),
              ],
            ),
            const Divider(),
            _buildStatRow(l10n.income, numberFormat.format(totalIncome), AppTheme.incomeGreen),
            _buildStatRow(l10n.expenses, numberFormat.format(totalExpense), AppTheme.expenseRed),
            const Divider(),
            _buildStatRow(
              l10n.netBalance,
              numberFormat.format(net),
              net >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
              isBold: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final period = _selectedDateRange != null
                      ? '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}'
                      : 'كل الفترات';

                  // تصدير بيانات هذه العملة فقط بشكل مستقل
                  await PdfService.generateFullReport(
                    companyName: 'حساباتي',
                    period: period,
                    currency: currencyCode,
                    totalIncome: totalIncome,
                    totalExpense: totalExpense,
                    transactionsData: transactionsData,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: Text('${l10n.exportPdf} ($currencyCode)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
