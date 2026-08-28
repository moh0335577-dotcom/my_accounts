import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/features/transactions/data/category_repository.dart';
import 'package:drift/drift.dart' as drift;

class CategoriesManagementScreen extends ConsumerStatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  ConsumerState<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends ConsumerState<CategoriesManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التصنيفات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المقبوضات'),
            Tab(text: 'المدفوعات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList('income'),
          _buildCategoryList('expense'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(String type) {
    final stream = ref.watch(categoryRepositoryProvider).watchCategories(type);

    return StreamBuilder<List<Category>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return const Center(child: Text('لا يوجد تصنيفات مضافة'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.category_outlined)),
                title: Text(category.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => ref.read(categoryRepositoryProvider).deleteCategory(category.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final type = _tabController.index == 0 ? 'income' : 'expense';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة تصنيف ${type == 'income' ? 'قبض' : 'دفع'}'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم التصنيف'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(categoryRepositoryProvider).addCategory(
                  CategoriesCompanion.insert(
                    name: nameController.text,
                    type: type,
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}


