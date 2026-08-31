import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/features/people/data/people_repository.dart';
import 'package:drift/drift.dart' as drift;

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleStream = ref.watch(peopleRepositoryProvider).watchAllPeople();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأشخاص والجهات'),
      ),
      body: StreamBuilder<List<Person>>(
        stream: peopleStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final people = snapshot.data ?? [];
          if (people.isEmpty) {
            return const Center(child: Text('لا يوجد أشخاص مضافين'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(person.phone ?? 'بدون رقم هاتف'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditPersonDialog(context, ref, person),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeletePerson(context, ref, person),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navigate to person details/transactions
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPersonDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة شخص/جهة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(peopleRepositoryProvider).addPerson(
                  PeopleCompanion.insert(
                    name: nameController.text,
                    phone: drift.Value(phoneController.text),
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

  void _showEditPersonDialog(BuildContext context, WidgetRef ref, Person person) {
    final nameController = TextEditingController(text: person.name);
    final phoneController = TextEditingController(text: person.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل البيانات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(peopleRepositoryProvider).updatePerson(
                  PeopleCompanion(
                    id: drift.Value(person.id),
                    name: drift.Value(nameController.text),
                    phone: drift.Value(phoneController.text),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePerson(BuildContext context, WidgetRef ref, Person person) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف "${person.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await ref.read(peopleRepositoryProvider).deletePerson(person.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
