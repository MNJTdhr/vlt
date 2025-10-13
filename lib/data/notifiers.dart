// lib/data/notifiers.dart
import 'package:flutter/material.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';


/// --- NOTIFIERS ---
ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);
ValueNotifier<bool> selectedThemeNotifier = ValueNotifier(false);
ValueNotifier<List<VaultFolder>> foldersNotifier = ValueNotifier([]);


/// --- FOLDER DATA HELPERS ---

List<VaultFolder> getDefaultFolders() {
  final now = DateTime.now();
  return [
    VaultFolder(
      id: 'photos_${now.millisecondsSinceEpoch}',
      name: 'Photos',
      icon: Icons.photo_library,
      color: Colors.blue,
      itemCount: 0,
      parentPath: 'root',
      creationDate: now,
    ),
    VaultFolder(
      id: 'videos_${now.millisecondsSinceEpoch + 1}',
      name: 'Videos',
      icon: Icons.video_library,
      color: Colors.red,
      itemCount: 0,
      parentPath: 'root',
      creationDate: now,
    ),
    VaultFolder(
      id: 'documents_${now.millisecondsSinceEpoch + 2}',
      name: 'Documents',
      icon: Icons.folder,
      color: Colors.orange,
      itemCount: 0,
      parentPath: 'root',
      creationDate: now,
    ),
    VaultFolder(
      id: 'notes_${now.millisecondsSinceEpoch + 3}',
      name: 'Notes',
      icon: Icons.note,
      color: Colors.green,
      itemCount: 0,
      parentPath: 'root',
      creationDate: now,
    ),
  ];
}

/// ✨ MODIFIED: Central function to refresh all item counts using efficient database queries.
Future<void> refreshItemCounts() async {
  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  
  for (final folder in currentFolders) {
    // Get counts directly from the database, which is much faster.
    final fileCount = await StorageHelper.getFileCount(folder.id);
    final subfolderCount = await StorageHelper.getSubfolderCount(folder.id);
    
    // Update the item count on the existing folder object.
    folder.itemCount = subfolderCount + fileCount;
  }

  // Update the notifier to rebuild the UI with correct counts.
  // Creating a new list from the modified one to ensure the ValueNotifier detects the change.
  foldersNotifier.value = List<VaultFolder>.from(currentFolders);
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