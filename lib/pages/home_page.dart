// lib/pages/home_page.dart
import 'package:flutter/material.dart';
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
                        color:
                            Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
            child: ValueListenableBuilder<List<VaultFolder>>(
              valueListenable: foldersNotifier,
              builder: (context, folders, child) {
                final rootFolders =
                    folders.where((f) => f.parentPath == 'root').toList();

                if (rootFolders.isEmpty) {
                  return _buildEmptyState(context);
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: rootFolders.length,
                  itemBuilder: (context, index) {
                    final folder = rootFolders[index];
                    final subfolderCount = folders
                        .where((subfolder) => subfolder.parentPath == folder.id)
                        .length;
                    final folderWithCount =
                        folder.copyWith(itemCount: subfolderCount);

                    return FolderCard(
                      folder: folderWithCount,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderViewPage(folder: folder),
                          ),
                        );
                      },
                      onRename: (folder, newName) {
                        _renameFolder(context, folder, newName);
                      },
                      onDelete: (f) => _deleteFolder(context, f),
                      onCustomize: (folder, icon, color) {
                        _customizeFolder(context, folder, icon, color);
                      },
                    );
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first folder',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // ✨ NOTE: The helper methods below this line are no longer part of the HomePage widget.
  // They are now defined as standalone functions within the file for clarity.
}

/// ✨ OVERHAULED: Uses the new StorageHelper methods.
void _renameFolder(
  BuildContext context,
  VaultFolder folder,
  String newName,
) async {
  final updatedFolder = folder.copyWith(name: newName);

  // Update the physical .metadata.json file.
  await StorageHelper.updateFolderMetadata(updatedFolder);

  // Update the app's state.
  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);
  if (folderIndex != -1) {
    currentFolders[folderIndex] = updatedFolder;
    foldersNotifier.value = currentFolders;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Folder renamed to "$newName"')),
  );
}

/// ✨ OVERHAULED: Uses the new StorageHelper methods.
void _deleteFolder(BuildContext context, VaultFolder folder) async {
  // Delete the physical folder and its contents.
  await StorageHelper.deleteFolder(folder);

  // Update the app's state by removing the folder and any of its children.
  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  final List<String> idsToDelete = [folder.id];
  
  // Simple recursive delete logic for the in-memory list
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

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Folder "${folder.name}" deleted')),
  );
}

/// ✨ OVERHAULED: Uses the new StorageHelper methods.
void _customizeFolder(
  BuildContext context,
  VaultFolder folder,
  IconData newIcon,
  Color newColor,
) async {
  final updatedFolder = folder.copyWith(icon: newIcon, color: newColor);

  // Update the physical .metadata.json file.
  await StorageHelper.updateFolderMetadata(updatedFolder);

  // Update the app's state.
  final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
  final folderIndex = currentFolders.indexWhere((f) => f.id == folder.id);
  if (folderIndex != -1) {
    currentFolders[folderIndex] = updatedFolder;
    foldersNotifier.value = currentFolders;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Folder "${folder.name}" customized')),
  );
}