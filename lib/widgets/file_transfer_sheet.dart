// lib/widgets/file_transfer_sheet.dart
import 'package:flutter/material.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/models/vault_folder.dart';

class FileTransferSheet extends StatefulWidget {
  final VaultFolder sourceFolder;

  const FileTransferSheet({
    super.key,
    required this.sourceFolder,
  });

  @override
  State<FileTransferSheet> createState() => _FileTransferSheetState();
}

class _FileTransferSheetState extends State<FileTransferSheet> {
  // A stack to manage navigation history. The last item is the current folder.
  final List<VaultFolder> _folderStack = [
    VaultFolder(
      id: 'root',
      name: 'Root',
      icon: Icons.home_work_rounded,
      color: Colors.grey,
      itemCount: 0,
      parentPath: '',
      creationDate: DateTime.now(),
    )
  ];

  /// Gets the currently displayed folder from the top of the stack.
  VaultFolder get _currentFolder => _folderStack.last;

  /// Gets the subfolders for the currently displayed folder.
  List<VaultFolder> _getSubfolders() {
    return foldersNotifier.value
        .where((f) => f.parentPath == _currentFolder.id)
        .toList();
  }

  /// Navigates into a subfolder.
  void _navigateTo(VaultFolder folder) {
    setState(() {
      _folderStack.add(folder);
    });
  }

  /// Navigates back to the parent folder.
  void _navigateBack() {
    if (_folderStack.length > 1) {
      setState(() {
        _folderStack.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subfolders = _getSubfolders();
    final isAtRoot = _folderStack.length == 1;
    // The transfer is disabled if the destination is the same as the source.
    final canTransfer = _currentFolder.id != widget.sourceFolder.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            _buildHeader(isAtRoot),
            const Divider(),
            const SizedBox(height: 8),

            // --- Folder List ---
            Expanded(
              child: subfolders.isEmpty
                  ? const Center(child: Text('This folder is empty.'))
                  : ListView.builder(
                      itemCount: subfolders.length,
                      itemBuilder: (context, index) {
                        final folder = subfolders[index];
                        return ListTile(
                          leading: Icon(folder.icon, color: folder.color),
                          title: Text(folder.name),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _navigateTo(folder),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // --- Action Button ---
            FilledButton.icon(
              onPressed: canTransfer
                  ? () {
                      // Pop the sheet and return the selected folder.
                      Navigator.of(context).pop(_currentFolder);
                    }
                  : null, // Disable button if it's the source folder
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text(
                canTransfer
                    ? 'Transfer to "${_currentFolder.name}"'
                    : 'File is already here',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: canTransfer
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAtRoot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          // Show back button only when not at the root level.
          if (!isAtRoot)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateBack,
            )
          else
            const SizedBox(width: 48), // Placeholder to keep alignment

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Select Destination',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                // Build a breadcrumb-style path display.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _folderStack.map((f) => f.name).join(' / '),
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Close button on the right.
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}