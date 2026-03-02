import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'google_drive_service.dart';
import '../database/database_helper.dart';

class BackupResult {
  final bool success;
  final String message;
  const BackupResult({required this.success, required this.message});
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  Future<BackupResult> createBackup({int keepLast = 5}) async {
    if (!GoogleDriveService.instance.isSignedIn) {
      return const BackupResult(success: false, message: 'Not signed in to Google Drive.');
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(await getDatabasesPath(), 'diginotes.db');
      final tempDir = await getTemporaryDirectory();
      final timestamp = _formatTimestamp(DateTime.now());
      final zipPath = p.join(tempDir.path, 'diginotes_backup_$timestamp.zip');

      // Close DB to ensure file is fully flushed before zipping
      await DatabaseHelper().closeDatabase();

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        encoder.addFile(dbFile, 'db/diginotes.db');
      }

      await _addDirToZip(encoder, appDir, appDir.path);
      encoder.close();

      final fileId = await GoogleDriveService.instance.uploadFile(
        File(zipPath),
        'diginotes_backup_$timestamp.zip',
      );

      await File(zipPath).delete();

      if (fileId != null) {
        // Auto-cleanup old backups after successful upload
        await _cleanupOldBackups(keepLast: keepLast);
        return const BackupResult(success: true, message: 'Backup uploaded to Google Drive.');
      }
      return const BackupResult(success: false, message: 'Upload to Google Drive failed.');
    } catch (e) {
      return BackupResult(success: false, message: 'Backup error: $e');
    }
  }

  Future<BackupResult> restoreBackup(String fileId, String fileName) async {
    if (!GoogleDriveService.instance.isSignedIn) {
      return const BackupResult(success: false, message: 'Not signed in to Google Drive.');
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(await getDatabasesPath(), 'diginotes.db');
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, fileName);

      final downloaded = await GoogleDriveService.instance.downloadFile(fileId, zipPath);
      if (downloaded == null) {
        return const BackupResult(success: false, message: 'Download failed.');
      }

      // Close DB before replacing its file
      await DatabaseHelper().closeDatabase();

      final bytes = await downloaded.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (!file.isFile) continue;
        String outPath;
        if (file.name.startsWith('db/')) {
          outPath = dbPath;
        } else if (file.name.startsWith('media/')) {
          outPath = p.join(appDir.path, file.name.replaceFirst('media/', ''));
        } else {
          continue;
        }
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }

      await downloaded.delete();

      return const BackupResult(
        success: true,
        message: 'Restore complete! Please restart the app for changes to take effect.',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Restore error: $e');
    }
  }

  /// Keeps only the [keepLast] most recent backups, deletes the rest.
  Future<void> _cleanupOldBackups({int keepLast = 5}) async {
    try {
      final backups = await GoogleDriveService.instance.listBackups();
      // listBackups() already returns newest first (orderBy: createdTime desc)
      if (backups.length <= keepLast) return;

      final toDelete = backups.sublist(keepLast);
      for (final file in toDelete) {
        if (file.id != null) {
          await GoogleDriveService.instance.deleteFile(file.id!);
        }
      }
    } catch (e) {
      // Non-critical — don't fail the backup if cleanup fails
      print('Backup cleanup error: $e');
    }
  }

  Future<void> _addDirToZip(ZipFileEncoder encoder, Directory dir, String base) async {
    await for (final entity in dir.list()) {
      if (entity is File) {
        final rel = p.relative(entity.path, from: base);
        encoder.addFile(entity, 'media/$rel');
      } else if (entity is Directory) {
        await _addDirToZip(encoder, entity, base);
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${pad(dt.month)}${pad(dt.day)}_${pad(dt.hour)}${pad(dt.minute)}${pad(dt.second)}';
  }
}
