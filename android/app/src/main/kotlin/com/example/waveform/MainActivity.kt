package com.example.waveform

import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.waveform/metadata",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getMediaMetadata") {
                extractMediaMetadata(call, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun extractMediaMetadata(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: run {
            result.success(null)
            return
        }
        val filePath = args["filePath"] as? String
        val contentUri = args["contentUri"] as? String

        Thread {
            val retriever = MediaMetadataRetriever()
            try {
                var set = false
                if (!contentUri.isNullOrBlank()) {
                    try {
                        retriever.setDataSource(this, Uri.parse(contentUri))
                        set = true
                    } catch (_: Exception) {
                        set = false
                    }
                }
                if (!set && !filePath.isNullOrBlank()) {
                    try {
                        retriever.setDataSource(filePath)
                        set = true
                    } catch (_: Exception) {
                        set = false
                    }
                }
                if (!set) {
                    result.success(null)
                    return@Thread
                }

                val durationMs = try {
                    retriever
                        .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                        ?.toLongOrNull()
                        ?.toInt()
                } catch (_: Exception) {
                    null
                }

                val artwork = try {
                    retriever.embeddedPicture
                } catch (_: Exception) {
                    null
                }

                result.success(
                    mapOf(
                        "durationMs" to durationMs,
                        "artwork" to artwork,
                    ),
                )
            } catch (e: Exception) {
                Log.w("WaveformMetadata", "Error extracting metadata", e)
                result.success(null)
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {
                    // Ignore release failures.
                }
            }
        }.start()
    }
}
