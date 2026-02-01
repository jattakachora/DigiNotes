import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../models/folder.dart';
import '../models/media_item.dart';
import '../models/audio_note.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'diginotes.db');
    return await openDatabase(
      path,
      version: 6, // Increment version to trigger migration
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _cleanupInvalidEntries(db);
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        position INTEGER DEFAULT 0,
        emoji TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE media_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL,
        type TEXT NOT NULL,
        folder_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        display_name TEXT,
        text_note TEXT,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE audio_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL,
        media_item_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        title TEXT,
        FOREIGN KEY (media_item_id) REFERENCES media_items (id) ON DELETE CASCADE
      )
    ''');

    await db.insert('folders', {
      'name': 'Inbox',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': 0,
      'emoji': '📥',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE media_items ADD COLUMN display_name TEXT');
      final columns = await db.rawQuery("PRAGMA table_info(folders);");
      final hasEmoji = columns.any((col) => col['name'] == 'emoji');
      if (!hasEmoji) {
        await db.execute('ALTER TABLE folders ADD COLUMN emoji TEXT');
      }
    }

    if (oldVersion < 3) {
      final cols = await db.rawQuery("PRAGMA table_info(folders);");
      final hasPosition = cols.any((col) => col['name'] == 'position');
      if (!hasPosition) {
        await db.execute('ALTER TABLE folders ADD COLUMN position INTEGER DEFAULT 0');
      }

      final folders = await db.query('folders', orderBy: 'name DESC');
      for (int i = 0; i < folders.length; i++) {
        final id = folders[i]['id'] as int;
        final isInbox = folders[i]['name'] == 'Inbox';
        await db.update('folders', {'position': isInbox ? 0 : i + 1},
            where: 'id = ?', whereArgs: [id]);
      }
    }

    if (oldVersion < 4) {
      final cols = await db.rawQuery("PRAGMA table_info(folders);");
      final hasEmojiCol = cols.any((col) => col['name'] == 'emoji');
      if (!hasEmojiCol) {
        await db.execute('ALTER TABLE folders ADD COLUMN emoji TEXT');
      }
    }

    if (oldVersion < 5) {
      await _cleanupInvalidEntries(db);
    }

    if (oldVersion < 6) {
      // Fix the audio_notes table column name mismatch
      print('Migrating audio_notes table to fix duration column...');
      
      // Check current columns
      final cols = await db.rawQuery("PRAGMA table_info(audio_notes);");
      final hasDurationMs = cols.any((col) => col['name'] == 'duration_ms');
      final hasDuration = cols.any((col) => col['name'] == 'duration');
      
      if (hasDurationMs && !hasDuration) {
        // Migration needed: rename duration_ms to duration
        print('Renaming duration_ms to duration...');
        
        // Create new table with correct schema
        await db.execute('''
          CREATE TABLE audio_notes_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL,
            media_item_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            duration INTEGER NOT NULL,
            title TEXT,
            FOREIGN KEY (media_item_id) REFERENCES media_items (id) ON DELETE CASCADE
          )
        ''');
        
        // Copy data from old table to new table
        await db.execute('''
          INSERT INTO audio_notes_new (id, path, media_item_id, created_at, duration, title)
          SELECT id, path, media_item_id, created_at, duration_ms, title
          FROM audio_notes
        ''');
        
        // Drop old table
        await db.execute('DROP TABLE audio_notes');
        
        // Rename new table to original name
        await db.execute('ALTER TABLE audio_notes_new RENAME TO audio_notes');
        
        print('Audio notes table migration complete!');
      } else if (!hasDuration) {
        // Table doesn't have duration column at all, add it
        print('Adding duration column...');
        await db.execute('ALTER TABLE audio_notes ADD COLUMN duration INTEGER DEFAULT 0');
      }
    }
  }

  Future<void> _cleanupInvalidEntries(Database db) async {
    try {
      final mediaItems = await db.query('media_items');
      for (var item in mediaItems) {
        final path = item['path'] as String;
        final file = File(path);
        if (!await file.exists()) {
          await db.delete('media_items', where: 'id = ?', whereArgs: [item['id']]);
          print('Deleted invalid media item: $path');
        }
      }

      final audioNotes = await db.query('audio_notes');
      for (var note in audioNotes) {
        final path = note['path'] as String;
        final file = File(path);
        if (!await file.exists()) {
          await db.delete('audio_notes', where: 'id = ?', whereArgs: [note['id']]);
          print('Deleted invalid audio note: $path');
        }
      }
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  Future<int> insertFolder(MediaFolder folder) async {
    final db = await database;
    return await db.insert('folders', folder.toMap());
  }

  Future<List<MediaFolder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'position ASC, created_at DESC');
    return maps.map((map) => MediaFolder.fromMap(map)).toList();
  }

  Future<void> deleteFolder(int id) async {
    final db = await database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateFolder(MediaFolder folder) async {
    final db = await database;
    await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> renameFolder(int id, String name, {String? emoji}) async {
    final db = await database;
    Map<String, dynamic> updateMap = {'name': name};
    if (emoji != null) {
      updateMap['emoji'] = emoji;
    }
    await db.update('folders', updateMap, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateFolderPosition(int id, int position) async {
    final db = await database;
    await db.update('folders', {'position': position}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertMediaItem(MediaItem item) async {
    final db = await database;
    return await db.insert('media_items', item.toMap());
  }

  Future<List<MediaItem>> getMediaItemsByFolder(int folderId) async {
    final db = await database;
    final maps = await db.query('media_items',
        where: 'folder_id = ?', whereArgs: [folderId], orderBy: 'created_at DESC');

    List<MediaItem> validItems = [];
    for (var map in maps) {
      final item = MediaItem.fromMap(map);
      if (await File(item.path).exists()) {
        validItems.add(item);
      } else {
        await deleteMediaItem(item.id!);
      }
    }
    return validItems;
  }

  Future<void> updateMediaItem(MediaItem item) async {
    final db = await database;
    await db.update('media_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> moveMediaItem(int itemId, int newFolderId) async {
    final db = await database;
    await db.update('media_items', {'folder_id': newFolderId},
        where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> deleteMediaItem(int id) async {
    final db = await database;
    await db.delete('media_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertAudioNote(AudioNote note) async {
    final db = await database;
    print('Inserting audio note to database: ${note.toMap()}');
    final id = await db.insert('audio_notes', note.toMap());
    print('Audio note inserted with ID: $id');
    return id;
  }

  Future<List<AudioNote>> getAudioNotesByMediaItem(int mediaItemId) async {
    final db = await database;
    print('Fetching audio notes for media item: $mediaItemId');
    final maps = await db.query('audio_notes',
        where: 'media_item_id = ?', whereArgs: [mediaItemId], orderBy: 'created_at DESC');
    
    print('Found ${maps.length} audio notes in database');

    List<AudioNote> validNotes = [];
    for (var map in maps) {
      print('Processing audio note: $map');
      final note = AudioNote.fromMap(map);
      if (await File(note.path).exists()) {
        validNotes.add(note);
        print('Audio note valid: ${note.path}');
      } else {
        await deleteAudioNote(note.id!);
        print('Audio note invalid, deleted: ${note.path}');
      }
    }
    print('Returning ${validNotes.length} valid audio notes');
    return validNotes;
  }

  Future<void> deleteAudioNote(int id) async {
    final db = await database;
    await db.delete('audio_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MediaFolder>> searchFoldersByName(String query) async {
    final db = await database;
    final maps = await db.query(
      'folders',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['%${query.toLowerCase()}%'],
    );
    return maps.map((map) => MediaFolder.fromMap(map)).toList();
  }

  Future<List<MediaItem>> searchMediaItems(String query) async {
    final db = await database;
    final maps = await db.query(
      'media_items',
      where: 'LOWER(display_name) LIKE ? OR LOWER(text_note) LIKE ?',
      whereArgs: ['%${query.toLowerCase()}%', '%${query.toLowerCase()}%'],
    );

    List<MediaItem> validItems = [];
    for (var map in maps) {
      final item = MediaItem.fromMap(map);
      if (await File(item.path).exists()) {
        validItems.add(item);
      } else {
        await deleteMediaItem(item.id!);
      }
    }
    return validItems;
  }
}
