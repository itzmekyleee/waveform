import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../models/song_model.dart';
import '../../services/audio_handler.dart';
import '../../services/storage_service.dart';
import '../../theme/glass_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/app_toast.dart';
import '../now_playing_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const _sectionCount = 5;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnims = List.generate(_sectionCount, (i) {
      final start = (i * 0.12).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _stagger,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _slideAnims = List.generate(_sectionCount, (i) {
      final start = (i * 0.12).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _stagger,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

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
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final player = context.read<PlayerProvider>();
    final isShuffle = context.select<PlayerProvider, bool>((p) => p.isShuffle);
    final repeatMode = context.select<PlayerProvider, AudioRepeatMode>(
      (p) => p.repeatMode,
    );
    final library = context.read<LibraryProvider>();
    final storage = context.read<StorageService>();
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            children: [
              _buildAnimatedSection(
                index: 0,
                theme: theme,
                label: 'Appearance',
                children: [
                  _buildThemeSelector(context, themeProvider, isDark),
                ],
              ),
              const SizedBox(height: 24),
              _buildAnimatedSection(
                index: 1,
                theme: theme,
                label: 'Playback',
                children: [
                  _buildIosTile(
                    icon: Icons.shuffle_rounded,
                    iconColor: isShuffle ? theme.colorScheme.primary : null,
                    title: 'Shuffle',
                    subtitle: 'Randomize playback order',
                    trailing: _IOSSwitch(
                      value: isShuffle,
                      onChanged: (_) {
                        HapticFeedback.lightImpact();
                        player.toggleShuffle();
                      },
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      player.toggleShuffle();
                    },
                  ),
                  _buildIosDivider(),
                  _buildIosTile(
                    icon: repeatMode != AudioRepeatMode.off
                        ? (repeatMode == AudioRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded)
                        : Icons.repeat_rounded,
                    iconColor: repeatMode != AudioRepeatMode.off
                        ? theme.colorScheme.primary
                        : null,
                    title: 'Repeat',
                    subtitle: 'Mode: ${repeatMode.name}',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      player.cycleRepeat();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildAnimatedSection(
                index: 2,
                theme: theme,
                label: 'Library',
                children: [
                  _buildIosTile(
                    icon: Icons.refresh_rounded,
                    iconColor: theme.colorScheme.primary,
                    title: 'Rescan Library',
                    subtitle: '${library.allSongs.length} songs found',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await library.scanLibrary();
                      if (context.mounted) {
                        showAppToast(
                          context,
                          'Found ${library.allSongs.length} songs',
                          icon: Icons.check_rounded,
                          severity: ToastSeverity.success,
                        );
                      }
                    },
                  ),
                  _buildIosDivider(),
                  _buildIosTile(
                    icon: Icons.history_rounded,
                    iconColor: Colors.teal,
                    title: 'Recently Played',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final recent = context
                          .read<PlaylistProvider>()
                          .getRecentlyPlayed();
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration: AppDuration.page,
                          reverseTransitionDuration: AppDuration.page,
                           pageBuilder: (_, a, b) => _SongListScreen(
                            title: 'Recently Played',
                            songs: recent,
                          ),
                          transitionsBuilder: (_, anim, c, child) {
                            return FadeTransition(
                              opacity: CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              ),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  _buildIosDivider(),
                  _buildIosTile(
                    icon: Icons.trending_up_rounded,
                    iconColor: Colors.orange,
                    title: 'Most Played',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final mostPlayed = context
                          .read<PlaylistProvider>()
                          .getMostPlayed();
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration: AppDuration.page,
                          reverseTransitionDuration: AppDuration.page,
                           pageBuilder: (_, a, b) => _SongListScreen(
                            title: 'Most Played',
                            songs: mostPlayed,
                          ),
                          transitionsBuilder: (_, anim, c, child) {
                            return FadeTransition(
                              opacity: CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              ),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildAnimatedSection(
                index: 3,
                theme: theme,
                label: 'Now Playing',
                children: [
                  _buildNowPlayingSetting(
                    context,
                    theme,
                    storage,
                    'Show Queue Sidebar',
                    'Display the up next queue beside the player on wide screens',
                    Icons.queue_music_rounded,
                  ),
                  _buildIosDivider(),
                  _buildNowPlayingHideNavSetting(
                    context,
                    theme,
                    storage,
                    'Hide Navigation Sidebar',
                    'Collapse the navigation sidebar when the player is open',
                    Icons.view_sidebar_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildAnimatedSection(
                index: 4,
                theme: theme,
                label: 'About',
                children: [
                  _buildIosTile(
                    icon: Icons.graphic_eq_rounded,
                    iconColor: theme.colorScheme.primary,
                    title: 'Waveform',
                    subtitle: 'Version 1.0.0 • Offline Music Player',
                    trailing: const SizedBox.shrink(),
                    onTap: null,
                  ),
                  _buildIosDivider(),
                  _buildIosTile(
                    icon: Icons.privacy_tip_rounded,
                    iconColor: Colors.indigo,
                    title: 'Privacy',
                    subtitle: 'No data ever leaves your device.',
                    trailing: const SizedBox.shrink(),
                    onTap: null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedSection({
    required int index,
    required ThemeData theme,
    required String label,
    required List<Widget> children,
  }) {
    return AnimatedBuilder(
      animation: _stagger,
      builder: (context, _) {
        return FadeTransition(
          opacity: _fadeAnims[index],
          child: SlideTransition(
            position: _slideAnims[index],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel(context, label),
                const SizedBox(height: 8),
                GlassPanel(
                  borderRadius: 16,
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(children: children),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final modes = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        child: Row(
          children: modes.map((mode) {
            final isSelected = themeProvider.themeMode == mode.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  themeProvider.setThemeMode(mode.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: -1,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: isSelected ? 28 : 24,
                        height: isSelected ? 28 : 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          mode.$2,
                          size: isSelected ? 16 : 15,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        child: Text(mode.$3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNowPlayingSetting(
    BuildContext context,
    ThemeData theme,
    StorageService storage,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return _buildIosTile(
      icon: icon,
      iconColor: theme.colorScheme.primary,
      title: title,
      subtitle: subtitle,
      trailing: _IOSSwitch(
        value: storage.showQueueSidebar,
        onChanged: (v) {
          HapticFeedback.lightImpact();
          storage.setShowQueueSidebar(v);
          setState(() {});
        },
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        storage.setShowQueueSidebar(!storage.showQueueSidebar);
        setState(() {});
      },
    );
  }

  Widget _buildNowPlayingHideNavSetting(
    BuildContext context,
    ThemeData theme,
    StorageService storage,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return _buildIosTile(
      icon: icon,
      iconColor: Colors.teal,
      title: title,
      subtitle: subtitle,
      trailing: _IOSSwitch(
        value: storage.hideSidebarOnNowPlaying,
        onChanged: (v) {
          HapticFeedback.lightImpact();
          storage.setHideSidebarOnNowPlaying(v);
          setState(() {});
        },
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        storage.setHideSidebarOnNowPlaying(!storage.hideSidebarOnNowPlaying);
        setState(() {});
      },
    );
  }

  Widget _buildIosTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return _PressableTile(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.grey).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildIosDivider() {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 60,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

class _PressableTile extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _PressableTile({this.onTap, required this.child});

  @override
  State<_PressableTile> createState() => _PressableTileState();
}

class _PressableTileState extends State<_PressableTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _press.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _press.reverse() : null,
      onTapCancel: () => _press.reverse(),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class _IOSSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _IOSSwitch({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 51,
        height: 31,
        decoration: BoxDecoration(
          color: value
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(15.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SongListScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const _SongListScreen({required this.title, required this.songs});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: songs.isEmpty
          ? const Center(child: Text('No songs'))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 4),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final isPlaying = player.currentSong?.id == song.id;
                return SongTile(
                  song: song,
                  index: index + 1,
                  isPlaying: isPlaying,
                  onTap: () {
                    player.playSongList(songs, startIndex: index);
                    openNowPlaying(context);
                  },
                  trailing: song.playCount > 0
                      ? Text(
                          '${song.playCount} plays',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
