// lib/utils/storage_helper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../data/database_helper.dart';
import '../models/vault_folder.dart';

class StorageHelper {
  static const String _recycleBinId = '.recycle_bin';
  static const _uuid = Uuid();

  static Future<Directory> getVaultRootDirectory() async {
    final dir = Directory('/storage/emulated/0/Android/media/com.vlt.app/.vlt');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getRecycleBinDirectory() async {
    final root = await getVaultRootDirectory();
    final dir = Directory(p.join(root.path, _recycleBinId));
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<bool> requestStoragePermission() async {
    return await Permission.manageExternalStorage.request().isGranted;
  }

  static Future<Directory?> findFolderDirectoryById(String folderId) async {
    final root = await getVaultRootDirectory();
    if (folderId == _recycleBinId) return getRecycleBinDirectory();
    
    // To find a folder, we now query the database to get its parent path.
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
    );

    if (maps.isEmpty) {
      debugPrint('Error finding folder by ID: $folderId not found in database.');
      return null;
    }
    
    final folder = VaultFolder.fromMap(maps.first);
    
    Directory parentDir;
    if (folder.parentPath == 'root') {
      parentDir = await getVaultRootDirectory();
    } else {
      // Recursively find the parent directory.
      final parent = await findFolderDirectoryById(folder.parentPath);
      if (parent == null) return null;
      parentDir = parent;
    }
    
    final folderDir = Directory(p.join(parentDir.path, folder.id));
    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }
    return folderDir;
  }
  
  // ✨ --- FOLDER DATABASE OPERATIONS --- ✨

  static Future<void> createFolder(VaultFolder newFolder) async {
    if (!await requestStoragePermission()) return;
    
    // Create the physical directory for the folder's contents.
    final parentDir = newFolder.parentPath == 'root'
        ? await getVaultRootDirectory()
        : await findFolderDirectoryById(newFolder.parentPath);
    
    if (parentDir != null) {
      final folderDir = Directory(p.join(parentDir.path, newFolder.id));
      if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
      }
    }
    
    // Insert the folder's metadata into the database.
    final db = await DatabaseHelper().database;
    await db.insert(
      'folders',
      newFolder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateFolderMetadata(VaultFolder updatedFolder) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'folders',
      updatedFolder.toMap(),
      where: 'id = ?',
      whereArgs: [updatedFolder.id],
    );
  }

  static Future<void> deleteFolder(VaultFolder folderToDelete) async {
    final db = await DatabaseHelper().database;
    
    // Recursively find all child folders and files to delete.
    final List<String> folderIdsToDelete = [folderToDelete.id];
    final List<VaultFile> filesToDelete = [];

    Future<void> findChildren(String parentId) async {
        final childrenFolders = await db.query('folders', where: 'parentPath = ?', whereArgs: [parentId]);
        for (var map in childrenFolders) {
            final childFolder = VaultFolder.fromMap(map);
            folderIdsToDelete.add(childFolder.id);
            await findChildren(childFolder.id); // Recurse
        }
        final childrenFiles = await db.query('files', where: 'originalParentPath = ?', whereArgs: [parentId]);
        filesToDelete.addAll(childrenFiles.map((map) => VaultFile.fromMap(map)));
    }

    await findChildren(folderToDelete.id);

    // Delete all associated files and folders from the database.
    await db.transaction((txn) async {
        await txn.delete('files', where: 'originalParentPath IN (${folderIdsToDelete.map((_) => '?').join(',')})', whereArgs: folderIdsToDelete);
        await txn.delete('folders', where: 'id IN (${folderIdsToDelete.map((_) => '?').join(',')})', whereArgs: folderIdsToDelete);
    });

    // Delete the physical folder from storage.
    final folderDir = await findFolderDirectoryById(folderToDelete.id);
    if (folderDir != null && await folderDir.exists()) {
      await folderDir.delete(recursive: true);
    }
  }

  static Future<List<VaultFolder>> getAllFolders() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query('folders');
    return List.generate(maps.length, (i) {
      return VaultFolder.fromMap(maps[i]);
    });
  }

  // ✨ --- FILE DATABASE OPERATIONS --- ✨

  static Future<void> saveFileToVault({
    required VaultFolder folder,
    required File file,
  }) async {
    final folderDir = await findFolderDirectoryById(folder.id);
    if (folderDir == null) return;

    final newFileName = '${_uuid.v4()}${p.extension(file.path)}';
    final newFilePath = p.join(folderDir.path, newFileName);
    
    await file.copy(newFilePath);

    final vaultFile = VaultFile(
      id: newFileName,
      fileName: p.basename(file.path),
      originalPath: file.path,
      dateAdded: DateTime.now(),
      originalParentPath: folder.id,
    );
    
    await addFileRecord(vaultFile);
  }

  /// ✨ ADDED: Adds a single file record to the database. Used by self-healing.
  static Future<void> addFileRecord(VaultFile file) async {
    final db = await DatabaseHelper().database;
    await db.insert('files', file.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// ✨ ADDED: Deletes a single file record from the database by its ID. Used by self-healing.
  static Future<void> deleteFileRecord(String fileId) async {
    final db = await DatabaseHelper().database;
    await db.delete('files', where: 'id = ?', whereArgs: [fileId]);
  }

  static Future<void> updateFileMetadata(VaultFile updatedFile) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'files',
      updatedFile.toMap(),
      where: 'id = ?',
      whereArgs: [updatedFile.id],
    );
  }
  
  static Future<List<VaultFile>> getFilesForFolder(VaultFolder folder) async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'files',
      where: 'originalParentPath = ? AND isInRecycleBin = 0',
      whereArgs: [folder.id],
    );
    return List.generate(maps.length, (i) {
      return VaultFile.fromMap(maps[i]);
    });
  }

  static Future<void> transferFile(
    VaultFile fileToMove,
    VaultFolder sourceFolder,
    VaultFolder destinationFolder,
  ) async {
    final sourceDir = await findFolderDirectoryById(sourceFolder.id);
    final destinationDir = await findFolderDirectoryById(destinationFolder.id);

    if (sourceDir == null || destinationDir == null) {
      debugPrint('Error: Source or destination folder not found.');
      return;
    }

    // 1. Move the physical file
    final sourceFile = File(p.join(sourceDir.path, fileToMove.id));
    if (await sourceFile.exists()) {
      try {
        await sourceFile.rename(p.join(destinationDir.path, fileToMove.id));
      } catch (e) {
        debugPrint('Error moving file: $e');
        return; // Stop if the file move fails
      }
    }

    // 2. Update the file's metadata in the database to point to the new folder.
    final movedFile = fileToMove.copyWith(originalParentPath: destinationFolder.id);
    await updateFileMetadata(movedFile);
  }

  static Future<void> moveFileToRecycleBin(VaultFile file, VaultFolder sourceFolder) async {
    final sourceDir = await findFolderDirectoryById(sourceFolder.id);
    final recycleBinDir = await getRecycleBinDirectory();
    if (sourceDir == null) return;

    final sourceFile = File(p.join(sourceDir.path, file.id));
    if (await sourceFile.exists()) {
      await sourceFile.rename(p.join(recycleBinDir.path, file.id));
    }

    final recycledFile = file.copyWith(
      isInRecycleBin: true,
      deletionDate: DateTime.now(),
      // The originalParentPath stays the same, so we know where to restore it to.
    );
    await updateFileMetadata(recycledFile);
  }

  static Future<void> restoreFileFromRecycleBin(VaultFile fileToRestore) async {
    final destinationDir = await findFolderDirectoryById(fileToRestore.originalParentPath);
    final recycleBinDir = await getRecycleBinDirectory();
    if (destinationDir == null) return;
    
    final sourceFile = File(p.join(recycleBinDir.path, fileToRestore.id));
    if (await sourceFile.exists()) {
      await sourceFile.rename(p.join(destinationDir.path, fileToRestore.id));
    }
    
    final restoredFile = fileToRestore.copyWith(isInRecycleBin: false, setDeletionDateToNull: true);
    await updateFileMetadata(restoredFile);
  }

  static Future<List<VaultFile>> loadRecycledFiles() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'files',
      where: 'isInRecycleBin = 1',
    );
    return List.generate(maps.length, (i) {
      return VaultFile.fromMap(maps[i]);
    });
  }

  static Future<void> permanentlyDeleteFile(VaultFile file) async {
    // Delete the physical file from the recycle bin.
    final recycleBinDir = await getRecycleBinDirectory();
    final fileToDelete = File(p.join(recycleBinDir.path, file.id));
    if (await fileToDelete.exists()) {
      await fileToDelete.delete();
    }
    
    // Delete the file's metadata record from the database.
    await deleteFileRecord(file.id);
  }

  static Future<void> permanentlyDeleteAllRecycledFiles() async {
    final db = await DatabaseHelper().database;
    final recycledFiles = await loadRecycledFiles();

    // Delete all physical files.
    final recycleBinDir = await getRecycleBinDirectory();
    if (await recycleBinDir.exists()) {
      for (final file in recycledFiles) {
        final fileToDelete = File(p.join(recycleBinDir.path, file.id));
        if (await fileToDelete.exists()) {
          await fileToDelete.delete();
        }
      }
    }
    
    // Delete all recycled file records from the database.
    await db.delete('files', where: 'isInRecycleBin = 1');
  }

  static Future<List<File>> getFolderContents(VaultFolder folder) async {
    final folderDir = await findFolderDirectoryById(folder.id);
    if (folderDir == null || !await folderDir.exists()) return [];

    try {
      final entities = folderDir.listSync(recursive: false);
      // This function still works as before; it's used for self-healing.
      return entities.whereType<File>()
          .where((file) => !p.basename(file.path).startsWith('.'))
          .toList();
    } catch (e) {
      debugPrint('Error reading folder contents: $e');
      return [];
    }
  }

  // ✨ --- COUNTING OPERATIONS --- ✨

  static Future<int> getSubfolderCount(String parentId) async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM folders WHERE parentPath = ?', [parentId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  static Future<int> getFileCount(String parentId) async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM files WHERE originalParentPath = ? AND isInRecycleBin = 0', [parentId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}