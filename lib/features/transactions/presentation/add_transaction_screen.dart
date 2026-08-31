import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:my_accounts/features/transactions/data/transaction_repository.dart';
import 'package:my_accounts/core/theme/app_theme.dart';
import 'package:my_accounts/core/utils/file_service.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final int? transactionId;
  final int? initialProjectId;

  const AddTransactionScreen({super.key, this.transactionId, this.initialProjectId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _transactionType = 'income';
  int? _selectedCurrencyId;
  int? _selectedProjectId;
  int? _selectedCategoryId;
  int? _selectedPersonId;
  DateTime _selectedDate = DateTime.now();
  
  final List<File> _newAttachments = [];
  List<Attachment> _existingAttachments = [];

  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    if (widget.transactionId != null) {
      _isEdit = true;
      _loadTransactionData();
    } else {
      _loadDefaults();
    }
  }

  void _loadTransactionData() async {
    final db = ref.read(databaseProvider);
    final tx = await (db.select(db.transactions)..where((t) => t.id.equals(widget.transactionId!))).getSingleOrNull();
    if (tx != null && mounted) {
      setState(() {
        _transactionType = tx.type;
        _amountController.text = tx.amount.toString();
        _reasonController.text = tx.reason;
        _notesController.text = tx.notes ?? '';
        _selectedCurrencyId = tx.currencyId;
        _selectedProjectId = tx.projectId;
        _selectedCategoryId = tx.categoryId;
        _selectedPersonId = tx.personId;
        _selectedDate = tx.transactionDate;
      });
      
      final attaches = await (db.select(db.attachments)..where((a) => a.transactionId.equals(tx.id))).get();
      setState(() {
        _existingAttachments = attaches;
      });
    }
  }

  void _loadDefaults() async {
    final db = ref.read(databaseProvider);
    final defaultCurrency = await (db.select(db.currencies)..where((t) => t.isDefault.equals(true))).getSingleOrNull();
    if (mounted && defaultCurrency != null) {
      setState(() {
        _selectedCurrencyId = defaultCurrency.id;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل عملية' : l10n.addTransaction),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'income', label: Text(l10n.income), icon: const Icon(Icons.add_circle_outline)),
                  ButtonSegment(value: 'expense', label: Text(l10n.expenses), icon: const Icon(Icons.remove_circle_outline)),
                ],
                selected: {_transactionType},
                onSelectionChanged: (value) {
                  setState(() {
                    _transactionType = value.first;
                    _selectedCategoryId = null;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'يرجى إدخال المبلغ';
                  if (double.tryParse(value) == null) return 'يرجى إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<List<Currency>>(
                      future: db.select(db.currencies).get(),
                      builder: (context, snapshot) {
                        final currencies = snapshot.data ?? [];
                        return DropdownButtonFormField<int>(
                          value: _selectedCurrencyId,
                          decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                          items: currencies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.code))).toList(),
                          onChanged: (val) => setState(() => _selectedCurrencyId = val),
                          validator: (val) => val == null ? 'مطلوب' : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<List<Category>>(
                      future: (db.select(db.categories)..where((t) => t.type.equals(_transactionType))).get(),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        return DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('غير محدد')),
                            ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: l10n.reason,
                  hintText: 'مثلاً: دفعة أولى، أجور عمال...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'يرجى إدخال السبب' : null,
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<Project>>(
                future: db.select(db.projects).get(),
                builder: (context, snapshot) {
                  final projects = snapshot.data ?? [];
                  return DropdownButtonFormField<int>(
                    value: _selectedProjectId,
                    decoration: InputDecoration(
                      labelText: l10n.project,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.work_outline),
                    ),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('شخصي (بدون مشروع)')),
                      ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedProjectId = val),
                  );
                },
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<Person>>(
                future: db.select(db.people).get(),
                builder: (context, snapshot) {
                  final people = snapshot.data ?? [];
                  return DropdownButtonFormField<int>(
                    value: _selectedPersonId,
                    decoration: const InputDecoration(
                      labelText: 'الطرف المرتبط',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('غير محدد')),
                      ...people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedPersonId = val),
                  );
                },
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.date,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('yyyy-MM-dd — HH:mm').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.notes,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Attachments Section
              Text('المرفقات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._existingAttachments.map((a) => Chip(
                    label: Text(a.fileName, style: const TextStyle(fontSize: 10)),
                    onDeleted: () => _removeExistingAttachment(a),
                  )),
                  ..._newAttachments.map((f) => Chip(
                    label: Text(p.basename(f.path), style: const TextStyle(fontSize: 10)),
                    onDeleted: () => setState(() => _newAttachments.remove(f)),
                    backgroundColor: Colors.blue[50],
                  )),
                  ActionChip(
                    avatar: const Icon(Icons.add_a_photo, size: 16),
                    label: const Text('إضافة'),
                    onPressed: _pickAttachment,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _transactionType == 'income' ? AppTheme.incomeGreen : AppTheme.expenseRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_isEdit ? 'تحديث العملية' : l10n.save, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
              title: const Text('تصوير بالكاميرا'),
              onTap: () async {
                Navigator.pop(context);
                final file = await FileService.pickImage(ImageSource.camera);
                if (file != null) {
                  setState(() {
                    _newAttachments.add(file);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryBlue),
              title: const Text('اختيار من المعرض'),
              onTap: () async {
                Navigator.pop(context);
                final file = await FileService.pickImage(ImageSource.gallery);
                if (file != null) {
                  setState(() {
                    _newAttachments.add(file);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppTheme.primaryBlue),
              title: const Text('اختيار ملف / مستند'),
              onTap: () async {
                Navigator.pop(context);
                final file = await FileService.pickFile();
                if (file != null) {
                  setState(() {
                    _newAttachments.add(file);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeExistingAttachment(Attachment a) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.attachments)..where((t) => t.id.equals(a.id))).go();
    await FileService.deleteFile(a.filePath);
    setState(() {
      _existingAttachments.removeWhere((element) => element.id == a.id);
    });
  }

  void _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      final repo = ref.read(transactionRepositoryProvider);
      final db = ref.read(databaseProvider);
      final amount = double.parse(_amountController.text);
      
      final companion = TransactionsCompanion(
        id: _isEdit ? drift.Value(widget.transactionId!) : const drift.Value.absent(),
        type: drift.Value(_transactionType),
        amount: drift.Value(amount),
        currencyId: drift.Value(_selectedCurrencyId!),
        projectId: drift.Value(_selectedProjectId),
        categoryId: drift.Value(_selectedCategoryId),
        personId: drift.Value(_selectedPersonId),
        reason: drift.Value(_reasonController.text),
        notes: drift.Value(_notesController.text),
        transactionDate: drift.Value(_selectedDate),
        updatedAt: drift.Value(DateTime.now()),
      );

      int txId;
      if (_isEdit) {
        await repo.updateTransaction(companion);
        txId = widget.transactionId!;
      } else {
        txId = await repo.addTransaction(companion);
      }

      // Save new attachments
      for (var file in _newAttachments) {
        final savedPath = await FileService.saveAttachment(file);
        await db.into(db.attachments).insert(AttachmentsCompanion.insert(
          transactionId: txId,
          fileName: p.basename(file.path),
          filePath: savedPath,
          fileType: p.extension(file.path),
        ));
      }

      if (mounted) {
        context.pop();
      }
    }
  }
}
