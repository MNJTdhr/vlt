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

  /// The date and time the folder was created.
  final DateTime creationDate;

  /// Constructor to initialize all required properties
  const VaultFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.itemCount,
    required this.parentPath,
    required this.creationDate,
  });

  /// Create a new folder based on an existing one with changes
  VaultFolder copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    int? itemCount,
    String? parentPath,
    DateTime? creationDate,
  }) {
    return VaultFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      itemCount: itemCount ?? this.itemCount,
      parentPath: parentPath ?? this.parentPath,
      creationDate: creationDate ?? this.creationDate,
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
    'creationDate': creationDate.toIso8601String(),
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
      creationDate: json['creationDate'] != null
          ? DateTime.parse(json['creationDate'])
          : DateTime.now(),
    );
  }
}

// ✨ --- CORRECTED VaultFile DATA MODEL --- ✨

/// Represents a single file within a vault folder.
class VaultFile {
  /// Unique ID for this file.
  final String id;

  /// The name of the file on disk (e.g., "image1.jpg").
  final String fileName;

  /// The original path of the file on the device before import.
  final String originalPath;

  /// The date and time the file was added to the vault.
  final DateTime dateAdded;

  /// A flag to indicate if the file is in the recycle bin.
  final bool isInRecycleBin;

  /// The date the file was moved to the recycle bin (for auto-purge features).
  final DateTime? deletionDate;
  // ✨ FIX: Stores the ID of the folder where the file originally lived.
  final String originalParentPath;

  const VaultFile({
    required this.id,
    required this.fileName,
    required this.originalPath,
    required this.dateAdded,
    this.isInRecycleBin = false,
    this.deletionDate,
    required this.originalParentPath, // ✨ ADDED
  });

  /// Creates a new instance with updated properties.
  VaultFile copyWith({
    String? id,
    String? fileName,
    String? originalPath,
    DateTime? dateAdded,
    bool? isInRecycleBin,
    bool setDeletionDateToNull = false,
    DateTime? deletionDate,
    String? originalParentPath, // ✨ ADDED
  }) {
    return VaultFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      originalPath: originalPath ?? this.originalPath,
      dateAdded: dateAdded ?? this.dateAdded,
      isInRecycleBin: isInRecycleBin ?? this.isInRecycleBin,
      deletionDate: setDeletionDateToNull
          ? null
          : (deletionDate ?? this.deletionDate),
      originalParentPath:
          originalParentPath ?? this.originalParentPath, // ✨ ADDED
    );
  }

  /// Converts the object to a JSON map for file persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'originalPath': originalPath,
    'dateAdded': dateAdded.toIso8601String(),
    'isInRecycleBin': isInRecycleBin,
    'deletionDate': deletionDate?.toIso8601String(),
    'originalParentPath': originalParentPath, // ✨ ADDED
  };

  /// Creates a VaultFile object from a JSON map.
  factory VaultFile.fromJson(Map<String, dynamic> json) {
    return VaultFile(
      id: json['id'],
      fileName: json['fileName'],
      originalPath: json['originalPath'],
      dateAdded: DateTime.parse(json['dateAdded']),
      isInRecycleBin: json['isInRecycleBin'] ?? false,
      deletionDate: json['deletionDate'] != null
          ? DateTime.parse(json['deletionDate'])
          : null,
      // ✨ ADDED: Load the original path, with a fallback for safety.
      originalParentPath: json['originalParentPath'] ?? 'root',
    );
  }
}
