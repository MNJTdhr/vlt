// lib/pages/photo_view_page.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  // Cached folder directory (resolved once)
  Directory? _parentFolderDir;
  bool _folderReady = false;

  // Cache for FileImages to avoid recreating providers
  final Map<int, FileImage> _imageProviderCache = {};

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

    // Resolve the parent folder directory and begin precaching
    _resolveFolderDirAndPrecache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      // Additional preloading handled after folder ready
      _isInitialLoad = false;
    }
  }

  Future<void> _resolveFolderDirAndPrecache() async {
    // Resolve once
    final dir = await StorageHelper.findFolderDirectoryById(widget.parentFolder.id);
    if (!mounted) return;
    setState(() {
      _parentFolderDir = dir;
      _folderReady = true;
    });

    // Precache current and neighbors after first frame so context is valid for precacheImage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheSurrounding(_currentIndex);
    });
  }

  Future<void> _precacheSurrounding(int index) async {
    if (!_folderReady || _parentFolderDir == null) return;
    // Precache current, +/-2
    for (int i = -2; i <= 2; i++) {
      _precacheImage(index + i);
    }
  }

  Future<void> _precacheImage(int index) async {
    if (index < 0 || index >= _updatableFiles.length) return;
    if (!_folderReady || _parentFolderDir == null) return;

    final vaultFile = _updatableFiles[index];
    final file = File(p.join(_parentFolderDir!.path, vaultFile.id));

    if (!await file.exists()) return;

    // Cache the FileImage for reuse
    final provider = FileImage(file);
    _imageProviderCache[index] = provider;

    try {
      // ignore: use_build_context_synchronously
      precacheImage(provider, context);
    } catch (e) {
      // ignore precache errors silently
      debugPrint('Precache failed for ${file.path}: $e');
    }
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    _imageProviderCache.clear();
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
      // Calculate translation so tapped point stays under the finger after scale
      end.translate(-position.dx * (targetScale - 1), -position.dy * (targetScale - 1));
      end.scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(begin: begin, end: end).animate(
      CurveTween(curve: Curves.easeOut).animate(_zoomAnimationController),
    );
    _zoomAnimationController.forward(from: 0);
  }

  // Modified: only allow swipe DOWN to dismiss; swipe UP does nothing now.
  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isSlideshowActive) return;
    final velocity = details.primaryVelocity ?? 0.0;

    if (velocity > 300) {
      Navigator.of(context).pop();
    }
    // removed: showing info on swipe up
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

    // If folder dir not ready yet, show a simple full-screen loader (only once)
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
            _isSlideshowActive ? _buildSlideshowView() : _buildInteractiveView(),
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedSlide(
                      offset: _showUI ? Offset.zero : const Offset(0, 1.5),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: _buildBottomToolbar(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveView() {
    return PageView.builder(
      physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      controller: _pageController,
      itemCount: _updatableFiles.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          // Reset zoom transformation for new page
          _transformationController.value = Matrix4.identity();
          _isZoomed = false;
        });

        // Pre-cache surrounding images for smooth swipe
        _precacheSurrounding(index);
      },
      itemBuilder: (context, index) {
        return _buildImagePage(_updatableFiles[index], index: index);
      },
    );
  }

  Widget _buildSlideshowView() {
    return Center(
      child: AnimatedSwitcher(
        duration: _slideshowTransitionDuration,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildImagePage(
          _updatableFiles[_currentIndex],
          key: ValueKey<String>(_updatableFiles[_currentIndex].id),
          index: _currentIndex,
        ),
      ),
    );
  }

  Widget _buildImagePage(VaultFile vaultFile, {Key? key, required int index}) {
    // We rely on cached _parentFolderDir and _imageProviderCache[index]
    final file = File(p.join(_parentFolderDir!.path, vaultFile.id));
    final provider = _imageProviderCache[index] ?? FileImage(file);

    // Ensure provider cached for future
    _imageProviderCache[index] = provider;

    return GestureDetector(
      key: key,
      onTap: _onViewTap,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      onVerticalDragEnd: _handleVerticalDragEnd,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        child: RepaintBoundary(
          child: Image(
            image: provider,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
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
              return const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 60,
                ),
              );
            },
          ),
        ),
      ),
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
          icon: Icon(_isSlideshowActive ? Icons.stop_circle_outlined : Icons.play_circle_outline),
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
            _buildBottomAction(Icons.drive_file_move_outline, 'Transfer', _showTransferSheet),
            _buildBottomAction(Icons.delete, 'Recycle', _moveCurrentFileToRecycleBin),
            _buildFavoriteButton(currentFile),
            _buildBottomAction(Icons.share_outlined, 'Share', _shareCurrentFile),
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
          Icon(currentFile.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: currentFile.isFavorite ? Colors.red : Colors.white),
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

      // Pre-cache the next image in the slideshow.
      _precacheImage(nextIndex + 1);

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
  void _unhidePlaceholder() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unhide coming soon!')));

  Future<void> _toggleFavorite() async {
    final currentFile = _updatableFiles[_currentIndex];
    final updatedFile = currentFile.copyWith(isFavorite: !currentFile.isFavorite);

    setState(() {
      _updatableFiles[_currentIndex] = updatedFile;
    });

    await StorageHelper.updateFileMetadata(updatedFile);
  }

  Future<void> _showTransferSheet() async {
    _stopSlideshow();

    final currentFile = _updatableFiles[_currentIndex];

    final VaultFolder? destinationFolder = await showModalBottomSheet<VaultFolder>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: FileTransferSheet(sourceFolder: widget.parentFolder),
      ),
    );

    if (destinationFolder != null && mounted) {
      await StorageHelper.transferFile(currentFile, widget.parentFolder, destinationFolder);
      await refreshItemCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File transferred to "${destinationFolder.name}"')),
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
        content: Text('Are you sure you want to move "${currentFile.fileName}" to the recycle bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move')),
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
    if (!_folderReady || _parentFolderDir == null) return;

    final filePath = p.join(_parentFolderDir!.path, vaultFile.id);
    final file = XFile(filePath);
    await Share.shareXFiles([file]);
  }

  void _showInfoSheet() async {
    _stopSlideshow();

    final vaultFile = _updatableFiles[_currentIndex];
    if (!_folderReady || _parentFolderDir == null) return;

    final file = File(p.join(_parentFolderDir!.path, vaultFile.id));
    if (!await file.exists()) return;

    final fileStat = await file.stat();
    final imageBytes = await file.readAsBytes();

    // Use compute to decode image for dimensions only when requested (keeps UI responsive)
    final decodedImage = await compute(img.decodeImage, imageBytes);

    final fileSize = NumberFormat.compact().format(fileStat.size);
    final dimensions = decodedImage != null ? '${decodedImage.width} × ${decodedImage.height}' : 'N/A';
    final dateAdded = DateFormat.yMMMd().add_jm().format(vaultFile.dateAdded);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Text(
                      vaultFile.fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action placeholder')));
                    },
                    icon: const Icon(Icons.copy, color: Colors.white70),
                  ),
                ]),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
        ),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis, maxLines: 3)),
      ]),
    );
  }
}
