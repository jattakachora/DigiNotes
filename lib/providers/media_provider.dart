import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/folder.dart';
import '../models/media_item.dart';
import '../models/audio_note.dart';
import '../database/database_helper.dart';

class MediaProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<MediaFolder> _folders = [];
  List<MediaItem> _currentFolderItems = [];
  List<AudioNote> _currentAudioNotes = [];
  MediaFolder? _currentFolder;
  
  // NEW: for search results
  List<dynamic> _searchResults = [];

  List<MediaFolder> get folders => _folders;
  List<MediaItem> get currentFolderItems => _currentFolderItems;
  List<AudioNote> get currentAudioNotes => _currentAudioNotes;
  MediaFolder? get currentFolder => _currentFolder;
  List<dynamic> get searchResults => _searchResults;

  DatabaseHelper get dbHelper => _dbHelper;

  Future<void> loadFolders() async {
    try {
      _folders = await _dbHelper.getAllFolders();
      final inbox = _folders.where((f) => f.name == 'Inbox').toList();
      final others = _folders.where((f) => f.name != 'Inbox').toList();
      _folders = [...inbox, ...others];
      notifyListeners();
    } catch (e) {
      print('Error loading folders: $e');
    }
  }

  // NEW: Search method
  Future<void> searchFoldersAndMedia(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    try {
      final foldersResult = await _dbHelper.searchFoldersByName(query);
      final mediaResult = await _dbHelper.searchMediaItems(query);

      _searchResults = [
        ...foldersResult.map((folder) => {'type': 'folder', 'item': folder}),
        ...mediaResult.map((media) => {'type': 'media', 'item': media}),
      ];

      notifyListeners();
    } catch (e) {
      print('Error performing search: $e');
    }
  }

  Future<void> createFolder(String name, {String? emoji}) async {
    try {
      final currentCount = _folders.length;
      final folder = MediaFolder(
        name: name,
        createdAt: DateTime.now(),
        position: currentCount,
        emoji: emoji ?? '📁',
      );
      await _dbHelper.insertFolder(folder);
      await loadFolders();
    } catch (e) {
      print('Error creating folder: $e');
    }
  }

  Future<void> deleteFolder(int id) async {
    try {
      await _dbHelper.deleteFolder(id);
      await loadFolders();
    } catch (e) {
      print('Error deleting folder: $e');
    }
  }

  Future<void> renameFolder(int folderId, String newName, {String? emoji}) async {
    try {
      await _dbHelper.renameFolder(folderId, newName, emoji: emoji);
      await loadFolders();
    } catch (e) {
      print('Error renaming folder: $e');
    }
  }

  Future<void> updateFolderOrder(List<MediaFolder> orderedFolders) async {
    try {
      for (int i = 0; i < orderedFolders.length; i++) {
        await _dbHelper.updateFolderPosition(orderedFolders[i].id!, i);
      }
      await loadFolders();
    } catch (e) {
      print('Error updating folder order: $e');
    }
  }

  Future<void> setCurrentFolder(MediaFolder folder) async {
    try {
      _currentFolder = folder;
      _currentFolderItems = await _dbHelper.getMediaItemsByFolder(folder.id!);
      notifyListeners();
    } catch (e) {
      print('Error setting current folder: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.storage,
        Permission.photos,
        Permission.microphone,
      ].request();

      bool cameraGranted = statuses[Permission.camera] == PermissionStatus.granted;
      bool storageGranted = statuses[Permission.storage] == PermissionStatus.granted ||
          statuses[Permission.photos] == PermissionStatus.granted;
      bool micGranted = statuses[Permission.microphone] == PermissionStatus.granted;

      return cameraGranted && storageGranted && micGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> addMediaFromCamera(bool isVideo) async {
    try {
      if (!await _requestPermissions()) {
        print('Permissions denied');
        return;
      }

      final picker = ImagePicker();
      XFile? file;

      if (isVideo) {
        file = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
      } else {
        file = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      }

      if (file != null && _currentFolder != null) {
        final mediaItem = MediaItem(
          path: file.path,
          type: isVideo ? 'video' : 'image',
          folderId: _currentFolder!.id!,
          createdAt: DateTime.now(),
          displayName: null,
          textNote: null,
        );

        await _dbHelper.insertMediaItem(mediaItem);
        await setCurrentFolder(_currentFolder!);
      }
    } catch (e) {
      print('Error in addMediaFromCamera: $e');
    }
  }

  Future<void> addMediaFromFiles() async {
    try {
      if (!await _requestPermissions()) {
        print('Permissions denied');
        return;
      }
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
      );

      if (result != null && _currentFolder != null) {
        for (PlatformFile file in result.files) {
          if (file.path != null) {
            String type = _getMediaType(file.path!);
            if (type.isNotEmpty) {
              final mediaItem = MediaItem(
                path: file.path!,
                type: type,
                folderId: _currentFolder!.id!,
                createdAt: DateTime.now(),
                displayName: null,
                textNote: null,
              );
              await _dbHelper.insertMediaItem(mediaItem);
            }
          }
        }
        await setCurrentFolder(_currentFolder!);
      }
    } catch (e) {
      print('Error in addMediaFromFiles: $e');
    }
  }

  String _getMediaType(String path) {
    String extension = path.toLowerCase().split('.').last;
    List<String> imageExts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    List<String> videoExts = ['mp4', 'avi', 'mov', 'wmv', 'flv', '3gp', 'mkv'];

    if (imageExts.contains(extension)) return 'image';
    if (videoExts.contains(extension)) return 'video';
    return '';
  }

  Future<void> updateMediaDisplayName(MediaItem item, String? displayName) async {
    try {
      final updatedItem = MediaItem(
        id: item.id,
        path: item.path,
        type: item.type,
        folderId: item.folderId,
        createdAt: item.createdAt,
        displayName: displayName,
        textNote: item.textNote,
      );
      await _dbHelper.updateMediaItem(updatedItem);
      await setCurrentFolder(_currentFolder!);
    } catch (e) {
      print('Error updating media display name: $e');
    }
  }

  Future<void> updateMediaNote(MediaItem item, String? textNote) async {
    try {
      final updatedItem = MediaItem(
        id: item.id,
        path: item.path,
        type: item.type,
        folderId: item.folderId,
        createdAt: item.createdAt,
        displayName: item.displayName,
        textNote: textNote,
      );
      await _dbHelper.updateMediaItem(updatedItem);
      await setCurrentFolder(_currentFolder!);
    } catch (e) {
      print('Error updating media note: $e');
    }
  }

  Future<void> moveMediaItem(int itemId, int newFolderId) async {
    try {
      await _dbHelper.moveMediaItem(itemId, newFolderId);
      if (_currentFolder != null) {
        await setCurrentFolder(_currentFolder!);
      }
    } catch (e) {
      print('Error moving media item: $e');
    }
  }

  Future<void> deleteMediaItem(int itemId) async {
    try {
      MediaItem? item;
      try {
        item = _currentFolderItems.firstWhere((element) => element.id == itemId);
      } catch (e) {
        print('Media item not found: $e');
        return;
      }
      try {
        final file = File(item.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting physical file: $e');
      }
      await _dbHelper.deleteMediaItem(itemId);
      if (_currentFolder != null) {
        await setCurrentFolder(_currentFolder!);
      }
    } catch (e) {
      print('Error deleting media item: $e');
    }
  }

  Future<void> loadAudioNotes(int mediaItemId) async {
  try {
    _currentAudioNotes = await _dbHelper.getAudioNotesByMediaItem(mediaItemId);
    notifyListeners();
  } catch (e) {
    print('Error loading audio notes: $e');
  }
  }

  

  Future<void> addAudioNote(AudioNote note) async {
  try {
    print('==== ADDING AUDIO NOTE ====');
    print('Path: ${note.path}');
    print('Media Item ID: ${note.mediaItemId}');
    print('Duration: ${note.duration}');
    
    // Check if file exists
    final file = File(note.path);
    final exists = await file.exists();
    print('File exists: $exists');
    
    if (!exists) {
      print('ERROR: Audio file does not exist at path: ${note.path}');
      throw Exception('Audio file not found');
    }
    
    final noteId = await _dbHelper.insertAudioNote(note);
    print('Audio note inserted with ID: $noteId');
    
    await loadAudioNotes(note.mediaItemId);
    print('Audio notes reloaded. Count: ${_currentAudioNotes.length}');
    print('==== AUDIO NOTE ADDED ====');
  } catch (e) {
    print('ERROR adding audio note: $e');
    print('Stack trace: ${StackTrace.current}');
    rethrow;
  }
}


  Future<void> deleteAudioNote(int noteId, int mediaItemId) async {
    try {
      try {
        final audioNote = _currentAudioNotes.firstWhere((note) => note.id == noteId);
        final file = File(audioNote.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting audio file: $e');
      }
      await _dbHelper.deleteAudioNote(noteId);
      await loadAudioNotes(mediaItemId);
    } catch (e) {
      print('Error deleting audio note: $e');
    }
  }
}
