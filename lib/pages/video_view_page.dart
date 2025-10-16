// lib/pages/video_view_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vlt/data/notifiers.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';
import 'package:vlt/widgets/file_transfer_sheet.dart';

/// ✨ A full-featured video player page with a modern, gesture-based UI.
class VideoViewPage extends StatefulWidget {
  final List<VaultFile> files;
  final int initialIndex;
  final VaultFolder parentFolder;

  const VideoViewPage({
    super.key,
    required this.files,
    required this.initialIndex,
    required this.parentFolder,
  });

  @override
  State<VideoViewPage> createState() => _VideoViewPageState();
}

class _VideoViewPageState extends State<VideoViewPage> {
  late VideoPlayerController _controller;
  late int _currentIndex;
  late List<VaultFile> _updatableFiles; // ✨ ADDED: To handle local updates.
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // Playback state
  bool _isLooping = false;
  final List<double> _playbackSpeeds = [0.5, 1.0, 1.25, 1.5, 2.0];
  double _currentSpeed = 1.0;

  // Gesture control state
  double _initialBrightness = 0.5;

  // State for brightness indicator
  bool _showBrightnessIndicator = false;
  double _currentBrightness = 0.5;
  Timer? _hideIndicatorTimer;

  // State for volume indicator
  bool _showVolumeIndicator = false;
  double _currentVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _updatableFiles = List.from(widget.files); // ✨ ADDED
    _currentIndex = _updatableFiles.isEmpty // ✨ MODIFIED
        ? 0
        : widget.initialIndex.clamp(0, _updatableFiles.length - 1);

    _loadLoopingPreference();
    _initializePlayer(_currentIndex);
    WakelockPlus.enable(); // Keep screen awake

    ScreenBrightness().current.then(
      (brightness) {
        _initialBrightness = brightness;
        _currentBrightness = brightness;
      },
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _hideIndicatorTimer?.cancel();
    _controller.dispose();
    WakelockPlus.disable(); // Allow screen to sleep again
    // Restore the original brightness on exit.
    ScreenBrightness().setScreenBrightness(_initialBrightness);
    // Ensure screen orientation is reset on exit
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _loadLoopingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLooping = prefs.getBool('isVideoLooping') ?? false;
      });
    }
  }

  Future<void> _initializePlayer(int index) async {
    if (mounted && _isInitialized) {
      _controller.removeListener(_videoListener);
      await _controller.dispose();
    }

    // ✨ MODIFIED: Check against _updatableFiles
    if (index < 0 || index >= _updatableFiles.length) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final vaultFile = _updatableFiles[index]; // ✨ MODIFIED
    final folderDir = await StorageHelper.findFolderDirectoryById(
      widget.parentFolder.id,
    );
    if (folderDir == null) return;

    final file = File(p.join(folderDir.path, vaultFile.id));
    if (!file.existsSync()) {
      if (mounted) setState(() => _isInitialized = false);
      return;
    }

    _controller = VideoPlayerController.file(file);
    _controller.addListener(_videoListener);

    await _controller.initialize();

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _controller.setLooping(_isLooping);
        _controller.setPlaybackSpeed(_currentSpeed);
        _controller.play();
        _startHideControlsTimer();
        _currentVolume = _controller.value.volume; // Initialize current volume
      });
    }
  }

  void _videoListener() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.position >= _controller.value.duration &&
        !_isLooping) {
      _playNext();
    }
  }

  void _playNext() {
    // ✨ MODIFIED
    if (_currentIndex < _updatableFiles.length - 1) {
      setState(() {
        _currentIndex++;
        _isInitialized = false;
      });
      _initializePlayer(_currentIndex);
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _playPrevious() {
    if (_controller.value.position > const Duration(seconds: 3)) {
      _controller.seekTo(Duration.zero);
    } else {
      if (_currentIndex > 0) {
        setState(() {
          _currentIndex--;
          _isInitialized = false;
        });
        _initializePlayer(_currentIndex);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      } else {
        _hideControlsTimer?.cancel();
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLeft = details.globalPosition.dx < screenWidth / 2;
    double delta =
        details.primaryDelta! / (MediaQuery.of(context).size.height / 1.5);

    _hideIndicatorTimer?.cancel();

    if (isLeft) {
      if (!_showVolumeIndicator) {
        setState(() {
          _showVolumeIndicator = true;
        });
      }
      double newVolume = (_controller.value.volume - delta).clamp(0.0, 1.0);
      _controller.setVolume(newVolume);
      setState(() {
        _currentVolume = newVolume;
      });
    } else {
      if (!_showBrightnessIndicator) {
        setState(() {
          _showBrightnessIndicator = true;
        });
      }
      ScreenBrightness().current.then((currentValue) {
        double newBrightness = (currentValue - delta).clamp(0.0, 1.0);
        ScreenBrightness().setScreenBrightness(newBrightness);
        if (mounted) {
          setState(() {
            _currentBrightness = newBrightness;
          });
        }
      });
    }

    _hideIndicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
        });
      }
    });
  }

  // ✨ --- ADDED: ALL ACTION METHODS --- ✨
  Future<void> _showRenameDialog() async {
    _controller.pause();
    final currentFile = _updatableFiles[_currentIndex];
    final TextEditingController controller =
        TextEditingController(text: currentFile.fileName);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );

    if (newName != null && newName != currentFile.fileName) {
      final updatedFile = currentFile.copyWith(fileName: newName);
      setState(() {
        _updatableFiles[_currentIndex] = updatedFile;
      });
      await StorageHelper.updateFileMetadata(updatedFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File renamed to "$newName"')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final currentFile = _updatableFiles[_currentIndex];
    final updatedFile =
        currentFile.copyWith(isFavorite: !currentFile.isFavorite);
    setState(() {
      _updatableFiles[_currentIndex] = updatedFile;
    });
    await StorageHelper.updateFileMetadata(updatedFile);
  }

  Future<void> _showTransferSheet() async {
    _controller.pause();
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
          currentFile, widget.parentFolder, destinationFolder);
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
    _controller.pause();
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
      await StorageHelper.moveFileToRecycleBin(
          currentFile, widget.parentFolder);
      await refreshItemCounts();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _shareCurrentFile() async {
    _controller.pause();
    final vaultFile = _updatableFiles[_currentIndex];
    final folderDir =
        await StorageHelper.findFolderDirectoryById(widget.parentFolder.id);
    if (folderDir == null) return;
    final filePath = p.join(folderDir.path, vaultFile.id);
    await Share.shareXFiles([XFile(filePath)]);
  }

  void _showInfoSheet() async {
    _controller.pause();
    final vaultFile = _updatableFiles[_currentIndex];
    final folderDir =
        await StorageHelper.findFolderDirectoryById(widget.parentFolder.id);
    if (folderDir == null) return;
    final file = File(p.join(folderDir.path, vaultFile.id));
    if (!await file.exists()) return;

    final fileStat = await file.stat();
    final fileSize = NumberFormat.compact().format(fileStat.size);
    final dimensions =
        '${_controller.value.size.width.toInt()} × ${_controller.value.size.height.toInt()}';
    final dateAdded = DateFormat.yMMMd().add_jm().format(vaultFile.dateAdded);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vaultFile.fileName,
                  style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              _infoRow('Path:', '/${widget.parentFolder.name}'),
              _infoRow('Original Path:', vaultFile.originalPath),
              _infoRow('File Size:', fileSize),
              _infoRow('Dimensions:', dimensions),
              _infoRow('Date Added:', dateAdded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
            child: Text(value,
                overflow: TextOverflow.ellipsis, maxLines: 3)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isInitialized
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleControls,
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    behavior: HitTestBehavior.translucent,
                  ),
                  _buildBrightnessIndicator(),
                  _buildVolumeIndicator(),
                  _buildOverlayControls(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildBrightnessIndicator() {
    return AnimatedOpacity(
      opacity: _showBrightnessIndicator ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.brightness_6_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '${(_currentBrightness * 100).toInt()}%',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeIndicator() {
    IconData getVolumeIcon() {
      if (_currentVolume <= 0) {
        return Icons.volume_off;
      } else if (_currentVolume < 0.5) {
        return Icons.volume_down;
      } else {
        return Icons.volume_up;
      }
    }

    return AnimatedOpacity(
      opacity: _showVolumeIndicator ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(getVolumeIcon(), color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '${(_currentVolume * 100).toInt()}%',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayControls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        children: [
          _buildTopBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final currentFile = _updatableFiles[_currentIndex];
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTapDown: (_) => _startHideControlsTimer(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  currentFile.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                child: Text(
                  '${_currentSpeed}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  final currentIndex = _playbackSpeeds.indexOf(_currentSpeed);
                  final nextIndex = (currentIndex + 1) % _playbackSpeeds.length;
                  setState(() => _currentSpeed = _playbackSpeeds[nextIndex]);
                  _controller.setPlaybackSpeed(_currentSpeed);
                },
              ),
              // ✨ MODIFIED: Added icons to the PopupMenuButton items.
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'transfer':
                      _showTransferSheet();
                      break;
                    case 'rename':
                      _showRenameDialog();
                      break;
                    case 'recycle':
                      _moveCurrentFileToRecycleBin();
                      break;
                    case 'favorite':
                      _toggleFavorite();
                      break;
                    case 'share':
                      _shareCurrentFile();
                      break;
                    case 'details':
                      _showInfoSheet();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final isFavorite = _updatableFiles[_currentIndex].isFavorite;
                  return [
                    PopupMenuItem(
                      value: 'transfer',
                      child: Row(
                        children: const [
                          Icon(Icons.drive_file_move_outline),
                          SizedBox(width: 16),
                          Text('Transfer'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: const [
                          Icon(Icons.edit),
                          SizedBox(width: 16),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'recycle',
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 16),
                          Text('Recycle'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'favorite',
                      child: Row(
                        children: [
                          Icon(isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border),
                          const SizedBox(width: 16),
                          Text(isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: const [
                          Icon(Icons.share_outlined),
                          SizedBox(width: 16),
                          Text('Share'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline),
                          SizedBox(width: 16),
                          Text('Details'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTapDown: (_) => _startHideControlsTimer(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, VideoPlayerValue value, child) {
                  final remaining = value.duration - value.position;
                  return Row(
                    children: [
                      Text(
                        _formatDuration(value.position),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.red,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white12,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                      Text(
                        '-${_formatDuration(remaining)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _isLooping ? Icons.repeat_one : Icons.repeat,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() {
                        _isLooping = !_isLooping;
                        _controller.setLooping(_isLooping);
                        prefs.setBool('isVideoLooping', _isLooping);
                      });
                    },
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: _playPrevious,
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 50,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                              _hideControlsTimer?.cancel();
                            } else {
                              _controller.play();
                              _startHideControlsTimer();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: _playNext,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: () {
                      final isPortrait =
                          MediaQuery.of(context).orientation ==
                              Orientation.portrait;
                      if (isPortrait) {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]);
                      } else {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                        ]);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}