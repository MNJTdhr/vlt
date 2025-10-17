// lib/widgets/folder_card.dart
import 'package:flutter/material.dart';
import 'package:vlt/models/vault_folder.dart';

class FolderCard extends StatelessWidget {
  final VaultFolder folder;
  final VoidCallback onTap;
  final void Function(VaultFolder folder, String newName) onRename;
  final void Function(VaultFolder folder) onDelete;
  final void Function(VaultFolder folder, IconData icon, Color color)
  onCustomize;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170, // ✅ Prevent overflow error
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  // ✨ FIX: Centered the column
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize:
                        MainAxisSize.min, // ✅ Important to limit height
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: folder.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(folder.icon, size: 32, color: folder.color),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        folder.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${folder.itemCount} items',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                    size: 20,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _showRenameDialog(context);
                        break;
                      case 'customize':
                        _showCustomizeDialog(context);
                        break;
                      case 'delete':
                        onDelete(folder);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'customize',
                      child: Row(
                        children: [
                          Icon(Icons.palette_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Customize'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: folder.name);

    void submitRename() {
      final newName = controller.text.trim();
      if (newName.isNotEmpty) {
        Navigator.pop(context);
        onRename(folder, newName);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Name'),
          onSubmitted: (_) => submitRename(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submitRename, child: const Text('Rename')),
        ],
      ),
    );
  }

  // ✨ MODIFIED: Replaced the bottom sheet with a centered AlertDialog.
  void _showCustomizeDialog(BuildContext context) {
    IconData selectedIcon = folder.icon;
    Color selectedColor = folder.color;

    final availableIcons = [
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

    final availableColors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
      Colors.deepOrange,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Customize Folder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Icon',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: availableIcons.map((icon) {
                        return IconButton(
                          icon: Icon(
                            icon,
                            color: icon == selectedIcon
                                ? selectedColor
                                : Colors.grey,
                          ),
                          onPressed: () =>
                              setDialogState(() => selectedIcon = icon),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Color',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: availableColors.map((color) {
                        final isSelected = color == selectedColor;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: color,
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onCustomize(folder, selectedIcon, selectedColor);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
