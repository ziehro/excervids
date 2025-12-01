import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import 'dart:math';

AudioPlayerHandler? audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ziehro.excervids.channel.audio',
        androidNotificationChannelName: 'ExcerVids Audio',
        androidNotificationOngoing: true,
      ),
    ) as AudioPlayerHandler;
  } catch (e) {
    print('Failed to initialize audio service: $e');
    // Continue without audio service - video playback will still work
  }

  runApp(const ExcerVidsApp());
}

class AudioPlayerHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  AudioPlayerHandler() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(playbackState.value.copyWith(
        playing: _player.playing,
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
      ));
    });
  }

  Future<void> playFile(String path, String title) async {
    mediaItem.add(MediaItem(
      id: path,
      title: title,
      displayTitle: title,
    ));

    await _player.setFilePath(path);
    _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
}

class ExcerVidsApp extends StatelessWidget {
  const ExcerVidsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExcerVids',
      theme: ThemeData.dark(),
      home: const VideoListScreen(),
    );
  }
}

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({Key? key}) : super(key: key);

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  Map<String, List<File>> videosByFolder = {};
  List<File> allVideos = [];
  late Directory appDirectory;
  bool isLoading = true;
  SharedPreferences? prefs;
  List<String> playedVideos = [];
  String? lastPlayedDate;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _requestPermissions();
      await _setupDirectory();
      await _loadPreferences();
      await _loadVideos();
    } catch (e) {
      print('Initialization error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().split(' ')[0];
      lastPlayedDate = prefs?.getString('lastPlayedDate');

      if (lastPlayedDate != today) {
        playedVideos = [];
        await prefs?.setStringList('playedVideos', []);
        await prefs?.setString('lastPlayedDate', today);
        lastPlayedDate = today;
      } else {
        playedVideos = prefs?.getStringList('playedVideos') ?? [];
      }
    } catch (e) {
      print('Error loading preferences: $e');
      playedVideos = [];
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
        await Permission.notification.request();
      }
    } catch (e) {
      print('Permission error: $e');
    }
  }

  Future<void> _setupDirectory() async {
    if (Platform.isAndroid) {
      // Main ExcerVids folder
      final excerVidsDir = Directory('/storage/emulated/0/Download/ExcerVids');
      if (!await excerVidsDir.exists()) {
        await excerVidsDir.create(recursive: true);
      }
      appDirectory = excerVidsDir;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      appDirectory = Directory('${directory.path}/ExcerVids');
      if (!await appDirectory.exists()) {
        await appDirectory.create(recursive: true);
      }
    }
  }

  Future<void> _loadVideos() async {
    setState(() => isLoading = true);

    try {
      videosByFolder = {};
      allVideos = [];

      // Scan ExcerVids folder
      await _scanDirectory(appDirectory);

      // Also scan Movies folder if it exists
      if (Platform.isAndroid) {
        final moviesDir = Directory('/storage/emulated/0/Movies');
        if (await moviesDir.exists()) {
          await _scanDirectory(moviesDir);
        }
      }
    } catch (e) {
      print('Error loading videos: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> _scanDirectory(Directory dir) async {
    try {
      final entities = dir.listSync();

      for (var entity in entities) {
        if (entity is Directory) {
          await _scanDirectory(entity);
        } else if (entity is File) {
          if (entity.path.toLowerCase().endsWith('.mp4') ||
              entity.path.toLowerCase().endsWith('.mov') ||
              entity.path.toLowerCase().endsWith('.avi') ||
              entity.path.toLowerCase().endsWith('.mkv')) {

            final folderPath = entity.parent.path;
            final folderName = folderPath.split('/').last;

            if (!videosByFolder.containsKey(folderName)) {
              videosByFolder[folderName] = [];
            }
            videosByFolder[folderName]!.add(entity);
            allVideos.add(entity);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  void _deleteVideo(File file) async {
    await file.delete();
    await _loadVideos();
  }

  void _playVideo(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoFile: file),
      ),
    );
  }

  Future<void> _playAudioOnly(File file) async {
    if (audioHandler == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio service not available')),
        );
      }
      return;
    }

    final fileName = file.path.split('/').last;
    await audioHandler!.playFile(file.path, fileName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing audio: $fileName'),
          action: SnackBarAction(
            label: 'Stop',
            onPressed: () => audioHandler?.stop(),
          ),
        ),
      );
    }
  }

  Future<void> _playDailyVideo({bool audioOnly = false}) async {
    if (allVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No videos available')),
      );
      return;
    }

    final unplayedVideos = allVideos.where((file) {
      return !playedVideos.contains(file.path);
    }).toList();

    if (unplayedVideos.isEmpty) {
      playedVideos = [];
      await prefs?.setStringList('playedVideos', []);
      _playDailyVideo(audioOnly: audioOnly);
      return;
    }

    final random = Random();
    final randomVideo = unplayedVideos[random.nextInt(unplayedVideos.length)];

    playedVideos.add(randomVideo.path);
    await prefs?.setStringList('playedVideos', playedVideos);

    if (audioOnly) {
      await _playAudioOnly(randomVideo);
    } else {
      _playVideo(randomVideo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unplayedCount = allVideos.where((f) => !playedVideos.contains(f.path)).length;
    final sortedFolders = videosByFolder.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ExcerVids'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: audioHandler != null ? () => audioHandler!.stop() : null,
            tooltip: 'Stop Audio',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: allVideos.isEmpty ? null : () => _playDailyVideo(audioOnly: false),
                    icon: const Icon(Icons.shuffle),
                    label: Text('Random Video ($unplayedCount left)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (allVideos.isEmpty || audioHandler == null)
                        ? null
                        : () => _playDailyVideo(audioOnly: true),
                    icon: const Icon(Icons.headphones),
                    label: Text(audioHandler == null
                        ? 'Audio Service Unavailable'
                        : 'Random Audio (Background)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : allVideos.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No videos found'),
                  const SizedBox(height: 8),
                  Text(
                    'Scanning:\n${appDirectory.path}\n/storage/emulated/0/Movies',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: sortedFolders.length,
              itemBuilder: (context, index) {
                final folderName = sortedFolders[index];
                final videos = videosByFolder[folderName]!;

                return ExpansionTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folderName),
                  subtitle: Text('${videos.length} videos'),
                  children: videos.map((video) {
                    final name = video.path.split('/').last;
                    final isPlayed = playedVideos.contains(video.path);

                    return ListTile(
                      contentPadding: const EdgeInsets.only(left: 72, right: 16),
                      leading: Icon(
                        Icons.play_circle_outline,
                        color: isPlayed ? Colors.grey : null,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isPlayed ? Colors.grey : null,
                        ),
                      ),
                      subtitle: isPlayed ? const Text('Played today', style: TextStyle(fontSize: 12)) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.headphones, size: 20),
                            onPressed: audioHandler != null
                                ? () => _playAudioOnly(video)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteVideo(video),
                          ),
                        ],
                      ),
                      onTap: () => _playVideo(video),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  const VideoPlayerScreen({Key? key, required this.videoFile}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.videoFile.path.split('/').last),
      ),
      body: Center(
        child: _isInitialized
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            VideoProgressIndicator(_controller, allowScrubbing: true),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    _controller.value.volume > 0
                        ? Icons.volume_up
                        : Icons.volume_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.setVolume(
                        _controller.value.volume > 0 ? 0 : 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ],
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}