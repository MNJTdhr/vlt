// lib/data/notifiers.dart
import 'package:flutter/material.dart';
import '../models/vault_folder.dart';

/// --- NOTIFIERS ---

// ✨ FIX: Added the missing notifiers back. Your main.dart needs these.
/// Current selected page index (e.g. Home, Settings)
ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);

/// App theme toggle (true = dark mode, false = light mode)
ValueNotifier<bool> selectedThemeNotifier = ValueNotifier(false);

/// Folder list notifier — updates UI reactively
final foldersNotifier = ValueNotifier<List<VaultFolder>>([]);


/// --- INITIAL DATA HELPERS ---

/// Creates a few starter folders on first launch. This is called from main.dart.
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