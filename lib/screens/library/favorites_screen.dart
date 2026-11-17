import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/empty_state.dart';
import '../now_playing_screen.dart';

class FavoritesScreen extends StatelessWidget {
  final TextEditingController searchQuery;

  const FavoritesScreen({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final player = context.read<PlayerProvider>();
    final query = searchQuery.text.toLowerCase();

    var favorites = playlistProvider.getFavoriteSongs();

    if (query.isNotEmpty) {
      favorites = favorites
          .where((s) =>
              s.displayTitle.toLowerCase().contains(query) ||
              s.displayArtist.toLowerCase().contains(query))
          .toList();
    }

    return favorites.isEmpty
        ? EmptyState(
            icon: query.isNotEmpty ? Icons.search_off_rounded : Icons.favorite_border_rounded,
            title: query.isNotEmpty ? 'No favorites found' : 'No favorites yet',
            subtitle: query.isNotEmpty
                ? 'Try a different search term.'
                : 'Tap the heart icon on any song to add it to your favorites.',
          )
        : Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
                  child: FilledButton.tonalIcon(
                    onPressed: () => player.playSongList(favorites),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play All'),
                  ),
                ),
              ),
              Expanded(
                child: Selector<PlayerProvider, int?>(
                  selector: (_, p) => p.currentSong?.id,
                  builder: (context, currentSongId, _) {
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 60),
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final song = favorites[index];
                        final isPlaying = currentSongId == song.id;
                        return SongTile(
                          song: song,
                          index: index + 1,
                          isPlaying: isPlaying,
                          onTap: () async {
                            await player.playSongList(favorites, startIndex: index);
                            if (context.mounted) {
                              openNowPlaying(context);
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.favorite_rounded,
                                color: Colors.red, size: 20),
                            onPressed: () =>
                                playlistProvider.toggleFavorite(song.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
  }
}
