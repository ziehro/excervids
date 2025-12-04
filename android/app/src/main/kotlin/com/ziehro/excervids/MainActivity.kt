package com.ziehro.excervids

import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.common.Tracks
import androidx.media3.common.C
import androidx.media3.common.TrackSelectionOverride
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.ziehro.excervids/audio_tracks"
    private var exoPlayer: ExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAudioTracks" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        getAudioTracks(path, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is null", null)
                    }
                }
                "setAudioTrack" -> {
                    val groupIndex = call.argument<Int>("groupIndex")
                    if (groupIndex != null) {
                        setAudioTrack(groupIndex)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Index is null", null)
                    }
                }
                "releasePlayer" -> {
                    releasePlayer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getAudioTracks(path: String, result: MethodChannel.Result) {
        trackSelector = DefaultTrackSelector(this)
        exoPlayer = ExoPlayer.Builder(this)
            .setTrackSelector(trackSelector!!)
            .build()

        val mediaItem = MediaItem.fromUri(Uri.parse(path))
        exoPlayer?.setMediaItem(mediaItem)
        exoPlayer?.prepare()

        var hasReplied = false
        val listener = object : androidx.media3.common.Player.Listener {
            override fun onTracksChanged(tracks: Tracks) {
                if (hasReplied) return
                hasReplied = true

                val audioTracks = mutableListOf<Map<String, Any>>()

                tracks.groups.forEachIndexed { groupIndex, trackGroup ->
                    if (trackGroup.type == C.TRACK_TYPE_AUDIO) {
                        // Check each track in the group
                        for (trackIndex in 0 until trackGroup.length) {
                            val format = trackGroup.getTrackFormat(trackIndex)
                            audioTracks.add(mapOf(
                                "groupIndex" to groupIndex,
                                "trackIndex" to trackIndex,
                                "language" to (format.language ?: "und"),
                                "label" to (format.label ?: format.language ?: "Audio ${audioTracks.size + 1}"),
                                "channelCount" to format.channelCount,
                                "sampleRate" to format.sampleRate,
                                "bitrate" to format.bitrate,
                                "codec" to (format.sampleMimeType ?: "unknown")
                            ))
                        }
                    }
                }

                result.success(audioTracks)
                exoPlayer?.removeListener(this)
            }
        }

        exoPlayer?.addListener(listener)
    }

    private fun setAudioTrack(groupIndex: Int) {
        trackSelector?.let { selector ->
            exoPlayer?.currentTracks?.groups?.getOrNull(groupIndex)?.let { trackGroup ->
                val builder = selector.parameters.buildUpon()
                builder.clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                builder.addOverride(
                    TrackSelectionOverride(trackGroup.mediaTrackGroup, listOf(0))
                )
                selector.setParameters(builder.build())
            }
        }
    }

    private fun releasePlayer() {
        exoPlayer?.release()
        exoPlayer = null
        trackSelector = null
    }

    override fun onDestroy() {
        super.onDestroy()
        releasePlayer()
    }
}