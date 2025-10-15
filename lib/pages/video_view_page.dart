// lib/pages/video_view_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';

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

  // ✨ ADDED: State for volume indicator
  bool _showVolumeIndicator = false;
  double _currentVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

    if (index < 0 || index >= widget.files.length) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final vaultFile = widget.files[index];
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
    if (_currentIndex < widget.files.length - 1) {
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

  // ✨ MODIFIED: Now handles showing indicators for both volume and brightness.
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
                  _buildVolumeIndicator(), // ✨ ADDED: Volume indicator widget
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
  
  // ✨ ADDED: A new widget for the volume indicator.
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
    final currentFile = widget.files[_currentIndex];
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  final file = widget.files[_currentIndex];
                  if (value == 'share') {
                    final folderDir =
                        await StorageHelper.findFolderDirectoryById(
                      widget.parentFolder.id,
                    );
                    if (folderDir == null) return;
                    final filePath = p.join(folderDir.path, file.id);
                    await Share.shareXFiles([XFile(filePath)]);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'share', child: Text('Share')),
                  const PopupMenuItem(value: 'details', child: Text('Details')),
                ],
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
                        style: const TextStyle(color: Colors.white, fontSize: 12),
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
                        style: const TextStyle(color: Colors.white, fontSize: 12),
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