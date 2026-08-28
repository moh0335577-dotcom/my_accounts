import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';
import 'package:intl/intl.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/core/utils/pdf_service.dart';

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

    final summaryStream = repository.getBalancePerCurrency(
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
      body: StreamBuilder<List<TransactionSummary>>(
        stream: summaryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final summaries = snapshot.data ?? [];
          if (summaries.isEmpty) {
            return Center(child: Text(l10n.noTransactions));
          }

          final Map<String, List<TransactionSummary>> grouped = {};
          for (var s in summaries) {
            grouped.putIfAbsent(s.currencyCode, () => []).add(s);
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
              ...grouped.entries.map((entry) => _buildCurrencyReport(context, entry.key, entry.value, l10n)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  double totalIncome = 0;
                  double totalExpense = 0;

                  for (final item in summaries) {
                    if (item.type == 'income') {
                      totalIncome += item.total;
                    } else if (item.type == 'expense') {
                      totalExpense += item.total;
                    }
                  }

                  final transactionsData = summaries.map((item) {
                    return <String, dynamic>{
                      'date': _selectedDateRange != null
                          ? '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - '
                          '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}'
                          : 'كل الفترات',
                      'type': item.type == 'income' ? 'مقبوضات' : 'مدفوعات',
                      'reason': 'إجمالي العمليات',
                      'project': '-',
                      'amount':
                      '${NumberFormat.decimalPattern().format(item.total)} ${item.currencyCode}',
                    };
                  }).toList();

                  final currency = summaries.isNotEmpty
                      ? summaries.first.currencyCode
                      : 'SYP';

                  final period = _selectedDateRange != null
                      ? '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)}'
                      ' - '
                      '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}'
                      : 'كل الفترات';

                  await PdfService.generateFullReport(
                    companyName: 'حساباتي',
                    period: period,
                    currency: currency,
                    totalIncome: totalIncome,
                    totalExpense: totalExpense,
                    transactionsData: transactionsData,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(l10n.exportPdf),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrencyReport(BuildContext context, String currencyCode, List<TransactionSummary> items, AppLocalizations l10n) {
    double income = 0;
    double expense = 0;
    String symbol = '';

    for (var item in items) {
      symbol = item.currencySymbol;
      if (item.type == 'income') income += item.total;
      if (item.type == 'expense') expense += item.total;
    }

    final net = income - expense;
    final numberFormat = NumberFormat.decimalPattern();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(currencyCode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(symbol, style: const TextStyle(fontSize: 20, color: Colors.grey)),
              ],
            ),
            const Divider(),
            _buildReportRow(l10n.income, numberFormat.format(income), AppTheme.incomeGreen),
            _buildReportRow(l10n.expenses, numberFormat.format(expense), AppTheme.expenseRed),
            const Divider(),
            _buildReportRow(
              l10n.netBalance,
              numberFormat.format(net),
              net >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


