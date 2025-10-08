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
    Icons.lock,
  ];

  final List<Color> availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

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
                children: availableIcons.map((icon) {
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
            Row(
              children: availableColors.map((color) {
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
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
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

  Future<void> _createFolder() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final id = 'folder_${DateTime.now().millisecondsSinceEpoch}';
    final parent = widget.parentPath;
    final fullPath =
        parent == 'root' ? name : '$parent/$name';

    final newFolder = VaultFolder(
      id: id,
      name: name,
      icon: selectedIcon,
      color: selectedColor,
      itemCount: 0,
      parentPath: parent,
    );

    final updatedList = List<VaultFolder>.from(foldersNotifier.value);
    updatedList.add(newFolder);
    foldersNotifier.value = updatedList;

    await StorageHelper.createPersistentFolder(fullPath);
    await StorageHelper.saveFoldersMetadata(updatedList);

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
