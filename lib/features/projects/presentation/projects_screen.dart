import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:my_accounts/core/database/app_database.dart';
import 'package:my_accounts/features/projects/data/project_repository.dart';
import 'package:drift/drift.dart' as drift;

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projectsStream = ref.watch(projectRepositoryProvider).watchAllProjects();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projects),
      ),
      body: StreamBuilder<List<Project>>(
        stream: projectsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final projects = snapshot.data ?? [];
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('لا يوجد مشاريع مضافة حالياً'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(project.description ?? 'بدون وصف'),
                  trailing: _buildStatusChip(project.status, l10n),
                  onTap: () {
                    // Navigate to project details
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProjectDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusChip(String status, AppLocalizations l10n) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = Colors.green;
        label = l10n.active;
        break;
      case 'completed':
        color = Colors.blue;
        label = l10n.completed;
        break;
      case 'stopped':
        color = Colors.orange;
        label = l10n.stopped;
        break;
      case 'archived':
        color = Colors.grey;
        label = l10n.archived;
        break;
      default:
        color = Colors.black;
        label = status;
    }
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showAddProjectDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مشروع جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم المشروع'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(projectRepositoryProvider).addProject(
                      ProjectsCompanion.insert(
                        name: nameController.text,
                        description: drift.Value(descController.text),
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


