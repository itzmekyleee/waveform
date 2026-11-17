import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaMetadata {
  final int? durationMs;
  final Uint8List? artwork;

  const MediaMetadata({this.durationMs, this.artwork});
}

class MetadataExtractor {
  MetadataExtractor._();

  static const MethodChannel _channel =
      MethodChannel('com.example.waveform/metadata');

  static Future<MediaMetadata?> getMediaMetadata({
    String? filePath,
    String? contentUri,
  }) async {
    if ((filePath == null || filePath.isEmpty) &&
        (contentUri == null || contentUri.isEmpty)) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getMediaMetadata',
        {
          'filePath': filePath,
          'contentUri': contentUri,
        },
      );
      if (result == null) return null;
      return MediaMetadata(
        durationMs: result['durationMs'] as int?,
        artwork: result['artwork'] as Uint8List?,
      );
    } catch (e) {
      debugPrint('MetadataExtractor error: $e');
      return null;
    }
  }
}
