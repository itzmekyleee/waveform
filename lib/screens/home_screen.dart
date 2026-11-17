import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/color_provider.dart';
import '../services/storage_service.dart';
import '../services/audio_handler.dart';
import '../models/song_model.dart';
import '../widgets/player_bar.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/now_playing_view.dart';
import '../widgets/queue_sidebar.dart';
import '../widgets/queue_list.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'library/songs_screen.dart';
import 'library/albums_screen.dart';
import 'library/artists_screen.dart';
import 'library/playlists_screen.dart';
import 'library/favorites_screen.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'library/settings_tab.dart';
import 'now_playing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  static const _tabDuration = Duration(milliseconds: 300);
  static const _tabCurve = Curves.easeOutCubic;

  bool _nowPlayingActive = false;
  late final AnimationController _queueSidebarController;
  late final Animation<double> _queueSidebarAnimation;

  final ValueNotifier<double> _wideVertOffset = ValueNotifier(0);
  late AnimationController _wideVertSettleController;
  Animation<double>? _wideVertAnim;
  VoidCallback? _wideVertAnimListener;
  bool _wideVertDismissing = false;

  // Horizontal swipe-to-change-song carousel for the wide Now Playing.
  final ValueNotifier<double> _wideDragOffset = ValueNotifier(0);
  final ValueNotifier<Song?> _wideAdjacentSong = ValueNotifier(null);
  final ValueNotifier<int> _wideDragDirection = ValueNotifier(1);
  late final AnimationController _wideDragSettleController;
  double _wideSettleFrom = 0;
  double _wideSettleTo = 0;
  Curve _wideSettleCurve = Curves.easeOutCubic;
  bool _wideCommitting = false;
  Song? _wideDisplayedSong;
  PlayerProvider? _widePlayer;

  /// Width of the hosted player pane, i.e. how far a song travels on a swipe.
  double _widePaneWidth = 0;

  double get _wideEffectiveOffset {
    if (!_wideDragSettleController.isAnimating) return _wideDragOffset.value;
    final t = _wideSettleCurve.transform(_wideDragSettleController.value);
    return _wideSettleFrom + (_wideSettleTo - _wideSettleFrom) * t;
  }

  void _resetWideCarousel() {
    _wideDragOffset.value = 0;
    _wideAdjacentSong.value = null;
    _wideCommitting = false;
    if (_wideDragSettleController.isAnimating) {
      _wideDragSettleController.stop();
    }
  }

  late final List<Widget> _screens = [
    SongsScreen(searchQuery: _searchController),
    AlbumsScreen(searchQuery: _searchController),
    ArtistsScreen(searchQuery: _searchController),
    const PlaylistsScreen(),
    FavoritesScreen(searchQuery: _searchController),
    const SettingsTab(),
  ];

  static const _navEntries = <(IconData, String)>[
    (Icons.music_note_rounded, 'Songs'),
    (Icons.album_rounded, 'Albums'),
    (Icons.person_rounded, 'Artists'),
    (Icons.queue_music_rounded, 'Playlists'),
    (Icons.favorite_rounded, 'Favorites'),
    (Icons.settings_rounded, 'Settings'),
  ];

  final FocusNode _keyboardFocus = FocusNode();

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _queueSidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _queueSidebarAnimation = CurvedAnimation(
      parent: _queueSidebarController,
      curve: Curves.easeOutCubic,
    );
    _wideVertSettleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_handleWideVertSettleStatus);
    _wideDragSettleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addStatusListener(_handleWideDragSettleStatus);
    setWideNowPlayingHost(null);
    WidgetsBinding.instance.addObserver(this);
    _searchFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlaylistProvider>().loadPlaylists();
      _widePlayer = context.read<PlayerProvider>();
      _widePlayer?.addListener(_onWidePlayerChanged);
      if (_isDesktop) {
        _keyboardFocus.requestFocus();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<LibraryProvider>().rescanOnResume();
      if (_isDesktop) {
        _keyboardFocus.requestFocus();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    setWideNowPlayingHost(null);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _queueSidebarController.dispose();
    _widePlayer?.removeListener(_onWidePlayerChanged);
    _wideDragSettleController.removeStatusListener(_handleWideDragSettleStatus);
    _wideDragSettleController.dispose();
    _wideDragOffset.dispose();
    _wideAdjacentSong.dispose();
    _wideDragDirection.dispose();
    _wideVertSettleController.dispose();
    _stopWideVertAnim();
    _wideVertOffset.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final player = context.read<PlayerProvider>();
    if (event.logicalKey == LogicalKeyboardKey.space) {
      player.togglePlayPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      player.seek(player.position + const Duration(seconds: 5));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      player.seek(player.position - const Duration(seconds: 5));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final newVol = (player.volume + 0.1).clamp(0.0, 1.0);
      player.setVolume(newVol);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final newVol = (player.volume - 0.1).clamp(0.0, 1.0);
      player.setVolume(newVol);
    }
  }

  void openNowPlayingWide() {
    if (_nowPlayingActive) return;
    final storage = context.read<StorageService>();
    final showQueueSidebar = storage.showQueueSidebar;
    _resetWideCarousel();
    _wideDisplayedSong = context.read<PlayerProvider>().currentSong;
    setState(() => _nowPlayingActive = true);
    if (showQueueSidebar) {
      _queueSidebarController.forward();
    }
  }

  void closeNowPlayingWide() {
    if (!_nowPlayingActive) return;
    _queueSidebarController.reverse();
    _resetWideCarousel();
    setState(() => _nowPlayingActive = false);
  }

  /// Keeps the carousel in step with song changes that did not come from a
  /// swipe (queue sidebar tap, mini player, hardware key).
  void _onWidePlayerChanged() {
    if (!mounted || !_nowPlayingActive) return;
    if (_wideDragSettleController.isAnimating || _wideCommitting) return;
    final actual = _widePlayer?.currentSong;
    if (actual == null || actual.id == _wideDisplayedSong?.id) return;
    _resetWideCarousel();
    setState(() => _wideDisplayedSong = actual);
  }

  void _handleWideDragSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_wideCommitting) {
      final adjacent = _wideAdjacentSong.value;
      _wideCommitting = false;
      setState(() {
        if (adjacent != null) _wideDisplayedSong = adjacent;
        _wideDragOffset.value = 0;
        _wideAdjacentSong.value = null;
      });
    } else {
      setState(() {
        _wideDragOffset.value = 0;
        _wideAdjacentSong.value = null;
      });
    }
  }

  Song? _wideAdjacentFor(PlayerProvider player, int index) {
    final queue = player.queue;
    if (queue.length <= 1) return null;
    if (index >= 0 && index < queue.length) return queue[index];
    return player.repeatMode == AudioRepeatMode.all
        ? queue[(index + queue.length) % queue.length]
        : null;
  }

  void _onWideDragStart(PlayerProvider player) {
    if (_wideDragSettleController.isAnimating) return;
    _wideCommitting = false;
    _wideDragOffset.value = 0;
    _wideAdjacentSong.value = null;
    _wideDisplayedSong ??= player.currentSong;
  }

  void _onWideDragUpdate(
    DragUpdateDetails details,
    PlayerProvider player,
    double width,
  ) {
    if (_wideDragSettleController.isAnimating) return;
    final newOffset = _wideDragOffset.value + details.delta.dx;

    double clamped = newOffset;
    if (newOffset.abs() > width * 0.5) {
      clamped =
          newOffset.sign *
          (width * 0.5 + (newOffset.abs() - width * 0.5) * 0.3);
    }
    _wideDragOffset.value = clamped;

    if (_wideDragOffset.value > 20) {
      _wideDragDirection.value = -1;
      _wideAdjacentSong.value = _wideAdjacentFor(
        player,
        player.currentIndex - 1,
      );
    } else if (_wideDragOffset.value < -20) {
      _wideDragDirection.value = 1;
      _wideAdjacentSong.value = _wideAdjacentFor(
        player,
        player.currentIndex + 1,
      );
    } else {
      _wideAdjacentSong.value = null;
    }
  }

  void _onWideDragEnd(
    DragEndDetails details,
    PlayerProvider player,
    double width,
  ) {
    if (_wideDragSettleController.isAnimating) return;
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    final magnitude = _wideDragOffset.value.abs();
    final strongFlick = velocity.abs() > 900;

    if (magnitude < 20 && strongFlick) {
      _wideDragDirection.value = velocity < 0 ? 1 : -1;
      _wideAdjacentSong.value = _wideAdjacentFor(
        player,
        player.currentIndex + _wideDragDirection.value,
      );
    }

    final shouldCommit =
        _wideAdjacentSong.value != null &&
        (magnitude > width * 0.22 || strongFlick);
    if (shouldCommit) {
      _wideCommit(player, _wideDragDirection.value, width);
    } else {
      _wideSpringBack();
    }
  }

  void _wideCommit(PlayerProvider player, int direction, double width) {
    // Mirrors the phone behaviour: a backwards swipe early in the track
    // restarts it rather than stepping to the previous song.
    if (direction < 0 && player.position.inSeconds > 3) {
      player.skipToPrevious();
      _wideSpringBack();
      return;
    }
    if (_wideAdjacentSong.value == null) {
      _wideAdjacentSong.value = _wideAdjacentFor(
        player,
        player.currentIndex + direction,
      );
    }
    final adjacent = _wideAdjacentSong.value;
    if (adjacent == null) return;
    if (_wideDragSettleController.isAnimating) {
      _wideDragSettleController.stop();
    }

    void skip() {
      if (direction > 0) {
        player.skipToNext();
      } else {
        player.skipToPrevious();
      }
    }

    if (AppHelpers.reduceMotion) {
      setState(() {
        _wideCommitting = false;
        _wideDisplayedSong = adjacent;
        _wideDragOffset.value = 0;
        _wideAdjacentSong.value = null;
      });
      skip();
      return;
    }

    // The commit flag has to be raised before skipping, otherwise the
    // synchronous player notification is mistaken for an external change and
    // the carousel jumps to the new song mid-drag.
    _wideCommitting = true;
    _wideDragDirection.value = direction;
    _wideSettleFrom = _wideDragOffset.value;
    _wideSettleTo = -direction * width;
    _wideSettleCurve = Curves.easeOutCubic;
    _wideDragSettleController.duration = const Duration(milliseconds: 320);
    _wideDragSettleController.forward(from: 0);
    skip();
  }

  void _wideSpringBack() {
    if (_wideDragSettleController.isAnimating) {
      _wideDragSettleController.stop();
    }
    if (AppHelpers.reduceMotion) {
      setState(() {
        _wideDragOffset.value = 0;
        _wideAdjacentSong.value = null;
      });
      return;
    }
    _wideSettleFrom = _wideDragOffset.value;
    _wideSettleTo = 0;
    _wideSettleCurve = Curves.elasticOut;
    _wideDragSettleController.duration = const Duration(milliseconds: 500);
    _wideDragSettleController.forward(from: 0);
  }

  double get _wideVertDismissThreshold =>
      MediaQuery.of(context).size.height * 0.3;

  void _onWideVertDragStart(DragStartDetails details) {
    if (_wideVertSettleController.isAnimating) return;
  }

  void _onWideVertDragUpdate(DragUpdateDetails details) {
    if (_wideVertSettleController.isAnimating) return;
    final delta = details.delta.dy;
    var newVal = _wideVertOffset.value + delta;
    if (newVal < 0) return;
    _wideVertOffset.value = newVal;
  }

  void _onWideVertDragEnd(DragEndDetails details) {
    if (_wideVertSettleController.isAnimating) return;
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dy;
    final fastFlick = velocity > 900;
    final shouldDismiss =
        _wideVertOffset.value >= _wideVertDismissThreshold || fastFlick;
    if (shouldDismiss) {
      _animateWideVertDismiss();
    } else {
      _animateWideVertSpringBack();
    }
  }

  void _stopWideVertAnim() {
    if (_wideVertAnim != null && _wideVertAnimListener != null) {
      _wideVertAnim!.removeListener(_wideVertAnimListener!);
    }
    _wideVertAnim = null;
    _wideVertAnimListener = null;
  }

  void _animateWideVertDismiss() {
    _stopWideVertAnim();
    _wideVertDismissing = true;
    final start = _wideVertOffset.value;
    final screenHeight = MediaQuery.of(context).size.height;
    _wideVertSettleController.duration = const Duration(milliseconds: 300);
    _wideVertAnim = Tween<double>(begin: start, end: screenHeight).animate(
      CurvedAnimation(
        parent: _wideVertSettleController,
        curve: Curves.easeInCubic,
      ),
    );
    _wideVertAnimListener = () => _wideVertOffset.value = _wideVertAnim!.value;
    _wideVertAnim!.addListener(_wideVertAnimListener!);
    _wideVertSettleController.forward(from: 0).whenCompleteOrCancel(() {
      _stopWideVertAnim();
    });
  }

  void _animateWideVertSpringBack() {
    _stopWideVertAnim();
    _wideVertDismissing = false;
    final start = _wideVertOffset.value;
    _wideVertSettleController.duration = const Duration(milliseconds: 280);
    _wideVertAnim = Tween<double>(begin: start, end: 0.0).animate(
      CurvedAnimation(
        parent: _wideVertSettleController,
        curve: Curves.elasticOut,
      ),
    );
    _wideVertAnimListener = () => _wideVertOffset.value = _wideVertAnim!.value;
    _wideVertAnim!.addListener(_wideVertAnimListener!);
    _wideVertSettleController.forward(from: 0).whenCompleteOrCancel(() {
      _stopWideVertAnim();
    });
  }

  void _handleWideVertSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_wideVertDismissing) {
      _wideVertDismissing = false;
      _wideVertOffset.value = 0;
      closeNowPlayingWide();
    }
  }

  double _queueSidebarWidthFor(double screenWidth) {
    if (screenWidth >= 1500) return AppConstants.queueSidebarWidthExpanded;
    if (screenWidth >= 1100) return AppConstants.queueSidebarWidthMedium;
    return AppConstants.queueSidebarWidthCompact;
  }

  /// Width of the permanent Up Next pane in the landscape two-pane layout.
  double _landscapeQueuePaneWidth(double contentWidth) {
    final width = contentWidth * 0.38;
    if (width < AppConstants.landscapeQueuePaneMinWidth) {
      return AppConstants.landscapeQueuePaneMinWidth;
    }
    if (width > AppConstants.landscapeQueuePaneMaxWidth) {
      return AppConstants.landscapeQueuePaneMaxWidth;
    }
    return width;
  }

  /// Width the player pane gets inside the shell. The floating shell has no
  /// rail; in landscape the permanent Up Next pane takes its share, elsewhere
  /// the slide-in queue panel does.
  double _nowPlayingPaneWidth(double screenWidth, {required bool landscape}) {
    final storage = context.read<StorageService>();
    final contentWidth = screenWidth > AppConstants.contentMaxWidth
        ? AppConstants.contentMaxWidth
        : screenWidth;
    if (landscape) {
      return contentWidth - _landscapeQueuePaneWidth(contentWidth);
    }
    final queue = storage.showQueueSidebar
        ? _queueSidebarWidthFor(screenWidth)
        : 0.0;
    return contentWidth - queue;
  }

  /// The queue panel's width is reserved up front so opening it does not
  /// re-lay-out the player on every animation frame. The content slides by
  /// the same distance to keep the motion coherent with the panel.
  Widget _buildQueueAwareContent(Widget child, double queueWidth) {
    if (queueWidth <= 0) return child;
    return AnimatedBuilder(
      animation: _queueSidebarAnimation,
      builder: (context, inner) => Transform.translate(
        offset: Offset((1 - _queueSidebarAnimation.value) * queueWidth, 0),
        child: inner,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: PopScope(
        canPop: true,
        child: Scaffold(
          body: KeyboardListener(
            focusNode: _keyboardFocus,
            onKeyEvent: _handleKeyEvent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final isLarge = width >= AppConstants.breakpointTablet;
                // Tablet landscape gets the two-pane player + Up Next screen.
                final isLandscape = isLarge && width > height;

                // Only the floating large-screen shell can host the player in
                // place. Landscape always hosts: its player and queue share one
                // screen even when the player pane is too narrow for its own
                // art/controls split.
                final paneWidth = _nowPlayingPaneWidth(
                  width,
                  landscape: isLandscape,
                );
                final canHostNowPlaying =
                    isLandscape ||
                    paneWidth >= AppConstants.nowPlayingSplitMinWidth;
                final wantsNowPlaying =
                    _nowPlayingActive &&
                    context.read<PlayerProvider>().currentSong != null;

                setWideNowPlayingHost(
                  isLarge
                      ? WideNowPlayingHost(
                          paneWidth: paneWidth,
                          onOpen: openNowPlayingWide,
                          preferInPlace: isLandscape,
                        )
                      : null,
                );

                if (isLarge) {
                  return _buildFloatingShell(
                    theme,
                    width,
                    isLandscape: isLandscape,
                    wantsNowPlaying: wantsNowPlaying,
                    canHostNowPlaying: canHostNowPlaying,
                  );
                }

                return Column(
                  children: [
                    _buildTopNav(theme),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: _screens,
                      ),
                    ),
                    const SafeArea(top: false, child: PlayerBar()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Tablet landscape, tablet portrait and desktop all share one shell: a
  /// centred, width-capped content column with an elevated navigation pill
  /// floating below it. Nothing runs to the window edges any more.
  Widget _buildFloatingShell(
    ThemeData theme,
    double width, {
    required bool isLandscape,
    required bool wantsNowPlaying,
    required bool canHostNowPlaying,
  }) {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, _) {
        final storage = context.read<StorageService>();
        final showNowPlaying = wantsNowPlaying && canHostNowPlaying;
        // Landscape now playing is its own full screen: player + Up Next only.
        // No floating pill, no slide-in queue panel.
        final twoPane = showNowPlaying && isLandscape;
        final hideNav =
            twoPane || (showNowPlaying && storage.hideSidebarOnNowPlaying);
        final queueVisible =
            showNowPlaying && storage.showQueueSidebar && !twoPane;
        final queueWidth = _queueSidebarWidthFor(width);

        late final Widget content;
        if (twoPane) {
          content = _buildNowPlayingLandscapeLayout(theme, width);
        } else if (showNowPlaying) {
          content = _buildQueueAwareContent(
            _buildNowPlayingWideLayout(theme),
            queueVisible ? queueWidth : 0.0,
          );
        } else {
          content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppConstants.contentMaxWidth,
              ),
              child: _buildAnimatedContent(
                theme,
                gutter: AppConstants.contentGutterWide,
              ),
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SafeArea(bottom: false, child: content),
                  ),
                  if (!hideNav)
                    _buildFloatingBottomBar(
                      theme,
                      withPlayer: !showNowPlaying,
                    ),
                ],
              ),
            ),
            if (queueVisible)
              SizedBox(
                width: queueWidth,
                child: AnimatedBuilder(
                  animation: _queueSidebarAnimation,
                  builder: (context, child) {
                    final t = _queueSidebarAnimation.value;
                    return Transform.translate(
                      offset: Offset((1 - t) * queueWidth, 0),
                      child: Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: QueueSidebar(width: queueWidth),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The mini player and the nav pill share one centred, capped column so the
  /// whole bottom stack lines up with the content above it.
  Widget _buildFloatingBottomBar(ThemeData theme, {required bool withPlayer}) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.contentMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (withPlayer) const PlayerBar(),
              _FloatingNavBar(
                controller: _tabController,
                entries: _navEntries,
                duration: _tabDuration,
                curve: _tabCurve,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The player hosted in the shell: backdrop, dismiss affordance and the
  /// shared composition. The composition decides on its own whether it has
  /// room for the landscape split.
  Widget _buildNowPlayingWideLayout(ThemeData theme) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsBold.musicNote,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No track playing',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final displayed = _wideDisplayedSong ?? song;

    return AnimatedBuilder(
      animation: _wideVertOffset,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _wideVertOffset.value),
        child: child,
      ),
      child: SizedBox.expand(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onWideVertDragStart,
          onVerticalDragUpdate: _onWideVertDragUpdate,
          onVerticalDragEnd: _onWideVertDragEnd,
          child: Stack(
            children: [
              Positioned.fill(child: _buildNowPlayingBackdrop(theme, song)),
              const Positioned.fill(child: _NowPlayingScrim()),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppConstants.nowPlayingMaxWidth,
                    ),
                    child: Column(
                      children: [
                        _buildWideDismissChevron(),
                        Expanded(
                          child: _buildWidePlayerPane(theme, player, displayed),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Landscape tablets get one full screen: the player on the left and a
  /// permanent Up Next pane on the right. The floating nav and the slide-in
  /// queue panel are both absent here.
  Widget _buildNowPlayingLandscapeLayout(ThemeData theme, double width) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return _buildNowPlayingWideLayout(theme);

    final displayed = _wideDisplayedSong ?? song;
    final contentWidth = width > AppConstants.contentMaxWidth
        ? AppConstants.contentMaxWidth
        : width;
    final queueWidth = _landscapeQueuePaneWidth(contentWidth);

    return AnimatedBuilder(
      animation: _wideVertOffset,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _wideVertOffset.value),
        child: child,
      ),
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(child: _buildNowPlayingBackdrop(theme, song)),
            const Positioned.fill(child: _NowPlayingScrim()),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppConstants.contentMaxWidth,
                  ),
                  child: Column(
                    children: [
                      _buildWideDismissChevron(),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: _onWideVertDragStart,
                                onVerticalDragUpdate: _onWideVertDragUpdate,
                                onVerticalDragEnd: _onWideVertDragEnd,
                                child: _buildWidePlayerPane(
                                  theme,
                                  player,
                                  displayed,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: queueWidth,
                              child: _buildUpNextPane(theme, player),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpNextPane(ThemeData theme, PlayerProvider player) {
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(20);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: radius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsBold.queue,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Up Next',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${player.queue.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            Expanded(
              child: QueueList(
                artSize: 40,
                dismissible: true,
                reorderable: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shared player composition: swipe-to-change-song, artwork, metadata and
  /// transport. Used by both the portrait wide pane and the landscape split.
  Widget _buildWidePlayerPane(
    ThemeData theme,
    PlayerProvider player,
    Song displayed,
  ) {
    return LayoutBuilder(
      builder: (context, pane) {
        _widePaneWidth = pane.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _onWideDragStart(player),
          onHorizontalDragUpdate: (d) =>
              _onWideDragUpdate(d, player, _widePaneWidth),
          onHorizontalDragEnd: (d) => _onWideDragEnd(d, player, _widePaneWidth),
          child: NowPlayingView(
            player: player,
            song: displayed,
            adjacentSong: _wideAdjacentSong.value,
            dragOffset: _wideEffectiveOffset,
            dragDirection: _wideDragDirection.value,
            active: true,
            isPlaying: player.isPlaying,
            onPrev: () => _wideCommit(player, -1, _widePaneWidth),
            onNext: () => _wideCommit(player, 1, _widePaneWidth),
            onToggleQueue: () {
              final storage = context.read<StorageService>();
              storage.setShowQueueSidebar(!storage.showQueueSidebar);
            },
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
        );
      },
    );
  }

  Widget _buildNowPlayingBackdrop(ThemeData theme, Song song) {
    final colorProv = context.watch<ColorProvider>();
    final base =
        colorProv.dominantColor ?? AppHelpers.generateArtColor('$song-$song');

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: base),
        BlurredArtBackground(song: song),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                base.withValues(alpha: 0.5),
                theme.colorScheme.surface.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideDismissChevron() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _wideVertOffset.value = 0;
        closeNowPlayingWide();
      },
      child: SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Icon(
              PhosphorIconsBold.caretDown,
              size: 26,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedContent(
    ThemeData theme, {
    double gutter = AppConstants.contentGutterCompact,
  }) {
    final library = context.watch<LibraryProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Library',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              final subtitle = switch (_tabController.index) {
                0 => '${library.songs.length} songs',
                1 => '${library.albums.length} albums',
                2 => '${library.artists.length} artists',
                3 => '${playlistProvider.playlists.length} playlists',
                4 => '${playlistProvider.getFavoriteSongs().length} favorites',
                _ => 'Customize your experience',
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: _tabDuration,
                    switchInCurve: _tabCurve,
                    switchOutCurve: _tabCurve,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.15),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      key: ValueKey(subtitle),
                      padding: const EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  _buildCompactControls(theme, library),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: _tabDuration,
              switchInCurve: _tabCurve,
              switchOutCurve: _tabCurve,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_tabController.index),
                child: _screens[_tabController.index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNav(ThemeData theme) {
    final library = context.watch<LibraryProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + 8,
        12,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Library',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              final subtitle = switch (_tabController.index) {
                0 => '${library.songs.length} songs',
                1 => '${library.albums.length} albums',
                2 => '${library.artists.length} artists',
                3 => '${playlistProvider.playlists.length} playlists',
                4 => '${playlistProvider.getFavoriteSongs().length} favorites',
                _ => 'Customize your experience',
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: _tabDuration,
                    switchInCurve: _tabCurve,
                    switchOutCurve: _tabCurve,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.15),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      key: ValueKey(subtitle),
                      padding: const EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  _buildCompactControls(theme, library),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _SegmentedNavBar(
            controller: _tabController,
            entries: _navEntries,
            duration: _tabDuration,
            curve: _tabCurve,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactControls(ThemeData theme, LibraryProvider library) {
    final isDark = theme.brightness == Brightness.dark;
    final isSongsTab = _tabController.index == 0;
    final isAlbumsTab = _tabController.index == 1;
    final isArtistsTab = _tabController.index == 2;
    final isFavoritesTab = _tabController.index == 4;
    final showSearch =
        isSongsTab || isAlbumsTab || isArtistsTab || isFavoritesTab;
    final showSort = isSongsTab;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: (!showSearch && !showSort)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Row(
                children: [
                  if (showSearch)
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocus,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                ),
                                onChanged: (value) {
                                  library.search(value);
                                  setState(() {});
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty ||
                                _searchFocus.hasFocus)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    library.clearSearch();
                                    FocusScope.of(context).unfocus();
                                    setState(() {});
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (showSearch && showSort) const SizedBox(width: 8),
                  if (showSort)
                    GestureDetector(
                      onTap: () => _showSortSheet(context, library),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 19,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (showSearch) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final player = context.read<PlayerProvider>();
                        final songs = library.songs;
                        if (songs.isNotEmpty) {
                          songs.shuffle();
                          player.playSongList(songs);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIconsBold.shuffle,
                          size: 19,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _showSortSheet(BuildContext context, LibraryProvider library) {
    final theme = Theme.of(context);

    showGlassBottomSheet(
      context,
      maxWidth: 420,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'Sort by',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _sortOption(ctx, library, 'title', 'Title', Icons.title_rounded),
          _sortOption(ctx, library, 'artist', 'Artist', Icons.person_rounded),
          _sortOption(ctx, library, 'album', 'Album', Icons.album_rounded),
          _sortOption(
            ctx,
            library,
            'date_added',
            'Date Added',
            Icons.calendar_today_rounded,
          ),
          _sortOption(
            ctx,
            library,
            'duration',
            'Duration',
            Icons.timer_rounded,
          ),
        ],
      ),
    );
  }

  Widget _sortOption(
    BuildContext ctx,
    LibraryProvider library,
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = library.sortField == value;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          library.setSortField(value);
          Navigator.pop(ctx);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact, elevated navigation pill for tablets and desktop. It keeps the
/// app's sliding-indicator language, but floats with its own margins and
/// shadow instead of being pinned to a screen edge.
class _FloatingNavBar extends StatelessWidget {
  final TabController controller;
  final List<(IconData, String)> entries;
  final Duration duration;
  final Curve curve;

  const _FloatingNavBar({
    required this.controller,
    required this.entries,
    required this.duration,
    required this.curve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pillRadius = BorderRadius.circular(32);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppConstants.floatingNavMaxWidth,
        ),
        child: Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2C2C2E).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: pillRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / entries.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: duration,
                        curve: curve,
                        left: controller.index * tabWidth,
                        top: 0,
                        width: tabWidth,
                        height: constraints.maxHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: pillRadius,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(entries.length, (index) {
                          final isSelected = controller.index == index;
                          final iconColor = isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                controller.animateTo(
                                  index,
                                  duration: duration,
                                  curve: curve,
                                );
                              },
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                curve: curve,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: iconColor,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      entries[index].$1,
                                      size: 20,
                                      color: iconColor,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      entries[index].$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SegmentedNavBar extends StatelessWidget {
  final TabController controller;
  final List<(IconData, String)> entries;
  final Duration duration;
  final Curve curve;

  const _SegmentedNavBar({
    required this.controller,
    required this.entries,
    required this.duration,
    required this.curve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 56,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / entries.length;

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: curve,
                    left: controller.index * tabWidth,
                    top: 0,
                    width: tabWidth,
                    height: constraints.maxHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(entries.length, (index) {
                      final isSelected = controller.index == index;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            controller.animateTo(
                              index,
                              duration: duration,
                              curve: curve,
                            );
                          },
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            curve: curve,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              letterSpacing: isSelected ? 0.2 : 0,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  entries[index].$1,
                                  size: 20,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entries[index].$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _NowPlayingScrim extends StatelessWidget {
  const _NowPlayingScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
        ),
      ),
    );
  }
}
