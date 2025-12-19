import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'main.dart'; // For audioHandler
import 'audio_track_selector.dart';

class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  const VideoPlayerScreen({Key? key, required this.videoFile}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlayingInBackground = false;
  List<Map<String, dynamic>> _audioTracks = [];
  int _selectedTrackGroupIndex = 0;
  int _selectedTrackIndex = 0;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _wasPlaying = false;
  Duration? _lastPosition;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();

    // Add listener to continuously track position and errors
    // Note: listener added in _initializeVideo after controller is created
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    _controller.addListener(_videoListener);

    try {
      await _controller.initialize();

      if (!mounted) return;

      setState(() => _isInitialized = true);

      // Load and set audio tracks AFTER video is initialized
      try {
        await _loadAudioTracks();
      } catch (audioError) {
        print('⚠️ Audio track loading failed: $audioError');
        print('▶️ Playing video with default audio');
      }

      if (mounted) {
        await _controller.play();
        WakelockPlus.enable();
        _startHideTimer();
      }
    } catch (error) {
      print('❌ Error initializing video: $error');

      // Check if it's an audio-related error
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('audio') || errorString.contains('mediacodec')) {
        print('🔧 Audio error detected, trying video-only mode...');
        await _tryVideoOnlyMode();
      } else {
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading video: ${error.toString().split(':').last}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _tryVideoOnlyMode() async {
    print('🎬 Attempting video-only initialization...');

    try {
      // Dispose the failed controller
      _controller.removeListener(_videoListener);
      await _controller.dispose();

      // Create new controller
      _controller = VideoPlayerController.file(widget.videoFile);
      _controller.addListener(_videoListener);

      // Try to initialize again
      await _controller.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);

        // Show warning about audio
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Video playing with limited audio. Audio track may have issues.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        await _controller.play();
        WakelockPlus.enable();
        _startHideTimer();
      }
    } catch (retryError) {
      print('❌ Video-only mode also failed: $retryError');

      if (mounted) {
        // Show detailed error with file info
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Cannot Play Video'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This video has audio encoding issues and cannot be played.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('The problem:'),
                Text(
                  '• MP3 audio codec not compatible with video player',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                const Text('Solution:'),
                Text(
                  '1. Re-encode video with AAC audio\n2. Use: ffmpeg -i input.mp4 -c:v copy -c:a aac output.mp4',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Text(
                  'File: ${widget.videoFile.path.split('/').last}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close video screen
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _videoListener() {
    if (_controller.value.isInitialized) {
      _lastPosition = _controller.value.position;
      //_wasPlaying = _controller.value.isPlaying;

      // Handle video errors
      if (_controller.value.hasError) {
        print('❌ Video player error: ${_controller.value.errorDescription}');
        if (mounted && _controller.value.errorDescription != null) {
          // Try to recover by seeking slightly forward
          final currentPos = _controller.value.position;
          _controller.seekTo(currentPos + const Duration(milliseconds: 100));
        }
      }
    }
  }

  Future<void> _refreshAudioTrack() async {
    // Force re-apply the selected audio track
    if (_audioTracks.isNotEmpty) {
      try {
        await AudioTrackSelector.setAudioTrack(
          _selectedTrackGroupIndex,
          _selectedTrackIndex,
        );
        print('🔄 Refreshed audio track: group=$_selectedTrackGroupIndex, track=$_selectedTrackIndex');
      } catch (e) {
        print('⚠️ Could not refresh audio track: $e');
        print('   Continuing with current audio...');
        // Don't throw error - just continue with whatever track is playing
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      }
    });
  }

  Future<void> _loadAudioTracks() async {
    try {
      print('🎵 Loading audio tracks...');
      final tracks = await AudioTrackSelector.getAudioTracks(widget.videoFile.path);
      print('📋 Found ${tracks.length} audio tracks');

      if (!mounted) return;

      setState(() => _audioTracks = tracks);

      if (tracks.isEmpty) {
        print('⚠️ No audio tracks found, playing with default audio');
        return;
      }

      // Wait for video player to be fully ready
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Try to select first audio track (Track 1 = music+voice)
      final firstTrack = tracks[0];
      final groupIndex = firstTrack['groupIndex'] as int;
      final trackIndex = firstTrack['trackIndex'] as int;

      print('🎯 Attempting to select Track 1: group=$groupIndex, track=$trackIndex');

      try {
        await AudioTrackSelector.setAudioTrack(groupIndex, trackIndex);

        if (mounted) {
          setState(() {
            _selectedTrackGroupIndex = groupIndex;
            _selectedTrackIndex = trackIndex;
          });
          print('✅ Auto-selected Track 1 (Music + Voice)');
          print('   Selected group: $_selectedTrackGroupIndex, track: $_selectedTrackIndex');
        }
      } catch (e) {
        print('❌ Error setting Track 1: $e');

        // Fallback: Try Track 2 if Track 1 fails
        if (tracks.length > 1 && mounted) {
          print('🔄 Trying fallback to Track 2...');
          try {
            final secondTrack = tracks[1];
            final fallbackGroupIndex = secondTrack['groupIndex'] as int;
            final fallbackTrackIndex = secondTrack['trackIndex'] as int;

            await AudioTrackSelector.setAudioTrack(fallbackGroupIndex, fallbackTrackIndex);

            if (mounted) {
              setState(() {
                _selectedTrackGroupIndex = fallbackGroupIndex;
                _selectedTrackIndex = fallbackTrackIndex;
              });
              print('✅ Fallback to Track 2 successful');
            }
          } catch (fallbackError) {
            print('❌ Track 2 also failed: $fallbackError');
            print('⚠️ Playing with default audio track');
          }
        } else {
          print('⚠️ Only one track available or widget unmounted, playing with default');
        }
      }
    } catch (e) {
      print('❌ Fatal error loading audio tracks: $e');
      print('⚠️ Continuing with default audio');
    }
  }

  void _showAudioTrackDialog() {
    if (_audioTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio tracks available')),
      );
      return;
    }

    print('🎵 Opening audio track dialog');
    print('   Current selection: group=$_selectedTrackGroupIndex, track=$_selectedTrackIndex');
    print('   Available tracks: ${_audioTracks.length}');

    for (var i = 0; i < _audioTracks.length; i++) {
      final track = _audioTracks[i];
      print('   Track $i: group=${track['groupIndex']}, track=${track['trackIndex']}, label=${track['label']}');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.audiotrack, color: Colors.blue),
            SizedBox(width: 8),
            Text('Select Audio Track'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _audioTracks.asMap().entries.map((entry) {
              final track = entry.value;
              final trackNumber = entry.key + 1;
              final isSelected = _selectedTrackGroupIndex == track['groupIndex'] &&
                  _selectedTrackIndex == track['trackIndex'];

              // Better labels for P90X3 videos
              String trackLabel;
              if (trackNumber == 1) {
                trackLabel = 'Track 1 - Music + Voice';
              } else if (trackNumber == 2) {
                trackLabel = 'Track 2 - Music Only';
              } else {
                trackLabel = track['label'] ?? 'Track $trackNumber';
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Radio<int>(
                    value: entry.key,
                    groupValue: _audioTracks.indexWhere((t) =>
                    t['groupIndex'] == _selectedTrackGroupIndex &&
                        t['trackIndex'] == _selectedTrackIndex
                    ),
                    onChanged: (value) async {
                      if (value != null) {
                        final selectedTrack = _audioTracks[value];
                        final groupIndex = selectedTrack['groupIndex'] as int;
                        final trackIndex = selectedTrack['trackIndex'] as int;

                        print('🎵 Switching to track $value: group=$groupIndex, track=$trackIndex');

                        try {
                          // Save current position in case we need to recover
                          final currentPosition = _controller.value.position;
                          final wasPlayingBefore = _controller.value.isPlaying;

                          // Set the audio track
                          await AudioTrackSelector.setAudioTrack(groupIndex, trackIndex);

                          // Update state
                          if (mounted) {
                            setState(() {
                              _selectedTrackGroupIndex = groupIndex;
                              _selectedTrackIndex = trackIndex;
                            });
                          }

                          // If video stopped playing during switch, resume it
                          if (wasPlayingBefore && !_controller.value.isPlaying && mounted) {
                            await _controller.seekTo(currentPosition);
                            await _controller.play();
                          }

                          // Close dialog
                          if (mounted) {
                            Navigator.pop(context);

                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched to $trackLabel'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }

                          print('✅ Track switched successfully');
                        } catch (e) {
                          print('❌ Error switching track: $e');
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not switch track. Using current audio.'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 3),
                                action: SnackBarAction(
                                  label: 'OK',
                                  textColor: Colors.white,
                                  onPressed: () {},
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  title: Text(
                    trackLabel,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'Language: ${track['language']} | ${track['codec']} | ${track['channelCount']} channels',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('📱 Lifecycle state: $state');

    if (state == AppLifecycleState.inactive) {
      // FIRST save - capture true playing state before anything pauses
      if (!_isPlayingInBackground) {
        // Only update if not already in background audio mode
        _wasPlaying = _controller.value.isPlaying;
        _lastPosition = _controller.value.position;
        print('💤 App inactive. Captured playing state: $_wasPlaying');
      }
    } else if (state == AppLifecycleState.paused) {
      // Don't re-save _wasPlaying here - keep the value from inactive state
      print('⏸️ App paused. Preserving was playing: $_wasPlaying, Position: $_lastPosition');

      // Only start background audio if actually going to background (not just rotating)
      if (_wasPlaying && audioHandler != null && !_isPlayingInBackground) {
        _controller.pause();
        WakelockPlus.disable();
        // Delay to check if we're really going to background
        Future.delayed(const Duration(milliseconds: 500), () {
          if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
            print('🎵 Starting background audio (was playing: $_wasPlaying)');
            _startBackgroundAudio(_lastPosition ?? Duration.zero);
          } else {
            print('⚠️ Not really backgrounded, was just screen off');
          }
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      print('▶️ App resumed. Background audio: $_isPlayingInBackground, Was playing: $_wasPlaying');

      if (_isPlayingInBackground) {
        // Coming back from actual background
        print('🔄 Resuming from background audio');
        _resumeVideoFromAudio();
        WakelockPlus.enable();
      } else if (_wasPlaying) {
        // Screen turned back on or returning from inactive state
        print('▶️ Resuming video playback (was playing: $_wasPlaying)');

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _controller.value.isInitialized) {
            if (!_controller.value.isPlaying) {
              print('▶️ Starting playback now');
              _controller.play();
              WakelockPlus.enable();
              // Refresh audio track after resuming
              _refreshAudioTrack();
              print('✅ Video resumed successfully');
            } else {
              print('ℹ️ Video already playing');
            }
          }
        });
      } else {
        print('ℹ️ Video was not playing, staying paused');
      }
    }
  }

  Future<void> _startBackgroundAudio(Duration position) async {
    if (audioHandler == null) return;

    final fileName = widget.videoFile.path.split('/').last;
    await audioHandler!.playFile(widget.videoFile.path, fileName);
    await audioHandler!.seek(position);

    if (mounted) {
      setState(() => _isPlayingInBackground = true);
    }
  }

  Future<void> _resumeVideoFromAudio() async {
    if (audioHandler == null) return;

    try {
      final audioPosition = audioHandler!.player.position;
      await audioHandler!.stop();

      if (mounted && _isInitialized) {
        setState(() => _isPlayingInBackground = false);

        await _controller.seekTo(audioPosition);
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted && _wasPlaying) {  // ← THIS IS THE PROBLEM
          await _controller.play();
          WakelockPlus.enable();
        }
      }
    } catch (e) {
      print('Error resuming video from audio: $e');
      if (mounted) {
        setState(() => _isPlayingInBackground = false);
      }
    }
  }

  @override
  void deactivate() {
    // Save state when widget is being deactivated (e.g., during orientation change)
    if (_controller.value.isInitialized) {
      _wasPlaying = _controller.value.isPlaying;
      _lastPosition = _controller.value.position;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_videoListener);
    if (_isPlayingInBackground && audioHandler != null) {
      audioHandler!.stop();
    }
    _controller.dispose();
    AudioTrackSelector.releasePlayer();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.value.isPlaying) {
      WakelockPlus.enable();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isInitialized && _controller.value.isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WakelockPlus.enable();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized
          ? GestureDetector(
        onTap: _toggleControls,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                // Back button in top-left corner
                if (_showControls)
                  Positioned(
                    top: 40,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, size: 32),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                // Skip buttons - ALWAYS VISIBLE
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip backward 1 minute (far left)
                      IconButton(
                        icon: const Icon(Icons.replay_10, size: 36),
                        onPressed: () {
                          final current = _controller.value.position;
                          final target = current - const Duration(minutes: 1);
                          _controller.seekTo(
                            target < Duration.zero ? Duration.zero : target,
                          );
                          if (_showControls) _startHideTimer();
                        },
                        tooltip: 'Back 1 minute',
                        color: Colors.white,
                      ),

                      // Skip forward 1 minute (far right)
                      IconButton(
                        icon: const Icon(Icons.forward_10, size: 36),
                        onPressed: () {
                          final current = _controller.value.position;
                          final duration = _controller.value.duration;
                          final target = current + const Duration(minutes: 1);
                          _controller.seekTo(
                            target > duration ? duration : target,
                          );
                          if (_showControls) _startHideTimer();
                        },
                        tooltip: 'Forward 1 minute',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                if (_showControls)
                  Container(
                    color: Colors.black54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                        // Play/Pause (center)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 48,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                    WakelockPlus.disable();
                                    _hideTimer?.cancel();
                                  } else {
                                    _controller.play();
                                    WakelockPlus.enable();
                                    _startHideTimer();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        // Volume and Audio track controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                                size: 32,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller.setVolume(_controller.value.volume > 0 ? 0 : 1);
                                });
                              },
                            ),
                            if (_audioTracks.length > 1)
                              IconButton(
                                icon: const Icon(Icons.audiotrack, size: 32),
                                onPressed: _showAudioTrackDialog,
                                tooltip: 'Audio Tracks',
                                color: Colors.white,
                              ),
                          ],
                        ),
                        if (_isPlayingInBackground)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Audio playing in background',
                              style: TextStyle(color: Colors.green),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}