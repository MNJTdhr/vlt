// lib/pages/folder_view_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:open_file/open_file.dart';

import '../data/notifiers.dart';
import '../utils/storage_helper.dart';

class FolderViewPage extends StatefulWidget {
  final String folderName;

  const FolderViewPage({super.key, required this.folderName});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage>
    with SingleTickerProviderStateMixin {
  late VaultFolder currentFolder;
  List<FileSystemEntity> folderFiles = []; // List of files/subfolders
  bool isFabMenuOpen = false;
  late AnimationController _fabAnimationController;

  // Color and icon options for subfolders
  final List<Color> availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  final List<IconData> availableIcons = [
    Icons.folder,
    Icons.photo_library,
    Icons.video_library,
    Icons.note,
    Icons.music_note,
    Icons.picture_as_pdf,
    Icons.description,
    Icons.archive,
    Icons.favorite,
    Icons.star,
    Icons.work,
    Icons.school,
  ];

  @override
  void initState() {
    super.initState();
    currentFolder = foldersNotifier.value.firstWhere(
      (f) => f.name == widget.folderName,
      orElse: () => foldersNotifier.value.first,
    );
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadFolderFiles();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadFolderFiles() async {
    final base = await StorageHelper.getVaultRootDirectory();
    final folderPath = Directory('${base.path}/${widget.folderName}');
    if (await folderPath.exists()) {
      final files = folderPath.listSync();
      setState(() {
        folderFiles = files;
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
            folderName: widget.folderName,
            file: originalFile,
          );
        }
      }

      if (!mounted) return;
      await _loadFolderFiles();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.files.length} file(s) copied')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected')),
      );
    }
  }

  Future<void> _handleOption(String type) async {
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
        _showCreateSubfolderDialog();
        break;
    }
  }

  void _showCreateSubfolderDialog() {
    final nameController = TextEditingController();
    IconData selectedIcon = availableIcons[0];
    Color selectedColor = availableColors[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 16,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(Icons.drag_handle, size: 30, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text("Create New Folder",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Center(
                  child: Text("Choose name, icon and color",
                      style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Enter folder name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Choose Icon",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((icon) {
                    final isSelected = icon == selectedIcon;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedIcon = icon),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? selectedColor.withOpacity(0.2)
                              : Colors.grey.shade200,
                          border: Border.all(
                            color:
                                isSelected ? selectedColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(icon,
                            color:
                                isSelected ? selectedColor : Colors.black),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text("Choose Color",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: availableColors.map((color) {
                    final isSelected = color == selectedColor;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedColor = color),
                      child: CircleAvatar(
                        backgroundColor: color,
                        radius: 16,
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text("Cancel"),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          await StorageHelper.createPersistentSubfolder(
                            widget.folderName,
                            name,
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                          await _loadFolderFiles();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                      ),
                      label: const Text("Create Folder"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }

  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);
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
            const Center(child: Icon(Icons.play_circle, color: Colors.white, size: 36)),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _openFile(file),
        child: const Center(child: Icon(Icons.insert_drive_file, size: 40)),
      );
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
          child: Text(label,
              style: TextStyle(
                  color: currentFolder.color, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final isEmpty = folderFiles.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
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
                  Text('The "${widget.folderName}" folder is empty.',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Click the + button to add content.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                itemCount: folderFiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final file = folderFiles[index];
                  if (file is File) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumbnail(file),
                    );
                  } else if (file is Directory) {
                    final folderName = p.basename(file.path);
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderViewPage(
                                folderName: '${widget.folderName}/$folderName'),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder,
                                size: 40, color: currentFolder.color),
                            const SizedBox(height: 4),
                            Text(
                              folderName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
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
              turns: Tween(begin: 0.0, end: 0.125).animate(_fabAnimationController),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
