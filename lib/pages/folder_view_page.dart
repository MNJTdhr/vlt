// lib/pages/folder_view_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../data/notifiers.dart';
import 'package:vlt/utils/storage_helper.dart';

class FolderViewPage extends StatefulWidget {
  final String folderName;

  const FolderViewPage({super.key, required this.folderName});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage> {
  late VaultFolder currentFolder;
  bool isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    // Retrieve the folder info from the notifier by name
    currentFolder = foldersNotifier.value.firstWhere(
      (f) => f.name == widget.folderName,
      orElse: () => foldersNotifier.value.first,
    );
  }

  // Toggles the floating action button expansion
  void _toggleFab() {
    setState(() {
      isFabExpanded = !isFabExpanded;
    });
  }

  // Handles each option from the FAB
  void _handleOption(String type) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$type - Coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        backgroundColor: currentFolder.color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: currentFolder.color),
            const SizedBox(height: 16),
            Text(
              'The "${widget.folderName}" folder is empty.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Click the + button to add content.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),

      // Floating Action Button Stack
      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Show options only if expanded
          if (isFabExpanded)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 72),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildFabOption(
                    Icons.folder,
                    'Add Folder',
                    () => _handleOption('Add Folder'),
                  ),
                  const SizedBox(height: 4),
                  _buildFabOption(
                    Icons.image,
                    'Add Images',
                    () => _handleOption('Add Images'),
                  ),
                  const SizedBox(height: 4),
                  _buildFabOption(
                    Icons.videocam,
                    'Add Videos',
                    () => _handleOption('Add Videos'),
                  ),
                  const SizedBox(height: 4),
                  _buildFabOption(
                    Icons.insert_drive_file,
                    'Add Files',
                    () => _handleOption('Add Files'),
                  ),
                ],
              ),
            ),

          // Main toggle FAB
          FloatingActionButton(
            onPressed: _toggleFab,
            backgroundColor: currentFolder.color,
            child: Icon(isFabExpanded ? Icons.close : Icons.add),
          ),
        ],
      ),
    );
  }

  // Builds each individual FAB option (folder, images, etc.)
  Widget _buildFabOption(IconData icon, String label, VoidCallback onTap) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          _toggleFab();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: currentFolder.color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: currentFolder.color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: currentFolder.color, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
