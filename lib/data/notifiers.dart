// lib/data/notifiers.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';

// ✨ ADDED: Enum to define the available sort options for the home page.
enum HomeSortOption {
  manual, // ✨ ADDED
  dateNewest,
  dateOldest,
  nameAZ,
  nameZA,
}

/// --- NOTIFIERS ---
ValueNotifier<int> selectedPageNotifier = ValueNotifier(0);
ValueNotifier<bool> selectedThemeNotifier = ValueNotifier(false);
// ✨ ADDED: Notifier for the primary theme color.
ValueNotifier<Color> selectedColorNotifier = ValueNotifier(Colors.blue);
ValueNotifier<List<VaultFolder>> foldersNotifier = ValueNotifier([]);
// ✨ ADDED: Notifier to hold the current sort order for the home page folders.
ValueNotifier<HomeSortOption> homeSortNotifier =
    ValueNotifier(HomeSortOption.manual); // ✨ MODIFIED: Default to manual sort.

/// --- THEME HELPERS ---

// ✨ MODIFIED: Loads both theme mode and color preference from disk.
Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  // Reads the 'isDarkMode' boolean. Defaults to false (light mode).
  selectedThemeNotifier.value = prefs.getBool('isDarkMode') ?? false;

  // Reads the 'themeColor' integer. Defaults to blue.
  final colorValue = prefs.getInt('themeColor') ?? Colors.blue.value;
  selectedColorNotifier.value = Color(colorValue);
}

// ✨ ADDED: Saves the theme preferences to disk and updates the notifiers.
// This replaces the old toggleThemePreference function.
Future<void> saveThemePreference(
    {required bool isDarkMode, required Color color}) async {
  final prefs = await SharedPreferences.getInstance();

  // Update the global notifiers to trigger UI rebuilds.
  selectedThemeNotifier.value = isDarkMode;
  selectedColorNotifier.value = color;

  // Save the new values to the device.
  await prefs.setBool('isDarkMode', isDarkMode);
  await prefs.setInt('themeColor', color.value);
}

/// --- SORTING HELPERS ---

// ✨ ADDED: Loads the saved home page sort preference from disk.
Future<void> loadHomeSortPreference() async {
  final prefs = await SharedPreferences.getInstance();
  final savedIndex = prefs.getInt('homeSortOrder');
  if (savedIndex != null && savedIndex < HomeSortOption.values.length) {
    homeSortNotifier.value = HomeSortOption.values[savedIndex];
  }
}

// ✨ ADDED: Saves the selected home page sort preference to disk.
Future<void> saveHomeSortPreference(HomeSortOption option) async {
  final prefs = await SharedPreferences.getInstance();
  homeSortNotifier.value = option;
  await prefs.setInt('homeSortOrder', option.index);
}

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
      sortOrder: 0, // ✨ ADDED
    ),
    VaultFolder(
      id: 'videos_${now.millisecondsSinceEpoch + 1}',
      name: 'Videos',
      icon: Icons.video_library,
      color: Colors.red,
      itemCount: 0,
      parentPath: 'root',
      creationDate: now,
      sortOrder: 1, // ✨ ADDED
    ),
    VaultFolder(
      id: 'documents_${now.millisecondsSinceEpoch + 2}',
      name: 'Documents',
      icon: Icons.folder,
      color: Colors.orange,
      itemCount: 0,
      parentPath: 'root',
      creationDate: now,
      sortOrder: 2, // ✨ ADDED
    ),
    VaultFolder(
      id: 'notes_${now.millisecondsSinceEpoch + 3}',
      name: 'Notes',
      icon: Icons.note,
      color: Colors.green,
      itemCount: 0,
      parentPath: 'root',
      creationDate: now,
      sortOrder: 3, // ✨ ADDED
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