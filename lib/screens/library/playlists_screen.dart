import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song_model.dart';
import '../../models/smart_playlist.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/player_bar.dart';
import '../../widgets/empty_state.dart';
import '../../theme/glass_theme.dart';
import 'playlist_detail_screen.dart';
import '../now_playing_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistProvider = context.watch<PlaylistProvider>();

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: GestureDetector(
              onTap: () => _showCreateSheet(context, playlistProvider),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'New',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(theme, playlistProvider, context)),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, PlaylistProvider playlistProvider, BuildContext context) {
    final playlists = playlistProvider.playlists;

    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Text(
            'Smart Playlists',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...List.generate(SmartPlaylist.all.length, (index) {
          final smart = SmartPlaylist.all[index];
          return _SmartPlaylistTile(smart: smart);
        }),
        if (playlists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'My Playlists',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...List.generate(playlists.length, (index) {
            final playlist = playlists[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: GlassPanel(
                key: ValueKey(playlist.id),
                borderRadius: 14,
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 8, right: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.secondaryContainer,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.queue_music_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    playlist.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${playlist.songCount} songs',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlaylistDetailScreen(playlistId: playlist.id),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ],
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'No playlists yet',
              subtitle:
                  'Create your first playlist to organize your favorite songs.',
              actionLabel: 'Create Playlist',
              onAction: () => _showCreateSheet(context, playlistProvider),
            ),
          ),
      ],
    );
  }

  void _showCreateSheet(BuildContext context, PlaylistProvider provider) {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _CreatePlaylistDialog(
        controller: controller,
        isDark: isDark,
        theme: theme,
        onCreate: () {
          if (controller.text.trim().isNotEmpty) {
            provider.createPlaylist(controller.text.trim());
            Navigator.pop(ctx);
          }
        },
      ),
    );
  }
}

class _SmartPlaylistTile extends StatelessWidget {
  final SmartPlaylist smart;

  const _SmartPlaylistTile({required this.smart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistProvider = context.read<PlaylistProvider>();
    final library = context.read<LibraryProvider>();

    final gradientColors = switch (smart.type) {
      SmartPlaylistType.recentlyAdded => [
          const Color(0xFF1A237E),
          const Color(0xFF283593),
        ],
      SmartPlaylistType.mostPlayed => [
          const Color(0xFFB71C1C),
          const Color(0xFFC62828),
        ],
      SmartPlaylistType.recentlyPlayed => [
          const Color(0xFF004D40),
          const Color(0xFF00695C),
        ],
      SmartPlaylistType.recentAlbums => [
          const Color(0xFF4A148C),
          const Color(0xFF6A1B9A),
        ],
      SmartPlaylistType.recentArtists => [
          const Color(0xFFE65100),
          const Color(0xFFEF6C00),
        ],
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: GlassPanel(
        borderRadius: 14,
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 8, right: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: gradientColors),
            ),
            child: Icon(smart.icon, color: Colors.white),
          ),
          title: Text(
            smart.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            smart.description,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onTap: () {
            final songs = playlistProvider.getSmartPlaylistSongs(
              smart.type,
              library.allSongs,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _SmartPlaylistDetailScreen(
                  title: smart.name,
                  songs: songs,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SmartPlaylistDetailScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const _SmartPlaylistDetailScreen({
    required this.title,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.playlist_play_rounded),
              tooltip: 'Play all',
              onPressed: () {
                context.read<PlayerProvider>().playSongList(songs, startIndex: 0);
              },
            ),
        ],
      ),
      bottomNavigationBar: const SafeArea(child: PlayerBar()),
      body: songs.isEmpty
          ? const Center(child: Text('No songs found'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 60),
              itemCount: songs.length,
              itemBuilder: (context, index) => SongTile(
                song: songs[index],
                index: index,
                isPlaying: false,
                onTap: () async {
                  await context
                      .read<PlayerProvider>()
                      .playSongList(songs, startIndex: index);
                  if (context.mounted) {
                    openNowPlaying(context);
                  }
                },
              ),
            ),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onCreate;

  const _CreatePlaylistDialog({
    required this.controller,
    required this.isDark,
    required this.theme,
    required this.onCreate,
  });

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  late final Animation<double> _fadeTitle;
  late final Animation<double> _fadeInput;
  late final Animation<double> _fadeButtons;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeTitle = CurvedAnimation(
      parent: _stagger,
      curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
    );
    _fadeInput = CurvedAnimation(
      parent: _stagger,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
    );
    _fadeButtons = CurvedAnimation(
      parent: _stagger,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _stagger.forward();
    });
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = widget.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeTransition(
                    opacity: _fadeTitle,
                    child: Text(
                      'New Playlist',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeInput,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.playlist_play_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Playlist name',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              textCapitalization: TextCapitalization.words,
                              onSubmitted: (_) => widget.onCreate(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeButtons,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: widget.onCreate,
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'Create',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
