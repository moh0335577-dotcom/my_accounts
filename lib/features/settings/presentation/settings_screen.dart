import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/localization/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:my_accounts/features/settings/presentation/settings_provider.dart';
import 'package:my_accounts/core/utils/security_service.dart';
import 'package:my_accounts/core/utils/backup_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final backupService = ref.read(backupServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'الإدارة العامة'),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('إدارة الأشخاص والجهات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/people'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('إدارة التصنيفات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(l10n.trash),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/trash'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'التطبيق'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('اللغة (Language)'),
            subtitle: Text(settings.locale.languageCode == 'ar' ? 'العربية' : 'English'),
            onTap: () {
              final newLocale = settings.locale.languageCode == 'ar' 
                  ? const Locale('en') 
                  : const Locale('ar');
              settingsNotifier.setLocale(newLocale);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('المظهر (Theme)'),
            subtitle: Text(_getThemeName(settings.themeMode)),
            onTap: () => _showThemeDialog(context, settingsNotifier, settings.themeMode),
          ),
          const Divider(),
          _buildSectionHeader(context, 'البيانات والأمان'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('نسخ احتياطي واستعادة'),
            onTap: () => _showBackupDialog(context, backupService),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('قفل التطبيق (PIN/Biometric)'),
            trailing: Switch(
              value: settings.isLocked,
              onChanged: (val) async {
                final success = await SecurityService.authenticate();
                if (success) {
                  settingsNotifier.toggleLock(val);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشلت عملية التحقق')),
                  );
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('عن التطبيق'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'حساباتي | My Accounts',
                applicationVersion: '1.0.0',
                applicationIcon: const FlutterLogo(size: 40),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'فاتح';
      case ThemeMode.dark: return 'داكن';
      case ThemeMode.system: return 'تلقائي حسب النظام';
    }
  }

  void _showThemeDialog(BuildContext context, SettingsNotifier notifier, ThemeMode current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر المظهر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('تلقائي'),
              value: ThemeMode.system,
              groupValue: current,
              onChanged: (val) { notifier.setThemeMode(val!); Navigator.pop(context); },
            ),
            RadioListTile(
              title: const Text('فاتح'),
              value: ThemeMode.light,
              groupValue: current,
              onChanged: (val) { notifier.setThemeMode(val!); Navigator.pop(context); },
            ),
            RadioListTile(
              title: const Text('داكن'),
              value: ThemeMode.dark,
              groupValue: current,
              onChanged: (val) { notifier.setThemeMode(val!); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, dynamic backupService) {
     showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('تصدير نسخة احتياطية (Export)'),
              onTap: () async {
                Navigator.pop(context);
                await backupService.exportBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('استعادة نسخة احتياطية (Import)'),
              onTap: () async {
                Navigator.pop(context);
                final success = await backupService.importBackup();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم استعادة البيانات بنجاح، يرجى إعادة تشغيل التطبيق')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}


