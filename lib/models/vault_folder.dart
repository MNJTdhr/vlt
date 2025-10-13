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

  /// The ID of the folder’s parent ("root" for top-level folders)
  final String parentPath;

  /// The date and time the folder was created.
  final DateTime creationDate;
  
  /// Number of items in the folder (files + subfolders).
  /// This is not stored in the database and is calculated dynamically.
  int itemCount;

  /// Constructor to initialize all required properties
  VaultFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.itemCount = 0, // ✨ MODIFIED: Now has a default value and is not final
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

  // ✨ --- DATABASE METHODS --- ✨

  /// Converts the VaultFolder object to a Map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'color': color.value,
      'parentPath': parentPath,
      'creationDate': creationDate.toIso8601String(),
    };
  }

  /// Creates a VaultFolder object from a Map retrieved from the database.
  factory VaultFolder.fromMap(Map<String, dynamic> map) {
    return VaultFolder(
      id: map['id'],
      name: map['name'],
      icon: IconData(
        map['iconCodePoint'],
        fontFamily: map['iconFontFamily'],
        fontPackage: map['iconFontPackage'],
      ),
      color: Color(map['color']),
      parentPath: map['parentPath'],
      creationDate: DateTime.parse(map['creationDate']),
      // itemCount is not in the map, it will be populated later.
    );
  }
}

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

  /// Stores the ID of the folder where the file originally lived.
  final String originalParentPath;
  
  /// A flag to indicate if the file is a favorite.
  final bool isFavorite;

  const VaultFile({
    required this.id,
    required this.fileName,
    required this.originalPath,
    required this.dateAdded,
    this.isInRecycleBin = false,
    this.deletionDate,
    required this.originalParentPath,
    this.isFavorite = false,
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
    String? originalParentPath,
    bool? isFavorite,
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
          originalParentPath ?? this.originalParentPath,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // ✨ --- DATABASE METHODS --- ✨

  /// Converts the VaultFile object to a Map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'originalPath': originalPath,
      'dateAdded': dateAdded.toIso8601String(),
      'isInRecycleBin': isInRecycleBin ? 1 : 0, // Convert bool to integer
      'deletionDate': deletionDate?.toIso8601String(),
      'originalParentPath': originalParentPath,
      'isFavorite': isFavorite ? 1 : 0, // Convert bool to integer
    };
  }

  /// Creates a VaultFile object from a Map retrieved from the database.
  factory VaultFile.fromMap(Map<String, dynamic> map) {
    return VaultFile(
      id: map['id'],
      fileName: map['fileName'],
      originalPath: map['originalPath'],
      dateAdded: DateTime.parse(map['dateAdded']),
      isInRecycleBin: map['isInRecycleBin'] == 1, // Convert integer to bool
      deletionDate: map['deletionDate'] != null
          ? DateTime.parse(map['deletionDate'])
          : null,
      originalParentPath: map['originalParentPath'],
      isFavorite: map['isFavorite'] == 1, // Convert integer to bool
    );
  }
}