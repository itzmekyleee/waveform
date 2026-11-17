import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final ScannerService _scanner;
  final StorageService _storage;

  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  bool _isLoading = false;
  bool _isScanning = false;
  String _searchQuery = '';
  String _sortField = 'title';
  bool _sortAscending = true;

  String get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  DateTime? _lastScanTime;

  LibraryProvider(this._scanner, this._storage);

  List<Song> get allSongs => _allSongs;
  List<Song> get songs => _searchQuery.isEmpty ? _sortedAll : _sortedFiltered;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String get searchQuery => _searchQuery;

  String _dedupeKey(Song s) =>
      '${s.title.trim().toLowerCase()}|${s.artist.trim().toLowerCase()}|${s.album.trim().toLowerCase()}';

  List<Song> _dedupe(List<Song> songs) {
    final seen = <String>{};
    final result = <Song>[];
    for (final s in songs) {
      if (seen.add(_dedupeKey(s))) {
        result.add(s);
      }
    }
    return result;
  }

  List<Song> _applySort(List<Song> list) {
    final result = List<Song>.from(list);
    switch (_sortField) {
      case 'title':
        result.sort((a, b) => _sortAscending
            ? a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase())
            : b.displayTitle.toLowerCase().compareTo(a.displayTitle.toLowerCase()));
        break;
      case 'artist':
        result.sort((a, b) => _sortAscending
            ? a.displayArtist.toLowerCase().compareTo(b.displayArtist.toLowerCase())
            : b.displayArtist.toLowerCase().compareTo(a.displayArtist.toLowerCase()));
        break;
      case 'album':
        result.sort((a, b) => _sortAscending
            ? a.displayAlbum.toLowerCase().compareTo(b.displayAlbum.toLowerCase())
            : b.displayAlbum.toLowerCase().compareTo(a.displayAlbum.toLowerCase()));
        break;
      case 'date_added':
        result.sort((a, b) => _sortAscending
            ? a.dateAdded.compareTo(b.dateAdded)
            : b.dateAdded.compareTo(a.dateAdded));
        break;
      case 'duration':
        result.sort((a, b) => _sortAscending
            ? a.durationMs.compareTo(b.durationMs)
            : b.durationMs.compareTo(a.durationMs));
        break;
      default:
        result.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
    }
    return result;
  }

  List<Song> get _sortedAll => _applySort(_allSongs);
  List<Song> get _sortedFiltered => _applySort(_filteredSongs);

  List<String> get artists => _allSongs.map((s) => s.displayArtist).toSet().toList()..sort();
  List<String> get genres => _allSongs.map((s) => s.genre).toSet().where((g) => g.isNotEmpty && g != 'Unknown').toList()..sort();

  List<String> get albums {
    final albumSet = <String>{};
    for (final song in _allSongs) {
      albumSet.add(song.displayAlbum);
    }
    return albumSet.toList()..sort();
  }

  List<String> get folders {
    final folderSet = <String>{};
    for (final song in _allSongs) {
      final parts = song.filePath.split('/');
      if (parts.length > 1) {
        folderSet.add(parts.sublist(0, parts.length - 1).join('/'));
      }
    }
    return folderSet.toList()..sort();
  }

  List<Song> getSongsByArtist(String artist) =>
      _allSongs.where((s) => s.displayArtist == artist).toList();

  List<Song> getSongsByAlbum(String album) =>
      _allSongs.where((s) => s.displayAlbum == album).toList();

  List<Song> getSongsByGenre(String genre) =>
      _allSongs.where((s) => s.genre == genre).toList();

  List<Song> getSongsByFolder(String folder) =>
      _allSongs.where((s) {
        final parts = s.filePath.split('/');
        return parts.sublist(0, parts.length - 1).join('/') == folder;
      }).toList();

  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();

    _allSongs = _dedupe(_storage.getAllSongs());
    notifyListeners();

    await scanLibrary();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> scanLibrary() async {
    final active = _activeScan;
    if (active != null) {
      return active;
    }

    _isScanning = true;
    notifyListeners();

    final future = _doScan();
    _activeScan = future;
    try {
      await future;
    } finally {
      _activeScan = null;
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<void>? _activeScan;

  Future<void> _doScan() async {
    try {
      _scanner.cancelScan();
      _scanner.reset();
      final songs = await _scanner
          .scanAllSongs()
          .timeout(const Duration(seconds: 60));
      _allSongs = _dedupe(songs);
      _lastScanTime = DateTime.now();
      await _storage.saveSongs(songs);
      _scanner.notifyArtChanged();
    } on TimeoutException {
      _scanner.cancelScan();
      debugPrint('Library scan timed out');
    } catch (e) {
      debugPrint('Error scanning library: $e');
    }
  }

  void search(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredSongs = [];
    } else {
      final q = query.toLowerCase();
      _filteredSongs = _allSongs.where((s) {
        return s.displayTitle.toLowerCase().contains(q) ||
            s.displayArtist.toLowerCase().contains(q) ||
            s.displayAlbum.toLowerCase().contains(q) ||
            s.genre.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }

  void setSortField(String field) {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = true;
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredSongs = [];
    notifyListeners();
  }

  Song? getSongById(int id) {
    try {
      return _allSongs.firstWhere((s) => s.id == id);
    } catch (_) {
      return _storage.getSong(id);
    }
  }

  void updateSongDuration(int id, int durationMs) {
    if (durationMs <= 0) return;
    final index = _allSongs.indexWhere((s) => s.id == id);
    if (index >= 0 && _allSongs[index].durationMs != durationMs) {
      _allSongs[index].durationMs = durationMs;
      notifyListeners();
    }
    _storage.setSongDuration(id, durationMs);
  }

  Future<void> rescanOnResume() async {
    if (_lastScanTime != null && DateTime.now().difference(_lastScanTime!) < const Duration(minutes: 5)) {
      return;
    }
    final currentCount = _allSongs.length;
    await scanLibrary();
    if (_allSongs.length != currentCount) {
      debugPrint('Library changed: $currentCount -> ${_allSongs.length} songs');
    }
  }
}
