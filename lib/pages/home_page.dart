// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:vlt/widgets/folder_card.dart';
import '../data/notifiers.dart';
import 'package:vlt/pages/folder_view_page.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/widgets/folder_creator_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.all(20),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         Theme.of(context).colorScheme.primary.withOpacity(0.1),
          //         Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          //       ],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     borderRadius: BorderRadius.circular(16),
          //     border: Border.all(
          //       color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          //     ),
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Icon(
          //         Icons.security,
          //         size: 32,
          //         color: Theme.of(context).colorScheme.primary,
          //       ),
          //       const SizedBox(height: 8),
          //       Text(
          //         'Secure Vault',
          //         style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          //               fontWeight: FontWeight.bold,
          //             ),
          //       ),
          //       const SizedBox(height: 4),
          //       Text(
          //         'Your private files are safe and encrypted',
          //         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          //               color:
          //                   Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          //             ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 24),
          // Folders section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folders',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) =>
                        const FolderCreatorSheet(parentPath: 'root'),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Folders grid
          Expanded(
            child: ValueListenableBuilder<HomeSortOption>(
              valueListenable: homeSortNotifier,
              builder: (context, sortOption, _) {
                return ValueListenableBuilder<List<VaultFolder>>(
                  valueListenable: foldersNotifier,
                  builder: (context, folders, child) {
                    final rootFolders =
                        folders.where((f) => f.parentPath == 'root').toList();

                    // ✨ MODIFIED: Sorting logic now includes the 'manual' option.
                    rootFolders.sort((a, b) {
                      switch (sortOption) {
                        case HomeSortOption.manual:
                          return a.sortOrder.compareTo(b.sortOrder);
                        case HomeSortOption.dateNewest:
                          return b.creationDate.compareTo(a.creationDate);
                        case HomeSortOption.dateOldest:
                          return a.creationDate.compareTo(b.creationDate);
                        case HomeSortOption.nameAZ:
                          return a.name
                              .toLowerCase()
                              .compareTo(b.name.toLowerCase());
                        case HomeSortOption.nameZA:
                          return b.name
                              .toLowerCase()
                              .compareTo(a.name.toLowerCase());
                      }
                    });

                    if (rootFolders.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    // ✨ ADDED: Conditionally return a reorderable grid or a standard one.
                    if (sortOption == HomeSortOption.manual) {
                      return ReorderableGridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: rootFolders.length,
                        itemBuilder: (context, index) {
                          final folder = rootFolders[index];
                          return SizedBox(
                            key: ValueKey(folder.id),
                            child: FolderCard(
                              folder: folder,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FolderViewPage(folder: folder),
                                  ),
                                );
                              },
                              onRename: (f, newName) =>
                                  _renameFolder(context, f, newName),
                              onDelete: (f) => _deleteFolder(context, f),
                              onCustomize: (f, icon, color) =>
                                  _customizeFolder(context, f, icon, color),
                            ),
                          );
                        },
                        onReorder: (oldIndex, newIndex) {
                          _onReorder(rootFolders, oldIndex, newIndex);
                        },
                      );
                    } else {
                      // This is the standard, non-reorderable grid.
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: rootFolders.length,
                        itemBuilder: (context, index) {
                          final folder = rootFolders[index];
                          return FolderCard(
                            folder: folder,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FolderViewPage(folder: folder),
                                ),
                              );
                            },
                            onRename: (f, newName) =>
                                _renameFolder(context, f, newName),
                            onDelete: (f) => _deleteFolder(context, f),
                            onCustomize: (f, icon, color) =>
                                _customizeFolder(context, f, icon, color),
                          );
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No folders yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first folder',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ✨ MODIFIED: Handles the logic for reordering folders and updates the UI instantly.
void _onReorder(
    List<VaultFolder> rootFolders, int oldIndex, int newIndex) async {
  // 1. Perform the reorder in the local list.
  final movedFolder = rootFolders.removeAt(oldIndex);
  rootFolders.insert(newIndex, movedFolder);

  // 2. Create a new list where each folder object has its 'sortOrder' property updated.
  final List<VaultFolder> updatedRootFolders = [];
  for (int i = 0; i < rootFolders.length; i++) {
    updatedRootFolders.add(rootFolders[i].copyWith(sortOrder: i));
  }

  // 3. Update the database with the new correct sort order.
  await StorageHelper.updateFolderSortOrder(updatedRootFolders);

  // 4. Update the global notifier with the list that contains the updated objects.
  final otherFolders = foldersNotifier.value
      .where((folder) => folder.parentPath != 'root')
      .toList();
  foldersNotifier.value = [...updatedRootFolders, ...otherFolders];
}


/// Renames a folder's metadata in the database.
void _renameFolder(
  BuildContext context,
  VaultFolder folder,
  String newName,
) async {
  final updatedFolder = folder.copyWith(name: newName);
  await StorageHelper.updateFolderMetadata(updatedFolder);

  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);
  if (folderIndex != -1) {
    currentFolders[folderIndex] = updatedFolder;
    foldersNotifier.value = currentFolders;
  }

  if (ScaffoldMessenger.of(context).mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder renamed to "$newName"')),
    );
  }
}

/// Deletes a folder and all its contents from the database, then refreshes item counts.
void _deleteFolder(BuildContext context, VaultFolder folder) async {
  await StorageHelper.deleteFolder(folder);

  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  // Find all children recursively to remove from the notifier list in one go.
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

  // Refresh the item counts for all remaining folders.
  await refreshItemCounts();

  if (ScaffoldMessenger.of(context).mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "${folder.name}" deleted')),
    );
  }
}

/// Customizes a folder's metadata in the database.
void _customizeFolder(
  BuildContext context,
  VaultFolder folder,
  IconData newIcon,
  Color newColor,
) async {
  final updatedFolder = folder.copyWith(icon: newIcon, color: newColor);
  await StorageHelper.updateFolderMetadata(updatedFolder);

  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);
  if (folderIndex != -1) {
    currentFolders[folderIndex] = updatedFolder;
    foldersNotifier.value = currentFolders;
  }

  if (ScaffoldMessenger.of(context).mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "${folder.name}" customized')),
    );
  }
}