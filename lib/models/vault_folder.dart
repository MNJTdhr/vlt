// lib/models/vault_folder.dart
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

  /// The ID of the folder’s parent ("root" for top-level folders)
  final String parentPath;

  // ✨ NEW: The date and time the folder was created.
  final DateTime creationDate;

  /// Constructor to initialize all required properties
  const VaultFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.itemCount,
    required this.parentPath,
    required this.creationDate, // ✨ ADDED
  });

  /// Create a new folder based on an existing one with changes
  VaultFolder copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? itemCount,
    String? parentPath,
    DateTime? creationDate, // ✨ ADDED
  }) {
    return VaultFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      itemCount: itemCount ?? this.itemCount,
      parentPath: parentPath ?? this.parentPath,
      creationDate: creationDate ?? this.creationDate, // ✨ ADDED
    );
  }

  /// Convert to JSON for file persistence
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'iconFontPackage': icon.fontPackage,
        'color': color.value,
        'itemCount': itemCount,
        'parentPath': parentPath,
        'creationDate': creationDate.toIso8601String(), // ✨ ADDED
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
      parentPath: json['parentPath'] ?? 'root',
      // ✨ ADDED: Load the creation date, with a fallback for older data
      creationDate: json['creationDate'] != null
          ? DateTime.parse(json['creationDate'])
          : DateTime.now(),
    );
  }
}