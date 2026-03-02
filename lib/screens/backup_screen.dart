import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../services/google_drive_service.dart';
import '../services/backup_service.dart';
import '../services/backup_scheduler.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  bool _loadingBackups = false;
  String _statusMessage = '';
  List<drive.File> _backups = [];
  BackupFrequency _frequency = BackupFrequency.never;
  final _driveService = GoogleDriveService.instance;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _driveService.tryAutoSignIn();
    final freq = await BackupScheduler.instance.getFrequency();
    if (mounted) setState(() => _frequency = freq);
    if (_driveService.isSignedIn) await _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loadingBackups = true);
    final list = await _driveService.listBackups();
    if (mounted) setState(() { _backups = list; _loadingBackups = false; });
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final ok = await _driveService.signIn();
    if (ok) await _loadBackups();
    if (mounted) setState(() {
      _loading = false;
      _statusMessage = ok ? 'Signed in as ${_driveService.currentUser?.email}' : 'Sign-in cancelled.';
    });
  }

  Future<void> _signOut() async {
    await _driveService.signOut();
    if (mounted) setState(() { _backups = []; _statusMessage = 'Signed out.'; });
  }

  Future<void> _createBackup() async {
    setState(() { _loading = true; _statusMessage = 'Creating backup...'; });
    final result = await BackupService.instance.createBackup();
    if (result.success) await _loadBackups();
    if (mounted) setState(() { _loading = false; _statusMessage = result.message; });
  }

  Future<void> _confirmRestore(drive.File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Text(
          'Restore "${file.name}"?\n\nThis will overwrite all current data. The app will need to restart afterwards.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _loading = true; _statusMessage = 'Restoring backup...'; });
    final result = await BackupService.instance.restoreBackup(file.id!, file.name!);
    if (mounted) setState(() { _loading = false; _statusMessage = result.message; });

    if (result.success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Restore Complete'),
          content: const Text('Your data has been restored. Please close and reopen the app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _confirmDelete(drive.File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Delete "${file.name}" from Google Drive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _driveService.deleteFile(file.id!);
    if (ok) await _loadBackups();
    if (mounted) setState(() => _statusMessage = ok ? 'Backup deleted.' : 'Delete failed.');
  }

  Future<void> _setSchedule(BackupFrequency freq) async {
    await BackupScheduler.instance.setFrequency(freq);
    if (mounted) setState(() {
      _frequency = freq;
      _statusMessage = freq == BackupFrequency.never
          ? 'Scheduled backup disabled.'
          : 'Backup scheduled: ${freq.name}.';
    });
  }

  String _formatFileDate(drive.File file) {
    if (file.createdTime == null) return '';
    final dt = file.createdTime!.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  String _formatSize(drive.File file) {
    final bytes = int.tryParse(file.size ?? '0') ?? 0;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive Backup'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Google Account ──────────────────────────────────
            _SectionHeader(icon: Icons.account_circle, title: 'Google Account'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _driveService.isSignedIn
                    ? Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Connected', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  _driveService.currentUser?.email ?? '',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          TextButton(onPressed: _signOut, child: const Text('Sign Out')),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.grey),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Not connected to Google Drive')),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _signIn,
                            icon: const Icon(Icons.login, size: 18),
                            label: const Text('Sign In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Manual Backup ───────────────────────────────────
            _SectionHeader(icon: Icons.backup, title: 'Manual Backup'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Creates a zip of your entire DigiNotes database and all media files, uploaded to Google Drive.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_loading || !_driveService.isSignedIn) ? null : _createBackup,
                        icon: _loading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(_loading ? 'Working...' : 'Backup Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Schedule ────────────────────────────────────────
            _SectionHeader(icon: Icons.schedule, title: 'Scheduled Backups'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: BackupFrequency.values.map((freq) {
                    final labels = {
                      BackupFrequency.never: 'Disabled',
                      BackupFrequency.daily: 'Daily',
                      BackupFrequency.weekly: 'Weekly',
                      BackupFrequency.monthly: 'Monthly',
                    };
                    return RadioListTile<BackupFrequency>(
                      value: freq,
                      groupValue: _frequency,
                      title: Text(labels[freq]!),
                      activeColor: Colors.blue,
                      onChanged: _driveService.isSignedIn
                          ? (v) => _setSchedule(v!)
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ),

            if (!_driveService.isSignedIn)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 8),
                child: Text(
                  'Sign in to enable scheduled backups.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),

            const SizedBox(height: 20),

            // ── Existing Backups ────────────────────────────────
            _SectionHeader(icon: Icons.history, title: 'Existing Backups'),
            if (_loadingBackups)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_backups.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _driveService.isSignedIn ? 'No backups yet.' : 'Sign in to view backups.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ...(_backups.map((file) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder_zip, color: Colors.blue, size: 36),
                  title: Text(
                    file.name ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatFileDate(file)}  •  ${_formatSize(file)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.orange),
                        tooltip: 'Restore',
                        onPressed: _loading ? null : () => _confirmRestore(file),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: _loading ? null : () => _confirmDelete(file),
                      ),
                    ],
                  ),
                ),
              ))),

            // ── Status bar ──────────────────────────────────────
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusMessage.toLowerCase().contains('fail') ||
                            _statusMessage.toLowerCase().contains('error')
                        ? Colors.red[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _statusMessage.toLowerCase().contains('fail') ||
                              _statusMessage.toLowerCase().contains('error')
                          ? Colors.red[200]!
                          : Colors.green[200]!,
                    ),
                  ),
                  child: Text(_statusMessage),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
