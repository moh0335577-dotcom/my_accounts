import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';
import 'package:my_accounts/features/people/data/people_repository.dart';
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
  int? _selectedPersonId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.watch(transactionRepositoryProvider);
    final peopleStream = ref.watch(peopleRepositoryProvider).watchAllPeople();
    final db = ref.watch(databaseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    final transactionsStream = repository.watchAllTransactions(
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      personId: _selectedPersonId,
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
          if (_selectedDateRange != null || _selectedPersonId != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() {
                _selectedDateRange = null;
                _selectedPersonId = null;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          // قائمة الفلترة - تم إصلاح "الشريط الأبيض"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              ),
              child: StreamBuilder<List<Person>>(
                stream: peopleStream,
                builder: (context, snapshot) {
                  final people = snapshot.data ?? [];
                  return DropdownButtonFormField<int?>(
                    value: _selectedPersonId,
                    dropdownColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'فلترة حسب الشخص / الجهة',
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100],
                      prefixIcon: Icon(Icons.person_search, color: isDark ? Colors.blueAccent : AppTheme.primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('جميع الأشخاص')),
                      ...people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedPersonId = val),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TypedResult>>(
              stream: transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final allTransactions = snapshot.data ?? [];
                if (allTransactions.isEmpty) {
                  return Center(child: Text(l10n.noTransactions));
                }

                final Map<String, List<TypedResult>> groupedByCurrency = {};
                for (var row in allTransactions) {
                  final currency = row.readTable(db.currencies);
                  groupedByCurrency.putIfAbsent(currency.code, () => []).add(row);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedByCurrency.length,
                  itemBuilder: (context, index) {
                    final entry = groupedByCurrency.entries.elementAt(index);
                    return _buildCurrencyCard(
                      context,
                      entry.key,
                      entry.value,
                      l10n,
                      db,
                    );
                  },
                );
              },
            ),
          ),
        ],
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
    String? personName;

    for (var row in transactions) {
      final tx = row.readTable(db.transactions);
      final curr = row.readTable(db.currencies);
      final person = row.readTableOrNull(db.people);

      symbol = curr.symbol;
      if (person != null && _selectedPersonId == person.id) {
        personName = person.name;
      }

      if (tx.type == 'income') totalIncome += tx.amount;
      else totalExpense += tx.amount;
    }

    final net = totalIncome - totalExpense;
    final numberFormat = NumberFormat.decimalPattern();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 10,
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
        side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(symbol, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w200, color: isDark ? Colors.white24 : Colors.grey.shade300)),
                Text(currencyCode, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              ],
            ),
            const Divider(height: 40, thickness: 0.5),
            _buildStatRow('المقبوضات', numberFormat.format(totalIncome), AppTheme.incomeGreen),
            const SizedBox(height: 16),
            _buildStatRow('المدفوعات', numberFormat.format(totalExpense), AppTheme.expenseRed),
            const Divider(height: 40, thickness: 0.5),
            _buildStatRow(
              'صافي الرصيد',
              numberFormat.format(net),
              net >= 0 ? AppTheme.incomeGreen : AppTheme.expenseRed,
              isBold: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final List<Map<String, dynamic>> data = transactions.map((row) {
                    final tx = row.readTable(db.transactions);
                    final curr = row.readTable(db.currencies);
                    final proj = row.readTableOrNull(db.projects);
                    final cat = row.readTableOrNull(db.categories);
                    final person = row.readTableOrNull(db.people);
                    return {
                      'date': DateFormat('yyyy-MM-dd').format(tx.transactionDate),
                      'type': tx.type == 'income' ? 'قبض' : 'صرف',
                      'project': proj?.name ?? '-',
                      'category': cat?.name ?? '-',
                      'reason': tx.reason,
                      'person': person?.name ?? '-',
                      'amount': '${numberFormat.format(tx.amount)} ${curr.code}',
                      'notes': tx.notes ?? '-',
                    };
                  }).toList();

                  final period = _selectedDateRange != null
                      ? '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}'
                      : 'كافة العمليات التاريخية';

                  await PdfService.generateFullReport(
                    companyName: personName != null ? 'كشف حساب: $personName' : 'كشف حساب مالي عام',
                    period: period,
                    currency: currencyCode,
                    totalIncome: totalIncome,
                    totalExpense: totalExpense,
                    transactionsData: data,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 24),
                label: Text('تصدير كشف حساب ($currencyCode)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value, style: TextStyle(fontSize: isBold ? 26 : 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: isBold ? 18 : 17, color: isBold ? Colors.white : Colors.grey.shade400, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
