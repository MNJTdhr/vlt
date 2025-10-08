// lib/utils/storage_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../models/vault_folder.dart';

class StorageHelper {
  static const String _metadataFileName = '.metadata.json';

  /// Returns the base directory of the vault.
  static Future<Directory> getVaultRootDirectory() async {
    final dir = Directory('/storage/emulated/0/Android/media/com.vlt.app/.vlt');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Asks for necessary storage permissions.
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// ✨ NEW: Recursively finds a folder's directory by its ID.
  static Future<Directory?> findFolderDirectoryById(String folderId) async {
    final root = await getVaultRootDirectory();
    final entities = root.listSync(recursive: true);
    for (var entity in entities) {
      if (entity is Directory && path.basename(entity.path) == folderId) {
        return entity;
      }
    }
    return null;
  }
  
  /// ✨ NEW: Saves a single folder's metadata to its own directory.
  static Future<void> saveFolderMetadata(VaultFolder folder) async {
    Directory? folderDir;
    if (folder.parentPath == 'root') {
      final root = await getVaultRootDirectory();
      folderDir = Directory(path.join(root.path, folder.id));
    } else {
      final parentDir = await findFolderDirectoryById(folder.parentPath);
      if (parentDir != null) {
        folderDir = Directory(path.join(parentDir.path, folder.id));
      }
    }

    if (folderDir == null) return;
    
    if (!await folderDir.exists()) {
       await folderDir.create(recursive: true);
    }

    final metadataFile = File(path.join(folderDir.path, _metadataFileName));
    await metadataFile.writeAsString(jsonEncode(folder.toJson()));
  }

  /// ✨ NEW: Creates a new folder, including its physical directory and metadata file.
  static Future<void> createFolder(VaultFolder newFolder) async {
    if (!await requestStoragePermission()) return;
    await saveFolderMetadata(newFolder);
  }

  /// ✨ NEW: Updates a folder's metadata (for rename, customize).
  static Future<void> updateFolderMetadata(VaultFolder updatedFolder) async {
    // Renaming the folder name is just updating the metadata file.
    // The physical directory name (which is the folder ID) does not change.
    await saveFolderMetadata(updatedFolder);
  }

  /// ✨ NEW: Deletes a folder's physical directory.
  static Future<void> deleteFolder(VaultFolder folderToDelete) async {
    final folderDir = await findFolderDirectoryById(folderToDelete.id);
    if (folderDir != null && await folderDir.exists()) {
      await folderDir.delete(recursive: true);
    }
  }

  /// ✨ OVERHAULED: Loads all folders by scanning the disk for metadata files.
  static Future<List<VaultFolder>> loadAllFoldersFromDisk() async {
    final root = await getVaultRootDirectory();
    final folders = <VaultFolder>[];

    if (!await root.exists()) {
      return folders;
    }

    final entities = root.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File && path.basename(entity.path) == _metadataFileName) {
        try {
          final content = await entity.readAsString();
          final folder = VaultFolder.fromJson(jsonDecode(content));
          folders.add(folder);
        } catch (e) {
          debugPrint('Error reading metadata file ${entity.path}: $e');
        }
      }
    }
    return folders;
  }
  
  // This function can remain largely the same, but we need to find the folder path differently
  static Future<File?> saveFileToVault({
    required VaultFolder folder,
    required File file,
  }) async {
    final folderDir = await findFolderDirectoryById(folder.id);
    if (folderDir == null) return null;

    try {
      final filename = path.basename(file.path);
      final newFilePath = path.join(folderDir.path, filename);
      return await file.copy(newFilePath);
    } catch (e) {
      debugPrint('Failed to save file: $e');
      return null;
    }
  }

  // This function can also remain, but it's better to pass the folder object
  static Future<List<FileSystemEntity>> getFolderContents(VaultFolder folder) async {
    final folderDir = await findFolderDirectoryById(folder.id);
    if (folderDir == null || !await folderDir.exists()) return [];
    
    try {
      // Return everything except the metadata file itself
      return folderDir.listSync(recursive: false)
          .where((entity) => path.basename(entity.path) != _metadataFileName)
          .toList();
    } catch (e) {
      debugPrint('Error reading folder contents: $e');
      return [];
    }
  }
}