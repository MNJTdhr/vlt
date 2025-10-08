// lib/utils/storage_helper.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../data/notifiers.dart';
import '../models/vault_folder.dart'; // Required for metadata parsing

class StorageHelper {
  static const String folderMetadataKey = 'vault_folder_metadata';

  /// ✅ Returns the base directory of the vault
  /// e.g., /storage/emulated/0/Android/media/com.vlt.app/.vlt
  static Future<Directory> getBaseDirectory() async {
    final dir = Directory('/storage/emulated/0/Android/media/com.vlt.app/.vlt');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// ✅ Shortcut for naming consistency
  static Future<Directory> getVaultRootDirectory() => getBaseDirectory();

  /// ✅ Asks for MANAGE_EXTERNAL_STORAGE permission
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// ✅ Save folder metadata list to SharedPreferences as JSON
  /// Stores all UI + path-related info for folder recovery
  static Future<void> saveFoldersMetadata(List<VaultFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> jsonList = folders.map((f) => f.toJson()).toList();

    await prefs.setString(folderMetadataKey, jsonEncode(jsonList));
  }

  /// ✅ Load folder metadata from SharedPreferences
  /// Decodes full folder list including UI and path details
  static Future<List<VaultFolder>> loadFoldersMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(folderMetadataKey);

    if (data == null) return [];

    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => VaultFolder.fromJson(json)).toList();
  }

  /// ✅ Create a folder (main or nested) inside the vault
  /// Takes full path like: "Work" or "root/Projects/Reports"
  static Future<Directory?> createPersistentFolder(String fullPath) async {
    final permissionGranted = await requestStoragePermission();
    if (!permissionGranted) return null;

    final root = await getVaultRootDirectory();
    final folder = Directory(path.join(root.path, fullPath));

    if (!(await folder.exists())) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// ✅ Rename folder from oldPath to newPath
  /// Paths can include nested structure
  static Future<void> renamePersistentFolder(String oldPath, String newPath) async {
    final root = await getVaultRootDirectory();
    final oldFolder = Directory(path.join(root.path, oldPath));
    final newFolder = Directory(path.join(root.path, newPath));

    if (await oldFolder.exists()) {
      await oldFolder.rename(newFolder.path);
    }
  }

  /// ✅ Delete folder at a given path (recursive delete)
  static Future<void> deletePersistentFolder(String fullPath) async {
    final root = await getVaultRootDirectory();
    final folder = Directory(path.join(root.path, fullPath));

    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  /// ✅ Save a file into a folder (nested path allowed)
  /// If context is passed, error dialog will show
  static Future<File?> saveFileToVault({
    required String folderName,
    required File file,
    BuildContext? context,
  }) async {
    try {
      final root = await getVaultRootDirectory();
      final folder = Directory(path.join(root.path, folderName));

      if (!(await folder.exists())) {
        await folder.create(recursive: true);
      }

      final filename = path.basename(file.path);
      final newFilePath = path.join(folder.path, filename);
      final newFile = await file.copy(newFilePath);

      return newFile;
    } catch (e) {
      if (context != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('File Error'),
                content: Text('Failed to save file:\n$e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        });
      }

      return null;
    }
  }

  /// ✅ Load all files and folders under a given path
  /// Used to populate FolderViewPage content
  static Future<List<FileSystemEntity>> getFolderContents(String fullPath) async {
    try {
      final root = await getVaultRootDirectory();
      final folder = Directory(path.join(root.path, fullPath));
      if (await folder.exists()) {
        return folder.listSync(recursive: false);
      }
    } catch (e) {
      debugPrint('Error reading folder contents: $e');
    }
    return [];
  }
}
