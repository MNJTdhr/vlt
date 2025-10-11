// lib/pages/photo_view_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

import 'package:vlt/data/notifiers.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';

class PhotoViewPage extends StatefulWidget {
  final List<VaultFile> files;
  final int initialIndex;
  final VaultFolder parentFolder;

  const PhotoViewPage({
    super.key,
    required this.files,
    required this.initialIndex,
    required this.parentFolder,
  });

  @override
  State<PhotoViewPage> createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();

    // ✅ Clamp the index safely in case list is empty or shorter than expected
    _currentIndex = widget.files.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.files.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Prevent crash if no files
    if (widget.files.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No files to display',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ✅ Main PageView with safe itemCount
          PageView.builder(
            controller: _pageController,
            itemCount: widget.files.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final vaultFile = widget.files[index];

              return FutureBuilder<Directory?>(
                future: StorageHelper.findFolderDirectoryById(
                  widget.parentFolder.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
                    final filePath = p.join(snapshot.data!.path, vaultFile.id);
                    final file = File(filePath);

                    return GestureDetector(
                      onTap: _toggleUIVisibility,
                      child: InteractiveViewer(
                        child: file.existsSync()
                            ? Image.file(
                                file,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 60)),
                              )
                            : const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white, size: 60),
                              ),
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              );
            },
          ),

          // ✅ Top + bottom UI overlays (animated)
          AnimatedOpacity(
            opacity: _showUI ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showUI,
              child: Column(
                children: [
                  _buildAppBar(),
                  const Spacer(),
                  _buildBottomAppBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleUIVisibility() {
    setState(() => _showUI = !_showUI);
  }

  AppBar _buildAppBar() {
    final vaultFile = widget.files[_currentIndex];

    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.5),
      foregroundColor: Colors.white,
      title: Text(
        vaultFile.fileName,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: _showInfoSheet,
          tooltip: 'Details',
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: _shareCurrentFile,
          tooltip: 'Share',
        ),
        IconButton(
          icon: const Icon(Icons.recycling),
          onPressed: _moveCurrentFileToRecycleBin,
          tooltip: 'Recycle Bin',
        ),
      ],
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      color: Colors.black.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Center(
          child: Text(
            '${_currentIndex + 1} / ${widget.files.length}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }

  // 🗑️ Move file to recycle bin
  Future<void> _moveCurrentFileToRecycleBin() async {
    final currentFile = widget.files[_currentIndex];
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Recycle Bin'),
        content: Text(
          'Are you sure you want to move "${currentFile.fileName}" to the recycle bin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await StorageHelper.moveFileToRecycleBin(
        currentFile,
        widget.parentFolder,
      );
      await refreshItemCounts();
      if (mounted) Navigator.pop(context);
    }
  }

  // 📤 Share file
  Future<void> _shareCurrentFile() async {
    final vaultFile = widget.files[_currentIndex];
    final folderDir =
        await StorageHelper.findFolderDirectoryById(widget.parentFolder.id);
    if (folderDir == null) return;

    final filePath = p.join(folderDir.path, vaultFile.id);
    final file = XFile(filePath);
    await Share.shareXFiles([file]);
  }

  // 🧾 Show info sheet
  void _showInfoSheet() async {
    final vaultFile = widget.files[_currentIndex];
    final folderDir =
        await StorageHelper.findFolderDirectoryById(widget.parentFolder.id);
    if (folderDir == null) return;

    final file = File(p.join(folderDir.path, vaultFile.id));
    if (!await file.exists()) return;

    final fileStat = await file.stat();
    final decodedImage = img.decodeImage(await file.readAsBytes());

    final fileSize = NumberFormat.compact().format(fileStat.size);
    final dimensions = decodedImage != null
        ? '${decodedImage.width} × ${decodedImage.height}'
        : 'N/A';
    final dateAdded = DateFormat.yMMMd().add_jm().format(vaultFile.dateAdded);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vaultFile.fileName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16)),
              const Divider(height: 24, color: Colors.white30),
              Text('Path: /${widget.parentFolder.name}'),
              Text('Original Path: ${vaultFile.originalPath}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text('Size: $fileSize'),
              Text('Dimensions: $dimensions'),
              Text('Date Added: $dateAdded'),
            ],
          ),
        ),
      ),
    );
  }
}
