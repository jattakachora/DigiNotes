class MediaFolder {
  final int? id;
  final String name;
  final DateTime createdAt;
  final int? position;
  final String? emoji; // Emoji icon for the folder

  MediaFolder({
    this.id,
    required this.name,
    required this.createdAt,
    this.position,
    this.emoji,
  });

  // Convert a MediaFolder into a Map for storing in DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'position': position,
      'emoji': emoji,
    };
  }

  // Create a MediaFolder from a Map fetched from DB
  factory MediaFolder.fromMap(Map<String, dynamic> map) {
    return MediaFolder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      position: map['position'] as int?,
      emoji: map['emoji'] as String?,
    );
  }
}
