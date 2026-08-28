import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';
import 'package:my_accounts/core/utils/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:open_file/open_file.dart';
import 'package:drift/drift.dart' hide Column;

class TransactionDetailsScreen extends ConsumerWidget {
  final int transactionId;

  const TransactionDetailsScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);

    final transactionQuery = db.select(db.transactions).join([
      leftOuterJoin(db.projects, db.projects.id.equalsExp(db.transactions.projectId)),
      leftOuterJoin(db.currencies, db.currencies.id.equalsExp(db.transactions.currencyId)),
      leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
      leftOuterJoin(db.people, db.people.id.equalsExp(db.transactions.personId)),
    ])..where(db.transactions.id.equals(transactionId));

    final attachmentsQuery = db.select(db.attachments)..where((t) => t.transactionId.equals(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactions),
        actions: [
          StreamBuilder(
            stream: transactionQuery.watchSingleOrNull(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
              final row = snapshot.data!;
              final tx = row.readTable(db.transactions);
              final currency = row.readTable(db.currencies);
              final project = row.readTableOrNull(db.projects);
              final person = row.readTableOrNull(db.people);

              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: l10n.exportPdf,
                    onPressed: () => PdfService.exportSingleTransaction(tx, currency, project),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _shareTransaction(tx, currency, project, person),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/edit-transaction/${tx.id}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, ref, tx.id),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: transactionQuery.watchSingleOrNull(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('العملية غير موجودة'));
          }

          final row = snapshot.data!;
          final tx = row.readTable(db.transactions);
          final project = row.readTableOrNull(db.projects);
          final currency = row.readTable(db.currencies);
          final category = row.readTableOrNull(db.categories);
          final person = row.readTableOrNull(db.people);

          final isIncome = tx.type == 'income';
          final color = isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isIncome ? Icons.add_circle : Icons.remove_circle,
                          color: color,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${isIncome ? "+" : "-"} ${NumberFormat.decimalPattern().format(tx.amount)} ${currency.code}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tx.reason,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                _buildInfoRow(context, Icons.work_outline, l10n.project, project?.name ?? 'شخصي'),
                _buildInfoRow(context, Icons.category_outlined, 'التصنيف', category?.name ?? 'غير محدد'),
                _buildInfoRow(context, Icons.person_outline, l10n.person, person?.name ?? 'غير محدد'),
                _buildInfoRow(
                  context,
                  Icons.calendar_today_outlined,
                  l10n.date,
                  DateFormat('yyyy-MM-dd').format(tx.transactionDate),
                ),
                _buildInfoRow(
                  context,
                  Icons.access_time,
                  l10n.time,
                  DateFormat('HH:mm').format(tx.transactionDate),
                ),
                if (tx.notes != null && tx.notes!.isNotEmpty)
                  _buildInfoRow(context, Icons.notes, l10n.notes, tx.notes!),
                
                const SizedBox(height: 24),
                Text('المرفقات', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                StreamBuilder<List<Attachment>>(
                  stream: attachmentsQuery.watch(),
                  builder: (context, attachSnapshot) {
                    final attachments = attachSnapshot.data ?? [];
                    if (attachments.isEmpty) {
                      return const Text('لا توجد مرفقات لهذه العملية', style: TextStyle(color: Colors.grey, fontSize: 12));
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: attachments.length,
                      itemBuilder: (context, index) {
                        final a = attachments[index];
                        final isImage = ['.jpg', '.jpeg', '.png'].contains(a.fileType.toLowerCase());
                        
                        return GestureDetector(
                          onTap: () => _openFile(a.filePath),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isImage 
                                ? Image.file(File(a.filePath), fit: BoxFit.cover)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.insert_drive_file, color: Colors.grey),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.extension(a.filePath).toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),
                if (tx.deletedAt != null)
                   Center(
                     child: Text(
                       'محذوفة بتاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(tx.deletedAt!)}',
                       style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                     ),
                   ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareTransaction(Transaction tx, Currency curr, Project? proj, Person? pers) {
    final type = tx.type == 'income' ? 'قبض' : 'دفع';
    final text = '''
تفاصيل عملية $type:
المبلغ: ${NumberFormat.decimalPattern().format(tx.amount)} ${curr.code}
السبب: ${tx.reason}
المشروع: ${proj?.name ?? 'شخصي'}
الطرف: ${pers?.name ?? 'غير محدد'}
التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(tx.transactionDate)}
الملاحظات: ${tx.notes ?? ''}
تم الإرسال عبر تطبيق حساباتي
''';
    Share.share(text);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من نقل هذه العملية إلى سلة المحذوفات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await ref.read(transactionRepositoryProvider).softDeleteTransaction(id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                context.pop(); // Go back from details
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _openFile(String path) async {
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done) {
      // Handle error
    }
  }
}


