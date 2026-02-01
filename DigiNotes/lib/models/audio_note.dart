class AudioNote {
  final int? id;
  final String path;
  final int mediaItemId;
  final DateTime createdAt;
  final Duration duration;
  final String? title;

  AudioNote({
    this.id,
    required this.path,
    required this.mediaItemId,
    required this.createdAt,
    required this.duration,
    this.title,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'media_item_id': mediaItemId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'duration': duration.inMilliseconds, // FIXED: Changed from duration_ms to duration
      'title': title,
    };
  }

  factory AudioNote.fromMap(Map<String, dynamic> map) {
    return AudioNote(
      id: map['id'],
      path: map['path'],
      mediaItemId: map['media_item_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      duration: Duration(milliseconds: map['duration']), // FIXED: Changed from duration_ms to duration
      title: map['title'],
    );
  }
}
