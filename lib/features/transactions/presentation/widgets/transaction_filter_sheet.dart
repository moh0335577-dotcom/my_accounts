import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import '../transactions_notifier.dart';

class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  ConsumerState<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends ConsumerState<TransactionFilterSheet> {
  late TransactionsFilter _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = ref.read(transactionsFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.filter, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() => _tempFilter = TransactionsFilter());
                },
                child: const Text('إعادة تعيين'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Project Filter
          FutureBuilder<List<Project>>(
            future: db.select(db.projects).get(),
            builder: (context, snapshot) {
              final projects = snapshot.data ?? [];
              return DropdownButtonFormField<int?>(
                value: _tempFilter.projectId,
                decoration: InputDecoration(labelText: l10n.project, border: const OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('الكل')),
                  ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                ],
                onChanged: (val) => setState(() => _tempFilter = _tempFilter.copyWith(projectId: val, clearProjectId: val == null)),
              );
            },
          ),
          const SizedBox(height: 16),

          // Type Filter
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('الكل')),
              ButtonSegment(value: 'income', label: Text('قبض')),
              ButtonSegment(value: 'expense', label: Text('دفع')),
            ],
            selected: {_tempFilter.type},
            onSelectionChanged: (val) => setState(() => _tempFilter = _tempFilter.copyWith(type: val.first, clearType: val.first == null)),
          ),
          const SizedBox(height: 16),

          // Date Filter
          ListTile(
            title: const Text('الفترة الزمنية'),
            subtitle: Text(_tempFilter.startDate == null 
                ? 'الكل' 
                : '${DateFormat('yyyy-MM-dd').format(_tempFilter.startDate!)} - ${DateFormat('yyyy-MM-dd').format(_tempFilter.endDate!)}'),
            trailing: const Icon(Icons.date_range),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange: _tempFilter.startDate != null 
                    ? DateTimeRange(start: _tempFilter.startDate!, end: _tempFilter.endDate!) 
                    : null,
              );
              if (picked != null) {
                setState(() => _tempFilter = _tempFilter.copyWith(
                  startDate: picked.start,
                  endDate: picked.end,
                ));
              }
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              ref.read(transactionsFilterProvider.notifier).state = _tempFilter;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('تطبيق الفلتر'),
          ),
        ],
      ),
    );
  }
}


