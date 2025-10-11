// lib/pages/folder_view_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:vlt/pages/photo_view_page.dart';
import 'package:vlt/widgets/folder_card.dart';
import 'package:vlt/widgets/folder_creator_sheet.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/models/vault_folder.dart';

class FolderViewPage extends StatefulWidget {
  final VaultFolder folder;
  const FolderViewPage({super.key, required this.folder});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage>
    with SingleTickerProviderStateMixin {
  late VaultFolder currentFolder;
  List<File> folderFiles = [];
  List<VaultFile> _vaultFiles = [];

  late AnimationController _fabAnimationController;
  bool isFabMenuOpen = false;

  @override
  void initState() {
    super.initState();
    currentFolder = widget.folder;
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    foldersNotifier.addListener(_onFoldersChanged);
    _loadAllFolderContents();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    foldersNotifier.removeListener(_onFoldersChanged);
    super.dispose();
  }

  void _onFoldersChanged() {
    if (mounted) {
      setState(() {
        final foundFolders =
            foldersNotifier.value.where((f) => f.id == widget.folder.id);
        if (foundFolders.isNotEmpty) {
          currentFolder = foundFolders.first;
        }
        _loadAllFolderContents();
      });
    }
  }

  /// Load both real files and metadata for this folder.
  Future<void> _loadAllFolderContents() async {
    final physicalFiles = await StorageHelper.getFolderContents(currentFolder);
    final fileMetadata = await StorageHelper.loadVaultFileIndex(currentFolder);

    if (mounted) {
      setState(() {
        physicalFiles.sort((a, b) {
          final aIndex =
              fileMetadata.indexWhere((vf) => vf.id == p.basename(a.path));
          final bIndex =
              fileMetadata.indexWhere((vf) => vf.id == p.basename(b.path));
          return aIndex.compareTo(bIndex);
        });
        folderFiles = physicalFiles;
        _vaultFiles = fileMetadata;
      });
    }
  }

  void _toggleFabMenu() {
    setState(() {
      isFabMenuOpen = !isFabMenuOpen;
      if (isFabMenuOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  Future<void> _pickAndCopyFiles(FileType type) async {
    bool permissionGranted = false;

    if (type == FileType.image) {
      permissionGranted = await Permission.photos.request().isGranted ||
          await Permission.storage.request().isGranted;
    } else if (type == FileType.video) {
      permissionGranted = await Permission.videos.request().isGranted ||
          await Permission.storage.request().isGranted;
    } else {
      permissionGranted =
          await Permission.manageExternalStorage.request().isGranted;
    }

    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access files.')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: type,
    );

    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        final path = file.path;
        if (path != null) {
          final originalFile = File(path);
          await StorageHelper.saveFileToVault(
            folder: currentFolder,
            file: originalFile,
          );
        }
      }
      await refreshItemCounts();
      await _loadAllFolderContents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.files.length} file(s) copied')),
      );
    }
  }

  List<VaultFolder> _getSubfolders() {
    return foldersNotifier.value
        .where((f) => f.parentPath == currentFolder.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final subfolders = _getSubfolders();
    final files = folderFiles;
    final isEmpty = files.isEmpty && subfolders.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentFolder.name),
        backgroundColor: currentFolder.color,
        foregroundColor: Colors.white,
      ),
      body: isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: currentFolder.color),
                  const SizedBox(height: 16),
                  Text(
                    'The "${currentFolder.name}" folder is empty.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click the + button to add content.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                itemCount: subfolders.length + files.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  // 📁 Subfolders
                  if (index < subfolders.length) {
                    final subfolder = subfolders[index];
                    return FolderCard(
                      folder: subfolder,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderViewPage(folder: subfolder),
                          ),
                        );
                      },
                      // ✅ Added missing callbacks
                      onRename: (f, newName) =>
                          _renameFolder(context, f, newName),
                      onDelete: (f) => _deleteFolder(context, f),
                      onCustomize: (f, icon, color) =>
                          _customizeFolder(context, f, icon, color),
                    );
                  }

                  // 📷 Files
                  final fileIndex = index - subfolders.length;
                  final physicalFile = files[fileIndex];
                  final vaultFile = _vaultFiles.firstWhere(
                    (vf) => vf.id == p.basename(physicalFile.path),
                    orElse: () => VaultFile(
                      id: p.basename(physicalFile.path),
                      fileName: p.basename(physicalFile.path),
                      originalPath: physicalFile.path,
                      dateAdded: DateTime.now(),
                      originalParentPath: currentFolder.id,
                    ),
                  );

                  return GestureDetector(
                    onTap: () {
                      final safeFiles = _vaultFiles.isNotEmpty
                          ? _vaultFiles
                          : _convertToVaultFiles(folderFiles);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoViewPage(
                            files: safeFiles,
                            initialIndex: fileIndex.clamp(
                              0,
                              safeFiles.length - 1,
                            ),
                            parentFolder: currentFolder,
                          ),
                        ),
                      );
                    },
                    onLongPress: () => _showFileOptions(context, vaultFile),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildThumbnail(physicalFile),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: _buildFabMenu(),
    );
  }

  // ✅ Helper to convert File list to VaultFile list (fallback)
  List<VaultFile> _convertToVaultFiles(List<File> files) {
    return files.map((f) {
      return VaultFile(
        id: p.basename(f.path),
        fileName: p.basename(f.path),
        originalPath: f.path,
        dateAdded: DateTime.now(),
        originalParentPath: currentFolder.id,
      );
    }).toList();
  }

  /// ✅ Restored: File options bottom sheet
  void _showFileOptions(BuildContext context, VaultFile file) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.recycling, color: Colors.orange),
              title: const Text('Move to Recycle Bin'),
              onTap: () {
                Navigator.pop(ctx);
                _moveFileToRecycleBin(context, file);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Restored: Move file to recycle bin
  void _moveFileToRecycleBin(BuildContext context, VaultFile file) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move to Recycle Bin'),
        content: Text(
          'Are you sure you want to move "${file.fileName}" to the recycle bin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await StorageHelper.moveFileToRecycleBin(file, currentFolder);
              await refreshItemCounts();
              await _loadAllFolderContents();
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }

  // --- Folder management actions ---
  void _renameFolder(BuildContext context, VaultFolder folder, String newName) async {
    final updatedFolder = folder.copyWith(name: newName);
    await StorageHelper.updateFolderMetadata(updatedFolder);

    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final index = currentFolders.indexWhere((f) => f.id == folder.id);
    if (index != -1) currentFolders[index] = updatedFolder;
    foldersNotifier.value = currentFolders;

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Folder renamed to "$newName"')));
    }
  }

  void _deleteFolder(BuildContext context, VaultFolder folder) async {
    await StorageHelper.deleteFolder(folder);
    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);

    final List<String> idsToDelete = [folder.id];
    void findChildren(String parentId) {
      final children = currentFolders.where((f) => f.parentPath == parentId);
      for (final child in children) {
        idsToDelete.add(child.id);
        findChildren(child.id);
      }
    }

    findChildren(folder.id);
    currentFolders.removeWhere((f) => idsToDelete.contains(f.id));
    foldersNotifier.value = currentFolders;
    await refreshItemCounts();

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Folder "${folder.name}" deleted')));
    }
  }

  void _customizeFolder(
      BuildContext context, VaultFolder folder, IconData icon, Color color) async {
    final updatedFolder = folder.copyWith(icon: icon, color: color);
    await StorageHelper.updateFolderMetadata(updatedFolder);

    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final index = currentFolders.indexWhere((f) => f.id == folder.id);
    if (index != -1) currentFolders[index] = updatedFolder;
    foldersNotifier.value = currentFolders;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder "${folder.name}" customized')),
      );
    }
  }

  // --- Thumbnail helpers ---
  Widget _buildThumbnail(File file) {
    final path = file.path;
    if (_isImage(path)) {
      return Image.file(file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    } else if (_isVideo(path)) {
      return Stack(
        fit: StackFit.expand,
        children: const [
          ColoredBox(color: Colors.black12),
          Center(child: Icon(Icons.play_circle, color: Colors.white, size: 36)),
        ],
      );
    } else {
      return const Icon(Icons.insert_drive_file);
    }
  }

  bool _isImage(String path) =>
      ['.jpg', '.jpeg', '.png', '.gif', '.webp']
          .contains(p.extension(path).toLowerCase());

  bool _isVideo(String path) =>
      ['.mp4', '.mov', '.avi', '.mkv']
          .contains(p.extension(path).toLowerCase());

  // --- Floating Action Menu ---
  Widget _buildFabMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isFabMenuOpen) ...[
          _buildMiniFab(Icons.folder, 'Add Folder',
              () => _handleOption('Add Folder')),
          const SizedBox(height: 10),
          _buildMiniFab(Icons.image, 'Add Images',
              () => _handleOption('Add Images')),
          const SizedBox(height: 10),
          _buildMiniFab(Icons.videocam, 'Add Videos',
              () => _handleOption('Add Videos')),
          const SizedBox(height: 10),
          _buildMiniFab(Icons.insert_drive_file, 'Add Files',
              () => _handleOption('Add Files')),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: _toggleFabMenu,
          backgroundColor: currentFolder.color,
          child: RotationTransition(
            turns:
                Tween(begin: 0.0, end: 0.125).animate(_fabAnimationController),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Future<void> _handleOption(String type) async {
    if (isFabMenuOpen) _toggleFabMenu();
    switch (type) {
      case 'Add Images':
        await _pickAndCopyFiles(FileType.image);
        break;
      case 'Add Videos':
        await _pickAndCopyFiles(FileType.video);
        break;
      case 'Add Files':
        await _pickAndCopyFiles(FileType.any);
        break;
      case 'Add Folder':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => FolderCreatorSheet(
            parentPath: currentFolder.id,
          ),
        );
        break;
    }
  }

  Widget _buildMiniFab(IconData icon, String label, VoidCallback onPressed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: kElevationToShadow[1],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: currentFolder.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 42,
          height: 42,
          child: FloatingActionButton(
            heroTag: null,
            onPressed: onPressed,
            backgroundColor: currentFolder.color,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}

