import 'package:flutter/material.dart';
import '../models/vault_folder.dart'; // ✅ Using the official model
import '../utils/storage_helper.dart';

/// --- NOTIFIERS ---

/// Current selected page index (e.g. Home, Settings)
ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);

/// App theme toggle (true = dark mode, false = light mode)
ValueNotifier<bool> selectedThemeNotifier = ValueNotifier(false);

/// Folder list notifier — updates UI reactively
ValueNotifier<List<VaultFolder>> foldersNotifier = ValueNotifier([]);


/// --- INITIAL DATA HELPERS ---

/// Creates a few starter folders on first launch
List<VaultFolder> getDefaultFolders() {
  return [
    VaultFolder(
      id: 'photos_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Photos',
      icon: Icons.photo_library,
      color: Colors.blue,
      itemCount: 0,
      parentPath: 'root',
    ),
    VaultFolder(
      id: 'videos_${DateTime.now().millisecondsSinceEpoch + 1}',
      name: 'Videos',
      icon: Icons.video_library,
      color: Colors.red,
      itemCount: 0,
      parentPath: 'root',
    ),
    VaultFolder(
      id: 'documents_${DateTime.now().millisecondsSinceEpoch + 2}',
      name: 'Documents',
      icon: Icons.folder,
      color: Colors.orange,
      itemCount: 0,
      parentPath: 'root',
    ),
    VaultFolder(
      id: 'notes_${DateTime.now().millisecondsSinceEpoch + 3}',
      name: 'Notes',
      icon: Icons.note,
      color: Colors.green,
      itemCount: 0,
      parentPath: 'root',
    ),
  ];
}

/// Called once at startup to load saved folders or create defaults
Future<void> initializeFolders() async {
  final savedFolders = await StorageHelper.loadFoldersMetadata();

  if (savedFolders.isNotEmpty) {
    foldersNotifier.value = savedFolders;
  } else {
    foldersNotifier.value = getDefaultFolders();
    await StorageHelper.saveFoldersMetadata(foldersNotifier.value);
  }
}


/// --- CONSTANTS FOR UI OPTIONS ---

/// Set of selectable icons shown during folder creation
const List<IconData> availableIcons = [
  Icons.folder,
  Icons.photo_library,
  Icons.video_library,
  Icons.note,
  Icons.music_note,
  Icons.picture_as_pdf,
  Icons.description,
  Icons.archive,
  Icons.favorite,
  Icons.star,
  Icons.work,
  Icons.school,
];

/// Set of selectable colors shown during folder creation
const List<Color> availableColors = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
  Colors.cyan,
  Colors.lime,
  Colors.deepOrange,
];
