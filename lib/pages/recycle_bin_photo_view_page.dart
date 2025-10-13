// lib/pages/recycle_bin_photo_view_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class RecycleBinPhotoViewPage extends StatefulWidget {
  final List<VaultFile> files;
  final int initialIndex;

  const RecycleBinPhotoViewPage({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  @override
  State<RecycleBinPhotoViewPage> createState() => _RecycleBinPhotoViewPageState();
}

class _RecycleBinPhotoViewPageState extends State<RecycleBinPhotoViewPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;
  bool _isZoomed = false;

  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });

    _transformationController.addListener(() {
      final scale = _transformationController.value.getMaxScaleOnAxis();
      if (_isZoomed && scale < 1.05) {
        setState(() => _isZoomed = false);
      } else if (!_isZoomed && scale > 1.05) {
        setState(() => _isZoomed = true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleUIVisibility() => setState(() => _showUI = !_showUI);

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _handleDoubleTap() {
    final position = _doubleTapPosition;
    if (position == null) return;

    final targetScale =
        _transformationController.value.getMaxScaleOnAxis() > 1.1 ? 1.0 : 2.0;

    final begin = _transformationController.value;
    final end = Matrix4.identity();

    if (targetScale != 1.0) {
      end.translate(-position.dx * (targetScale - 1),
          -position.dy * (targetScale - 1));
      end.scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurvedAnimation(parent: _zoomAnimationController, curve: Curves.easeOut),
    );
    _zoomAnimationController.forward(from: 0);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity > 300) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            PageView.builder(
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              controller: _pageController,
              itemCount: widget.files.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _transformationController.value = Matrix4.identity();
                  _isZoomed = false;
                });
              },
              itemBuilder: (context, index) {
                final vaultFile = widget.files[index];
                return FutureBuilder<Directory>(
                  future: StorageHelper.getRecycleBinDirectory(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      final filePath = p.join(snapshot.data!.path, vaultFile.id);
                      final file = File(filePath);

                      if (!file.existsSync()) {
                        return const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white, size: 60),
                        );
                      }

                      return GestureDetector(
                        onTap: _toggleUIVisibility,
                        onDoubleTapDown: _handleDoubleTapDown,
                        onDoubleTap: _handleDoubleTap,
                        onVerticalDragEnd:
                            _isZoomed ? null : _handleVerticalDragEnd,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 1.0,
                            maxScale: 4.0,
                            boundaryMargin: EdgeInsets.zero,
                            child: Image.file(
                              file,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white, size: 60),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return const Center(child: CircularProgressIndicator());
                  },
                );
              },
            ),

            // Overlay UI
            AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showUI,
                child: Column(
                  children: [
                    _buildAppBar(),
                    const Spacer(),
                    _buildBottomToolbar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    final vaultFile = widget.files[_currentIndex];
    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.5),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: BackButton(color: Colors.white),
      title: Text(vaultFile.fileName, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildBottomToolbar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomAction(Icons.restore, 'Restore', _restoreCurrentFile),
            _buildBottomAction(
              Icons.delete_forever,
              'Delete',
              _deleteCurrentFilePermanently,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onPressed,
      {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _restoreCurrentFile() async {
    final currentFile = widget.files[_currentIndex];
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore File'),
        content:
            Text('Do you want to restore "${currentFile.fileName}" to its folder?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // ✨ MODIFIED: Call the updated database method
      await StorageHelper.restoreFileFromRecycleBin(currentFile);
      await refreshItemCounts();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deleteCurrentFilePermanently() async {
    final currentFile = widget.files[_currentIndex];
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text(
            'Do you want to permanently delete "${currentFile.fileName}"? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await StorageHelper.permanentlyDeleteFile(currentFile);
      await refreshItemCounts(); // Although the item is gone, parent counts might need refresh.
      if (mounted) Navigator.of(context).pop();
    }
  }
}