import 'package:flutter/material.dart';

// Navigation state notifier
ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);

// Theme state notifier (true = dark mode, false = light mode)
ValueNotifier<bool> selectedThemeNotifier = ValueNotifier(false);

// Folder data model
class VaultFolder {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int itemCount;

  const VaultFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.itemCount = 0,
  });
}

// Default folders
final List<VaultFolder> defaultFolders = [
  const VaultFolder(
    id: 'photos',
    name: 'Photos',
    icon: Icons.photo_library,
    color: Colors.blue,
    itemCount: 0,
  ),
  const VaultFolder(
    id: 'videos',
    name: 'Videos',
    icon: Icons.video_library,
    color: Colors.red,
    itemCount: 0,
  ),
  const VaultFolder(
    id: 'documents',
    name: 'Documents',
    icon: Icons.folder,
    color: Colors.orange,
    itemCount: 0,
  ),
  const VaultFolder(
    id: 'notes',
    name: 'Notes',
    icon: Icons.note,
    color: Colors.green,
    itemCount: 0,
  ),
];