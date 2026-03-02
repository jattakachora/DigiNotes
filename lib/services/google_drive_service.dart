import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._();
  GoogleDriveService._();

  final _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<bool> tryAutoSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<drive.DriveApi?> _api() async {
    if (_currentUser == null) return null;
    final headers = await _currentUser!.authHeaders;
    return drive.DriveApi(_AuthClient(headers));
  }

  Future<String?> _getOrCreateFolder(drive.DriveApi api) async {
    const name = 'DigiNotes Backups';
    final q = "name='$name' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final result = await api.files.list(q: q, $fields: 'files(id)');
    if (result.files?.isNotEmpty == true) return result.files!.first.id;

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder, $fields: 'id');
    return created.id;
  }

  Future<String?> uploadFile(File file, String fileName) async {
    try {
      final api = await _api();
      if (api == null) return null;
      final folderId = await _getOrCreateFolder(api);
      if (folderId == null) return null;

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..mimeType = 'application/zip';

      final media = drive.Media(file.openRead(), await file.length());
      final result = await api.files.create(driveFile, uploadMedia: media, $fields: 'id,name');
      return result.id;
    } catch (e) {
      return null;
    }
  }

  Future<List<drive.File>> listBackups() async {
    try {
      final api = await _api();
      if (api == null) return [];
      final folderId = await _getOrCreateFolder(api);
      if (folderId == null) return [];

      final result = await api.files.list(
        q: "'$folderId' in parents and trashed=false",
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,size,createdTime)',
      );
      return result.files ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<File?> downloadFile(String fileId, String savePath) async {
    try {
      final api = await _api();
      if (api == null) return null;
      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final file = File(savePath);
      final sink = file.openWrite();
      await media.stream.pipe(sink);
      await sink.close();
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteFile(String fileId) async {
    try {
      final api = await _api();
      if (api == null) return false;
      await api.files.delete(fileId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
