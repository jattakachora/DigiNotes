class MediaItem {
  final int? id;
  final String path;
  final String type; // 'image' or 'video'
  final int folderId;
  final DateTime createdAt;
  final String? displayName; // NEW: Separate display name
  final String? textNote; // Keep for actual notes

  MediaItem({
    this.id,
    required this.path,
    required this.type,
    required this.folderId,
    required this.createdAt,
    this.displayName,
    this.textNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'type': type,
      'folder_id': folderId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'display_name': displayName,
      'text_note': textNote,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'],
      path: map['path'],
      type: map['type'],
      folderId: map['folder_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      displayName: map['display_name'],
      textNote: map['text_note'],
    );
  }
}
