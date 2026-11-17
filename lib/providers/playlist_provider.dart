import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/smart_playlist.dart';
import '../services/storage_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final StorageService _storage;

  List<Playlist> _playlists = [];
  Set<int> _favoriteIds = {};

  PlaylistProvider(this._storage);

  List<Playlist> get playlists => _playlists;
  Set<int> get favoriteIds => _favoriteIds;

  void loadPlaylists() {
    _playlists = _storage.getAllPlaylists();
    _favoriteIds = _storage.favoriteIds;
    notifyListeners();
  }

  Playlist createPlaylist(String name) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final playlist = Playlist(id: id, name: name);
    _playlists.add(playlist);
    _storage.savePlaylist(playlist);
    notifyListeners();
    return playlist;
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final old = _playlists[index];
      final updated = old.copyWith(name: newName);
      _playlists[index] = updated;
      await _storage.savePlaylist(updated);
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _storage.deletePlaylist(id);
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final playlist = _playlists[index];
      if (!playlist.songIds.contains(songId)) {
        playlist.songIds.add(songId);
        playlist.dateModified = DateTime.now();
        await _storage.savePlaylist(playlist);
        notifyListeners();
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final playlist = _playlists[index];
      playlist.songIds.remove(songId);
      playlist.dateModified = DateTime.now();
      await _storage.savePlaylist(playlist);
      notifyListeners();
    }
  }

  Future<void> reorderSongInPlaylist(String playlistId, int oldIndex, int newIndex) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final playlist = _playlists[index];
      final songId = playlist.songIds.removeAt(oldIndex);
      playlist.songIds.insert(newIndex, songId);
      playlist.dateModified = DateTime.now();
      await _storage.savePlaylist(playlist);
      notifyListeners();
    }
  }

  List<Song> getSongsInPlaylist(String playlistId, List<Song> allSongs) {
    final playlist = _playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => Playlist(id: '', name: ''),
    );
    final songIds = playlist.songIds;
    final result = <Song>[];
    for (final id in songIds) {
      try {
        result.add(allSongs.firstWhere((s) => s.id == id));
      } catch (_) {}
    }
    return result;
  }

  bool isFavorite(int songId) => _favoriteIds.contains(songId);

  Future<void> toggleFavorite(int songId) async {
    if (_favoriteIds.contains(songId)) {
      _favoriteIds.remove(songId);
    } else {
      _favoriteIds.add(songId);
    }
    notifyListeners();
    await _storage.toggleFavorite(songId);
  }

  List<Song> getFavoriteSongs() => _storage.getFavoriteSongs();

  List<Song> getRecentlyPlayed({int limit = 50}) => _storage.getRecentlyPlayed(limit: limit);

  List<Song> getMostPlayed({int limit = 50}) => _storage.getMostPlayed(limit: limit);

  void reorderPlaylists(int oldIndex, int newIndex) {
    final playlist = _playlists.removeAt(oldIndex);
    _playlists.insert(newIndex, playlist);
    notifyListeners();
  }

  List<Song> getSmartPlaylistSongs(SmartPlaylistType type, List<Song> allSongs) {
    switch (type) {
      case SmartPlaylistType.recentlyAdded:
        final sorted = List<Song>.from(allSongs)
          ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        return sorted.take(50).toList();
      case SmartPlaylistType.mostPlayed:
        final sorted = List<Song>.from(allSongs)
          ..sort((a, b) => b.playCount.compareTo(a.playCount));
        return sorted.where((s) => s.playCount > 0).take(50).toList();
      case SmartPlaylistType.recentlyPlayed:
        final sorted = List<Song>.from(allSongs)
          ..sort((a, b) {
            if (a.lastPlayed == null && b.lastPlayed == null) return 0;
            if (a.lastPlayed == null) return 1;
            if (b.lastPlayed == null) return -1;
            return b.lastPlayed!.compareTo(a.lastPlayed!);
          });
        return sorted.where((s) => s.lastPlayed != null).take(50).toList();
      case SmartPlaylistType.recentAlbums:
        final seen = <String>{};
        final sorted = List<Song>.from(allSongs)
          ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        return sorted.where((s) {
          final key = s.album.toLowerCase();
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).take(50).toList();
      case SmartPlaylistType.recentArtists:
        final seen = <String>{};
        final sorted = List<Song>.from(allSongs)
          ..sort((a, b) {
            if (a.lastPlayed == null && b.lastPlayed == null) return 0;
            if (a.lastPlayed == null) return 1;
            if (b.lastPlayed == null) return -1;
            return b.lastPlayed!.compareTo(a.lastPlayed!);
          });
        return sorted.where((s) {
          final key = s.artist.toLowerCase();
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).take(50).toList();
    }
  }
}
