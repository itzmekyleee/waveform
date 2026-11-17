import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_provider.dart';
import '../../models/playlist_model.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/song_actions_sheet.dart';
import '../../widgets/player_bar.dart';
import '../../widgets/empty_state.dart';
import '../now_playing_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final player = context.read<PlayerProvider>();
    final library = context.watch<LibraryProvider>();

    final playlist = playlistProvider.playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => throw Exception('Playlist not found'),
    );

    final songs = playlistProvider.getSongsInPlaylist(
      playlistId,
      library.allSongs,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => player.playSongList(songs),
              tooltip: 'Play all',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _showRenameDialog(context, playlist, playlistProvider);
                  break;
                case 'delete':
                  _confirmDelete(context, playlist, playlistProvider);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(child: PlayerBar()),
      body: songs.isEmpty
          ? EmptyState(
              icon: Icons.music_note_rounded,
              title: 'Empty playlist',
              subtitle:
                  'Add songs from the songs screen to fill this playlist.',
            )
          : Selector<PlayerProvider, int?>(
              selector: (_, p) => p.currentSong?.id,
              builder: (context, currentSongId, _) {
                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 60),
                  itemCount: songs.length,
                  onReorderItem: (oldIndex, newIndex) {
                    playlistProvider.reorderSongInPlaylist(
                      playlistId,
                      oldIndex,
                      newIndex,
                    );
                  },
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return SongTile(
                      key: ValueKey('${song.id}_$index'),
                      song: song,
                      index: index + 1,
                      isPlaying: currentSongId == song.id,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => showSongActionsSheet(
                          context,
                          actions: [
                            (
                              icon: Icons.playlist_remove_rounded,
                              label: 'Remove from Playlist',
                              onTap: () => playlistProvider
                                  .removeSongFromPlaylist(playlistId, song.id),
                            ),
                            (
                              icon: Icons.skip_next_rounded,
                              label: 'Play Next',
                              onTap: () => player.playNext(song),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    Playlist playlist,
    PlaylistProvider provider,
  ) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                provider.renamePlaylist(playlist.id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Playlist playlist,
    PlaylistProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Delete "${playlist.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.deletePlaylist(playlist.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
