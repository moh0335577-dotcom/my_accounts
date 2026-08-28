import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_accounts/core/database/database_provider.dart';
import 'backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupService(db);
});


