import 'package:hive/hive.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../utils/constants.dart';

class StorageService {
  late Box _settingsBox;
  late Box<Song> _songBox;
  late Box<Playlist> _playlistBox;
  late Box<int> _favoritesBox;

  Future<void> init() async {
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    _songBox = await Hive.openBox<Song>(AppConstants.songBox);
    _playlistBox = await Hive.openBox<Playlist>(AppConstants.playlistBox);
    _favoritesBox = await Hive.openBox<int>(AppConstants.favoritesBox);
  }

  // Settings
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  bool get hasCompletedOnboarding =>
      getSetting(AppConstants.settingHasCompletedOnboarding, defaultValue: false);

  Future<void> completeOnboarding() =>
      setSetting(AppConstants.settingHasCompletedOnboarding, true);

  double get volume => getSetting(AppConstants.settingVolume, defaultValue: 1.0);
  Future<void> setVolume(double v) => setSetting(AppConstants.settingVolume, v);

  int? get lastTrackId => getSetting(AppConstants.settingLastTrackId);
  Future<void> setLastTrackId(int? id) => setSetting(AppConstants.settingLastTrackId, id);

  int get lastPosition => getSetting(AppConstants.settingLastPosition, defaultValue: 0);
  Future<void> setLastPosition(int ms) => setSetting(AppConstants.settingLastPosition, ms);

  List<int> get lastQueue => (getSetting(AppConstants.settingLastQueue) as List?)?.cast<int>() ?? [];
  Future<void> setLastQueue(List<int> ids) => setSetting(AppConstants.settingLastQueue, ids);

  bool get shuffleMode => getSetting(AppConstants.settingShuffleMode, defaultValue: false);
  Future<void> setShuffleMode(bool v) => setSetting(AppConstants.settingShuffleMode, v);

  int get repeatMode => getSetting(AppConstants.settingRepeatMode, defaultValue: 0);
  Future<void> setRepeatMode(int v) => setSetting(AppConstants.settingRepeatMode, v);

  List<String> get scannedFolders =>
      (getSetting(AppConstants.settingScannedFolders) as List?)?.cast<String>() ?? [];
  Future<void> setScannedFolders(List<String> folders) =>
      setSetting(AppConstants.settingScannedFolders, folders);

  String get themeMode => getSetting(AppConstants.settingThemeMode, defaultValue: 'system');
  Future<void> setThemeMode(String v) => setSetting(AppConstants.settingThemeMode, v);

  bool get showQueueSidebar => getSetting(AppConstants.settingShowQueueSidebar, defaultValue: true);
  Future<void> setShowQueueSidebar(bool v) => setSetting(AppConstants.settingShowQueueSidebar, v);

  bool get hideSidebarOnNowPlaying => getSetting(AppConstants.settingHideSidebarOnNowPlaying, defaultValue: false);
  Future<void> setHideSidebarOnNowPlaying(bool v) => setSetting(AppConstants.settingHideSidebarOnNowPlaying, v);

  // Songs
  List<Song> getAllSongs() => _songBox.values.toList();

  Song? getSong(int id) => _songBox.get(id);

  Future<void> saveSongs(List<Song> songs) async {
    for (final song in songs) {
      final existing = _songBox.get(song.id);
      if (existing != null) {
        song.playCount = existing.playCount;
        song.lastPlayed = existing.lastPlayed;
      }
      await _songBox.put(song.id, song);
    }
  }

  Future<void> removeSong(int id) async => _songBox.delete(id);

  Future<void> setSongDuration(int id, int durationMs) async {
    final song = _songBox.get(id);
    if (song != null && song.durationMs != durationMs) {
      song.durationMs = durationMs;
      await _songBox.put(id, song);
    }
  }

  Future<void> clearSongs() async => _songBox.clear();

  Future<void> incrementPlayCount(int songId) async {
    final song = _songBox.get(songId);
    if (song != null) {
      song.playCount++;
      song.lastPlayed = DateTime.now();
      await _songBox.put(songId, song);
    }
  }

  // Playlists
  List<Playlist> getAllPlaylists() => _playlistBox.values.toList();

  Playlist? getPlaylist(String id) => _playlistBox.get(id);

  Future<void> savePlaylist(Playlist playlist) async {
    playlist.dateModified = DateTime.now();
    await _playlistBox.put(playlist.id, playlist);
  }

  Future<void> deletePlaylist(String id) async => _playlistBox.delete(id);

  // Favorites
  Set<int> get favoriteIds => _favoritesBox.values.toSet();

  bool isFavorite(int songId) => _favoritesBox.containsKey(songId);

  Future<void> toggleFavorite(int songId) async {
    if (_favoritesBox.containsKey(songId)) {
      await _favoritesBox.delete(songId);
    } else {
      await _favoritesBox.put(songId, songId);
    }
  }

  List<Song> getFavoriteSongs() {
    final ids = favoriteIds;
    return _songBox.values.where((s) => ids.contains(s.id)).toList();
  }

  List<Song> getRecentlyPlayed({int limit = 50}) {
    final songs = _songBox.values
        .where((s) => s.lastPlayed != null)
        .toList()
      ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return songs.take(limit).toList();
  }

  List<Song> getMostPlayed({int limit = 50}) {
    final songs = _songBox.values.where((s) => s.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return songs.take(limit).toList();
  }
}
