import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/album_art.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/player_bar.dart';
import '../../utils/helpers.dart';
import '../now_playing_screen.dart';

class AlbumsScreen extends StatelessWidget {
  final TextEditingController searchQuery;

  const AlbumsScreen({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final query = searchQuery.text.toLowerCase();

    if (library.isLoading) {
      return const SkeletonLoader(itemCount: 8, itemHeight: 88);
    }

    final albumsMap = <String, List<Song>>{};
    for (final song in library.allSongs) {
      albumsMap.putIfAbsent(song.displayAlbum, () => []).add(song);
    }
    var albums = albumsMap.keys.toList()..sort();

    if (query.isNotEmpty) {
      albums = albums
          .where((a) => a.toLowerCase().contains(query))
          .toList();
    }

    if (albums.isEmpty) {
      return EmptyState(
        icon: query.isNotEmpty ? Icons.search_off_rounded : Icons.album_rounded,
        title: query.isNotEmpty ? 'No albums found' : 'No albums found',
        subtitle: query.isNotEmpty
            ? 'Try a different search term.'
            : 'Albums will appear once your music library is scanned.',
        actionLabel: query.isNotEmpty ? null : 'Scan Library',
        onAction: query.isNotEmpty ? null : () => library.scanLibrary(),
      );
    }

    return _AlbumsGrid(albums: albums, albumsMap: albumsMap);
  }
}

class _AlbumsGrid extends StatelessWidget {
  final List<String> albums;
  final Map<String, List<Song>> albumsMap;

  const _AlbumsGrid({required this.albums, required this.albumsMap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxCardWidth = 200.0;
        final totalPadding = 32.0;
        final spacing = 16.0;
        final availableWidth = width - totalPadding;
        final crossAxisCount =
            (availableWidth / (maxCardWidth + spacing)).floor().clamp(2, 8);
        final cardWidth =
            (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 20,
            childAspectRatio: cardWidth / (cardWidth + 56),
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final albumName = albums[index];
            final albumSongs = albumsMap[albumName]!;
            final songCount = albumSongs.length;
            final artist =
                albumSongs.isNotEmpty ? albumSongs.first.displayArtist : '';

            return RepaintBoundary(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _AlbumDetailScreen(
                        albumName: albumName,
                        songs: albumSongs,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: 'album_art_$albumName',
                        child: AlbumArtWidget(
                          albumId: albumSongs.first.albumId,
                          title: albumName,
                          artist: artist,
                          filePath: albumSongs.first.filePath,
                          contentUri: albumSongs.first.contentUri,
                          size: cardWidth,
                          borderRadius: 12,
                          querySize: 256,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        albumName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '$songCount songs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AlbumDetailScreen extends StatelessWidget {
  final String albumName;
  final List<Song> songs;

  const _AlbumDetailScreen({required this.albumName, required this.songs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.read<PlayerProvider>();
    final artist = songs.isNotEmpty ? songs.first.displayArtist : '';
    final artColor = AppHelpers.generateArtColor(albumName);

    return Scaffold(
      bottomNavigationBar: const SafeArea(child: PlayerBar()),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                albumName,
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
                      artColor.withValues(alpha: 0.5),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'album_art_$albumName',
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: AlbumArtWidget(
                          albumId: songs.first.albumId,
                          title: albumName,
                          artist: artist,
                          filePath: songs.first.filePath,
                          contentUri: songs.first.contentUri,
                          size: 200,
                          borderRadius: 14,
                          querySize: 512,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 12),
            sliver: SliverList(
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
          ),
        ],
      ),
    );
  }
}
