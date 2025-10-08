// lib/pages/folder_view_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p; // ✨ FIX: Added 'as p' to fix the undefined name error.
import 'package:open_file/open_file.dart';
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
  List<FileSystemEntity> folderFiles = [];

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
    _loadFolderFiles();
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
        final foundFolders = foldersNotifier.value.where((f) => f.id == widget.folder.id);
        if (foundFolders.isNotEmpty) {
            currentFolder = foundFolders.first;
        }
        // Also reload file/folder list from disk
        _loadFolderFiles();
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

  Future<void> _loadFolderFiles() async {
    final contents = await StorageHelper.getFolderContents(currentFolder);
    if (mounted) {
      setState(() {
        folderFiles = contents;
      });
    }
  }

  void _openFile(File file) {
    OpenFile.open(file.path);
  }

  Future<void> _pickAndCopyFiles(FileType type) async {
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
      await _loadFolderFiles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.files.length} file(s) copied')),
      );
    }
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
            onFolderCreated: (folder) {
              // Notifier will handle the state update automatically
            },
          ),
        );
        break;
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
    final files = folderFiles.whereType<File>().toList();
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
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                itemCount: subfolders.length + files.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  if (index < subfolders.length) {
                    final subfolder = subfolders[index];
                    final subfolderCount = foldersNotifier.value
                        .where((f) => f.parentPath == subfolder.id)
                        .length;
                    final folderWithCount =
                        subfolder.copyWith(itemCount: subfolderCount);

                    return FolderCard(
                      folder: folderWithCount,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderViewPage(folder: subfolder),
                          ),
                        );
                      },
                      onRename: (f, newName) =>
                          _renameFolder(context, f, newName),
                      onDelete: (f) => _deleteFolder(context, f),
                      onCustomize: (f, icon, color) =>
                          _customizeFolder(context, f, icon, color),
                    );
                  } else {
                    // ✨ FIX: Completed the else block to display file thumbnails.
                    final file = files[index - subfolders.length];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildThumbnail(file),
                    );
                  }
                },
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedOpacity(
            opacity: isFabMenuOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Visibility(
              visible: isFabMenuOpen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildMiniFab(
                    icon: Icons.folder,
                    label: 'Add Folder',
                    onPressed: () => _handleOption('Add Folder'),
                  ),
                  const SizedBox(height: 10),
                  _buildMiniFab(
                    icon: Icons.image,
                    label: 'Add Images',
                    onPressed: () => _handleOption('Add Images'),
                  ),
                  const SizedBox(height: 10),
                  _buildMiniFab(
                    icon: Icons.videocam,
                    label: 'Add Videos',
                    onPressed: () => _handleOption('Add Videos'),
                  ),
                  const SizedBox(height: 10),
                  _buildMiniFab(
                    icon: Icons.insert_drive_file,
                    label: 'Add Files',
                    onPressed: () => _handleOption('Add Files'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          FloatingActionButton(
            onPressed: _toggleFabMenu,
            backgroundColor: currentFolder.color,
            child: RotationTransition(
              turns: Tween(
                begin: 0.0,
                end: 0.125,
              ).animate(_fabAnimationController),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  void _renameFolder(
    BuildContext context,
    VaultFolder folder,
    String newName,
  ) async {
    final updatedFolder = folder.copyWith(name: newName);
    await StorageHelper.updateFolderMetadata(updatedFolder);
    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final index = currentFolders.indexWhere((f) => f.id == folder.id);
    if (index != -1) {
      currentFolders[index] = updatedFolder;
      foldersNotifier.value = currentFolders;
    }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "${folder.name}" deleted')));
    }
  }

  void _customizeFolder(
    BuildContext context,
    VaultFolder folder,
    IconData icon,
    Color color,
  ) async {
    final updatedFolder = folder.copyWith(icon: icon, color: color);
    await StorageHelper.updateFolderMetadata(updatedFolder);
    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final index = currentFolders.indexWhere((f) => f.id == folder.id);
    if (index != -1) {
      currentFolders[index] = updatedFolder;
      foldersNotifier.value = currentFolders;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "${folder.name}" customized')));
    }
  }

  Widget _buildThumbnail(File file) {
    final path = file.path;
    if (_isImage(path)) {
      return GestureDetector(
        onTap: () => _openFile(file),
        child: Image.file(file, fit: BoxFit.cover),
      );
    } else if (_isVideo(path)) {
      return GestureDetector(
        onTap: () => _openFile(file),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black12),
            const Center(
              child: Icon(Icons.play_circle, color: Colors.white, size: 36),
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _openFile(file),
        child: Container(
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Icon(
            Icons.insert_drive_file,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
  }

  bool _isImage(String path) => [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
      ].contains(p.extension(path).toLowerCase());

  bool _isVideo(String path) =>
      ['.mp4', '.mov', '.avi', '.mkv'].contains(p.extension(path).toLowerCase());

  Widget _buildMiniFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
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