// lib/widgets/folder_creator_sheet.dart
import 'package:flutter/material.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/data/notifiers.dart';

/// FolderCreatorSheet - Reusable bottom sheet to create new folders
/// Can be used for root folders or subfolders by passing parentPath.
class FolderCreatorSheet extends StatefulWidget {
  final String parentPath;
  final void Function(VaultFolder folder)? onFolderCreated;

  const FolderCreatorSheet({
    super.key,
    this.parentPath = 'root',
    this.onFolderCreated,
  });

  @override
  State<FolderCreatorSheet> createState() => _FolderCreatorSheetState();
}

class _FolderCreatorSheetState extends State<FolderCreatorSheet> {
  final TextEditingController nameController = TextEditingController();
  IconData selectedIcon = Icons.folder;
  Color selectedColor = Colors.blue;
  
  // ✨ NOTE: The local 'availableIcons' and 'availableColors' lists have been removed
  // to use the global constants from 'notifiers.dart', ensuring consistency.

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView( // ✨ WRAPPED in SingleChildScrollView to prevent overflow
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(selectedIcon, size: 28, color: selectedColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create New Folder',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Choose name, icon and color',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Folder name input
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.drive_file_rename_outline),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),

              // Icon picker
              _buildLabel('Choose Icon'),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: availableIcons.map((icon) { // ✨ USING global constant
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = icon),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: icon == selectedIcon
                              ? selectedColor.withOpacity(0.15)
                              : Colors.transparent,
                          border: Border.all(
                            color:
                                icon == selectedIcon ? selectedColor : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: selectedColor),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Color picker
              _buildLabel('Choose Color'),
              const SizedBox(height: 12),
              SizedBox( // ✨ WRAPPED in SizedBox to allow horizontal scrolling on smaller screens
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: availableColors.map((color) { // ✨ USING global constant
                    final isSelected = color == selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  width: 2.5)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _createFolder,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Folder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  /// ✨ OVERHAULED: This function now uses the new file-based storage logic.
  Future<void> _createFolder() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      // Optional: Show a small error message if the name is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder name cannot be empty')),
      );
      return;
    }

    final newFolder = VaultFolder(
      // The physical folder will be named after this ID, not the display name.
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: selectedIcon,
      color: selectedColor,
      itemCount: 0,
      parentPath: widget.parentPath,
      creationDate: DateTime.now(), // Add the creation date
    );

    // Create the physical folder and its .metadata.json file.
    await StorageHelper.createFolder(newFolder);

    // Update the app's state.
    final updatedList = List<VaultFolder>.from(foldersNotifier.value);
    updatedList.add(newFolder);
    foldersNotifier.value = updatedList;

    if (widget.onFolderCreated != null) {
      widget.onFolderCreated!(newFolder);
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder "$name" created')),
      );
    }
  }
}