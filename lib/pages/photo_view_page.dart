// lib/pages/photo_view_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/widgets/file_transfer_sheet.dart';
import 'package:vlt/widgets/slideshow_options_sheet.dart';

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

  // State variables for slideshow functionality
  Timer? _slideshowTimer;
  bool _isSlideshowActive = false;
  Duration _slideshowTransitionDuration = const Duration(milliseconds: 400);
  bool _isSlideshowRandom = false;


  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();

    _updatableFiles = List.from(widget.files);

    _currentIndex = _updatableFiles.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _updatableFiles.length - 1);
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
      if (_isZoomed && scale < 1.1) {
        setState(() => _isZoomed = false);
      } else if (!_isZoomed && scale > 1.1) {
        setState(() => _isZoomed = true);
      }
    });
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
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
      end.translate(-position.dx * (targetScale - 1),
          -position.dy * (targetScale - 1));
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
    if (velocity < -300) {
      _showInfoSheet();
    } else if (velocity > 300) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_updatableFiles.isEmpty) {
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
            _isSlideshowActive
                ? _buildSlideshowView()
                : _buildInteractiveView(),

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
  
  /// The standard interactive PageView for manual swiping and zooming.
  Widget _buildInteractiveView() {
    return PageView.builder(
      physics: _isZoomed
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      controller: _pageController,
      itemCount: _updatableFiles.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _transformationController.value = Matrix4.identity();
        });
      },
      itemBuilder: (context, index) {
        return _buildImagePage(_updatableFiles[index]);
      },
    );
  }
  
  /// A view for the automated slideshow with fade transitions.
  Widget _buildSlideshowView() {
    // ✨ FIX: Wrap the AnimatedSwitcher in a Center widget.
    return Center(
      child: AnimatedSwitcher(
        duration: _slideshowTransitionDuration,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildImagePage(
          _updatableFiles[_currentIndex],
          key: ValueKey<String>(_updatableFiles[_currentIndex].id),
        ),
      ),
    );
  }

  /// A reusable function to build the content of a single page (image).
  Widget _buildImagePage(VaultFile vaultFile, {Key? key}) {
    return FutureBuilder<Directory?>(
      key: key,
      future: StorageHelper.findFolderDirectoryById(vaultFile.originalParentPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          final filePath = p.join(snapshot.data!.path, vaultFile.id);
          final file = File(filePath);

          if (!file.existsSync()) {
            return const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 60));
          }

          return GestureDetector(
            onTap: _onViewTap,
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            onVerticalDragEnd: _handleVerticalDragEnd,
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 60),
                  ),
                ),
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  AppBar _buildAppBar() {
    final vaultFile = _updatableFiles[_currentIndex];
    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.5),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: BackButton(
        color: Colors.white,
        onPressed: () {
          _stopSlideshow();
          Navigator.of(context).pop();
        },
      ),
      title: Text(vaultFile.fileName, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          icon: Icon(_isSlideshowActive
              ? Icons.stop_circle_outlined
              : Icons.play_circle_outline),
          tooltip: _isSlideshowActive ? 'Stop Slideshow' : 'Start Slideshow',
          onPressed: () {
            if (_isSlideshowActive) {
              _stopSlideshow();
            } else {
              _showSlideshowOptions();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Details',
          onPressed: _showInfoSheet,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildBottomToolbar() {
    final currentFile = _updatableFiles[_currentIndex];
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomAction(Icons.lock_open, 'Unhide', _unhidePlaceholder),
            _buildBottomAction(
                Icons.drive_file_move_outline, 'Transfer', _showTransferSheet),
            _buildBottomAction(
                Icons.delete, 'Recycle', _moveCurrentFileToRecycleBin),
            _buildFavoriteButton(currentFile),
            _buildBottomAction(
                Icons.share_outlined, 'Share', _shareCurrentFile),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(VaultFile currentFile) {
    return GestureDetector(
      onTap: _toggleFavorite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            currentFile.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: currentFile.isFavorite ? Colors.red : Colors.white,
          ),
          const SizedBox(height: 6),
          Text(
            'Favourite',
            style: TextStyle(
              color: currentFile.isFavorite ? Colors.red : Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
  
  // --- Slideshow Functions ---

  Future<void> _showSlideshowOptions() async {
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
    setState(() {
      _isSlideshowActive = true;
      _showUI = false;
      _slideshowTransitionDuration = transition;
    });

    _slideshowTimer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      int nextIndex;
      if (_isSlideshowRandom) {
        if (_updatableFiles.length <= 1) return;
        final random = Random();
        do {
          nextIndex = random.nextInt(_updatableFiles.length);
        } while (nextIndex == _currentIndex);
      } else {
        nextIndex = (_currentIndex + 1) % _updatableFiles.length; // Loop back
      }
      
      setState(() {
        _currentIndex = nextIndex;
      });
    });
  }

  void _stopSlideshow() {
    _slideshowTimer?.cancel();
    if (mounted && _isSlideshowActive) {
      setState(() {
        _isSlideshowActive = false;
        _showUI = true;
        _pageController.jumpToPage(_currentIndex);
      });
    }
  }

  // --- Other Action Methods ---

  void _unhidePlaceholder() =>
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unhide coming soon!'),
      ));

  Future<void> _toggleFavorite() async {
    final currentFile = _updatableFiles[_currentIndex];
    final updatedFile = currentFile.copyWith(isFavorite: !currentFile.isFavorite);

    setState(() {
      _updatableFiles[_currentIndex] = updatedFile;
    });

    await StorageHelper.updateFileMetadata(updatedFile, widget.parentFolder);
  }

  Future<void> _showTransferSheet() async {
    _stopSlideshow();
    final currentFile = _updatableFiles[_currentIndex];

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
              content: Text('File transferred to "${destinationFolder.name}"')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _moveCurrentFileToRecycleBin() async {
    _stopSlideshow();
    final currentFile = _updatableFiles[_currentIndex];
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Recycle Bin'),
        content: Text(
            'Are you sure you want to move "${currentFile.fileName}" to the recycle bin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await StorageHelper.moveFileToRecycleBin(currentFile, widget.parentFolder);
      await refreshItemCounts();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _shareCurrentFile() async {
    _stopSlideshow();
    final vaultFile = _updatableFiles[_currentIndex];
    final folderDir =
        await StorageHelper.findFolderDirectoryById(widget.parentFolder.id);
    if (folderDir == null) return;
    final filePath = p.join(folderDir.path, vaultFile.id);
    final file = XFile(filePath);
    await Share.shareXFiles([file]);
  }

  void _showInfoSheet() async {
    _stopSlideshow();
    final vaultFile = _updatableFiles[_currentIndex];
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
                      child: Text(vaultFile.fileName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Action placeholder')),
                        );
                      },
                      icon: const Icon(Icons.copy, color: Colors.white70),
                    )
                  ],
                ),
                const Divider(height: 20, color: Colors.white24),
                const SizedBox(height: 6),
                _infoRow('Path:', '/${widget.parentFolder.name}'),
                _infoRow('Original Path:', vaultFile.originalPath),
                _infoRow('File Size:', fileSize),
                _infoRow('Dimensions:', dimensions),
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
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white70))),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
                maxLines: 3),
          ),
        ],
      ),
    );
  }
}