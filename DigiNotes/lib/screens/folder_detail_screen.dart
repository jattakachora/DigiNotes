import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../providers/media_provider.dart';
import '../models/folder.dart';
import '../models/media_item.dart';
import 'media_detail_screen.dart';
import 'dart:io';
import 'dart:typed_data';

class FolderDetailScreen extends StatefulWidget {
  final MediaFolder folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MediaProvider>(context, listen: false)
          .setCurrentFolder(widget.folder);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip:
                _isGridView ? 'Switch to List View' : 'Switch to Grid View',
          ),
        ],
      ),
      body: Consumer<MediaProvider>(
        builder: (context, provider, child) {
          if (provider.currentFolderItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No media files yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use the buttons below to add media',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return _isGridView
              ? _buildGridView(provider.currentFolderItems)
              : _buildListView(provider.currentFolderItems);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildActionButtons(),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          // Take Photo Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _takePhoto(),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text(
                  'Photo',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Record Video Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _recordVideo(),
                icon: const Icon(Icons.videocam, size: 18),
                label: const Text(
                  'Video',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Pick Files Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _pickFiles(),
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text(
                  'Files',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<MediaItem> items) {
    return GridView.builder(
      padding: EdgeInsets.only(
        left: 8.0,
        right: 8.0,
        top: 8.0,
        bottom: MediaQuery.of(context).padding.bottom + 140.0,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _MediaGridTile(
          item: item,
          onTap: () => _showMediaDetail(context, item),
          onRename: (newName) => _renameMedia(item, newName),
          onDelete: () => _deleteMedia(item),
        );
      },
    );
  }

  Widget _buildListView(List<MediaItem> items) {
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8.0,
        bottom: MediaQuery.of(context).padding.bottom + 140.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _MediaListTile(
          item: item,
          onTap: () => _showMediaDetail(context, item),
          onRename: (newName) => _renameMedia(item, newName),
          onDelete: () => _deleteMedia(item),
        );
      },
    );
  }

  // Button action methods
  void _takePhoto() {
    Provider.of<MediaProvider>(context, listen: false)
        .addMediaFromCamera(false);
  }

  void _recordVideo() {
    Provider.of<MediaProvider>(context, listen: false).addMediaFromCamera(true);
  }

  void _pickFiles() {
    Provider.of<MediaProvider>(context, listen: false).addMediaFromFiles();
  }

  void _showMediaDetail(BuildContext context, MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaDetailScreen(item: item),
      ),
    );
  }

  void _renameMedia(MediaItem item, String newName) {
    Provider.of<MediaProvider>(context, listen: false)
        .updateMediaDisplayName(item, newName);
  }

  void _deleteMedia(MediaItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text(
            'Are you sure you want to delete this media item and all its notes? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<MediaProvider>(context, listen: false)
          .deleteMediaItem(item.id!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media deleted successfully')),
      );
    }
  }

  // ignore: unused_element
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}

class _MediaGridTile extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final Function(String) onRename;
  final VoidCallback onDelete;

  const _MediaGridTile({
    required this.item,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_MediaGridTile> createState() => _MediaGridTileState();
}

class _MediaGridTileState extends State<_MediaGridTile> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'video') {
      _initVideoController();
    }
  }

  Future<void> _initVideoController() async {
    _videoController = VideoPlayerController.file(File(widget.item.path));
    try {
      await _videoController!.initialize();
      await _videoController!.seekTo(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media content
            if (widget.item.type == 'image')
              Image.file(
                File(widget.item.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 50),
                  );
                },
              )
            else if (widget.item.type == 'video')
              _isVideoInitialized && _videoController != null
                  ? VideoPlayer(_videoController!)
                  : Container(
                      color: Colors.black87,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),

            // Overlay with title and actions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.item.displayName?.isNotEmpty == true
                          ? widget.item.displayName!
                          : _formatDate(widget.item.createdAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => _showRenameDialog(),
                          icon: const Icon(Icons.edit,
                              color: Colors.white, size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Video indicator
            if (widget.item.type == 'video')
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 30,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final TextEditingController controller = TextEditingController(
      text: widget.item.displayName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Media'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onRename(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}

class _MediaListTile extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final Function(String) onRename;
  final VoidCallback onDelete;

  const _MediaListTile({
    required this.item,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_MediaListTile> createState() => _MediaListTileState();
}

class _MediaListTileState extends State<_MediaListTile> {
  Uint8List? _videoThumbnail;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'video') {
      _generateVideoThumbnail();
    }
  }

  Future<void> _generateVideoThumbnail() async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: widget.item.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 120,
        quality: 50,
      );
      if (mounted) {
        setState(() {
          _videoThumbnail = thumbnail;
        });
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 60,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.item.type == 'image'
              ? Image.file(
                  File(widget.item.path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 30),
                    );
                  },
                )
              : _videoThumbnail != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          _videoThumbnail!,
                          fit: BoxFit.cover,
                        ),
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: Colors.black87,
                          child: const Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
      title: Text(
        widget.item.displayName?.isNotEmpty == true
            ? widget.item.displayName!
            : _formatDate(widget.item.createdAt),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Created: ${_formatDate(widget.item.createdAt)}',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _showRenameDialog(context),
            icon: const Icon(Icons.edit, color: Colors.blue),
          ),
          IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
      onTap: widget.onTap,
    );
  }

  void _showRenameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: widget.item.displayName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Media'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onRename(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
