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

// Add 'SingleTickerProviderStateMixin' to use an AnimationController for the FAB animation.
class _FolderViewPageState extends State<FolderViewPage>
    with SingleTickerProviderStateMixin {
  late VaultFolder currentFolder;
  List<FileSystemEntity> folderFiles = []; // Stores files inside the folder

  // --- FAB Animation State ---
  late AnimationController _fabAnimationController;
  bool isFabMenuOpen = false; // Controls the FAB menu's open/closed state.

  @override
  void initState() {
    super.initState();
    currentFolder = foldersNotifier.value.firstWhere(
      (f) => f.name == widget.folderName,
      orElse: () => foldersNotifier.value.first,
    );

    // Initialize the AnimationController for the FAB open/close animation.
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _loadFolderFiles();
  }

  @override
  void dispose() {
    // Dispose the controller when the widget is removed to free up resources.
    _fabAnimationController.dispose();
    super.dispose();
  }

  /// Toggles the Floating Action Button menu between open and closed states.
  void _toggleFabMenu() {
    setState(() {
      isFabMenuOpen = !isFabMenuOpen;
      if (isFabMenuOpen) {
        // If the menu is opening, play the animation forward.
        _fabAnimationController.forward();
      } else {
        // If the menu is closing, play the animation in reverse.
        _fabAnimationController.reverse();
      }
    });
  }

  /// Loads all files from the specified folder directory.
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

  /// Opens the selected file using the device's default application.
  void _openFile(File file) {
    OpenFile.open(file.path);
  }

  /// Opens the file picker to select files of a specific type and copies them to the vault.
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

  /// Handles the action when a FAB menu item is tapped.
  Future<void> _handleOption(String type) async {
    // Close the FAB menu before performing the action.
    if (isFabMenuOpen) {
      _toggleFabMenu();
    }

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
        _showComingSoonDialog('Add Folder');
        break;
    }
  }

  /// Shows a dialog for features that are not yet implemented.
  void _showComingSoonDialog(String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: const Text('This feature will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // --- File Type Checkers ---
  bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }

  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);
  }

  /// Builds the appropriate thumbnail for a given file.
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
                child: Icon(Icons.play_circle, color: Colors.white, size: 36)),
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

  /// Builds a small, labeled Floating Action Button for the expandable menu.
  /// This widget represents one of the pop-up options.
  Widget _buildMiniFab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The label for the button, styled to look clean.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: kElevationToShadow[1],
          ),
          child: Text(label,
              style:
                  TextStyle(color: currentFolder.color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        // The small FAB itself.
        SizedBox(
          width: 42,
          height: 42,
          child: FloatingActionButton(
            heroTag: null, // Use null heroTag for multiple FABs on one screen.
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
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

      // --- Refactored Floating Action Button ---
      // This Column holds the expandable menu and the main FAB.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The expandable menu is wrapped in an AnimatedOpacity widget
          // to create a smooth fade-in/out effect.
          AnimatedOpacity(
            opacity: isFabMenuOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            // The Visibility widget ensures the menu items are not interactable when hidden.
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
          // This is the main Floating Action Button.
          FloatingActionButton(
            onPressed: _toggleFabMenu,
            backgroundColor: currentFolder.color,
            // The RotationTransition animates the '+' icon to an 'x' when the menu opens.
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
