// lib/pages/folder_view_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:vlt/pages/photo_view_page.dart';
import 'package:vlt/pages/video_view_page.dart';
import 'package:vlt/widgets/file_transfer_sheet.dart';
import 'package:vlt/widgets/folder_card.dart';
import 'package:vlt/widgets/folder_creator_sheet.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/models/vault_folder.dart';

enum SortOption {
  dateNewest,
  dateOldest,
  nameAZ,
  nameZA,
  sizeLargest,
  sizeSmallest,
}

class FolderViewPage extends StatefulWidget {
  final VaultFolder folder;
  const FolderViewPage({super.key, required this.folder});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage>
    with TickerProviderStateMixin {
  late VaultFolder currentFolder;
  List<File> folderFiles = [];
  List<VaultFile> _vaultFiles = [];

  late AnimationController _fabAnimationController;
  late AnimationController _loadingController;
  bool isFabMenuOpen = false;
  bool _isLoading = true;

  // State to manage the current sort order.
  SortOption _currentSortOption = SortOption.dateNewest;

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
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    foldersNotifier.addListener(_onFoldersChanged);
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadSortPreference();
    await _loadAllFolderContents();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _loadingController.dispose();
    foldersNotifier.removeListener(_onFoldersChanged);
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

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sort_order_${widget.folder.id}';
    final savedIndex = prefs.getInt(key);
    if (savedIndex != null && savedIndex < SortOption.values.length) {
      if (mounted) {
        setState(() {
          _currentSortOption = SortOption.values[savedIndex];
        });
      }
    }
  }

  Future<void> _saveSortPreference(SortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'sort_order_${widget.folder.id}';
    await prefs.setInt(key, option.index);
  }

  Future<void> _applySorting() async {
    if (_currentSortOption == SortOption.sizeLargest ||
        _currentSortOption == SortOption.sizeSmallest) {
      final Map<String, int> fileSizes = {};
      for (final file in folderFiles) {
        try {
          final stat = await file.stat();
          fileSizes[p.basename(file.path)] = stat.size;
        } catch (e) {
          fileSizes[p.basename(file.path)] = 0;
        }
      }

      _vaultFiles.sort((a, b) {
        final sizeA = fileSizes[a.id] ?? 0;
        final sizeB = fileSizes[b.id] ?? 0;
        if (_currentSortOption == SortOption.sizeLargest) {
          return sizeB.compareTo(sizeA);
        } else {
          return sizeA.compareTo(sizeB);
        }
      });
    } else {
      _vaultFiles.sort((a, b) {
        switch (_currentSortOption) {
          case SortOption.dateNewest:
            return b.dateAdded.compareTo(a.dateAdded);
          case SortOption.dateOldest:
            return a.dateAdded.compareTo(b.dateAdded);
          case SortOption.nameAZ:
            return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
          case SortOption.nameZA:
            return b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase());
          default:
            return 0;
        }
      });
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAllFolderContents() async {
    final physicalFilesResult =
        await StorageHelper.getFolderContents(currentFolder);
    List<VaultFile> fileMetadata =
        await StorageHelper.getFilesForFolder(currentFolder);

    bool needsUiRefresh = false;

    // --- Self-Healing Logic ---
    final physicalFileNames =
        physicalFilesResult.map((f) => p.basename(f.path)).toSet();
    final metadataFileIds = fileMetadata.map((mf) => mf.id).toSet();

    // 1. Find orphan files
    final orphanFiles = physicalFileNames.difference(metadataFileIds);
    if (orphanFiles.isNotEmpty) {
      needsUiRefresh = true;
      for (final fileName in orphanFiles) {
        final newRecord = VaultFile(
          id: fileName,
          fileName: 'recovered_file',
          originalPath: 'unknown',
          dateAdded: DateTime.now(),
          originalParentPath: currentFolder.id,
        );
        await StorageHelper.addFileRecord(newRecord);
        fileMetadata.add(newRecord);
      }
    }

    // 2. Find ghost records
    final ghostRecordIds = metadataFileIds.difference(physicalFileNames);
    if (ghostRecordIds.isNotEmpty) {
      needsUiRefresh = true;
      for (final fileId in ghostRecordIds) {
        await StorageHelper.deleteFileRecord(fileId);
      }
      fileMetadata.removeWhere((mf) => ghostRecordIds.contains(mf.id));
    }

    if (needsUiRefresh) {
      await refreshItemCounts();
    }

    if (mounted) {
      setState(() {
        folderFiles = physicalFilesResult;
        _vaultFiles = fileMetadata;
        _isLoading = false;
      });
      // Apply initial sort after loading.
      await _applySorting();
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
      permissionGranted = await Permission.photos.request().isGranted ||
          await Permission.storage.request().isGranted;
    } else if (type == FileType.video) {
      permissionGranted = await Permission.videos.request().isGranted ||
          await Permission.storage.request().isGranted;
    } else {
      permissionGranted =
          await Permission.manageExternalStorage.request().isGranted;
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
      final itemWidth =
          (renderBox.size.width - (crossAxisSpacing * (crossAxisCount - 1))) /
              crossAxisCount;
      final itemHeight = itemWidth / childAspectRatio;

      final col = (localPos.dx / (itemWidth + crossAxisSpacing))
          .floor()
          .clamp(0, crossAxisCount - 1);
      final row = (localPos.dy / (itemHeight + mainAxisSpacing)).floor();

      final index = (row * crossAxisCount) + col;
      final globalIndex = baseIndex + index;

      if (index >= 0 &&
          index < items.length &&
          globalIndex != _lastDraggedIndex) {
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

  // ✨ MODIFIED: Centralized logic to navigate to the correct media viewer with the unified playlist.
  Future<void> _navigateToMediaViewer({required VaultFile tappedFile}) async {
    final bool isImage = _isImage(tappedFile.id);

    // Get all media of the correct type and split them into two sorted lists.
    final allMediaOfType = _vaultFiles.where((f) {
      return isImage ? _isImage(f.id) : _isVideo(f.id);
    }).toList();
    final favoriteMedia = allMediaOfType.where((f) => f.isFavorite).toList();
    final otherMedia = allMediaOfType.where((f) => !f.isFavorite).toList();

    // The playlist is ALWAYS the same: favorites first, then others.
    final List<VaultFile> playlist = [...favoriteMedia, ...otherMedia];

    // The initial index is just the position of the tapped file in this combined list.
    final int initialIndex = playlist.indexWhere((f) => f.id == tappedFile.id);

    if (initialIndex == -1 || !mounted) return;

    if (isImage) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoViewPage(
            files: playlist,
            initialIndex: initialIndex,
            parentFolder: currentFolder,
          ),
        ),
      );
    } else { // It's a video
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoViewPage(
            files: playlist,
            initialIndex: initialIndex,
            parentFolder: currentFolder,
          ),
        ),
      );
    }

    // Refresh content after returning from the viewer in case of changes
    await _loadAllFolderContents();
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
        appBar:
            _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
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
                            Icon(Icons.folder_open,
                                size: 64, color: currentFolder.color),
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
                          if (subfolders.isNotEmpty)
                            _buildFolderGrid(subfolders, _folderGridKey),
                          if (subfolders.isNotEmpty &&
                              (favoriteFiles.isNotEmpty ||
                                  otherFiles.isNotEmpty))
                            _buildDivider(),
                          if (favoriteFiles.isNotEmpty)
                            _buildFileGrid(favoriteFiles,
                                subfolders.isEmpty, _favoriteFileGridKey),
                          if (favoriteFiles.isNotEmpty &&
                              otherFiles.isNotEmpty)
                            _buildDivider(),
                          if (otherFiles.isNotEmpty)
                            _buildFileGrid(
                                otherFiles,
                                subfolders.isEmpty && favoriteFiles.isEmpty,
                                _otherFileGridKey),
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
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary),
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

  // ✨ MODIFIED: Simplified the onTap logic to use the new helper function.
  Widget _buildFileGrid(
      List<VaultFile> files, bool addTopPadding, GlobalKey gridKey) {
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
                  await _navigateToMediaViewer(tappedFile: vaultFile);
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
                    child: _buildThumbnail(physicalFile, vaultFile.id),
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'select') {
                setState(() => _isSelectionMode = true);
              } else if (value == 'sort') {
                _showSortOptionsSheet();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'select',
                child: Text('Select items'),
              ),
              const PopupMenuItem<String>(
                value: 'sort',
                child: Text('Sort by...'),
              ),
            ],
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
  void _unhidePlaceholder() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Unhide coming soon!')));
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
        await StorageHelper.updateFileMetadata(updatedFile);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(markAsFavorite
                ? 'Added to favorites.'
                : 'Removed from favorites.')),
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
              content: Text(
                  'Folders cannot be transferred. Please select only files.')),
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

  void _showSortOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    title: Text(
                      'Sort by',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Date added (Newest first)'),
                    value: SortOption.dateNewest,
                    groupValue: _currentSortOption,
                    onChanged: (SortOption? value) async {
                      if (value != null) {
                        setModalState(() => _currentSortOption = value);
                        await _saveSortPreference(value);
                        await _applySorting();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Date added (Oldest first)'),
                    value: SortOption.dateOldest,
                    groupValue: _currentSortOption,
                    onChanged: (SortOption? value) async {
                      if (value != null) {
                        setModalState(() => _currentSortOption = value);
                        await _saveSortPreference(value);
                        await _applySorting();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Name (A-Z)'),
                    value: SortOption.nameAZ,
                    groupValue: _currentSortOption,
                    onChanged: (SortOption? value) async {
                      if (value != null) {
                        setModalState(() => _currentSortOption = value);
                        await _saveSortPreference(value);
                        await _applySorting();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Name (Z-A)'),
                    value: SortOption.nameZA,
                    groupValue: _currentSortOption,
                    onChanged: (SortOption? value) async {
                      if (value != null) {
                        setModalState(() => _currentSortOption = value);
                        await _saveSortPreference(value);
                        await _applySorting();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Size (Largest first)'),
                    value: SortOption.sizeLargest,
                    groupValue: _currentSortOption,
                    onChanged: (SortOption? value) async {
                      if (value != null) {
                        setModalState(() => _currentSortOption = value);
                        await _saveSortPreference(value);
                        await _applySorting();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Size (Smallest first)'),
                    value: SortOption.sizeSmallest,
                    groupValue: _currentSortOption,
                    onChanged: (SortOption? value) async {
                      if (value != null) {
                        setModalState(() => _currentSortOption = value);
                        await _saveSortPreference(value);
                        await _applySorting();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Thumbnail helpers ---

  Future<Uint8List?> _generateVideoThumbnail(
      String videoPath, String fileId) async {
    final tempDir = await getTemporaryDirectory();
    final cacheFile = File(p.join(tempDir.path, 'thumbnails', '$fileId.jpg'));

    if (await cacheFile.exists()) {
      return await cacheFile.readAsBytes();
    }

    try {
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: 2000,
        maxWidth: 200,
        quality: 50,
      );

      if (thumbnailBytes != null) {
        await cacheFile.parent.create(recursive: true);
        await cacheFile.writeAsBytes(thumbnailBytes);
        return thumbnailBytes;
      }
    } catch (e) {
      debugPrint('Failed to generate or cache thumbnail for $videoPath: $e');
    }
    return null;
  }

  Widget _buildThumbnail(File file, String fileId) {
    final path = file.path;
    if (_isImage(path)) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    } else if (_isVideo(path)) {
      return FutureBuilder<Uint8List?>(
        future: _generateVideoThumbnail(path, fileId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.data != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
                const Center(
                    child: Icon(Icons.play_circle,
                        color: Colors.white70, size: 36)),
              ],
            );
          }
          return Container(
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
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