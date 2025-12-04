import 'package:flutter/services.dart';

class AudioTrackSelector {
  static const platform = MethodChannel('com.ziehro.excervids/audio_tracks');

  static Future<List<Map<String, dynamic>>> getAudioTracks(String path) async {
    try {
      final List<dynamic> tracks = await platform.invokeMethod('getAudioTracks', {'path': path});
      return tracks.map((t) => Map<String, dynamic>.from(t)).toList();
    } catch (e) {
      print('Error getting audio tracks: $e');
      return [];
    }
  }

  static Future<void> setAudioTrack(int groupIndex) async {
    try {
      await platform.invokeMethod('setAudioTrack', {'groupIndex': groupIndex});
    } catch (e) {
      print('Error setting audio track: $e');
    }
  }

  static Future<void> releasePlayer() async {
    try {
      await platform.invokeMethod('releasePlayer');
    } catch (e) {
      print('Error releasing player: $e');
    }
  }
}