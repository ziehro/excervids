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

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlayingInBackground = false;
  List<Map<String, dynamic>> _audioTracks = [];
  int _selectedTrackGroupIndex = 0;
  int _selectedTrackIndex = 0;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAudioTracks();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play();
          WakelockPlus.enable();
          _startHideTimer();
        }
      });
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
    final tracks = await AudioTrackSelector.getAudioTracks(widget.videoFile.path);
    if (mounted) {
      setState(() => _audioTracks = tracks);

      // Automatically select first audio track (Track 1 = music+voice)
      if (tracks.isNotEmpty) {
        final firstTrack = tracks[0];
        AudioTrackSelector.setAudioTrack(
          firstTrack['groupIndex'] as int,
          firstTrack['trackIndex'] as int,
        ).then((_) {
          if (mounted) {
            setState(() {
              _selectedTrackGroupIndex = firstTrack['groupIndex'] as int;
              _selectedTrackIndex = firstTrack['trackIndex'] as int;
            });
          }
        });
      }
    }
  }

  void _showAudioTrackDialog() {
    if (_audioTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio tracks available')),
      );
      return;
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
                        await AudioTrackSelector.setAudioTrack(
                          track['groupIndex'] as int,
                          track['trackIndex'] as int,
                        );
                        setState(() {
                          _selectedTrackGroupIndex = track['groupIndex'] as int;
                          _selectedTrackIndex = track['trackIndex'] as int;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to $trackLabel'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
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

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_controller.value.isPlaying && audioHandler != null) {
        final position = _controller.value.position;
        _controller.pause();
        WakelockPlus.disable();
        _startBackgroundAudio(position);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isPlayingInBackground) {
        _resumeVideoFromAudio();
        WakelockPlus.enable();
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

    final audioPosition = audioHandler!.player.position;
    await audioHandler!.stop();

    if (mounted) {
      setState(() => _isPlayingInBackground = false);
      await _controller.seekTo(audioPosition);
      await _controller.play();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
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
    if (_isInitialized && _controller.value.isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WakelockPlus.enable();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.videoFile.path.split('/').last),
        actions: [
          if (_audioTracks.length > 1)
            IconButton(
              icon: const Icon(Icons.audiotrack),
              onPressed: _showAudioTrackDialog,
              tooltip: 'Audio Tracks',
            ),
        ],
      ),
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
                if (_showControls)
                  Container(
                    color: Colors.black54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        VideoProgressIndicator(_controller, allowScrubbing: true),
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