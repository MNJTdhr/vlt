// lib/pages/video_view_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
// ✨ REMOVED: Unnecessary import for volume_controller
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vlt/models/vault_folder.dart';
import 'package:vlt/utils/storage_helper.dart';

/// ✨ A full-featured video player page with custom controls and gestures.
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

class _VideoViewPageState extends State<VideoViewPage> with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  late int _currentIndex;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // Playback state
  bool _isLooping = false;
  final List<double> _playbackSpeeds = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0];
  double _currentSpeed = 1.0;
  double _longPressSpeed = 2.0; // Default speed for press-and-hold

  // Gesture control state
  // ✨ REMOVED: _initialVolume is no longer needed
  double _initialBrightness = 0.5;

  // UI Animation
  late AnimationController _seekAnimationController;
  Animation<double>? _seekForwardAnimation;
  Animation<double>? _seekBackwardAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializePlayer(_currentIndex);
    WakelockPlus.enable(); // Keep screen awake

    // Initialize gesture-related values
    // ✨ REMOVED: The call to VolumeController() which was causing an error.
    ScreenBrightness().current.then((brightness) => _initialBrightness = brightness);

    _seekAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.dispose();
    _seekAnimationController.dispose();
    WakelockPlus.disable(); // Allow screen to sleep again
    // Optional: Reset brightness to its initial state
    // ScreenBrightness().setScreenBrightness(_initialBrightness);
    super.dispose();
  }

  Future<void> _initializePlayer(int index) async {
    // If a controller already exists, dispose of it first.
    if (mounted && _isInitialized) {
      // Remove listener from the old controller before disposing
      _controller.removeListener(_videoListener);
      await _controller.dispose();
    }
  
    // Ensure the index is valid
    if (index < 0 || index >= widget.files.length) {
      // If the playlist ends, pop the screen or show a message
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final vaultFile = widget.files[index];
    final folderDir = await StorageHelper.findFolderDirectoryById(widget.parentFolder.id);
    if (folderDir == null) return;
    
    final file = File(p.join(folderDir.path, vaultFile.id));
    if (!file.existsSync()) {
      // Handle file not found
      if (mounted) setState(() => _isInitialized = false);
      return;
    }

    _controller = VideoPlayerController.file(file);
    _controller.addListener(_videoListener); // Add listener before initializing

    await _controller.initialize();

    if (mounted) {
      setState(() {
        _isInitialized = true;
        _controller.setLooping(_isLooping);
        _controller.play();
        _startHideControlsTimer();
      });
    }
  }

  void _videoListener() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.position >= _controller.value.duration && !_isLooping) {
       // Using >= ensures we catch the end even if there's a slight timing difference
      _playNext();
    }
    // This setState is crucial to update the progress bar.
    if (mounted) setState(() {});
  }

  void _playNext() {
    if (_currentIndex < widget.files.length - 1) {
      setState(() {
        _currentIndex++;
        _isInitialized = false; // Show loading indicator
      });
      _initializePlayer(_currentIndex);
    } else {
        // Optional: Pop navigation when the last video finishes
        if (mounted) Navigator.of(context).pop();
    }
  }

  void _playPrevious() {
    // If video is past 3 seconds, restart it. Otherwise, go to previous.
    if (_controller.value.position > const Duration(seconds: 3)) {
      _controller.seekTo(Duration.zero);
    } else {
      if (_currentIndex > 0) {
        setState(() {
          _currentIndex--;
          _isInitialized = false; // Show loading indicator
        });
        _initializePlayer(_currentIndex);
      }
    }
  }

  /// ✨ Formats duration for display (e.g., 01:23)
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

  void _onVerticalDragUpdate(DragUpdateDetails details, bool isLeft) {
    // vertical drag changes volume (left) or brightness (right)
    double delta = details.primaryDelta! / (MediaQuery.of(context).size.height / 2); // Make it more sensitive
    if (isLeft) {
      // Volume (controls player's media volume)
      double newVolume = (_controller.value.volume - delta).clamp(0.0, 1.0);
      _controller.setVolume(newVolume);
    } else {
      // Brightness
      ScreenBrightness().current.then((brightness) {
        double newBrightness = (brightness - delta).clamp(0.0, 1.0);
        ScreenBrightness().setScreenBrightness(newBrightness);
      });
    }
    if (mounted) setState(() {});
  }
  
  // ✨ FIXED: Correctly implemented clamp for Duration
  void _seek(int seconds) {
    final currentPosition = _controller.value.position;
    final videoDuration = _controller.value.duration;
    var newPosition = currentPosition + Duration(seconds: seconds);

    if (newPosition < Duration.zero) {
      newPosition = Duration.zero;
    }
    if (newPosition > videoDuration) {
      newPosition = videoDuration;
    }
    
    _controller.seekTo(newPosition);
  }
  
  void _triggerSeekAnimation(bool isForward) {
    _seekAnimationController.forward(from: 0);
    setState(() {
      _seekForwardAnimation = isForward ? Tween<double>(begin: 0, end: 1).animate(_seekAnimationController) : null;
      _seekBackwardAnimation = !isForward ? Tween<double>(begin: 0, end: 1).animate(_seekAnimationController) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentFile = widget.files[_currentIndex];
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

                  // ✨ Gesture Detector Layer
                  _buildGestureDetector(),

                  // ✨ UI Controls Overlay
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: AbsorbPointer(
                      absorbing: !_showControls,
                      child: _buildControls(currentFile),
                    ),
                  ),
                  
                  // ✨ Seek Animation Indicators
                  _buildSeekIndicators(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildGestureDetector() {
    return Row(
      children: [
        // Left side for rewind & volume
        Expanded(
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: () {
              _seek(-5);
              _triggerSeekAnimation(false);
            },
            onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, true),
            onLongPress: () => _controller.setPlaybackSpeed(_longPressSpeed),
            onLongPressUp: () => _controller.setPlaybackSpeed(_currentSpeed),
            behavior: HitTestBehavior.translucent, // Allows gestures to pass through
          ),
        ),
        // Right side for forward & brightness
        Expanded(
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: () {
              _seek(10);
              _triggerSeekAnimation(true);
            },
            onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, false),
            onLongPress: () => _controller.setPlaybackSpeed(_longPressSpeed),
            onLongPressUp: () => _controller.setPlaybackSpeed(_currentSpeed),
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSeekIndicators() {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: _seekBackwardAnimation == null
                ? const SizedBox.shrink()
                : FadeTransition(
                    opacity: _seekBackwardAnimation!,
                    child: const Icon(Icons.replay_5, color: Colors.white, size: 50),
                  ),
          ),
        ),
        Expanded(
          child: Center(
            child: _seekForwardAnimation == null
                ? const SizedBox.shrink()
                : FadeTransition(
                    opacity: _seekForwardAnimation!,
                    child: const Icon(Icons.forward_10, color: Colors.white, size: 50),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(VaultFile currentFile) {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Column(
        children: [
          // ✨ Top Bar (AppBar)
          _buildAppBar(currentFile),
          const Spacer(),
          // ✨ Bottom Bar (Controls)
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildAppBar(VaultFile currentFile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
          // Speed changer button
          TextButton(
            child: Text(
              '${_longPressSpeed}x',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              final currentIndex = _playbackSpeeds.indexOf(_longPressSpeed);
              final nextIndex = (currentIndex + 1) % _playbackSpeeds.length;
              setState(() => _longPressSpeed = _playbackSpeeds[nextIndex]);
            },
          ),
          // Overflow menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              // Placeholder actions
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$value action triggered')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'share', child: Text('Share')),
              const PopupMenuItem(value: 'unhide', child: Text('Unhide')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
              const PopupMenuItem(value: 'transfer', child: Text('Transfer')),
              const PopupMenuItem(value: 'details', child: Text('Details')),
              CheckedPopupMenuItem(
                value: 'touch_controls',
                checked: true, // Placeholder
                child: const Text("Touch Controls"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(12.0).copyWith(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          Row(
            children: [
              Text(
                _formatDuration(_controller.value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Expanded(
                child: SizedBox(
                  height: 20,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              Text(
                _formatDuration(_controller.value.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Repeat toggle
              IconButton(
                icon: Icon(_isLooping ? Icons.repeat_one : Icons.repeat, color: Colors.white),
                onPressed: () {
                  setState(() => _isLooping = !_isLooping);
                  _controller.setLooping(_isLooping);
                },
              ),
              // Main playback controls
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                    onPressed: _playPrevious,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 50,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                        // Keep controls visible if user manually pauses
                        _showControls = true;
                        _startHideControlsTimer();
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                    onPressed: _playNext,
                  ),
                ],
              ),
              // Rotate button
              IconButton(
                icon: const Icon(Icons.screen_rotation, color: Colors.white),
                onPressed: () {
                  // Cycle through portrait, landscape, and auto
                  final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                  if (isPortrait) {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                  } else {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}