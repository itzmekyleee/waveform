import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/album_art.dart';
import '../../widgets/empty_state.dart';
import '../../utils/helpers.dart';
import '../../widgets/player_bar.dart';
import '../now_playing_screen.dart';

class ArtistsScreen extends StatelessWidget {
  final TextEditingController searchQuery;

  const ArtistsScreen({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final query = searchQuery.text.toLowerCase();

    if (library.isLoading) {
      return const SkeletonLoader(itemCount: 8, itemHeight: 72);
    }

    var artists = library.artists;

    if (query.isNotEmpty) {
      artists = artists
          .where((a) => a.toLowerCase().contains(query))
          .toList();
    }

    if (artists.isEmpty) {
      return EmptyState(
        icon: query.isNotEmpty ? Icons.search_off_rounded : Icons.person_rounded,
        title: query.isNotEmpty ? 'No artists found' : 'No artists found',
        subtitle: query.isNotEmpty
            ? 'Try a different search term.'
            : 'Artists will appear once your music library is scanned.',
        actionLabel: query.isNotEmpty ? null : 'Scan Library',
        onAction: query.isNotEmpty ? null : () => library.scanLibrary(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 60, top: 2),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artistName = artists[index];
        final artistSongs = library.getSongsByArtist(artistName);
        final albumCount =
            artistSongs.map((s) => s.displayAlbum).toSet().length;
        final firstSong = artistSongs.isNotEmpty ? artistSongs.first : null;

        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ArtistDetailScreen(
                      artistName: artistName,
                      songs: artistSongs,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipOval(
                      child: AlbumArtWidget(
                        albumId: firstSong?.albumId,
                        title: artistName,
                        artist: artistName,
                        filePath: firstSong?.filePath,
                        contentUri: firstSong?.contentUri,
                        size: 56,
                        borderRadius: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${artistSongs.length} songs • $albumCount albums',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArtistDetailScreen extends StatelessWidget {
  final String artistName;
  final List<Song> songs;

  const _ArtistDetailScreen({required this.artistName, required this.songs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.read<PlayerProvider>();
    final artColor = AppHelpers.generateArtColor(artistName);

    return Scaffold(
      bottomNavigationBar: const SafeArea(child: PlayerBar()),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      artColor.withValues(alpha: 0.3),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: artColor.withValues(alpha: 0.2),
                    child: Text(
                      AppHelpers.getInitials(artistName),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: artColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return SongTile(
                  song: songs[index],
                  index: index + 1,
                  isPlaying: player.currentSong?.id == songs[index].id,
                  onTap: () async {
                    await player.playSongList(songs, startIndex: index);
                    if (context.mounted) {
                      openNowPlaying(context);
                    }
                  },
                );
              },
              childCount: songs.length,
            ),
          ),
        ],
      ),
    );
  }
}
