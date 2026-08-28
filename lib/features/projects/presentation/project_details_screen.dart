import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';
import 'package:my_accounts/features/transactions/presentation/transactions_notifier.dart';

class ProjectDetailsScreen extends ConsumerWidget {
  final int projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    final repository = ref.watch(transactionRepositoryProvider);

    final projectStream = (db.select(db.projects)..where((t) => t.id.equals(projectId))).watchSingleOrNull();
    final summaryStream = repository.getBalancePerCurrency(projectId: projectId);
    final transactionsStream = repository.watchAllTransactions(projectId: projectId);

    return StreamBuilder<Project?>(
      stream: projectStream,
      builder: (context, projectSnapshot) {
        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final project = projectSnapshot.data;
        if (project == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('المشروع غير موجود')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  // TODO: Implement Edit Project
                },
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProjectInfoCard(project, l10n),
                      const SizedBox(height: 24),
                      Text(
                        'الإحصائيات المالية',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<List<TransactionSummary>>(
                        stream: summaryStream,
                        builder: (context, snapshot) {
                          final summaries = snapshot.data ?? [];
                          if (summaries.isEmpty) return const Text('لا توجد عمليات مالية لهذا المشروع');
                          return Column(
                            children: summaries.map((s) => _buildSummaryItem(s, l10n)).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.transactions,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              StreamBuilder<List>(
                stream: transactionsStream,
                builder: (context, snapshot) {
                  final results = snapshot.data ?? [];
                  if (results.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(child: Text('لا توجد عمليات')),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final row = results[index];
                        final tx = row.readTable(db.transactions);
                        final currency = row.readTable(db.currencies);
                        final isIncome = tx.type == 'income';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIncome ? AppTheme.incomeGreen.withOpacity(0.1) : AppTheme.expenseRed.withOpacity(0.1),
                              child: Icon(isIncome ? Icons.add : Icons.remove, color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed),
                            ),
                            title: Text(tx.reason),
                            subtitle: Text(DateFormat('yyyy-MM-dd').format(tx.transactionDate)),
                            trailing: Text(
                              '${isIncome ? "+" : "-"} ${NumberFormat.decimalPattern().format(tx.amount)} ${currency.code}',
                              style: TextStyle(color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed, fontWeight: FontWeight.bold),
                            ),
                            onTap: () => context.push('/transaction/${tx.id}'),
                          ),
                        );
                      },
                      childCount: results.length,
                    ),
                  );
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              // TODO: Navigate to Add Transaction with this project pre-selected
              context.push('/add-transaction'); 
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildProjectInfoCard(Project project, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الحالة', style: TextStyle(color: Colors.grey)),
                _buildStatusChip(project.status, l10n),
              ],
            ),
            const Divider(),
            if (project.description != null) ...[
              const Text('الوصف', style: TextStyle(color: Colors.grey)),
              Text(project.description!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
            ],
            Text(
              'تاريخ الإنشاء: ${DateFormat('yyyy-MM-dd').format(project.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, AppLocalizations l10n) {
    Color color = Colors.grey;
    String label = status;
    switch (status) {
      case 'active': color = Colors.green; label = l10n.active; break;
      case 'completed': color = Colors.blue; label = l10n.completed; break;
      case 'stopped': color = Colors.orange; label = l10n.stopped; break;
      case 'archived': color = Colors.grey; label = l10n.archived; break;
    }
    return Chip(label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: color);
  }

  Widget _buildSummaryItem(TransactionSummary s, AppLocalizations l10n) {
    final isIncome = s.type == 'income';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isIncome ? l10n.income : l10n.expenses),
          Text(
            '${isIncome ? "+" : "-"} ${NumberFormat.decimalPattern().format(s.total)} ${s.currencyCode}',
            style: TextStyle(color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}


