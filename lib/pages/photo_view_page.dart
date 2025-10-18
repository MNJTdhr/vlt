// lib/pages/photo_view_page.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; // Needed for DragStartBehavior
import 'package:flutter/physics.dart'; // Needed for Simulation
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/widgets/file_transfer_sheet.dart';
import 'package:vlt/widgets/slideshow_options_sheet.dart';

/// Custom scroll physics that allows overriding the drag start distance threshold.
class CustomScrollPhysics extends AlwaysScrollableScrollPhysics {
  final double dragStartDistance;

  const CustomScrollPhysics({required this.dragStartDistance, super.parent});

  @override
  CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomScrollPhysics(
      dragStartDistance: dragStartDistance,
      parent: buildParent(ancestor),
    );
  }

  @override
  double get dragStartDistanceMotionThreshold => dragStartDistance;
}

/// Custom scroll physics that removes the ballistic (settling) animation.
class NoBallisticScrollPhysics extends CustomScrollPhysics {
  const NoBallisticScrollPhysics({
    required super.dragStartDistance,
    super.parent,
  });

  @override
  NoBallisticScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return NoBallisticScrollPhysics(
      dragStartDistance: dragStartDistance,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (velocity.abs() < kMinFlingVelocity) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

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

class _PhotoViewPageState extends State<PhotoViewPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;
  bool _isZoomed = false;
  late List<VaultFile> _updatableFiles;

  // Slideshow
  Timer? _slideshowTimer;
  bool _isSlideshowActive = false;
  Duration _slideshowTransitionDuration = const Duration(milliseconds: 400);
  bool _isSlideshowRandom = false;

  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  Offset? _doubleTapPosition;

  bool _isInitialLoad = true;

  Directory? _parentFolderDir;
  bool _folderReady = false;

  final Map<int, FileImage> _imageProviderCache = {};

  int _pointerCount = 0;

  // State for Undo functionality
  VaultFile? _lastDeletedFile;
  int? _lastDeletedIndex;
  Timer? _undoCommitTimer;

  @override
  void initState() {
    super.initState();

    _updatableFiles = List.from(widget.files);
    _currentIndex = _updatableFiles.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _updatableFiles.length - 1);

    _pageController = PageController(initialPage: _currentIndex);

    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformationController.value = _zoomAnimation!.value;
          }
        });

    _transformationController.addListener(() {
      final scale = _transformationController.value.getMaxScaleOnAxis();
      if (_isZoomed && scale < 1.1) {
        setState(() => _isZoomed = false);
      } else if (!_isZoomed && scale > 1.1) {
        setState(() => _isZoomed = true);
      }
    });

    _resolveFolderDirAndPrecache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      _isInitialLoad = false;
    }
  }

  Future<void> _resolveFolderDirAndPrecache() async {
    final dir = await StorageHelper.findFolderDirectoryById(
      widget.parentFolder.id,
    );
    if (!mounted) return;
    setState(() {
      _parentFolderDir = dir;
      _folderReady = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _precacheSurrounding(_currentIndex);
      }
    });
  }

  Future<void> _precacheSurrounding(int index) async {
    if (!_folderReady || _parentFolderDir == null || _updatableFiles.isEmpty)
      return;
    int lowerBound = max(0, index - 2);
    int upperBound = min(_updatableFiles.length - 1, index + 2);

    for (int i = lowerBound; i <= upperBound; i++) {
      if (i >= 0 && i < _updatableFiles.length) {
        _precacheImage(i);
      }
    }
  }

  Future<void> _precacheImage(int index) async {
    if (!mounted || index < 0 || index >= _updatableFiles.length) return;
    if (!_folderReady || _parentFolderDir == null) return;

    final vaultFile = _updatableFiles[index];
    final file = File(p.join(_parentFolderDir!.path, vaultFile.id));

    if (!await file.exists()) {
      _imageProviderCache.remove(index);
      return;
    }

    // Re-cache if not present or maybe if file changed (less likely needed)
    if (!_imageProviderCache.containsKey(index)) {
      final provider = FileImage(file);
      _imageProviderCache[index] = provider;

      try {
        if (mounted) {
          precacheImage(provider, context);
        }
      } catch (e) {
        debugPrint('Precache failed for ${file.path}: $e');
        _imageProviderCache.remove(index);
      }
    }
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    _imageProviderCache.clear();
    _undoCommitTimer?.cancel();
    super.dispose();
  }

  void _onViewTap() {
    if (_isSlideshowActive) {
      _stopSlideshow();
    } else {
      setState(() => _showUI = !_showUI);
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _handleDoubleTap() {
    if (_isSlideshowActive) return;
    final position = _doubleTapPosition;
    if (position == null) return;

    final targetScale =
        _transformationController.value.getMaxScaleOnAxis() > 1.1 ? 1.0 : 2.5;

    final begin = _transformationController.value;
    final end = Matrix4.identity();
    if (targetScale != 1.0) {
      end.translate(
        -position.dx * (targetScale - 1),
        -position.dy * (targetScale - 1),
      );
      end.scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurveTween(curve: Curves.easeOut).animate(_zoomAnimationController),
    );
    _zoomAnimationController.forward(from: 0);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isSlideshowActive) return;
    final velocity = details.primaryVelocity ?? 0.0;

    if (velocity > 300) {
      _cancelUndo();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_updatableFiles.isEmpty && _lastDeletedFile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    // Clamp index BEFORE building PageView
    _currentIndex = _currentIndex.clamp(0, max(0, _updatableFiles.length - 1));

    if (!_folderReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            _isSlideshowActive
                ? _buildSlideshowView()
                : _buildInteractiveView(),
            IgnorePointer(
              ignoring: !_showUI,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSlide(
                      offset: _showUI ? Offset.zero : const Offset(0, -1.5),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: _buildAppBar(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        offset: _showUI ? Offset.zero : const Offset(0, 1.5),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(ignoring: !_showUI, child: _buildBottomToolbar()),
      ),
    );
  }

  Widget _buildInteractiveView() {
    final itemCount = _updatableFiles.length;

    // Jump in callback if index is invalid AFTER build
    if (_pageController.hasClients &&
        _pageController.page != null &&
        _pageController.page! >= itemCount &&
        itemCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(itemCount - 1);
        }
      });
    }

    return Listener(
      onPointerDown: (_) => setState(() => _pointerCount++),
      onPointerUp: (_) => setState(() => _pointerCount--),
      onPointerCancel: (_) => setState(() => _pointerCount--),
      child: PageView.builder(
        // Use a Key based on itemCount to force rebuild when list changes.
        // Add lastDeletedFile presence to key ensures rebuild on undo start/finish.
        key: ValueKey(
          itemCount.toString() + (_lastDeletedFile != null).toString(),
        ),
        physics: (_isZoomed || _pointerCount > 1 || _lastDeletedFile != null)
            ? const NeverScrollableScrollPhysics()
            : const NoBallisticScrollPhysics(dragStartDistance: 15.0),
        controller: _pageController,
        itemCount: itemCount,
        onPageChanged: (index) {
          if (_lastDeletedFile != null) return;
          setState(() {
            _currentIndex = index;
            if (!_isZoomed) {
              _transformationController.value = Matrix4.identity();
            }
            _isZoomed = false;
          });
          _precacheSurrounding(index);
        },
        itemBuilder: (context, index) {
          // This index should be correct due to PageView rebuild
          if (index >= _updatableFiles.length) {
            debugPrint(
              "ItemBuilder attempting to build invalid index $index / ${_updatableFiles.length}",
            );
            return Container(color: Colors.black);
          }
          final file = _updatableFiles[index];
          // Use index directly for cache key
          return _buildImagePage(file, index: index);
        },
      ),
    );
  }

  Widget _buildSlideshowView() {
    int displayIndex = _currentIndex;
    if (displayIndex >= _updatableFiles.length && _updatableFiles.isNotEmpty) {
      displayIndex = _updatableFiles.length - 1;
    } else if (_updatableFiles.isEmpty) {
      _stopSlideshow();
      return Container(color: Colors.black);
    }
    if (displayIndex < 0) return Container(color: Colors.black);

    return Center(
      child: AnimatedSwitcher(
        duration: _slideshowTransitionDuration,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildImagePage(
          _updatableFiles[displayIndex],
          key: ValueKey<String>(
            _updatableFiles[displayIndex].id + displayIndex.toString(),
          ),
          index: displayIndex,
        ),
      ),
    );
  }

  Widget _buildImagePage(VaultFile vaultFile, {Key? key, required int index}) {
    if (!_folderReady || _parentFolderDir == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final file = File(p.join(_parentFolderDir!.path, vaultFile.id));

    // Check existence. If missing, remove cache and show broken image.
    if (!file.existsSync()) {
      _imageProviderCache.remove(index);
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white, size: 60),
      );
    }

    // Get provider from cache or create+cache it. Use index as the key.
    final provider = _imageProviderCache.putIfAbsent(
      index,
      () => FileImage(file),
    );

    return GestureDetector(
      key: key, // Use the key passed down
      onTap: _onViewTap,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      onVerticalDragEnd: _isZoomed ? null : _handleVerticalDragEnd,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        child: RepaintBoundary(
          child: Image(
            image: provider,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              _imageProviderCache.remove(index); // Remove bad entry on error
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 60),
              );
            },
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    int displayIndex = _currentIndex;
    if (displayIndex >= _updatableFiles.length && _updatableFiles.isNotEmpty) {
      displayIndex = _updatableFiles.length - 1;
    } else if (_updatableFiles.isEmpty) {
      if (_lastDeletedFile != null && _lastDeletedIndex != null) {
        return AppBar(
          backgroundColor: Colors.black.withOpacity(0.5),
          foregroundColor: Colors.white,
          leading: BackButton(
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _lastDeletedFile!.fileName,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          actions: const [SizedBox(width: 48)],
        );
      } else {
        return AppBar(
          backgroundColor: Colors.black.withOpacity(0.5),
          leading: BackButton(
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
        );
      }
    }
    if (displayIndex < 0) {
      return AppBar(backgroundColor: Colors.black.withOpacity(0.5));
    }

    final vaultFile = _updatableFiles[displayIndex];
    final bool actionsEnabled = _lastDeletedFile == null;

    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.5),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: BackButton(
        color: Colors.white,
        onPressed: () {
          _stopSlideshow();
          _cancelUndo();
          Navigator.of(context).pop();
        },
      ),
      title: Text(vaultFile.fileName, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          icon: Icon(
            _isSlideshowActive
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline,
            color: (_updatableFiles.length <= 1 || !actionsEnabled)
                ? Colors.grey
                : Colors.white,
          ),
          tooltip: _isSlideshowActive ? 'Stop Slideshow' : 'Start Slideshow',
          onPressed: (_updatableFiles.length <= 1 || !actionsEnabled)
              ? null
              : () {
                  if (_isSlideshowActive) {
                    _stopSlideshow();
                  } else {
                    _showSlideshowOptions();
                  }
                },
        ),
        IconButton(
          icon: Icon(
            Icons.info_outline,
            color: actionsEnabled ? Colors.white : Colors.grey,
          ),
          tooltip: 'Details',
          onPressed: actionsEnabled ? _showInfoSheet : null,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildBottomToolbar() {
    int displayIndex = _currentIndex.clamp(
      0,
      max(0, _updatableFiles.length - 1),
    );

    VaultFile? currentFile;
    if (_lastDeletedFile != null &&
        _lastDeletedIndex == displayIndex &&
        _updatableFiles.isEmpty) {
      currentFile = _lastDeletedFile;
    } else if (displayIndex < _updatableFiles.length) {
      currentFile = _updatableFiles[displayIndex];
    }

    if (currentFile == null) return const SizedBox.shrink();

    return Container(
      color:
          Theme.of(context).bottomAppBarTheme.color ??
          Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 8,
      ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomAction(
            Icons.drive_file_move_outline,
            'Transfer',
            _showTransferSheet,
          ),
          _buildBottomAction(Icons.edit, 'Rename', _showRenameDialog),
          _buildBottomAction(
            Icons.delete,
            'Recycle',
            _moveCurrentFileToRecycleBin,
          ),
          _buildFavoriteButton(currentFile),
          _buildBottomAction(Icons.share_outlined, 'Share', _shareCurrentFile),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(VaultFile currentFile) {
    final bool enabled = _lastDeletedFile == null;
    final Color activeColor = currentFile.isFavorite
        ? Colors.red
        : Colors.white;
    final Color color = enabled ? activeColor : Colors.grey;
    final IconData icon = currentFile.isFavorite
        ? Icons.favorite
        : Icons.favorite_border;

    return GestureDetector(
      onTap: enabled ? _toggleFavorite : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text('Favourite', style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    final bool enabled = _lastDeletedFile == null;
    final Color color = enabled ? Colors.white : Colors.grey;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
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

  // --- Slideshow Functions ---
  Future<void> _showSlideshowOptions() async {
    if (_lastDeletedFile != null) return;
    final options = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const SlideshowOptionsSheet(),
    );

    if (options != null) {
      final interval = options['interval'] as double;
      final transition = options['transition'] as double;
      _isSlideshowRandom = options['random'] as bool;

      _startSlideshow(
        Duration(milliseconds: (interval * 1000).toInt()),
        Duration(milliseconds: (transition * 1000).toInt()),
      );
    }
  }

  void _startSlideshow(Duration interval, Duration transition) {
    if (_updatableFiles.length <= 1 || _lastDeletedFile != null) return;
    setState(() {
      _isSlideshowActive = true;
      _showUI = false;
      _slideshowTransitionDuration = transition;
      _transformationController.value = Matrix4.identity();
      _isZoomed = false;
    });

    _slideshowTimer = Timer.periodic(interval, (timer) {
      if (!mounted || !_isSlideshowActive) {
        timer.cancel();
        return;
      }
      if (_updatableFiles.length <= 1) {
        _stopSlideshow();
        return;
      }

      int nextIndex;
      if (_isSlideshowRandom) {
        final random = Random();
        do {
          nextIndex = random.nextInt(_updatableFiles.length);
        } while (nextIndex == _currentIndex);
      } else {
        nextIndex = (_currentIndex + 1) % _updatableFiles.length;
      }

      if (!_isSlideshowRandom) {
        _precacheImage(nextIndex + 1);
      }

      if (mounted) {
        setState(() {
          _currentIndex = nextIndex;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _stopSlideshow() {
    bool wasActive = _isSlideshowActive;
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    if (mounted && wasActive) {
      setState(() {
        _isSlideshowActive = false;
        _showUI = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        int safeIndex = _currentIndex.clamp(
          0,
          max(0, _updatableFiles.length - 1),
        );
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(safeIndex);
        }
      });
    }
  }

  // --- Other Action Methods ---
  void _unhidePlaceholder() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Unhide coming soon!')));

  Future<void> _showRenameDialog() async {
    if (_currentIndex >= _updatableFiles.length || _lastDeletedFile != null)
      return;
    _stopSlideshow();

    final currentFile = _updatableFiles[_currentIndex];
    final TextEditingController controller = TextEditingController(
      text: currentFile.fileName,
    );

    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename File'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmedName = controller.text.trim();
                if (trimmedName.isNotEmpty) {
                  Navigator.of(context).pop(trimmedName);
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName != currentFile.fileName && mounted) {
      final updatedFile = currentFile.copyWith(fileName: newName);

      setState(() {
        if (_currentIndex < _updatableFiles.length &&
            _updatableFiles[_currentIndex].id == currentFile.id) {
          _updatableFiles[_currentIndex] = updatedFile;
        }
      });

      await StorageHelper.updateFileMetadata(updatedFile);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File renamed to "$newName"')));
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentIndex >= _updatableFiles.length || _lastDeletedFile != null)
      return;
    _stopSlideshow();

    final currentFile = _updatableFiles[_currentIndex];
    final updatedFile = currentFile.copyWith(
      isFavorite: !currentFile.isFavorite,
    );

    setState(() {
      if (_currentIndex < _updatableFiles.length &&
          _updatableFiles[_currentIndex].id == currentFile.id) {
        _updatableFiles[_currentIndex] = updatedFile;
      }
    });

    await StorageHelper.updateFileMetadata(updatedFile);
  }

  Future<void> _showTransferSheet() async {
    if (_currentIndex >= _updatableFiles.length || _lastDeletedFile != null)
      return;
    _stopSlideshow();

    final currentFile = _updatableFiles[_currentIndex];
    final int indexToModify = _currentIndex;

    final VaultFolder? destinationFolder =
        await showModalBottomSheet<VaultFolder>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: FileTransferSheet(sourceFolder: widget.parentFolder),
          ),
        );

    if (destinationFolder != null && mounted) {
      await StorageHelper.transferFile(
        currentFile,
        widget.parentFolder,
        destinationFolder,
      );
      await refreshItemCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File transferred to "${destinationFolder.name}"'),
          ),
        );

        setState(() {
          if (indexToModify < _updatableFiles.length &&
              _updatableFiles[indexToModify].id == currentFile.id) {
            _updatableFiles.removeAt(indexToModify);
            _imageProviderCache.remove(indexToModify);
            if (_currentIndex >= _updatableFiles.length &&
                _updatableFiles.isNotEmpty) {
              _currentIndex = _updatableFiles.length - 1;
            }
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _updatableFiles.isEmpty) {
            Navigator.of(context).pop();
          } else if (mounted && _pageController.hasClients) {
            int safeIndex = _currentIndex.clamp(
              0,
              max(0, _updatableFiles.length - 1),
            );
            _pageController.jumpToPage(safeIndex);
            _precacheSurrounding(safeIndex);
          }
        });
      }
    }
  }

  Future<void> _moveCurrentFileToRecycleBin() async {
    if (_currentIndex >= _updatableFiles.length || _lastDeletedFile != null)
      return;
    _stopSlideshow();
    _cancelUndo();

    final currentFile = _updatableFiles[_currentIndex];
    final int indexToDelete = _currentIndex;

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

    if (confirmed != true || !mounted) return;

    final fileToDelete = _updatableFiles[indexToDelete];
    setState(() {
      _lastDeletedFile = fileToDelete;
      _lastDeletedIndex = indexToDelete;
      _updatableFiles.removeAt(indexToDelete);
      _imageProviderCache.remove(indexToDelete);

      if (_currentIndex >= _updatableFiles.length &&
          _updatableFiles.isNotEmpty) {
        _currentIndex = _updatableFiles.length - 1;
      }
    });

    StorageHelper.moveFileToRecycleBin(
      fileToDelete,
      widget.parentFolder,
    ).then((_) => refreshItemCounts());

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _updatableFiles.isEmpty) {
        Navigator.of(context).pop();
      } else if (mounted && _pageController.hasClients) {
        int safeIndex = _currentIndex.clamp(
          0,
          max(0, _updatableFiles.length - 1),
        );
        _pageController.jumpToPage(safeIndex);
        _precacheSurrounding(safeIndex);
      }
    });

    final snackBar = SnackBar(
      content: const Text('Moved to Recycle Bin'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          _undoDeletion();
        },
      ),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar).closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        _commitDeletion();
      }
    });

    _undoCommitTimer = Timer(const Duration(seconds: 4), () {
      _commitDeletion();
    });
  }

  // ✨ MODIFIED: Changed jumpToPage to animateToPage and clear cache
  Future<void> _undoDeletion() async {
    _undoCommitTimer?.cancel();
    _undoCommitTimer = null;
    if (!mounted || _lastDeletedFile == null || _lastDeletedIndex == null)
      return;

    final fileToRestore = _lastDeletedFile!;
    final originalIndex = _lastDeletedIndex!;

    // Clear undo state first
    setState(() {
      _lastDeletedFile = null;
      _lastDeletedIndex = null;
    });

    // Restore file in background
    await StorageHelper.restoreFileFromRecycleBin(fileToRestore);
    await refreshItemCounts();

    if (!mounted) return;

    // Re-insert, update index, and clear cache entry in setState
    setState(() {
      final insertIndex = originalIndex.clamp(0, _updatableFiles.length);
      _updatableFiles.insert(insertIndex, fileToRestore);
      _currentIndex = insertIndex;
      // ✨ ADDED: Clear cache for the restored index to force reload
      _imageProviderCache.remove(_currentIndex);
    });

    // Animate PageView back *after* UI rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _precacheSurrounding(_currentIndex);
      }
    });
  }

  void _commitDeletion() {
    _undoCommitTimer?.cancel();
    _undoCommitTimer = null;
    if (mounted && _lastDeletedFile != null) {
      setState(() {
        _lastDeletedFile = null;
        _lastDeletedIndex = null;
      });
      debugPrint("Deletion committed (Undo timeout or SnackBar dismissed)");
    }
  }

  void _cancelUndo() {
    _undoCommitTimer?.cancel();
    _undoCommitTimer = null;
    if (_lastDeletedFile != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          _lastDeletedFile = null;
          _lastDeletedIndex = null;
        });
      }
    }
  }

  Future<void> _shareCurrentFile() async {
    if (_currentIndex >= _updatableFiles.length || _lastDeletedFile != null)
      return;
    _stopSlideshow();

    final vaultFile = _updatableFiles[_currentIndex];
    if (!_folderReady || _parentFolderDir == null) return;

    final filePath = p.join(_parentFolderDir!.path, vaultFile.id);
    try {
      final file = XFile(filePath);
      await Share.shareXFiles([file]);
    } catch (e) {
      debugPrint("Error sharing file: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not share file.')));
      }
    }
  }

  void _showInfoSheet() async {
    if (_currentIndex >= _updatableFiles.length || _lastDeletedFile != null)
      return;
    _stopSlideshow();

    final vaultFile = _updatableFiles[_currentIndex];
    if (!_folderReady || _parentFolderDir == null) return;

    final file = File(p.join(_parentFolderDir!.path, vaultFile.id));
    if (!await file.exists()) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File not found.')));
      return;
    }

    String fileSize = 'N/A';
    try {
      final fileStat = await file.stat();
      fileSize = NumberFormat.compact().format(fileStat.size);
    } catch (e) {
      debugPrint("Error getting file size: $e");
    }

    final dateAdded = DateFormat.yMMMd().add_jm().format(vaultFile.dateAdded);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        vaultFile.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showRenameDialog();
                      },
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      tooltip: 'Rename',
                    ),
                  ],
                ),
                const Divider(height: 20, color: Colors.white24),
                const SizedBox(height: 6),
                _infoRow('Path:', '/${widget.parentFolder.name}'),
                _infoRow('Original Path:', vaultFile.originalPath),
                _infoRow('File Size:', fileSize),
                _AsyncDimensionsRow(imageFile: file),
                _infoRow('Date Added:', dateAdded),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AsyncDimensionsRow extends StatefulWidget {
  final File imageFile;

  const _AsyncDimensionsRow({required this.imageFile});

  @override
  State<_AsyncDimensionsRow> createState() => _AsyncDimensionsRowState();
}

class _AsyncDimensionsRowState extends State<_AsyncDimensionsRow> {
  String _dimensions = 'Loading...';

  @override
  void initState() {
    super.initState();
    _getDimensions();
  }

  Future<void> _getDimensions() async {
    if (!await widget.imageFile.exists()) {
      if (mounted) setState(() => _dimensions = 'File missing');
      return;
    }

    try {
      if (await widget.imageFile.length() == 0) {
        if (mounted) setState(() => _dimensions = 'Empty file');
        return;
      }

      final bytes = await widget.imageFile.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) setState(() => _dimensions = 'Empty file data');
        return;
      }

      final decodedImage = await compute(img.decodeImage, bytes);

      if (mounted && decodedImage != null) {
        setState(() {
          _dimensions = '${decodedImage.width} × ${decodedImage.height}';
        });
      } else if (mounted) {
        setState(() {
          _dimensions = 'Invalid format';
        });
      }
    } catch (e) {
      debugPrint('Error decoding image for dimensions: $e');
      if (mounted) {
        setState(() {
          _dimensions = 'Error decoding';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'Dimensions:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _dimensions,
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
