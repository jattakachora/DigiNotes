import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';
import 'dart:io';

class MediaItemWidget extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const MediaItemWidget({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<MediaItemWidget> createState() => _MediaItemWidgetState();
}

class _MediaItemWidgetState extends State<MediaItemWidget> {
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

            // Video play indicator
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

            // Note indicator
            if (widget.item.textNote != null &&
                widget.item.textNote!.isNotEmpty)
              const Positioned(
                bottom: 8,
                left: 8,
                child: Icon(
                  Icons.note,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
