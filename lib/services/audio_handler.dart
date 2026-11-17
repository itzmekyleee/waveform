import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song_model.dart';
import 'storage_service.dart';

/// Direct [BaseAudioHandler] that owns a single [AudioPlayer] and broadcasts
/// queue/mediaItem/playbackState to audio_service (media notification,
/// lock screen, headset controls).
class WaveformAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final StorageService _storage;
  List<Song> _queue = [];
  int _currentIndex = -1;
  int _loadGeneration = 0;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  bool _isShuffle = false;

  AudioPlayer get player => _player;
  List<Song> get currentQueue => _queue;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  final StreamController<List<Song>> _queueController =
      StreamController<List<Song>>.broadcast();
  Stream<List<Song>> get queueStream => _queueController.stream;

  WaveformAudioHandler(this._storage) {
    _init();
  }

  void _init() {
    _player.playbackEventStream.listen(_onPlaybackEvent);
    _player.playingStream.listen((_) => _broadcastState());
  }

  void _onPlaybackEvent(PlaybackEvent event) {
    final index = event.currentIndex;
    if (index != null && index >= 0 && index < _queue.length) {
      if (_currentIndex != index) {
        _currentIndex = index;
        _syncCurrentTrackState();
      }
    }
    if (event.processingState == ProcessingState.completed) {
      handleNext();
    }
    _broadcastState();
  }

  Uri _playbackUri(Song song) {
    final contentUri = song.contentUri?.trim() ?? '';
    if (contentUri.isNotEmpty) {
      final uri = Uri.tryParse(contentUri);
      if (uri != null && uri.scheme.isNotEmpty) {
        return uri;
      }
    }

    final path = song.filePath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.tryParse(path);
      if (uri != null) return uri;
    }

    if (song.id > 0 && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse('content://media/external/audio/media/${song.id}');
    }

    if (path.isNotEmpty) {
      return Uri.file(path);
    }

    throw StateError('Song has no playable path or content URI');
  }

  MediaItem _mediaItemFor(Song song) {
    final albumId = song.albumId != null && song.albumId! > 0 ? song.albumId : null;
    return MediaItem(
      id: song.filePath,
      title: song.displayTitle,
      artist: song.displayArtist,
      album: song.displayAlbum,
      duration: song.durationMs > 0 ? song.duration : null,
      artUri: albumId != null
          ? Uri.parse('content://media/external/audio/albumart/$albumId')
          : null,
      extras: {
        'songId': song.id,
        'albumId': albumId,
      },
    );
  }

  void _updateQueue() {
    queue.add(_queue.map(_mediaItemFor).toList());
    _queueController.add(_queue);
    _broadcastState();
  }

  void _syncCurrentTrackState() {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      mediaItem.add(_mediaItemFor(_queue[_currentIndex]));
    }
    _queueController.add(_queue);
    _broadcastState();
  }

  AudioProcessingState get _processingState {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode get _serviceRepeatMode {
    switch (_repeatMode) {
      case AudioRepeatMode.off:
        return AudioServiceRepeatMode.none;
      case AudioRepeatMode.one:
        return AudioServiceRepeatMode.one;
      case AudioRepeatMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  void _broadcastState() {
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ];
    playbackState.add(
      PlaybackState(
        processingState: _processingState,
        playing: _player.playing &&
            _player.processingState == ProcessingState.ready,
        controls: controls,
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
        repeatMode: _serviceRepeatMode,
        shuffleMode:
            _isShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      ),
    );
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

  @override
  Future<void> skipToNext() async => handleNext();

  @override
  Future<void> skipToPrevious() async => handlePrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    await playAtQueueIndex(index);
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    _isShuffle = enabled;
    await _storage.setShuffleMode(enabled);
    if (!enabled || _queue.isEmpty) {
      _broadcastState();
      return;
    }

    final current = _queue[_currentIndex >= 0 ? _currentIndex : 0];
    final rest = _queue.where((s) => s.id != current.id).toList()..shuffle();
    _queue = [current, ...rest];
    _currentIndex = 0;
    _loadGeneration++;
    _updateQueue();

    await _loadQueueAndPlay(0);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _repeatMode = AudioRepeatMode.off;
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        _repeatMode = AudioRepeatMode.one;
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        _repeatMode = AudioRepeatMode.all;
        await _player.setLoopMode(LoopMode.all);
        break;
    }
    await _storage.setRepeatMode(_repeatMode.index);
    _broadcastState();
  }

  Future<void> playSongList(List<Song> songs,
      {int startIndex = 0, bool shuffle = false}) async {
    if (songs.isEmpty) return;

    final shouldShuffle = shuffle || _storage.shuffleMode;

    var queue = List<Song>.from(songs);
    var index = startIndex;
    if (index < 0 || index >= queue.length) index = 0;

    if (shouldShuffle && queue.length > 1) {
      final current = queue[index];
      queue.removeAt(index);
      queue.shuffle();
      queue.insert(0, current);
      index = 0;
    }

    _queue = queue;
    _currentIndex = index;
    _loadGeneration++;
    _updateQueue();

    await _loadQueueAndPlay(index);
  }

  Future<void> _loadQueueAndPlay(int index,
      {bool useFilePaths = false}) async {
    if (_queue.isEmpty) return;
    final generation = _loadGeneration;
    index = index.clamp(0, _queue.length - 1);
    _currentIndex = index;

    Duration? initialPosition;
    if (_queue[index].id == _storage.lastTrackId) {
      final lastPos = _storage.lastPosition;
      if (lastPos > 0 &&
          (_queue[index].durationMs <= 0 || lastPos < _queue[index].durationMs)) {
        initialPosition = Duration(milliseconds: lastPos);
      }
    }

    try {
      final audioSources = _queue
          .map((s) => AudioSource.uri(
                useFilePaths ? Uri.file(s.filePath) : _playbackUri(s),
                tag: _mediaItemFor(s),
              ))
          .toList();

      final firstUri = _queue[index].filePath.isNotEmpty
          ? _playbackUri(_queue[index])
          : Uri.file(_queue[index].filePath);
      debugPrint('Loading ${_queue.length} tracks, starting at index $index: $firstUri');

      await _player.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
        initialIndex: index,
        initialPosition: initialPosition,
        preload: false,
      );

      if (generation != _loadGeneration) return;

      _storage.setLastTrackId(currentSong?.id);
      await _storage.setLastQueue(_queue.map((s) => s.id).toList());

      _syncCurrentTrackState();
      await _player.play();
      debugPrint('play() returned without throwing');
    } catch (e) {
      debugPrint('playSongList error: $e');
      if (generation != _loadGeneration) return;
      if (!useFilePaths && _queue.isNotEmpty) {
        debugPrint('Retrying queue with raw file paths...');
        await _loadQueueAndPlay(index, useFilePaths: true);
      }
    }
  }

  Future<void> addToQueue(Song song) async {
    final insertAt = _currentIndex >= 0 ? _currentIndex + 1 : _queue.length;
    _queue.insert(insertAt, song);
    _updateQueue();
    final source =
        AudioSource.uri(_playbackUri(song), tag: _mediaItemFor(song));
    final concat = _player.audioSource as ConcatenatingAudioSource?;
    if (concat != null) {
      await concat.insert(insertAt, source);
    }
    await _storage.setLastQueue(_queue.map((s) => s.id).toList());
  }

  Future<void> playNext(Song song) async {
    final insertAt = _currentIndex + 1;
    _queue.insert(insertAt, song);
    _updateQueue();
    final source =
        AudioSource.uri(_playbackUri(song), tag: _mediaItemFor(song));
    final concat = _player.audioSource as ConcatenatingAudioSource?;
    if (concat != null) {
      await concat.insert(insertAt, source);
    }
    await _storage.setLastQueue(_queue.map((s) => s.id).toList());
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    _updateQueue();
    final concat = _player.audioSource as ConcatenatingAudioSource?;
    if (concat != null) {
      await concat.removeAt(index);
    }
    if (index < _currentIndex) {
      _currentIndex--;
    }
    await _storage.setLastQueue(_queue.map((s) => s.id).toList());
  }

  Future<void> reorderInQueue(int oldIndex, int newIndex) async {
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    _updateQueue();
    final concat = _player.audioSource as ConcatenatingAudioSource?;
    if (concat != null) {
      await concat.removeAt(oldIndex);
      await concat.insert(
        newIndex,
        AudioSource.uri(_playbackUri(song), tag: _mediaItemFor(song)),
      );
    }
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    await _storage.setLastQueue(_queue.map((s) => s.id).toList());
  }

  void handleNext() {
    if (_queue.isEmpty) return;
    var next = _currentIndex + 1;
    if (next >= _queue.length) {
      if (_repeatMode == AudioRepeatMode.all) {
        next = 0;
      } else {
        return;
      }
    }
    _currentIndex = next;
    _syncCurrentTrackState();
    _seekAndPlay(next);
  }

  Future<void> playAtQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _syncCurrentTrackState();
    await _seekAndPlay(index);
  }

  void handlePrevious() {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero).catchError((dynamic _) {});
      return;
    }
    var prev = _currentIndex - 1;
    if (prev < 0) {
      if (_repeatMode == AudioRepeatMode.all) {
        prev = _queue.length - 1;
      } else {
        return;
      }
    }
    _currentIndex = prev;
    _syncCurrentTrackState();
    _seekAndPlay(prev);
  }

  Future<void> _seekAndPlay(int index) async {
    try {
      if (_player.processingState == ProcessingState.loading) {
        await _player.processingStateStream
            .firstWhere((s) => s != ProcessingState.loading)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => ProcessingState.idle,
            );
      }
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      debugPrint('skip error: $e');
    }
  }

  void updateLastPosition() {
    if (currentSong != null) {
      _storage.setLastPosition(_player.position.inMilliseconds);
    }
  }
}

enum AudioRepeatMode { off, one, all }
