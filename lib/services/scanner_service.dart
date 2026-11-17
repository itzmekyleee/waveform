import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/song_model.dart';
import '../utils/constants.dart';
import 'metadata_extractor.dart';

class ScannerService {
  static const int _maxProbesPerScan = 300;

  OnAudioQuery? _audioQuery;
  final Map<int, Uint8List?> _artCache = {};
  final Map<int, DateTime> _artFailed = {};
  final Set<int> _artLoading = {};

  final Map<String, Uint8List> _pathArtCache = {};
  final Map<String, DateTime> _pathArtFailed = {};

  final ValueNotifier<int> artVersion = ValueNotifier<int>(0);

  OnAudioQuery get audioQuery {
    _audioQuery ??= OnAudioQuery();
    return _audioQuery!;
  }

  int _scanGeneration = 0;

  void cancelScan() {
    _scanGeneration++;
  }

  void reset() {
    _artCache.clear();
    _artFailed.clear();
    _artLoading.clear();
    _pathArtCache.clear();
    _pathArtFailed.clear();
  }

  void notifyArtChanged() {
    artVersion.value++;
  }

  Future<List<Song>> scanAllSongs() async {
    final generation = _scanGeneration;
    final songs = await audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final result = <Song>[];
    var probed = 0;
    for (final audio in songs) {
      if (_scanGeneration != generation) break;
      if (!AppConstants.supportedExtensions.contains(audio.fileExtension.toLowerCase())) continue;
      if (audio.data.isEmpty) continue;

      var durationMs = audio.duration ?? 0;
      var contentUri = audio.uri;
      if (durationMs <= 0 && probed < _maxProbesPerScan) {
        probed++;
        final meta = await MetadataExtractor.getMediaMetadata(
          filePath: audio.data,
          contentUri: contentUri,
        );
        if (meta != null) {
          if (meta.durationMs != null && meta.durationMs! > 0) {
            durationMs = meta.durationMs!;
          }
          if (meta.artwork != null && meta.artwork!.isNotEmpty) {
            _pathArtCache[audio.data] = meta.artwork!;
          }
        }
      }

      final normalizedAlbumId = (audio.albumId != null && audio.albumId! > 0)
          ? audio.albumId
          : null;

      result.add(Song(
        id: audio.id,
        title: audio.title,
        artist: audio.artist ?? 'Unknown Artist',
        album: audio.album ?? 'Unknown Album',
        genre: audio.genre ?? 'Unknown',
        durationMs: durationMs > 0 ? durationMs : 0,
        filePath: audio.data,
        contentUri: contentUri,
        albumId: normalizedAlbumId,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(audio.dateAdded ?? 0),
        fileSize: audio.size,
      ));
    }

    return result;
  }

  Future<List<String>> detectMusicFolders() async {
    final songs = await audioQuery.querySongs(
      uriType: UriType.EXTERNAL,
    );

    final folders = <String>{};
    for (final song in songs) {
      final parts = song.data.split('/');
      if (parts.length > 1) {
        folders.add(parts.sublist(0, parts.length - 1).join('/'));
      }
    }
    return folders.toList()..sort();
  }

  Future<List<Song>> scanForChanges(List<Song> existingSongs) async {
    return scanAllSongs();
  }

  Future<Uint8List?> getAlbumArt(int albumId,
      {int size = 512, bool forceRetry = false}) async {
    if (albumId <= 0) return null;
    if (!forceRetry && _artCache.containsKey(albumId)) {
      return _artCache[albumId];
    }
    if (!forceRetry) {
      final failedAt = _artFailed[albumId];
      if (failedAt != null &&
          DateTime.now().difference(failedAt) < const Duration(seconds: 30)) {
        return null;
      }
    }
    if (_artLoading.contains(albumId)) {
      await Future.delayed(const Duration(milliseconds: 50));
      return getAlbumArt(albumId, size: size, forceRetry: forceRetry);
    }
    _artLoading.add(albumId);
    try {
      final result = await audioQuery.queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        size: size,
        quality: 100,
      );
      if (result != null && result.isNotEmpty) {
        _artCache[albumId] = result;
        _artFailed.remove(albumId);
      } else {
        _artFailed[albumId] = DateTime.now();
      }
      return result;
    } catch (_) {
      _artFailed[albumId] = DateTime.now();
      return null;
    } finally {
      _artLoading.remove(albumId);
    }
  }

  Future<Uint8List?> getSongArtwork(
    String filePath, {
    String? contentUri,
    bool forceRetry = false,
  }) async {
    if (filePath.isEmpty) return null;
    if (_pathArtCache.containsKey(filePath)) {
      return _pathArtCache[filePath];
    }
    if (!forceRetry) {
      final failedAt = _pathArtFailed[filePath];
      if (failedAt != null &&
          DateTime.now().difference(failedAt) < const Duration(seconds: 30)) {
        return null;
      }
    }
    try {
      final meta = await MetadataExtractor.getMediaMetadata(
        filePath: filePath,
        contentUri: contentUri,
      );
      final artwork = meta?.artwork;
      if (artwork != null && artwork.isNotEmpty) {
        _pathArtCache[filePath] = artwork;
        return artwork;
      }
      _pathArtFailed[filePath] = DateTime.now();
      return null;
    } catch (_) {
      _pathArtFailed[filePath] = DateTime.now();
      return null;
    }
  }
}
