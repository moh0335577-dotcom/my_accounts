import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dashboard_notifier.dart';
import 'package:my_accounts/features/transactions/presentation/transactions_notifier.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'widgets/income_expense_chart.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final balancesAsync = ref.watch(dashboardBalancesProvider);
    final recentTransactionsAsync = ref.watch(transactionsStreamProvider(TransactionsFilter()));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardBalancesProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balances Section
              balancesAsync.when(
                data: (balances) {
                  if (balances.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      ...balances.map((b) => _buildBalanceCard(context, l10n, b)).toList(),
                      const SizedBox(height: 16),
                      // Chart for the first currency as an overview
                      IncomeExpenseChart(
                        income: balances.first.totalIncome,
                        expense: balances.first.totalExpense,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
              
              const SizedBox(height: 24),
              
              // Projects Section
              _buildProjectSummaryHeader(context, l10n),
              const SizedBox(height: 16),
              _buildProjectsHorizontalList(ref),
              
              const SizedBox(height: 24),
              
              // Recent Transactions Section
              Text(
                l10n.recentTransactions,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              recentTransactionsAsync.when(
                data: (results) => _buildRecentTransactionsList(context, results, ref, l10n),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, AppLocalizations l10n, CurrencyBalance balance) {
    final numberFormat = NumberFormat.decimalPattern();
    
    return Card(
      color: AppTheme.primaryBlue,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.totalBalance,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    balance.code,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${numberFormat.format(balance.netBalance)} ${balance.symbol.isNotEmpty ? balance.symbol : balance.code}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    l10n.income,
                    numberFormat.format(balance.totalIncome),
                    Icons.arrow_downward,
                    AppTheme.incomeGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBalanceItem(
                    l10n.expenses,
                    numberFormat.format(balance.totalExpense),
                    Icons.arrow_upward,
                    AppTheme.expenseRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String label, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              amount,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.projects,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () => context.go('/projects'),
          child: const Text('عرض الكل'),
        ),
      ],
    );
  }

  Widget _buildProjectsHorizontalList(WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Project>>(
      stream: db.select(db.projects).watch(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) return const Text('لا يوجد مشاريع نشطة');
        
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(left: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.architecture, color: AppTheme.primaryBlue),
                        const SizedBox(height: 8),
                        Text(
                          project.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          project.status == 'active' ? 'نشط' : 'مكتمل',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactionsList(BuildContext context, List results, WidgetRef ref, AppLocalizations l10n) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(l10n.noTransactions, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final db = ref.read(databaseProvider);
    final recent = results.take(5).toList();

    return Column(
      children: recent.map((row) {
        final tx = row.readTable(db.transactions);
        final currency = row.readTable(db.currencies);
        final isIncome = tx.type == 'income';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIncome ? AppTheme.incomeGreen.withOpacity(0.1) : AppTheme.expenseRed.withOpacity(0.1),
              child: Icon(
                isIncome ? Icons.add : Icons.remove,
                color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
              ),
            ),
            title: Text(tx.reason, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(tx.transactionDate)),
            trailing: Text(
              '${isIncome ? "+" : "-"} ${NumberFormat.decimalPattern().format(tx.amount)} ${currency.code}',
              style: TextStyle(
                color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => context.push('/transaction/${tx.id}'),
          ),
        );
      }).toList(),
    );
  }
}


