// lib/pages/recycle_bin_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:path/path.dart' as p;
import 'package:vlt/pages/recycle_bin_photo_view_page.dart'; // ✅ Added import

class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  List<VaultFile> _recycledFiles = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<VaultFile> _selectedItems = {};

  // ✨ NEW: State for drag-to-select gesture
  final GlobalKey _gridKey = GlobalKey();
  int? _lastDraggedIndex;
  bool _isDragSelecting = false; // ✅ Track whether a drag selection is in progress

  @override
  void initState() {
    super.initState();
    _loadRecycledFiles();
  }

  Future<void> _loadRecycledFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final files = await StorageHelper.loadRecycledFiles();
    if (mounted) {
      setState(() {
        _recycledFiles = files;
        _isLoading = false;
      });
    }
  }

  void _toggleSelectionMode({VaultFile? initialSelection}) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItems.clear();
      if (initialSelection != null && _isSelectionMode) {
        _selectedItems.add(initialSelection);
      }
    });
  }

  /// ✅ Modified to open RecycleBinPhotoViewPage
  void _onItemTap(VaultFile file) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedItems.contains(file)) {
          _selectedItems.remove(file);
        } else {
          _selectedItems.add(file);
        }
      });
    } else {
      final index = _recycledFiles.indexOf(file);
      Navigator.of(context)
          .push(MaterialPageRoute(
        builder: (context) => RecycleBinPhotoViewPage(
          files: _recycledFiles,
          initialIndex: index,
        ),
      ))
          .then((_) async {
        // Refresh list in case a file was restored or deleted
        await _loadRecycledFiles();
      });
    }
  }

  /// ✨ Handles the drag gesture to select multiple items after long-press.
  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isSelectionMode || !_isDragSelecting) return;

    final RenderBox? gridRenderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridRenderBox == null) return;

    final position = gridRenderBox.globalToLocal(details.globalPosition);

    // Calculate grid dimensions
    final crossAxisCount = 3;
    final gridWidth = gridRenderBox.size.width;
    final itemWidth = gridWidth / crossAxisCount;
    final itemHeight = itemWidth; // Assuming square items

    // Calculate which item is being hovered over
    final dx = position.dx.clamp(0, gridWidth - 1);
    final dy = position.dy.clamp(0, gridRenderBox.size.height - 1);
    final row = (dy / itemHeight).floor();
    final col = (dx / itemWidth).floor();
    final index = (row * crossAxisCount) + col;

    if (index >= 0 &&
        index < _recycledFiles.length &&
        index != _lastDraggedIndex) {
      final file = _recycledFiles[index];
      if (!_selectedItems.contains(file)) {
        setState(() {
          _selectedItems.add(file);
        });
      }
      _lastDraggedIndex = index;
    }
  }

  void _onDragEnd([DragEndDetails? details]) {
    _lastDraggedIndex = null;
    _isDragSelecting = false;
  }

  void _selectAll() {
    setState(() {
      if (_selectedItems.length == _recycledFiles.length) {
        _selectedItems.clear();
      } else {
        _selectedItems.addAll(_recycledFiles);
      }
    });
  }

  Future<void> _restoreSelectedFiles() async {
    if (_selectedItems.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Items'),
        content: Text(
            'Are you sure you want to restore ${_selectedItems.length} selected item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      for (final file in _selectedItems) {
        await StorageHelper.restoreFileFromRecycleBin(
            file, foldersNotifier.value);
      }

      await refreshItemCounts();
      _toggleSelectionMode();
      await _loadRecycledFiles();
    }
  }

  Future<void> _deleteSelectedFilesPermanently() async {
    if (_selectedItems.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text(
            'Are you sure you want to permanently delete ${_selectedItems.length} selected item(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final file in _selectedItems) {
        await StorageHelper.permanentlyDeleteFile(file);
      }
      _toggleSelectionMode();
      await _loadRecycledFiles();
    }
  }

  Future<void> _deleteAllPermanently() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Recycle Bin'),
        content: const Text(
            'Are you sure you want to permanently delete every item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageHelper.permanentlyDeleteAllRecycledFiles();
      await _loadRecycledFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recycledFiles.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.recycling, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Recycle bin is empty.'),
                    ],
                  ),
                )
              : Listener(
                  onPointerUp: (_) => _onDragEnd(),
                  child: GestureDetector(
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: _onDragEnd,
                    child: GridView.builder(
                      key: _gridKey,
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _recycledFiles.length,
                      itemBuilder: (context, index) {
                        final file = _recycledFiles[index];
                        final isSelected = _selectedItems.contains(file);
                        return _buildGridItem(file, isSelected);
                      },
                    ),
                  ),
                ),
      bottomNavigationBar:
          _isSelectionMode && _selectedItems.isNotEmpty ? _buildBottomActionBar() : null,
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('Recycle Bin'),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_note),
          tooltip: 'Select Items',
          onPressed: _recycledFiles.isNotEmpty ? _toggleSelectionMode : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_forever),
          tooltip: 'Empty Recycle Bin',
          onPressed: _recycledFiles.isNotEmpty ? _deleteAllPermanently : null,
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
      title: Text('${_selectedItems.length} / ${_recycledFiles.length}'),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: _selectAll,
          child: Text(
            _selectedItems.length == _recycledFiles.length
                ? 'DESELECT ALL'
                : 'SELECT ALL',
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(VaultFile file, bool isSelected) {
    return GestureDetector(
      onTap: () => _onItemTap(file),
      onLongPressStart: (_) {
        // ✅ Long-press starts selection mode and enables drag-select
        if (!_isSelectionMode) {
          _toggleSelectionMode(initialSelection: file);
        } else {
          setState(() {
            _selectedItems.add(file);
          });
        }
        _isDragSelecting = true;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Directory>(
            future: StorageHelper.getRecycleBinDirectory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                final filePath = p.join(snapshot.data!.path, file.id);
                return _buildThumbnail(File(filePath));
              }
              return Container(color: Colors.grey.shade300);
            },
          ),
          if (_isSelectionMode)
            Container(
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.5)
                  : Colors.black.withOpacity(0.3),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
            onPressed: _restoreSelectedFiles,
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _deleteSelectedFilesPermanently,
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(File file) {
    final path = file.path;
    if (_isImage(path)) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.image_not_supported,
              color: Colors.grey, size: 40),
        ),
      );
    } else if (_isVideo(path)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black12),
          const Center(
              child: Icon(Icons.play_circle, color: Colors.white, size: 36)),
        ],
      );
    } else {
      return Container(
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Icon(
          Icons.insert_drive_file,
          size: 40,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
  }

  bool _isImage(String path) =>
      ['.jpg', '.jpeg', '.png', '.gif', '.webp']
          .contains(p.extension(path).toLowerCase());

  bool _isVideo(String path) =>
      ['.mp4', '.mov', '.avi', '.mkv']
          .contains(p.extension(path).toLowerCase());
}
