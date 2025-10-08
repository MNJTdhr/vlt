import 'package:flutter/material.dart';

/// Represents a single folder in the vault.
class VaultFolder {
  /// Unique ID for this folder (used for tracking, renaming, deletion)
  final String id;

  /// Visible name of the folder (e.g., "Photos", "Work")
  final String name;

  /// Folder icon shown in the UI
  final IconData icon;

  /// Folder color used for UI themes
  final Color color;

  /// Number of items in the folder (files + subfolders)
  final int itemCount;

  /// Full path to the folder’s parent (e.g. "root", "root/Work/Reports")
  /// Helps in organizing folder tree and restoring exact hierarchy
  final String parentPath;

  /// Constructor to initialize all required properties
  const VaultFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.itemCount,
    required this.parentPath,
  });

  /// Create a new folder based on an existing one with changes
  VaultFolder copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? itemCount,
    String? parentPath,
  }) {
    return VaultFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      itemCount: itemCount ?? this.itemCount,
      parentPath: parentPath ?? this.parentPath,
    );
  }

  /// Convert to JSON for SharedPreferences persistence
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'iconFontPackage': icon.fontPackage,
        'color': color.value,
        'itemCount': itemCount,
        'parentPath': parentPath,
      };

  /// Load from JSON map into usable VaultFolder object
  factory VaultFolder.fromJson(Map<String, dynamic> json) {
    return VaultFolder(
      id: json['id'],
      name: json['name'],
      icon: IconData(
        json['iconCodePoint'],
        fontFamily: json['iconFontFamily'],
        fontPackage: json['iconFontPackage'],
      ),
      color: Color(json['color']),
      itemCount: json['itemCount'],
      parentPath: json['parentPath'] ?? 'root', // default to root if missing
    );
  }
}
