import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../services/backup_service.dart';
import '../services/google_drive_service.dart';

const _taskName = 'diginotes_backup';
const _taskUnique = 'diginotes_backup_periodic';
const _prefKey = 'backup_frequency';

enum BackupFrequency { never, daily, weekly, monthly }

// Top-level — required by Workmanager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == _taskName) {
      final signedIn = await GoogleDriveService.instance.tryAutoSignIn();
      if (signedIn) {
        final result = await BackupService.instance.createBackup();
        return result.success;
      }
    }
    return false;
  });
}

class BackupScheduler {
  static final BackupScheduler instance = BackupScheduler._();
  BackupScheduler._();

  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  Future<BackupFrequency> getFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefKey) ?? 0;
    return BackupFrequency.values[index];
  }

  Future<void> setFrequency(BackupFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, frequency.index);
    await Workmanager().cancelByUniqueName(_taskUnique);

    if (frequency == BackupFrequency.never) return;

    final intervals = {
      BackupFrequency.daily: const Duration(days: 1),
      BackupFrequency.weekly: const Duration(days: 7),
      BackupFrequency.monthly: const Duration(days: 30),
    };

    await Workmanager().registerPeriodicTask(
      _taskUnique,
      _taskName,
      frequency: intervals[frequency]!,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
