import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/album_art.dart';
import '../../widgets/song_actions_sheet.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../now_playing_screen.dart';

class SongsScreen extends StatefulWidget {
  final TextEditingController searchQuery;

  const SongsScreen({super.key, required this.searchQuery});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();

    return _buildBody(library, theme);
  }

  Widget _buildBody(LibraryProvider library, ThemeData theme) {
    final songs = library.songs;

    if (songs.isEmpty && library.isScanning) {
      return const SkeletonLoader(itemCount: 10, itemHeight: 64);
    }

    if (songs.isEmpty && library.searchQuery.isEmpty) {
      return EmptyState(
        icon: Icons.music_note_rounded,
        title: 'No songs found',
        subtitle: 'Tap the button below to scan your device for music files.',
        actionLabel: 'Scan Library',
        onAction: () => library.scanLibrary(),
      );
    }

    if (songs.isEmpty && library.searchQuery.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try a different search term.',
      );
    }

    return Column(
      children: [
        if (library.isScanning)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        Expanded(
          child: Selector<PlayerProvider, int?>(
            selector: (_, player) => player.currentSong?.id,
            builder: (context, currentSongId, _) {
              final player = context.read<PlayerProvider>();
              return RefreshIndicator(
                onRefresh: () => library.scanLibrary(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 60, top: 2),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isPlaying = currentSongId == song.id;
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('anim_${song.id}'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index % 20) * 30),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: SongTile(
                        song: song,
                        index: index + 1,
                        isPlaying: isPlaying,
                        onTap: () async {
                          await player.playSongList(songs, startIndex: index);
                          if (context.mounted) {
                            openNowPlaying(context);
                          }
                        },
                        trailing: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => showSongActionsSheet(
                            context,
                            header: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 12, 2),
                              child: Row(
                                children: [
                                  AlbumArtWidget(
                                    albumId: song.albumId,
                                    title: song.displayTitle,
                                    artist: song.displayArtist,
                                    filePath: song.filePath,
                                    contentUri: song.contentUri,
                                    size: 40,
                                    borderRadius: 10,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.displayTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          song.displayArtist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              (
                                icon: Icons.skip_next_rounded,
                                label: 'Play Next',
                                onTap: () => player.playNext(song),
                              ),
                              (
                                icon: Icons.queue_music_rounded,
                                label: 'Add to Queue',
                                onTap: () async {
                                  await player.addToQueue(song);
                                  if (context.mounted) {
                                    showAppToast(
                                      context,
                                      'Added to queue',
                                      icon: Icons.queue_music_rounded,
                                      severity: ToastSeverity.success,
                                    );
                                  }
                                },
                              ),
                              (
                                icon: Icons.favorite_rounded,
                                label: 'Add to Favorites',
                                onTap: () => context
                                    .read<PlaylistProvider>()
                                    .toggleFavorite(song.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
