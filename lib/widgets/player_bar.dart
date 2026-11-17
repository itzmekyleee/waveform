import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'mini_player.dart';

typedef _SongIdentity = ({
  int? id,
  String title,
  String artist,
  String album,
  int? albumId,
  String filePath,
  String? contentUri,
});

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerProvider, _SongIdentity?>((p) {
      final s = p.currentSong;
      if (s == null) return null;
      return (
        id: s.id,
        title: s.displayTitle,
        artist: s.displayArtist,
        album: s.displayAlbum,
        albumId: s.albumId,
        filePath: s.filePath,
        contentUri: s.contentUri,
      );
    });
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final hasSong =
        context.select<PlayerProvider, bool>((p) => p.hasCurrentSong);

    return MiniPlayer(
      title: song?.title,
      artist: song?.artist,
      album: song?.album,
      albumId: song?.albumId,
      filePath: song?.filePath,
      contentUri: song?.contentUri,
      isPlaying: isPlaying,
      onTap: () {
        if (hasSong) openNowPlaying(context);
      },
      onPlayPause: () => context.read<PlayerProvider>().togglePlayPause(),
      onPrev: () => context.read<PlayerProvider>().skipToPrevious(),
      onNext: () => context.read<PlayerProvider>().skipToNext(),
      onSwipeLeft: () => context.read<PlayerProvider>().skipToNext(),
      onSwipeRight: () => context.read<PlayerProvider>().skipToPrevious(),
    );
  }
}
