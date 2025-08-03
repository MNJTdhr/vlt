import 'package:flutter/material.dart';
import '../data/notifiers.dart';
import 'package:vlt/pages/folder_view_page.dart';
import 'package:vlt/utils/storage_helper.dart';

// HomePage - Main screen displaying the vault interface
// Contains welcome section and folder grid layout with management features
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section - Displays app branding and security message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.security,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure Vault',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your private files are safe and encrypted',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Folders section header - Title and add button for folder management
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folders',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  // Show add folder bottom sheet instead of dialog
                  _showAddFolderBottomSheet(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Folders grid - Dynamic grid displaying all vault folders
          Expanded(
            child: ValueListenableBuilder<List<VaultFolder>>(
              valueListenable: foldersNotifier,
              builder: (context, folders, child) {
                if (folders.isEmpty) {
                  return _buildEmptyState(context);
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return _buildFolderCard(context, folder);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // _buildEmptyState - Shows when no folders exist
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No folders yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first folder',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // _buildFolderCard - Creates individual folder card widget with menu options
  // Displays folder icon, name, item count with tap functionality and 3-dot menu
  // Parameters: context for theming, folder data model
  Widget _buildFolderCard(BuildContext context, VaultFolder folder) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FolderViewPage(folderName: folder.name),
            ),
          );
        },

        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Folder icon with background - Colored container with folder-specific icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: folder.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(folder.icon, size: 32, color: folder.color),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Folder name - Primary title text
                  Text(
                    folder.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Item count - Shows number of files in folder
                  Text(
                    '${folder.itemCount} items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Three-dot menu - Positioned at top-right corner
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameFolderBottomSheet(context, folder);
                  } else if (value == 'delete') {
                    _showDeleteFolderDialog(context, folder);
                  } else if (value == 'customize') {
                    _showCustomizeFolderBottomSheet(context, folder);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'customize',
                    child: Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Customize'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
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
    );
  }

  // _showAddFolderBottomSheet - Shows bottom sheet to create new folder
  // Allows user to enter name, select icon and color in a drawer-style interface
  void _showAddFolderBottomSheet(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    IconData selectedIcon = Icons.folder;
    Color selectedColor = Colors.blue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Container(
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
                // Handle bar - Visual indicator for draggable bottom sheet
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Header with folder icon preview
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(selectedIcon, size: 28, color: selectedColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Folder',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Choose name, icon and color',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
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
                    hintText: 'Enter folder name',
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                  ),
                  autofocus: true,
                ),

                const SizedBox(height: 24),

                // Icon selection section
                Text(
                  'Choose Icon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: availableIcons.length,
                    itemBuilder: (context, index) {
                      final icon = availableIcons[index];
                      final isSelected = icon == selectedIcon;

                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedIcon = icon),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedColor.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: isSelected
                                  ? selectedColor
                                  : Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? selectedColor
                                : Theme.of(context).colorScheme.onSurface,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Color selection section
                Text(
                  'Choose Color',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableColors.length,
                    itemBuilder: (context, index) {
                      final color = availableColors[index];
                      final isSelected = color == selectedColor;

                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 3,
                                  )
                                : Border.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Action buttons
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
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isNotEmpty) {
                            final newFolder = VaultFolder(
                              id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              icon: selectedIcon,
                              color: selectedColor,
                              itemCount: 0,
                            );

                            final currentFolders = List<VaultFolder>.from(
                              foldersNotifier.value,
                            );
                            currentFolders.add(newFolder);
                            foldersNotifier.value = currentFolders;

                            // ✅ Create folder directory and save metadata
                            await StorageHelper.createPersistentFolder(name);
                            await StorageHelper.saveFoldersMetadata(
                              currentFolders,
                            );

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Folder "$name" created successfully!',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },

                        icon: const Icon(Icons.add),
                        label: const Text('Create Folder'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _showRenameFolderBottomSheet - Shows bottom sheet to rename existing folder
  void _showRenameFolderBottomSheet(BuildContext context, VaultFolder folder) {
    final TextEditingController nameController = TextEditingController(
      text: folder.name,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
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
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Header with folder preview
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: folder.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(folder.icon, size: 28, color: folder.color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rename Folder',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Enter a new name for this folder',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Name input
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.drive_file_rename_outline),
                ),
                autofocus: true,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _renameFolder(context, folder, value.trim());
                    Navigator.pop(context);
                  }
                },
              ),

              const SizedBox(height: 32),

              // Action buttons
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
                      onPressed: () {
                        final newName = nameController.text.trim();
                        if (newName.isNotEmpty) {
                          _renameFolder(context, folder, newName);
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Rename'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // _showDeleteFolderDialog - Shows confirmation dialog to delete folder
  void _showDeleteFolderDialog(BuildContext context, VaultFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"?\n\nThis action cannot be undone and all files in this folder will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _deleteFolder(context, folder);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // _showCustomizeFolderBottomSheet - Shows bottom sheet to customize folder icon and color
  void _showCustomizeFolderBottomSheet(
    BuildContext context,
    VaultFolder folder,
  ) {
    IconData selectedIcon = folder.icon;
    Color selectedColor = folder.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Container(
            padding: const EdgeInsets.all(24),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Header with folder preview
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(selectedIcon, size: 28, color: selectedColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize "${folder.name}"',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Change icon and color',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Icon selection section
                Text(
                  'Choose Icon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: availableIcons.length,
                    itemBuilder: (context, index) {
                      final icon = availableIcons[index];
                      final isSelected = icon == selectedIcon;

                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedIcon = icon),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? selectedColor.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: isSelected
                                  ? selectedColor
                                  : Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? selectedColor
                                : Theme.of(context).colorScheme.onSurface,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Color selection section
                Text(
                  'Choose Color',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableColors.length,
                    itemBuilder: (context, index) {
                      final color = availableColors[index];
                      final isSelected = color == selectedColor;

                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 3,
                                  )
                                : Border.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Action buttons
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
                        onPressed: () {
                          // Update folder appearance
                          _customizeFolder(
                            context,
                            folder,
                            selectedIcon,
                            selectedColor,
                          );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.palette),
                        label: const Text('Apply Changes'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // void _renameFolder(BuildContext context, VaultFolder folder, String newName) {
  //   final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  //   final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);

  //   if (folderIndex != -1) {
  //     currentFolders[folderIndex] = folder.copyWith(name: newName);
  //     foldersNotifier.value = currentFolders;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Folder renamed to "$newName"'),
  //         duration: const Duration(seconds: 2),
  //       ),
  //     );
  //   }
  // }

  void _renameFolder(
    BuildContext context,
    VaultFolder folder,
    String newName,
  ) async {
    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);

    if (folderIndex != -1) {
      currentFolders[folderIndex] = folder.copyWith(name: newName);
      foldersNotifier.value = currentFolders;

      // ✅ Save updated metadata
      await StorageHelper.saveFoldersMetadata(currentFolders);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder renamed to "$newName"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // _deleteFolder - Removes folder from the list
  // void _deleteFolder(BuildContext context, VaultFolder folder) {
  //   final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  //   currentFolders.removeWhere((f) => f.id == folder.id);
  //   foldersNotifier.value = currentFolders;

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text('Folder "${folder.name}" deleted'),
  //       duration: const Duration(seconds: 2),
  //     ),
  //   );
  // }

  void _deleteFolder(BuildContext context, VaultFolder folder) async {
    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    currentFolders.removeWhere((f) => f.id == folder.id);
    foldersNotifier.value = currentFolders;

    // ✅ Save updated metadata
    await StorageHelper.saveFoldersMetadata(currentFolders);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Folder "${folder.name}" deleted'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // void _customizeFolder(
  //   BuildContext context,
  //   VaultFolder folder,
  //   IconData newIcon,
  //   Color newColor,
  // ) {
  //   // Gets current folder list
  //   final currentFolders = List<VaultFolder>.from(foldersNotifier.value);

  //   // Finds the folder to update by ID
  //   final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);

  //   if (folderIndex != -1) {
  //     // Updates folder with new icon and color using copyWith
  //     currentFolders[folderIndex] = folder.copyWith(
  //       icon: newIcon,
  //       color: newColor,
  //     );

  //     // Updates the ValueNotifier to refresh UI
  //     foldersNotifier.value = currentFolders;

  //     // Shows success message
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Folder "${folder.name}" customized successfully!'),
  //         duration: const Duration(seconds: 2),
  //       ),
  //     );
  //   }
  // }

  void _customizeFolder(
    BuildContext context,
    VaultFolder folder,
    IconData newIcon,
    Color newColor,
  ) async {
    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);

    if (folderIndex != -1) {
      currentFolders[folderIndex] = folder.copyWith(
        icon: newIcon,
        color: newColor,
      );
      foldersNotifier.value = currentFolders;

      // ✅ Save updated metadata
      await StorageHelper.saveFoldersMetadata(currentFolders);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder "${folder.name}" customized successfully!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
