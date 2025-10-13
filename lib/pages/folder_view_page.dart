// lib/pages/folder_view_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:vlt/pages/photo_view_page.dart';
import 'package:vlt/widgets/file_transfer_sheet.dart';
import 'package:vlt/widgets/folder_card.dart';
import 'package:vlt/widgets/folder_creator_sheet.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/models/vault_folder.dart';

class FolderViewPage extends StatefulWidget {
  final VaultFolder folder;
  const FolderViewPage({super.key, required this.folder});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage>
    with TickerProviderStateMixin { // ✨ MODIFIED: Changed to support multiple controllers
  late VaultFolder currentFolder;
  List<File> folderFiles = [];
  List<VaultFile> _vaultFiles = [];

  late AnimationController _fabAnimationController;
  late AnimationController _loadingController; // ✨ ADDED: Controller for loading animation
  bool isFabMenuOpen = false;
  bool _isLoading = true; // ✨ ADDED: State for loading indicator

  // State for selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedItemIds = {};

  // State for hold-drag-select gesture
  final GlobalKey _folderGridKey = GlobalKey();
  final GlobalKey _favoriteFileGridKey = GlobalKey();
  final GlobalKey _otherFileGridKey = GlobalKey();
  int? _lastDraggedIndex;
  bool _isDragSelecting = false;


  @override
  void initState() {
    super.initState();
    currentFolder = widget.folder;
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // ✨ ADDED: Initialize and start the loading animation controller
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    foldersNotifier.addListener(_onFoldersChanged);
    _loadAllFolderContents();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _loadingController.dispose(); // ✨ ADDED: Dispose the loading controller
    foldersNotifier.removeListener(_onFoldersChanged);
    clearSharedImageCache(); 
    super.dispose();
  }

  void _onFoldersChanged() {
    if (mounted) {
      setState(() {
        final foundFolders = foldersNotifier.value.where(
          (f) => f.id == widget.folder.id,
        );
        if (foundFolders.isNotEmpty) {
          currentFolder = foundFolders.first;
        }
        _loadAllFolderContents();
      });
    }
  }

  /// ✨ REFINED: Load contents and perform self-healing synchronization.
  Future<void> _loadAllFolderContents() async {
    final physicalFiles = await StorageHelper.getFolderContents(currentFolder);
    List<VaultFile> fileMetadata = await StorageHelper.loadVaultFileIndex(currentFolder);

    // --- Self-Healing Logic ---
    bool needsUpdate = false;
    
    // Create sets for efficient lookup
    final physicalFileNames = physicalFiles.map((f) => p.basename(f.path)).toSet();
    final metadataFileIds = fileMetadata.map((mf) => mf.id).toSet();

    // 1. Find orphan files (exist on disk but not in metadata)
    final orphanFiles = physicalFileNames.difference(metadataFileIds);
    if (orphanFiles.isNotEmpty) {
      needsUpdate = true;
      for (final fileName in orphanFiles) {
        final physicalFile = physicalFiles.firstWhere((f) => p.basename(f.path) == fileName);
        fileMetadata.add(VaultFile(
          id: fileName,
          fileName: fileName, // Use the actual file name as a fallback
          originalPath: 'unknown', // Original path is lost
          dateAdded: DateTime.now(),
          originalParentPath: currentFolder.id,
        ));
      }
    }

    // 2. Find ghost metadata (exists in metadata but not on disk)
    final ghostMetadataIds = metadataFileIds.difference(physicalFileNames);
    if (ghostMetadataIds.isNotEmpty) {
      needsUpdate = true;
      fileMetadata.removeWhere((mf) => ghostMetadataIds.contains(mf.id));
    }

    // 3. If inconsistencies were found, save the corrected metadata
    if (needsUpdate) {
      await StorageHelper.saveVaultFileIndex(currentFolder, fileMetadata);
      await refreshItemCounts();
    }
    
    if (mounted) {
      setState(() {
        folderFiles = physicalFiles;
        _vaultFiles = fileMetadata;
        _isLoading = false; // ✨ MODIFIED: Hide loading indicator when done
      });
      _preloadInitialImages();
    }
  }

  /// Preloads the first few images in the folder into the shared cache.
  void _preloadInitialImages() {
    final allImages = _vaultFiles.where((f) => _isImage(f.id)).toList();
    for (int i = 0; i < allImages.length && i < 6; i++) {
      preloadImage(allImages[i], context);
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

  Future<void> _pickAndCopyFiles(FileType type) async {
    bool permissionGranted = false;

    if (type == FileType.image) {
      permissionGranted =
          await Permission.photos.request().isGranted ||
          await Permission.storage.request().isGranted;
    } else if (type == FileType.video) {
      permissionGranted =
          await Permission.videos.request().isGranted ||
          await Permission.storage.request().isGranted;
    } else {
      permissionGranted = await Permission.manageExternalStorage
          .request()
          .isGranted;
    }

    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access files.')),
        );
      }
      return;
    }

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
            folder: currentFolder,
            file: originalFile,
          );
        }
      }
      await refreshItemCounts();
      await _loadAllFolderContents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.files.length} file(s) copied')),
      );
    }
  }

  List<VaultFolder> _getSubfolders() {
    return foldersNotifier.value
        .where((f) => f.parentPath == currentFolder.id)
        .toList();
  }

  // --- SELECTION MODE LOGIC ---

  void _toggleSelectionMode({String? initialSelectionId}) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItemIds.clear();
      if (initialSelectionId != null && _isSelectionMode) {
        _selectedItemIds.add(initialSelectionId);
      }
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
        if (_selectedItemIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final allItemIds = [
        ..._getSubfolders().map((f) => f.id),
        ..._vaultFiles.map((f) => f.id),
      ];
      if (_selectedItemIds.length == allItemIds.length) {
        _selectedItemIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedItemIds.addAll(allItemIds);
      }
    });
  }

  // --- DRAG-TO-SELECT LOGIC ---
  void _onPanStart(DragStartDetails details) {
    if (_isSelectionMode) {
      _isDragSelecting = true;
      _handleDragSelection(details.globalPosition);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDragSelecting) {
      _handleDragSelection(details.globalPosition);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragSelecting = false;
    _lastDraggedIndex = null;
  }

  void _handleDragSelection(Offset globalPosition) {
    // Check folder grid
    _updateSelectionForGrid(
      globalPosition: globalPosition,
      gridKey: _folderGridKey,
      crossAxisCount: 2,
      childAspectRatio: 1.1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      items: _getSubfolders(),
      baseIndex: 0,
    );

    final favoriteFiles = _vaultFiles.where((f) => f.isFavorite).toList();
    // Check favorite files grid
    _updateSelectionForGrid(
      globalPosition: globalPosition,
      gridKey: _favoriteFileGridKey,
      crossAxisCount: 3,
      childAspectRatio: 1.0,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      items: favoriteFiles,
      baseIndex: _getSubfolders().length,
    );

    // Check other files grid
    _updateSelectionForGrid(
      globalPosition: globalPosition,
      gridKey: _otherFileGridKey,
      crossAxisCount: 3,
      childAspectRatio: 1.0,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      items: _vaultFiles.where((f) => !f.isFavorite).toList(),
      baseIndex: _getSubfolders().length + favoriteFiles.length,
    );
  }

  void _updateSelectionForGrid({
    required Offset globalPosition,
    required GlobalKey gridKey,
    required int crossAxisCount,
    required double childAspectRatio,
    required double crossAxisSpacing,
    required double mainAxisSpacing,
    required List<dynamic> items,
    required int baseIndex,
  }) {
    final renderBox = gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final localPos = renderBox.globalToLocal(globalPosition);

    if (localPos.dx >= 0 &&
        localPos.dx <= renderBox.size.width &&
        localPos.dy >= 0 &&
        localPos.dy <= renderBox.size.height) {
      final itemWidth = (renderBox.size.width - (crossAxisSpacing * (crossAxisCount - 1))) / crossAxisCount;
      final itemHeight = itemWidth / childAspectRatio;

      final col = (localPos.dx / (itemWidth + crossAxisSpacing)).floor().clamp(0, crossAxisCount - 1);
      final row = (localPos.dy / (itemHeight + mainAxisSpacing)).floor();

      final index = (row * crossAxisCount) + col;
      final globalIndex = baseIndex + index;

      if (index >= 0 && index < items.length && globalIndex != _lastDraggedIndex) {
        final item = items[index];
        final itemId = item.id as String;

        if (!_selectedItemIds.contains(itemId)) {
          setState(() {
            _selectedItemIds.add(itemId);
          });
        }
        _lastDraggedIndex = globalIndex;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subfolders = _getSubfolders();
    final favoriteFiles = _vaultFiles.where((f) => f.isFavorite).toList();
    final otherFiles = _vaultFiles.where((f) => !f.isFavorite).toList();
    final isEmpty =
        otherFiles.isEmpty && favoriteFiles.isEmpty && subfolders.isEmpty;

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          _toggleSelectionMode(); // Deactivate selection mode
          return false; // Prevent popping the route
        }
        return true; // Allow popping the route
      },
      child: Scaffold(
        appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
        body: _isLoading
            ? _buildLoadingIndicator()
            : GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: currentFolder.color),
                            const SizedBox(height: 16),
                            Text(
                              'The "${currentFolder.name}" folder is empty.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Click the + button to add content.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        slivers: [
                          if (subfolders.isNotEmpty) _buildFolderGrid(subfolders, _folderGridKey),
                          if (subfolders.isNotEmpty && (favoriteFiles.isNotEmpty || otherFiles.isNotEmpty))
                            _buildDivider(),
                          if (favoriteFiles.isNotEmpty)
                            _buildFileGrid(favoriteFiles, _vaultFiles, subfolders.isEmpty, _favoriteFileGridKey),
                          if (favoriteFiles.isNotEmpty && otherFiles.isNotEmpty)
                            _buildDivider(),
                          if (otherFiles.isNotEmpty)
                            _buildFileGrid(
                                otherFiles, _vaultFiles, subfolders.isEmpty && favoriteFiles.isEmpty, _otherFileGridKey),
                        ],
                      ),
              ),
        floatingActionButton: _isSelectionMode ? null : _buildFabMenu(),
        bottomNavigationBar: _isSelectionMode && _selectedItemIds.isNotEmpty
            ? _buildBottomActionBar()
            : null,
      ),
    );
  }

  // ✨ ADDED: Widget to display the timed loading indicator
  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: _loadingController.value,
                  strokeWidth: 5,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading Content...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolderGrid(List<VaultFolder> subfolders, GlobalKey gridKey) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        key: gridKey,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final subfolder = subfolders[index];
            final isSelected = _selectedItemIds.contains(subfolder.id);
            return GestureDetector(
              onLongPress: () {
                if (!_isSelectionMode) {
                  _toggleSelectionMode(initialSelectionId: subfolder.id);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FolderCard(
                    folder: subfolder,
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleItemSelection(subfolder.id);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderViewPage(folder: subfolder),
                          ),
                        );
                      }
                    },
                    onRename: (f, newName) => _renameFolder(context, f, newName),
                    onDelete: (f) => _deleteFolder(context, f),
                    onCustomize: (f, icon, color) =>
                        _customizeFolder(context, f, icon, color),
                  ),
                  if (_isSelectionMode)
                    _buildSelectionOverlay(isSelected, isFolder: true),
                ],
              ),
            );
          },
          childCount: subfolders.length,
        ),
      ),
    );
  }

  Widget _buildFileGrid(List<VaultFile> files, List<VaultFile> allFiles, bool addTopPadding, GlobalKey gridKey) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(8.0, addTopPadding ? 16.0 : 0.0, 8.0, 8.0),
      sliver: SliverGrid(
        key: gridKey,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final vaultFile = files[index];
            final isSelected = _selectedItemIds.contains(vaultFile.id);
            final physicalFile = folderFiles.firstWhere(
              (f) => p.basename(f.path) == vaultFile.id,
              orElse: () => File(''),
            );

            if (physicalFile.path.isEmpty) {
              return const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey));
            }

            return GestureDetector(
              onTap: () async {
                if (_isSelectionMode) {
                  _toggleItemSelection(vaultFile.id);
                } else {
                  final allImages = _vaultFiles.where((f) => _isImage(f.id)).toList();
                  final initialIndex = allImages.indexWhere((f) => f.id == vaultFile.id);
                  
                  if (initialIndex != -1) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoViewPage(
                          files: allImages,
                          initialIndex: initialIndex,
                          parentFolder: currentFolder,
                        ),
                      ),
                    );
                    await _loadAllFolderContents();
                  }
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _toggleSelectionMode(initialSelectionId: vaultFile.id);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildThumbnail(physicalFile),
                  ),
                  if (_isSelectionMode) _buildSelectionOverlay(isSelected),
                ],
              ),
            );
          },
          childCount: files.length,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Divider(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
      ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(currentFolder.name),
      backgroundColor: currentFolder.color,
      foregroundColor: Colors.white,
      actions: [
        if (!_getSubfolders().isEmpty || !_vaultFiles.isEmpty)
          IconButton(
            icon: const Icon(Icons.check_box_outlined),
            tooltip: 'Select Items',
            onPressed: () => setState(() => _isSelectionMode = true),
          ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _toggleSelectionMode,
      ),
      title: Text('${_selectedItemIds.length} selected'),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      actions: [
        TextButton(
          onPressed: _selectAll,
          child: Text(
            _selectedItemIds.length ==
                    (_getSubfolders().length + _vaultFiles.length)
                ? 'DESELECT ALL'
                : 'SELECT ALL',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionOverlay(bool isSelected, {bool isFolder = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.5)
            : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(isFolder ? 16 : 12),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomAction(Icons.lock_open, 'Unhide', _unhidePlaceholder),
          _buildBottomAction(
              Icons.drive_file_move_outline, 'Transfer', _transferSelectedFiles),
          _buildBottomAction(Icons.delete, 'Recycle', _recycleSelectedItems),
          _buildBottomAction(
              Icons.favorite, 'Favourite', _toggleFavoriteSelectedFiles),
          _buildBottomAction(Icons.share_outlined, 'Share', _sharePlaceholder),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
      IconData icon, String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // --- Placeholder and Action Methods for Bottom Bar ---
  void _unhidePlaceholder() => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unhide coming soon!')));
  void _sharePlaceholder() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Share coming soon!')));

  Future<void> _toggleFavoriteSelectedFiles() async {
    if (_selectedItemIds.isEmpty) return;

    final subfolderIds = _getSubfolders().map((f) => f.id).toSet();
    final hasFolders = _selectedItemIds.any((id) => subfolderIds.contains(id));

    if (hasFolders) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Folders cannot be favorited. Please select only files.')),
        );
      }
      return;
    }
    
    final firstFile = _vaultFiles.firstWhere(
      (f) => f.id == _selectedItemIds.first,
    );
    final bool markAsFavorite = !firstFile.isFavorite;

    for (final id in _selectedItemIds) {
      final fileToUpdate = _vaultFiles.firstWhere((f) => f.id == id);
      if (fileToUpdate.isFavorite != markAsFavorite) {
         final updatedFile = fileToUpdate.copyWith(isFavorite: markAsFavorite);
         await StorageHelper.updateFileMetadata(updatedFile, currentFolder);
      }
    }
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(markAsFavorite ? 'Added to favorites.' : 'Removed from favorites.')),
      );
    }
    
    _toggleSelectionMode();
    await _loadAllFolderContents();
  }

  Future<void> _transferSelectedFiles() async {
    if (_selectedItemIds.isEmpty) return;

    final subfolderIds = _getSubfolders().map((f) => f.id).toSet();
    final hasFolders = _selectedItemIds.any((id) => subfolderIds.contains(id));

    if (hasFolders) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Folders cannot be transferred. Please select only files.')),
        );
      }
      return;
    }

    final VaultFolder? destinationFolder =
        await showModalBottomSheet<VaultFolder>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: FileTransferSheet(sourceFolder: currentFolder),
      ),
    );

    if (destinationFolder == null || !mounted) return;

    for (final id in _selectedItemIds) {
      final fileToMove = _vaultFiles.firstWhere((f) => f.id == id);
      await StorageHelper.transferFile(
          fileToMove, currentFolder, destinationFolder);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${_selectedItemIds.length} item(s) transferred to "${destinationFolder.name}"')),
      );
    }

    _toggleSelectionMode();
    await refreshItemCounts();
    await _loadAllFolderContents();
  }

  Future<void> _recycleSelectedItems() async {
    if (_selectedItemIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Items to bin?'),
        content: Text(
            'Are you sure you want to delete ${_selectedItemIds.length} item(s)?\n\nFiles will be moved to the recycle bin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final allSubfolders = _getSubfolders();
    final allFiles = _vaultFiles;

    for (final id in Set<String>.from(_selectedItemIds)) {
      final fileMatch = allFiles.where((f) => f.id == id);
      if (fileMatch.isNotEmpty) {
        await StorageHelper.moveFileToRecycleBin(
            fileMatch.first, currentFolder);
        continue;
      }

      final folderMatch = allSubfolders.where((f) => f.id == id);
      if (folderMatch.isNotEmpty) {
        await _deleteFolder(context, folderMatch.first, showSnackbar: false);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected items recycled.')),
      );
    }

    _toggleSelectionMode();
    await refreshItemCounts();
    await _loadAllFolderContents();
  }

  // --- Folder management actions ---
  void _renameFolder(
    BuildContext context,
    VaultFolder folder,
    String newName,
  ) async {
    final updatedFolder = folder.copyWith(name: newName);
    await StorageHelper.updateFolderMetadata(updatedFolder);

    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final index = currentFolders.indexWhere((f) => f.id == folder.id);
    if (index != -1) currentFolders[index] = updatedFolder;
    foldersNotifier.value = currentFolders;

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Folder renamed to "$newName"')));
    }
  }

  Future<void> _deleteFolder(BuildContext context, VaultFolder folder,
      {bool showSnackbar = true}) async {
    await StorageHelper.deleteFolder(folder);
    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);

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
    await refreshItemCounts();

    if (showSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder "${folder.name}" deleted')),
      );
    }
  }

  void _customizeFolder(
    BuildContext context,
    VaultFolder folder,
    IconData icon,
    Color color,
  ) async {
    final updatedFolder = folder.copyWith(icon: icon, color: color);
    await StorageHelper.updateFolderMetadata(updatedFolder);

    final currentFolders = List<VaultFolder>.from(foldersNotifier.value);
    final index = currentFolders.indexWhere((f) => f.id == folder.id);
    if (index != -1) currentFolders[index] = updatedFolder;
    foldersNotifier.value = currentFolders;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder "${folder.name}" customized')),
      );
    }
  }

  // --- Thumbnail helpers ---
  Widget _buildThumbnail(File file) {
    final path = file.path;
    if (_isImage(path)) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    } else if (_isVideo(path)) {
      return Stack(
        fit: StackFit.expand,
        children: const [
          ColoredBox(color: Colors.black12),
          Center(child: Icon(Icons.play_circle, color: Colors.white, size: 36)),
        ],
      );
    } else {
      return const Icon(Icons.insert_drive_file);
    }
  }

  bool _isImage(String path) => [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
      ].contains(p.extension(path).toLowerCase());

  bool _isVideo(String path) => [
        '.mp4',
        '.mov',
        '.avi',
        '.mkv',
      ].contains(p.extension(path).toLowerCase());

  // --- Floating Action Menu ---
  Widget _buildFabMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isFabMenuOpen) ...[
          _buildMiniFab(
            Icons.folder,
            'Add Folder',
            () => _handleOption('Add Folder'),
          ),
          const SizedBox(height: 10),
          _buildMiniFab(
            Icons.image,
            'Add Images',
            () => _handleOption('Add Images'),
          ),
          const SizedBox(height: 10),
          _buildMiniFab(
            Icons.videocam,
            'Add Videos',
            () => _handleOption('Add Videos'),
          ),
          const SizedBox(height: 10),
          _buildMiniFab(
            Icons.insert_drive_file,
            'Add Files',
            () => _handleOption('Add Files'),
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: _toggleFabMenu,
          backgroundColor: currentFolder.color,
          child: RotationTransition(
            turns: Tween(
              begin: 0.0,
              end: 0.125,
            ).animate(_fabAnimationController),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Future<void> _handleOption(String type) async {
    if (isFabMenuOpen) _toggleFabMenu();
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
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => FolderCreatorSheet(parentPath: currentFolder.id),
        );
        break;
    }
  }

  Widget _buildMiniFab(IconData icon, String label, VoidCallback onPressed) {
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
          child: Text(
            label,
            style: TextStyle(
              color: currentFolder.color,
              fontWeight: FontWeight.bold,
            ),
          ),
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
}