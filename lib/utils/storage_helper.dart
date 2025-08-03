// lib/utils/storage_helper.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path; // ✅ Needed for file path handling
import '../data/notifiers.dart';

class StorageHelper {
  static const String folderMetadataKey = 'vault_folder_metadata';

  // ✅ Get the base directory: /storage/emulated/0/Android/media/com.vlt.app/.vlt/
  static Future<Directory> getBaseDirectory() async {
    final dir = Directory('/storage/emulated/0/Android/media/com.vlt.app/.vlt');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ✅ Alias for getBaseDirectory for consistency
  static Future<Directory> getVaultRootDirectory() => getBaseDirectory();

  // ✅ Request storage permission
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  // ✅ Save folders metadata to SharedPreferences
  static Future<void> saveFoldersMetadata(List<VaultFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = folders.map((folder) {
      return {
        'id': folder.id,
        'name': folder.name,
        'icon': folder.icon.codePoint,
        'color': folder.color.value,
        'itemCount': folder.itemCount,
      };
    }).toList();
    prefs.setString(folderMetadataKey, jsonEncode(jsonList));
  }

  // ✅ Load folders metadata from SharedPreferences
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

  // ✅ Create a folder in the base directory
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

  // ✅ Create a subfolder inside a folder in .vlt
  static Future<void> createPersistentSubfolder(String parentFolder, String subfolderName) async {
    final root = await getVaultRootDirectory();
    final subfolder = Directory(path.join(root.path, parentFolder, subfolderName));

    if (!(await subfolder.exists())) {
      await subfolder.create(recursive: true);
    }
  }

  // ✅ Copy a file to a vault folder
  static Future<File?> saveFileToVault({
    required String folderName,
    required File file,
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
      print('Error saving file to vault: $e');
      return null;
    }
  }
}
