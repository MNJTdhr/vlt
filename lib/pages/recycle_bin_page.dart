import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:path/path.dart' as p;

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

  @override
  void initState() {
    super.initState();
    _loadRecycledFiles();
  }

  Future<void> _loadRecycledFiles() async {
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItems.clear();
    });
  }

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
      // In the future, you could open a preview here.
    }
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
        content: Text('Are you sure you want to restore ${_selectedItems.length} selected item(s)?'),
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
        // ✨ FIX: Pass the full folder list to the helper function.
        await StorageHelper.restoreFileFromRecycleBin(file, foldersNotifier.value);
      }
      
      await refreshItemCounts();
      _toggleSelectionMode(); // Exit selection mode
      await _loadRecycledFiles(); // Refresh the list
    }
  }

  Future<void> _deleteSelectedFilesPermanently() async {
    if (_selectedItems.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text('Are you sure you want to permanently delete ${_selectedItems.length} selected item(s)? This action cannot be undone.'),
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
      _toggleSelectionMode(); // Exit selection mode
      await _loadRecycledFiles(); // Refresh the list
    }
  }
  
  Future<void> _deleteAllPermanently() async {
     final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Recycle Bin'),
        content: const Text('Are you sure you want to permanently delete every item in the recycle bin? This action cannot be undone.'),
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
              ? const Center(child: Text('Recycle bin is empty.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
       bottomNavigationBar: _isSelectionMode && _selectedItems.isNotEmpty ? _buildBottomActionBar() : null,
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
            _selectedItems.length == _recycledFiles.length ? 'DESELECT ALL' : 'SELECT ALL',
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(VaultFile file, bool isSelected) {
    return GestureDetector(
      onTap: () => _onItemTap(file),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // This is a placeholder for the thumbnail
          Container(
             color: Colors.grey.shade300,
             child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
          ),
          if (_isSelectionMode)
            Container(
              color: isSelected ? Colors.black.withOpacity(0.5) : Colors.transparent,
              child: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.white)
                  : const Icon(Icons.radio_button_unchecked, color: Colors.white70),
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
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: _deleteSelectedFilesPermanently,
          ),
        ],
      ),
    );
  }
}
