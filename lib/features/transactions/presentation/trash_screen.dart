import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import '../data/transaction_repository.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    final repository = ref.watch(transactionRepositoryProvider);
    
    // We can use the watchAllTransactions with includeDeleted = true
    final trashStream = repository.watchAllTransactions(includeDeleted: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trash),
      ),
      body: StreamBuilder(
        stream: trashStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('سلة المحذوفات فارغة'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final row = results[index];
              final tx = row.readTable(db.transactions);
              final currency = row.readTable(db.currencies);
              final isIncome = tx.type == 'income';

              return Card(
                color: Colors.grey[50],
                child: ListTile(
                  title: Text(tx.reason, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(tx.transactionDate)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green),
                        onPressed: () => repository.restoreTransaction(tx.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => _confirmPermanentDelete(context, repository, tx.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context, TransactionRepository repo, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نهائي'),
        content: const Text('هل أنت متأكد من حذف هذه العملية نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              repo.hardDeleteTransaction(id);
              Navigator.pop(context);
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }
}


