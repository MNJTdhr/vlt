import 'package:flutter/material.dart';

// Navigation state notifier
ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);

// Theme state notifier (true = dark mode, false = light mode)
ValueNotifier<bool> selectedThemeNotifier = ValueNotifier(false);

// Folders list notifier - manages dynamic folder list
ValueNotifier<List<VaultFolder>> foldersNotifier = ValueNotifier([]);

// Folder data model
class VaultFolder {
  final String id;
  String name; // Changed to mutable for renaming
  final IconData icon;
  final Color color;
  int itemCount; // Changed to mutable for updating count

  VaultFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.itemCount = 0,
  });

  // Copy method for updating folder properties
  VaultFolder copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? itemCount,
  }) {
    return VaultFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}

// Default folders - now moved to initialization function
List<VaultFolder> getDefaultFolders() {
  return [
    VaultFolder(
      id: 'photos_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Photos',
      icon: Icons.photo_library,
      color: Colors.blue,
      itemCount: 0,
    ),
    VaultFolder(
      id: 'videos_${DateTime.now().millisecondsSinceEpoch + 1}',
      name: 'Videos',
      icon: Icons.video_library,
      color: Colors.red,
      itemCount: 0,
    ),
    VaultFolder(
      id: 'documents_${DateTime.now().millisecondsSinceEpoch + 2}',
      name: 'Documents',
      icon: Icons.folder,
      color: Colors.orange,
      itemCount: 0,
    ),
    VaultFolder(
      id: 'notes_${DateTime.now().millisecondsSinceEpoch + 3}',
      name: 'Notes',
      icon: Icons.note,
      color: Colors.green,
      itemCount: 0,
    ),
  ];
}

// Initialize folders with default values
void initializeFolders() {
  if (foldersNotifier.value.isEmpty) {
    foldersNotifier.value = getDefaultFolders();
  }
}

// Available icons for new folders
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

// Available colors for new folders
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