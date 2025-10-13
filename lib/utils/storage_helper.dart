// lib/utils/storage_helper.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../data/notifiers.dart';
import '../models/vault_folder.dart';

class StorageHelper {
  static const String _folderMetadataFile = '.metadata.json';
  static const String _fileIndexFile = '.index.json';
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
    
    try {
        final entities = root.listSync(recursive: true);
        for (var entity in entities) {
            if (entity is Directory && p.basename(entity.path) == folderId) {
                return entity;
            }
        }
    } catch (e) {
        debugPrint('Error finding folder by ID: $e');
    }
    return null;
  }

  static Future<void> _saveFolderMetadata(VaultFolder folder) async {
    Directory? folderDir;
    if (folder.parentPath == 'root') {
      final root = await getVaultRootDirectory();
      folderDir = Directory(p.join(root.path, folder.id));
    } else {
      final parentDir = await findFolderDirectoryById(folder.parentPath);
      if (parentDir != null) {
        folderDir = Directory(p.join(parentDir.path, folder.id));
      }
    }

    if (folderDir == null) return;
    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }

    final metadataFile = File(p.join(folderDir.path, _folderMetadataFile));
    await metadataFile.writeAsString(jsonEncode(folder.toJson()));
  }

  static Future<List<VaultFile>> loadVaultFileIndex(VaultFolder folder) async {
    final folderDir = await findFolderDirectoryById(folder.id);
    if (folderDir == null) return [];

    final indexFile = File(p.join(folderDir.path, _fileIndexFile));
    if (!await indexFile.exists()) return [];
    
    try {
      final content = await indexFile.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((json) => VaultFile.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error reading file index for ${folder.name}: $e");
      return [];
    }
  }

  static Future<void> saveVaultFileIndex(VaultFolder folder, List<VaultFile> files) async {
    final folderDir = await findFolderDirectoryById(folder.id);
    if (folderDir == null) return;
    if (!await folderDir.exists()) {
        await folderDir.create(recursive: true);
    }

    final indexFile = File(p.join(folderDir.path, _fileIndexFile));
    final jsonList = files.map((file) => file.toJson()).toList();
    await indexFile.writeAsString(jsonEncode(jsonList));
  }
  
  static Future<void> createFolder(VaultFolder newFolder) async {
    if (!await requestStoragePermission()) return;
    await _saveFolderMetadata(newFolder);
  }

  static Future<void> updateFolderMetadata(VaultFolder updatedFolder) async {
    await _saveFolderMetadata(updatedFolder);
  }

  // ✨ --- NEW FUNCTION TO UPDATE A SINGLE FILE'S METADATA --- ✨
  static Future<void> updateFileMetadata(
    VaultFile updatedFile,
    VaultFolder parentFolder,
  ) async {
    // Load the current list of files for the folder.
    final fileIndex = await loadVaultFileIndex(parentFolder);
    
    // Find the index of the file we need to update.
    final int fileToUpdateIndex = fileIndex.indexWhere((f) => f.id == updatedFile.id);

    // If found, replace it with the updated version.
    if (fileToUpdateIndex != -1) {
      fileIndex[fileToUpdateIndex] = updatedFile;
      // Save the entire updated list back to the file.
      await saveVaultFileIndex(parentFolder, fileIndex);
    } else {
      debugPrint('Error: Could not find file with ID ${updatedFile.id} to update.');
    }
  }

  static Future<void> deleteFolder(VaultFolder folderToDelete) async {
    final folderDir = await findFolderDirectoryById(folderToDelete.id);
    if (folderDir != null && await folderDir.exists()) {
      await folderDir.delete(recursive: true);
    }
  }

  static Future<List<VaultFolder>> loadAllFoldersFromDisk() async {
    final root = await getVaultRootDirectory();
    final folders = <VaultFolder>[];

    if (!await root.exists()) return folders;

    try {
        final entities = root.listSync(recursive: true);
        for (final entity in entities) {
            if (entity is File && p.basename(entity.path) == _folderMetadataFile) {
                try {
                    final content = await entity.readAsString();
                    folders.add(VaultFolder.fromJson(jsonDecode(content)));
                } catch (e) {
                    debugPrint('Error reading metadata file ${entity.path}: $e');
                }
            }
        }
    } catch (e) {
        debugPrint('Error loading folders from disk: $e');
    }
    return folders;
  }
  
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

    final fileIndex = await loadVaultFileIndex(folder);
    fileIndex.add(vaultFile);
    await saveVaultFileIndex(folder, fileIndex);
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

    // 2. Update source folder's metadata
    final sourceIndex = await loadVaultFileIndex(sourceFolder);
    sourceIndex.removeWhere((f) => f.id == fileToMove.id);
    await saveVaultFileIndex(sourceFolder, sourceIndex);

    // 3. Update destination folder's metadata
    final destinationIndex = await loadVaultFileIndex(destinationFolder);
    // Update the file's metadata to reflect its new parent
    final movedFile = fileToMove.copyWith(originalParentPath: destinationFolder.id);
    destinationIndex.add(movedFile);
    await saveVaultFileIndex(destinationFolder, destinationIndex);
  }

  static Future<void> moveFileToRecycleBin(VaultFile file, VaultFolder sourceFolder) async {
    final sourceDir = await findFolderDirectoryById(sourceFolder.id);
    final recycleBinDir = await getRecycleBinDirectory();
    if (sourceDir == null) return;

    final sourceFile = File(p.join(sourceDir.path, file.id));
    if (await sourceFile.exists()) {
      await sourceFile.rename(p.join(recycleBinDir.path, file.id));
    }

    final sourceIndex = await loadVaultFileIndex(sourceFolder);
    sourceIndex.removeWhere((f) => f.id == file.id);
    await saveVaultFileIndex(sourceFolder, sourceIndex);

    final recycleBinFolder = VaultFolder(id: _recycleBinId, name: 'Recycle Bin', icon: Icons.error, color: Colors.transparent, itemCount: 0, parentPath: 'root', creationDate: DateTime.now());
    final recycleBinIndex = await loadVaultFileIndex(recycleBinFolder);
    
    final recycledFile = file.copyWith(
      isInRecycleBin: true,
      deletionDate: DateTime.now(),
      originalParentPath: sourceFolder.id,
    );
    recycleBinIndex.add(recycledFile);
    await saveVaultFileIndex(recycleBinFolder, recycleBinIndex);
  }

  static Future<void> restoreFileFromRecycleBin(VaultFile fileToRestore, List<VaultFolder> allFolders) async {
    final destinationFolder = allFolders.firstWhere(
        (f) => f.id == fileToRestore.originalParentPath,
        orElse: () => allFolders.firstWhere((f) => f.parentPath == 'root'),
    );

    final destinationDir = await findFolderDirectoryById(destinationFolder.id);
    final recycleBinDir = await getRecycleBinDirectory();
    if (destinationDir == null) return;
    
    final sourceFile = File(p.join(recycleBinDir.path, fileToRestore.id));
    if (await sourceFile.exists()) {
      await sourceFile.rename(p.join(destinationDir.path, fileToRestore.id));
    }
    
    final recycleBinFolder = VaultFolder(id: _recycleBinId, name: 'Recycle Bin', icon: Icons.error, color: Colors.transparent, itemCount: 0, parentPath: 'root', creationDate: DateTime.now());
    final recycleBinIndex = await loadVaultFileIndex(recycleBinFolder);
    recycleBinIndex.removeWhere((f) => f.id == fileToRestore.id);
    await saveVaultFileIndex(recycleBinFolder, recycleBinIndex);
    
    final destinationIndex = await loadVaultFileIndex(destinationFolder);
    final restoredFile = fileToRestore.copyWith(isInRecycleBin: false, setDeletionDateToNull: true);
    destinationIndex.add(restoredFile);
    await saveVaultFileIndex(destinationFolder, destinationIndex);
  }

  static Future<List<VaultFile>> loadRecycledFiles() async {
    final recycleBinFolder = VaultFolder(id: _recycleBinId, name: 'Recycle Bin', icon: Icons.error, color: Colors.transparent, itemCount: 0, parentPath: 'root', creationDate: DateTime.now());
    return await loadVaultFileIndex(recycleBinFolder);
  }

  static Future<void> permanentlyDeleteFile(VaultFile file) async {
    final recycleBinDir = await getRecycleBinDirectory();
    final fileToDelete = File(p.join(recycleBinDir.path, file.id));
    if (await fileToDelete.exists()) {
      await fileToDelete.delete();
    }

    final recycleBinFolder = VaultFolder(id: _recycleBinId, name: 'Recycle Bin', icon: Icons.error, color: Colors.transparent, itemCount: 0, parentPath: 'root', creationDate: DateTime.now());
    final index = await loadVaultFileIndex(recycleBinFolder);
    index.removeWhere((f) => f.id == file.id);
    await saveVaultFileIndex(recycleBinFolder, index);
  }

  static Future<void> permanentlyDeleteAllRecycledFiles() async {
    final recycleBinDir = await getRecycleBinDirectory();
    if (await recycleBinDir.exists()) {
        final entities = recycleBinDir.listSync();
        for(var entity in entities) {
            await entity.delete(recursive: true);
        }
    }
    final recycleBinFolder = VaultFolder(id: _recycleBinId, name: 'Recycle Bin', icon: Icons.error, color: Colors.transparent, itemCount: 0, parentPath: 'root', creationDate: DateTime.now());
    await saveVaultFileIndex(recycleBinFolder, []);
  }

  static Future<List<File>> getFolderContents(VaultFolder folder) async {
    final folderDir = await findFolderDirectoryById(folder.id);
    if (folderDir == null || !await folderDir.exists()) return [];

    try {
      final entities = folderDir.listSync(recursive: false);
      return entities.whereType<File>()
          .where((file) => !p.basename(file.path).startsWith('.'))
          .toList();
    } catch (e) {
      debugPrint('Error reading folder contents: $e');
      return [];
    }
  }
}