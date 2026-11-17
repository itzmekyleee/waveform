import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import '../services/audio_handler.dart';
import '../services/storage_service.dart';
import 'library_provider.dart';

class PlayerProvider extends ChangeNotifier {
  final WaveformAudioHandler _audioHandler;
  final StorageService _storage;
  final LibraryProvider? _library;

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  AudioRepeatMode _repeatMode = AudioRepeatMode.off;
  double _volume = 1.0;
  bool _isMuted = false;
  Timer? _sleepTimer;
  int? _sleepTimerSecondsRemaining;
  StreamSubscription? _positionSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _queueSub;

  PlayerProvider(this._audioHandler, this._storage, [this._library]) {
    _init();
  }

  void _onDurationKnown(Duration duration) {
    if (duration.inMilliseconds <= 0) return;
    if (_duration != duration) {
      _duration = duration;
      notifyListeners();
    }
    final song = _currentSong;
    if (song != null && song.durationMs != duration.inMilliseconds) {
      _library?.updateSongDuration(song.id, duration.inMilliseconds);
    }
  }

  void _syncFromAudioHandler() {
    _queue = _audioHandler.currentQueue;
    _currentIndex = _audioHandler.currentIndex;
    _currentSong = _audioHandler.currentSong;
    _isPlaying = _audioHandler.player.playing;
    final duration = _audioHandler.player.duration;
    if (duration != null) {
      _onDurationKnown(duration);
    }
    _position = _audioHandler.player.position;
    notifyListeners();
  }

  void _init() {
    _volume = _storage.volume;
    _isShuffle = _storage.shuffleMode;
    _repeatMode = AudioRepeatMode.values[_storage.repeatMode.clamp(0, AudioRepeatMode.values.length - 1)];
    _audioHandler.player.setVolume(_isMuted ? 0.0 : _volume);
    if (_isShuffle) {
      _audioHandler.setShuffleModeEnabled(true);
    }

    _positionSub = _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
    });

    _playingSub = _audioHandler.player.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _durationSub = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
        _onDurationKnown(dur);
      }
    });

    _queueSub = _audioHandler.queueStream.listen((q) {
      _queue = q;
      _currentIndex = _audioHandler.currentIndex;
      _currentSong = _audioHandler.currentSong;
      notifyListeners();
    });

    _audioHandler.player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queue.length) {
        _currentIndex = index;
        _currentSong = _audioHandler.currentSong;
        _syncFromAudioHandler();
      }
    });

    _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final extras = item.extras;
        if (extras != null && extras['songId'] != null) {
          final song = _storage.getSong(extras['songId']);
          if (song != null) {
            _currentSong = song;
            _storage.setLastTrackId(song.id);
            notifyListeners();
          }
        }
      }
    });
  }

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffle => _isShuffle;
  AudioRepeatMode get repeatMode => _repeatMode;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  int? get sleepTimerSecondsRemaining => _sleepTimerSecondsRemaining;
  bool get hasCurrentSong => _currentSong != null;

  WaveformAudioHandler get audioHandler => _audioHandler;

  Future<void> play() async {
    await _audioHandler.play();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  Future<void> playSong(Song song) async {
    final songs = _storage.getAllSongs();
    final index = songs.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      await _audioHandler.playSongList(
          songs, startIndex: index, shuffle: _isShuffle);
    } else {
      await _audioHandler.playSongList([song], startIndex: 0);
    }
  }

  Future<void> playSongList(List<Song> songs, {int startIndex = 0, bool shuffle = false}) async {
    await _audioHandler.playSongList(
        songs, startIndex: startIndex, shuffle: _isShuffle || shuffle);
  }

  Future<void> skipToNext() async {
    _audioHandler.handleNext();
  }

  Future<void> skipToPrevious() async {
    _audioHandler.handlePrevious();
  }

  Future<void> playAtQueueIndex(int index) async {
    await _audioHandler.playAtQueueIndex(index);
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    await _audioHandler.setShuffleModeEnabled(_isShuffle);
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    switch (_repeatMode) {
      case AudioRepeatMode.off:
        _repeatMode = AudioRepeatMode.one;
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case AudioRepeatMode.one:
        _repeatMode = AudioRepeatMode.all;
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case AudioRepeatMode.all:
        _repeatMode = AudioRepeatMode.off;
        await _audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    _isMuted = _volume <= 0.0;
    await _audioHandler.player.setVolume(_isMuted ? 0.0 : _volume);
    await _storage.setVolume(_volume);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_isMuted) {
      _isMuted = false;
      final targetVolume = _volume > 0 ? _volume : 1.0;
      _volume = targetVolume;
      await _audioHandler.player.setVolume(targetVolume);
    } else {
      _isMuted = true;
      await _audioHandler.player.setVolume(0.0);
    }
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    await _audioHandler.addToQueue(song);
  }

  Future<void> playNext(Song song) async {
    await _audioHandler.playNext(song);
  }

  Future<void> removeFromQueue(int index) async {
    await _audioHandler.removeFromQueue(index);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _audioHandler.reorderInQueue(oldIndex, newIndex);
  }

  void startSleepTimer(int seconds) {
    cancelSleepTimer();
    _sleepTimerSecondsRemaining = seconds;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerSecondsRemaining != null && _sleepTimerSecondsRemaining! > 0) {
        _sleepTimerSecondsRemaining = _sleepTimerSecondsRemaining! - 1;
        notifyListeners();
      } else {
        cancelSleepTimer();
        pause();
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerSecondsRemaining = null;
    notifyListeners();
  }

  void updatePlayHistory(Song song) async {
    await _storage.incrementPlayCount(song.id);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _queueSub?.cancel();
    _sleepTimer?.cancel();
    _audioHandler.updateLastPosition();
    super.dispose();
  }
}
