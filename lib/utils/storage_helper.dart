// lib/utils/storage_helper.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../data/notifiers.dart';

class StorageHelper {
  static const String folderMetadataKey = 'vault_folder_metadata';

  /// ✅ Get the base vault directory: /storage/emulated/0/Android/media/com.vlt.app/.vlt/
  static Future<Directory> getBaseDirectory() async {
    final dir = Directory('/storage/emulated/0/Android/media/com.vlt.app/.vlt');
    if (!(await dir.exists())) {
      await dir.create(recursive: true); // Create directory if not present
    }
    return dir;
  }

  /// ✅ Alias method for consistent naming
  static Future<Directory> getVaultRootDirectory() => getBaseDirectory();

  /// ✅ Ask for manage external storage permission
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// ✅ Save folder metadata list to SharedPreferences as JSON
  static Future<void> saveFoldersMetadata(List<VaultFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> jsonList = folders.map((folder) {
      return {
        'id': folder.id,
        'name': folder.name,
        'icon': folder.icon.codePoint,
        'color': folder.color.toARGB32(), // Save full color value
        'itemCount': folder.itemCount,
      };
    }).toList();

    prefs.setString(folderMetadataKey, jsonEncode(jsonList));
  }

  /// ✅ Load folder metadata from SharedPreferences
  static Future<List<VaultFolder>> loadFoldersMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(folderMetadataKey);

    if (data == null) return [];

    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) {
      return VaultFolder(
        id: json['id'],
        name: json['name'],
        icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
        color: Color(json['color']),
        itemCount: json['itemCount'],
      );
    }).toList();
  }

  /// ✅ Create a main folder inside .vlt directory
  static Future<Directory?> createPersistentFolder(String folderName) async {
    final permissionGranted = await requestStoragePermission();
    if (!permissionGranted) return null;

    final baseDir = await getBaseDirectory();
    final folder = Directory('${baseDir.path}/$folderName');

    if (!(await folder.exists())) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// ✅ Create subfolder inside a given parent folder in .vlt
  static Future<void> createPersistentSubfolder(
    String parentFolder,
    String subfolderName,
  ) async {
    final root = await getVaultRootDirectory();
    final subfolder = Directory(
      path.join(root.path, parentFolder, subfolderName),
    );

    if (!(await subfolder.exists())) {
      await subfolder.create(recursive: true);
    }
  }

  /// ✅ Save file to a vault folder
  ///
  /// If `context` is provided, shows an AlertDialog on error
  static Future<File?> saveFileToVault({
    required String folderName,
    required File file,
    BuildContext? context, // Optional context for showing error dialog
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
      // ✅ Use safe post-frame callback to avoid context errors after async gaps
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
}
