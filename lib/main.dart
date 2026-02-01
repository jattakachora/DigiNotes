import 'dart:async'; // Import for StreamSubscription

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:share_handler/share_handler.dart';

import 'providers/media_provider.dart';
import 'screens/folders_screen.dart';
import 'models/media_item.dart';
import 'models/folder.dart';

void main() {
  runApp(const DigiNotesApp());
}

class DigiNotesApp extends StatefulWidget {
  const DigiNotesApp({super.key});

  @override
  State<DigiNotesApp> createState() => _DigiNotesAppState();
}

class _DigiNotesAppState extends State<DigiNotesApp> {
  final QuickActions quickActions = const QuickActions();
  StreamSubscription<SharedMedia>? _sharedMediaStreamSubscription;

  @override
  void initState() {
    super.initState();
    _setupQuickActions();
    _setupSharingIntent();
  }

  void _setupQuickActions() {
    quickActions.initialize((String shortcutType) {
      _handleShortcutAction(shortcutType);
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_take_picture',
        localizedTitle: 'Take Picture',
        icon: 'camera',
      ),
      const ShortcutItem(
        type: 'action_record_video',
        localizedTitle: 'Record Video',
        icon: 'videocam',
      ),
    ]);
  }

  void _setupSharingIntent() async {
    _sharedMediaStreamSubscription = ShareHandler.instance.sharedMediaStream.listen(
      (SharedMedia media) {
        _handleSharedMedia(media);
      },
    );

    try {
      final initialMedia = await ShareHandler.instance.getInitialSharedMedia();
      if (initialMedia != null) {
        _handleSharedMedia(initialMedia);
      }
    } catch (e) {
      print('Error getting initial shared media: $e');
    }
  }

  Future<void> _handleSharedMedia(SharedMedia sharedMedia) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);

    // Load all folders first
    await mediaProvider.loadFolders();

    // Show folder selection dialog to user
    final MediaFolder? chosenFolder = await showDialog<MediaFolder>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Folder to Save Shared Media"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mediaProvider.folders.length,
            itemBuilder: (context, index) {
              final folder = mediaProvider.folders[index];
              // Fix: Access emoji via safe null-aware property
              final emojiDisplay = (folder as dynamic).emoji ?? '📁';
              return ListTile(
                leading: Text(
                  emojiDisplay,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(folder.name),
                onTap: () => Navigator.of(ctx).pop(folder),
              );
            },
          ),
        ),
      ),
    );

    if (chosenFolder == null) {
      return;
    }

    await _saveSharedMediaToFolder(sharedMedia, mediaProvider, context, chosenFolder);
  }

  Future<void> _saveSharedMediaToFolder(
    SharedMedia sharedMedia,
    MediaProvider mediaProvider,
    BuildContext context,
    MediaFolder folder,
  ) async {
    int savedCount = 0;
    final attachments = sharedMedia.attachments;
    if (attachments != null) {
      for (final attachment in attachments.whereType<SharedAttachment>()) {
        final path = attachment.path;
        if (path.isNotEmpty) {
          try {
            String type = '';
            if (attachment.type == SharedAttachmentType.image) {
              type = 'image';
            } else if (attachment.type == SharedAttachmentType.video) {
              type = 'video';
            }

            if (type.isNotEmpty) {
              final mediaItem = MediaItem(
                path: path,
                type: type,
                folderId: folder.id!,
                createdAt: DateTime.now(),
                displayName: null,
                textNote: null,
              );

              await mediaProvider.dbHelper.insertMediaItem(mediaItem);
              savedCount++;
            }
          } catch (e) {
            print('Error saving shared attachment: $e');
          }
        }
      }
    }

    if (savedCount > 0) {
      await mediaProvider.setCurrentFolder(folder);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedCount == 1
                ? '1 shared media file saved to "${folder.name}"'
                : '$savedCount shared media files saved to "${folder.name}"',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleShortcutAction(String shortcutType) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);

    mediaProvider.loadFolders().then((_) {
      final inboxFolder = mediaProvider.folders.firstWhere(
        (folder) => folder.name == 'Inbox',
        orElse: () => mediaProvider.folders.first,
      );

      mediaProvider.setCurrentFolder(inboxFolder).then((_) {
        switch (shortcutType) {
          case 'action_take_picture':
            mediaProvider.addMediaFromCamera(false);
            _showSuccessMessage(context, 'Taking picture...');
            break;
          case 'action_record_video':
            mediaProvider.addMediaFromCamera(true);
            _showSuccessMessage(context, 'Recording video...');
            break;
        }
      });
    });
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _sharedMediaStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MediaProvider(),
      child: MaterialApp(
        title: 'DigiNotes',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: const FoldersScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
