import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_item.dart';
import '../models/audio_note.dart';
import '../providers/media_provider.dart';
import '../widgets/zoomable_image_viewer.dart';
import '../widgets/audio_player_widget.dart';
import 'dart:io';
import 'dart:async';

class MediaDetailScreen extends StatefulWidget {
  final MediaItem item;

  const MediaDetailScreen({super.key, required this.item});

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  final TextEditingController _noteController = TextEditingController();
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _debounceTimer;
  Timer? _recordingTimer; // NEW: Add recording timer

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadAudioNotes();

    if (widget.item.type == 'video') {
      _initVideoController();
    }

    _noteController.text = widget.item.textNote ?? '';
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  Future<void> _initVideoController() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.item.path));
    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: false,
      looping: false,
      showControls: true,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blueAccent,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.lightBlue,
      ),
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      autoInitialize: true,
    );

    if (mounted) setState(() {});
  }

  void _loadAudioNotes() {
    Provider.of<MediaProvider>(context, listen: false)
        .loadAudioNotes(widget.item.id!);
  }

  void _autoSaveNote(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final updatedItem = MediaItem(
        id: widget.item.id,
        path: widget.item.path,
        type: widget.item.type,
        folderId: widget.item.folderId,
        createdAt: widget.item.createdAt,
        displayName: widget.item.displayName,
        textNote: text.trim().isEmpty ? null : text.trim(),
      );

      Provider.of<MediaProvider>(context, listen: false)
          .updateMediaNote(updatedItem, text.trim().isEmpty ? null : text.trim());
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _recorder?.closeRecorder();
    _noteController.dispose();
    _debounceTimer?.cancel();
    _recordingTimer?.cancel(); // NEW: Cancel recording timer
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      
      await _recorder!.startRecorder(toFile: path);
      
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      
      // NEW: Use a proper timer instead of recursive function
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isRecording || !mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingDuration = _recordingDuration + const Duration(seconds: 1);
        });
      });
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start recording')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder!.stopRecorder();
      
      setState(() {
        _isRecording = false;
      });
      
      _recordingTimer?.cancel(); // NEW: Cancel the timer
      
      if (path != null) {
        final audioNote = AudioNote(
          path: path,
          mediaItemId: widget.item.id!,
          createdAt: DateTime.now(),
          duration: _recordingDuration,
          title: 'Audio Note ${DateTime.now().millisecondsSinceEpoch}',
        );

        final provider = Provider.of<MediaProvider>(context, listen: false);
        await provider.addAudioNote(audioNote);
        
        // NEW: Force a reload with a small delay to ensure database has committed
        await Future.delayed(const Duration(milliseconds: 300));
        await provider.loadAudioNotes(widget.item.id!);
        
        if (mounted) {
          // NEW: Force UI rebuild
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio note saved!')),
          );
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save audio note')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _openImageViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZoomableImageViewer(imagePath: widget.item.path),
      ),
    );
  }

  Future<void> _shareMedia() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.item.path)],
        text: widget.item.type == 'video'
            ? 'Check out this video!'
            : 'Check out this photo!',
      );
    } catch (e) {
      print('Error sharing media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share media')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAudioNote(AudioNote note) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Audio Note'),
        content: const Text(
            'Are you sure you want to delete this audio note? This action cannot be undone.'),
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

    if (confirmed == true && mounted) {
      await Provider.of<MediaProvider>(context, listen: false)
          .deleteAudioNote(note.id!, widget.item.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio note deleted')),
        );
      }
    }
  }

  void _showMoveFolderDialog() {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mediaProvider.folders.length,
            itemBuilder: (context, index) {
              final folder = mediaProvider.folders[index];
              return ListTile(
                leading: Text(
                  folder.emoji ?? '📁',
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(folder.name),
                onTap: () {
                  mediaProvider.moveMediaItem(widget.item.id!, folder.id!);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareMedia,
          ),
          IconButton(
            icon: const Icon(Icons.move_to_inbox),
            onPressed: _showMoveFolderDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.item.type == 'image' ? _openImageViewer : null,
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.item.type == 'image'
                      ? Image.file(
                          File(widget.item.path),
                          fit: BoxFit.contain,
                        )
                      : _chewieController != null &&
                              _chewieController!
                                  .videoPlayerController.value.isInitialized
                          ? Chewie(controller: _chewieController!)
                          : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: Scrollbar(
                thumbVisibility: true,
                child: TextField(
                  controller: _noteController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: 'Add your notes here...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: (text) {
                    _autoSaveNote(text);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audio Notes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  label: Text(_isRecording ? 'Stop' : 'Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_isRecording)
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Consumer<MediaProvider>(
              builder: (context, provider, child) {
                print('Audio notes count: ${provider.currentAudioNotes.length}'); // NEW: Debug print
                
                if (provider.currentAudioNotes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No audio notes yet. Tap "Record" to add one.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audio Notes:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ...provider.currentAudioNotes.map((note) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            note.title ??
                                                'Audio Note ${note.id}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            _formatTimestamp(note.createdAt),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _confirmDeleteAudioNote(note),
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                    ),
                                  ],
                                ),
                                AudioPlayerWidget(
                                  audioNote: note,
                                  onDelete: null,
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
