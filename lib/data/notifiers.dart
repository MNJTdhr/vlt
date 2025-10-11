// lib/data/notifiers.dart
import 'package:flutter/material.dart';
import 'package:vlt/models/vault_folder.dart';
import 'dart:io'; // ✨ ADDED: Needed for File type
import 'package:vlt/utils/storage_helper.dart'; // ✨ ADDED: Needed for refresh function


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

/// ✨ NEW: Central function to refresh all item counts.
Future<void> refreshItemCounts() async {
  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  final List<VaultFolder> foldersWithRefreshedCounts = [];

  for (final folder in currentFolders) {
    // Get physical files
    final contents = await StorageHelper.getFolderContents(folder);
    final fileCount = contents.whereType<File>().length;

    // Get subfolders from our in-memory list
    final subfolderCount = currentFolders.where((sub) => sub.parentPath == folder.id).length;

    // Create a new folder instance with the updated total count
    foldersWithRefreshedCounts.add(folder.copyWith(itemCount: subfolderCount + fileCount));
  }

  // Update the notifier to rebuild the UI with correct counts
  foldersNotifier.value = foldersWithRefreshedCounts;
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