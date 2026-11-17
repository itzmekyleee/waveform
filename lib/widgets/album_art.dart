import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scanner_service.dart';
import '../utils/helpers.dart';

class AlbumArtWidget extends StatefulWidget {
  final int? albumId;
  final String title;
  final String artist;
  final String? filePath;
  final String? contentUri;
  final double size;
  final double borderRadius;
  final bool isPlaying;
  final int querySize;

  const AlbumArtWidget({
    super.key,
    this.albumId,
    this.filePath,
    this.contentUri,
    required this.title,
    required this.artist,
    this.size = 56,
    this.borderRadius = 12,
    this.isPlaying = false,
    this.querySize = 512,
  });

  @override
  State<AlbumArtWidget> createState() => _AlbumArtWidgetState();
}

class _AlbumArtWidgetState extends State<AlbumArtWidget> {
  Future<Uint8List?>? _cachedFuture;
  int? _cachedAlbumId;
  String? _cachedFilePath;
  int _retryCount = 0;
  ScannerService? _scanner;

  @override
  void initState() {
    super.initState();
    _loadArt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scanner = context.read<ScannerService>();
    if (!identical(_scanner, scanner)) {
      _scanner?.artVersion.removeListener(_onArtVersionChanged);
      _scanner = scanner;
      scanner.artVersion.addListener(_onArtVersionChanged);
    }
  }

  void _onArtVersionChanged() {
    if (!mounted) return;
    setState(() {
      _retryCount = 0;
      _loadArt(forceRetry: true);
    });
  }

  @override
  void didUpdateWidget(AlbumArtWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.albumId != _cachedAlbumId ||
        widget.filePath != _cachedFilePath) {
      _retryCount = 0;
      _loadArt();
    }
  }

  @override
  void dispose() {
    _scanner?.artVersion.removeListener(_onArtVersionChanged);
    super.dispose();
  }

  void _loadArt({bool forceRetry = false}) {
    _cachedAlbumId = widget.albumId;
    _cachedFilePath = widget.filePath;
    final scanner = _scanner ?? context.read<ScannerService>();
    _cachedFuture = _resolveArt(scanner, forceRetry).then((bytes) {
      if (bytes == null && mounted && _retryCount < 2) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() {
              _retryCount++;
              _loadArt(forceRetry: true);
            });
          }
        });
      }
      return bytes;
    });
  }

  Future<Uint8List?> _resolveArt(
      ScannerService scanner, bool forceRetry) async {
    final albumId = widget.albumId;
    if (albumId != null && albumId > 0) {
      final art = await scanner.getAlbumArt(
        albumId,
        size: widget.querySize,
        forceRetry: forceRetry || _retryCount > 0,
      );
      if (art != null && art.isNotEmpty) return art;
    }
    final path = widget.filePath;
    if (path != null && path.isNotEmpty) {
      final art = await scanner.getSongArtwork(
        path,
        contentUri: widget.contentUri,
        forceRetry: forceRetry || _retryCount > 0,
      );
      if (art != null && art.isNotEmpty) return art;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        AppHelpers.generateArtGradient('${widget.title}${widget.artist}');
    final initials = AppHelpers.getInitials(widget.title);

    if (_cachedAlbumId == null && _cachedFilePath == null) {
      return _buildGradient(colors, initials);
    }

    return FutureBuilder<Uint8List?>(
      future: _cachedFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final decodeSize = ((widget.size * dpr).round() & ~1).clamp(32, 2048);
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                cacheWidth: decodeSize,
                errorBuilder: (_, _, _) => _buildGradient(colors, initials),
              ),
            ),
          );
        }
        return _buildGradient(colors, initials);
      },
    );
  }

  Widget _buildGradient(List<Color> colors, String initials) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w700,
            fontSize: widget.size * 0.35,
          ),
        ),
      ),
    );
  }
}
