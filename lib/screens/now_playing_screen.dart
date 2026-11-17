import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../models/song_model.dart';
import '../providers/color_provider.dart';
import '../providers/player_provider.dart';
import '../services/audio_handler.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/now_playing_view.dart';
import '../widgets/queue_list.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  bool _showQueue = false;
  bool _routeAnimating = false;
  Animation<double>? _routeAnimation;

  final ValueNotifier<double> _dragOffset = ValueNotifier(0);
  final ValueNotifier<Song?> _adjacentSong = ValueNotifier(null);
  final ValueNotifier<int> _direction = ValueNotifier(1);
  final ValueNotifier<double> _vertOffset = ValueNotifier(0);
  late AnimationController _settleController;
  late AnimationController _vertSettleController;
  bool _vertDismissing = false;
  Animation<double>? _vertAnim;
  VoidCallback? _vertAnimListener;

  double _settleFrom = 0;
  double _settleTo = 0;
  Curve _settleCurve = Curves.easeOutCubic;
  bool _committing = false;
  Song? _displayedSong;
  Timer? _reconcileTimer;
  PlayerProvider? _player;

  /// Width of the carousel box, i.e. how far a song has to travel to leave.
  /// Set during build, read by the gesture handlers.
  double _viewportWidth = 0;

  double get _travelWidth => _viewportWidth > 0 ? _viewportWidth : 1;

  double get _effectiveOffset {
    if (!_settleController.isAnimating) return _dragOffset.value;
    final t = _settleCurve.transform(_settleController.value);
    return _settleFrom + (_settleTo - _settleFrom) * t;
  }

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addStatusListener(_handleSettleStatus);
    _vertSettleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_handleVertSettleStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _player = context.read<PlayerProvider>();
      _player?.addListener(_onPlayerChanged);
      if (_player?.currentSong != null) {
        _displayedSong = _player!.currentSong;
      }
      _routeAnimation = ModalRoute.of(context)?.animation;
      _routeAnimation?.addStatusListener(_handleRouteStatus);
      _handleRouteStatus(_routeAnimation?.status ?? AnimationStatus.dismissed);
    });
  }

  @override
  void dispose() {
    _reconcileTimer?.cancel();
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _player?.removeListener(_onPlayerChanged);
    _stopVertAnim();
    _settleController.removeStatusListener(_handleSettleStatus);
    _settleController.dispose();
    _vertSettleController.removeStatusListener(_handleVertSettleStatus);
    _vertSettleController.dispose();
    _dragOffset.dispose();
    _adjacentSong.dispose();
    _direction.dispose();
    _vertOffset.dispose();
    super.dispose();
  }

  void _handleSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_committing) {
      final adj = _adjacentSong.value;
      _committing = false;
      setState(() {
        if (adj != null) _displayedSong = adj;
        _dragOffset.value = 0;
        _adjacentSong.value = null;
      });
    } else {
      setState(() {
        _dragOffset.value = 0;
        _adjacentSong.value = null;
      });
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    if (_settleController.isAnimating || _committing) return;
    final actual = context.read<PlayerProvider>().currentSong;
    if (actual == null || actual.id == _displayedSong?.id) return;
    setState(() {
      _displayedSong = actual;
      _dragOffset.value = 0;
      _adjacentSong.value = null;
    });
  }

  void _handleRouteStatus(AnimationStatus status) {
    final animating =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (animating == _routeAnimating) return;
    setState(() => _routeAnimating = animating);
  }

  void _handleVertSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_vertDismissing) {
      _vertDismissing = false;
      Navigator.of(context).pop();
    }
  }

  void _onDragStart(DragStartDetails details, PlayerProvider player) {
    if (_settleController.isAnimating) return;
    _reconcileTimer?.cancel();
    _committing = false;
    _dragOffset.value = 0;
    _adjacentSong.value = null;
    _displayedSong ??= player.currentSong;
  }

  void _onDragUpdate(DragUpdateDetails details, PlayerProvider player) {
    if (_settleController.isAnimating) return;
    final travel = _travelWidth;
    final newOffset = _dragOffset.value + details.delta.dx;

    double clamped = newOffset;
    if (newOffset.abs() > travel * 0.5) {
      clamped =
          newOffset.sign *
          (travel * 0.5 + (newOffset.abs() - travel * 0.5) * 0.3);
    }

    _dragOffset.value = clamped;
    if (_dragOffset.value > 20) {
      _direction.value = -1;
      _adjacentSong.value = _adjacentFor(player, player.currentIndex - 1);
    } else if (_dragOffset.value < -20) {
      _direction.value = 1;
      _adjacentSong.value = _adjacentFor(player, player.currentIndex + 1);
    } else {
      _adjacentSong.value = null;
    }
  }

  Song? _adjacentFor(PlayerProvider player, int index) {
    final queue = player.queue;
    if (queue.length <= 1) return null;
    if (index >= 0 && index < queue.length) return queue[index];
    return player.repeatMode == AudioRepeatMode.all
        ? queue[(index + queue.length) % queue.length]
        : null;
  }

  void _onDragEnd(DragEndDetails details, PlayerProvider player) {
    if (_settleController.isAnimating) return;
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    final magnitude = _dragOffset.value.abs();
    final strongFlick = velocity.abs() > 900;

    if (magnitude < 20 && strongFlick) {
      _direction.value = velocity < 0 ? 1 : -1;
      _adjacentSong.value = _adjacentFor(
        player,
        player.currentIndex + _direction.value,
      );
    }

    final shouldCommit =
        _adjacentSong.value != null &&
        (magnitude > _travelWidth * 0.22 || strongFlick);
    if (shouldCommit) {
      _commit(player, _direction.value);
    } else {
      _springBack();
    }
  }

  /// A fixed-ish drag distance, so dismissing stays quick on a short landscape
  /// box where a share of the height would be most of the screen.
  double get _vertDismissThreshold {
    final height = MediaQuery.sizeOf(context).height;
    return (height * 0.25).clamp(96.0, 160.0);
  }

  void _onVertDragUpdate(DragUpdateDetails details) {
    if (_vertSettleController.isAnimating || _showQueue) return;
    final next = _vertOffset.value + details.delta.dy;
    if (next < 0) return;
    _vertOffset.value = next;
  }

  void _onVertDragEnd(DragEndDetails details) {
    if (_vertSettleController.isAnimating || _showQueue) return;
    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dy;
    final shouldDismiss =
        _vertOffset.value >= _vertDismissThreshold || velocity > 900;
    if (shouldDismiss) {
      _animateVertDismiss();
    } else {
      _animateVertSpringBack();
    }
  }

  void _stopVertAnim() {
    if (_vertAnim != null && _vertAnimListener != null) {
      _vertAnim!.removeListener(_vertAnimListener!);
    }
    _vertAnim = null;
    _vertAnimListener = null;
  }

  void _animateVertDismiss() {
    _stopVertAnim();
    _vertDismissing = true;
    final start = _vertOffset.value;
    final screenHeight = MediaQuery.sizeOf(context).height;
    _vertSettleController.duration = const Duration(milliseconds: 300);
    _vertAnim = Tween<double>(begin: start, end: screenHeight).animate(
      CurvedAnimation(parent: _vertSettleController, curve: Curves.easeInCubic),
    );
    _vertAnimListener = () => _vertOffset.value = _vertAnim!.value;
    _vertAnim!.addListener(_vertAnimListener!);
    _vertSettleController.forward(from: 0).whenCompleteOrCancel(_stopVertAnim);
  }

  void _animateVertSpringBack() {
    _stopVertAnim();
    _vertDismissing = false;
    final start = _vertOffset.value;
    _vertSettleController.duration = const Duration(milliseconds: 280);
    _vertAnim = Tween<double>(begin: start, end: 0.0).animate(
      CurvedAnimation(parent: _vertSettleController, curve: Curves.elasticOut),
    );
    _vertAnimListener = () => _vertOffset.value = _vertAnim!.value;
    _vertAnim!.addListener(_vertAnimListener!);
    _vertSettleController.forward(from: 0).whenCompleteOrCancel(_stopVertAnim);
  }

  void _commit(PlayerProvider player, int direction) {
    if (direction < 0 && player.position.inSeconds > 3) {
      player.skipToPrevious();
      _springBack();
      return;
    }
    if (_adjacentSong.value == null) {
      _adjacentSong.value = _adjacentFor(
        player,
        player.currentIndex + direction,
      );
    }
    final adjacent = _adjacentSong.value;
    if (adjacent == null) return;
    if (_settleController.isAnimating) _settleController.stop();
    _reconcileTimer?.cancel();

    void skip() {
      if (direction > 0) {
        player.skipToNext();
      } else {
        player.skipToPrevious();
      }
    }

    if (AppHelpers.reduceMotion) {
      setState(() {
        _committing = false;
        _displayedSong = adjacent;
        _dragOffset.value = 0;
        _adjacentSong.value = null;
      });
      skip();
      _scheduleReconcile();
      return;
    }

    _committing = true;
    _direction.value = direction;
    _settleFrom = _dragOffset.value;
    _settleTo = -direction * _travelWidth;
    _settleCurve = Curves.easeOutCubic;
    _settleController.duration = const Duration(milliseconds: 320);
    _settleController.forward(from: 0);
    skip();
    _scheduleReconcile();
  }

  void _springBack() {
    if (_settleController.isAnimating) _settleController.stop();
    if (AppHelpers.reduceMotion) {
      setState(() {
        _dragOffset.value = 0;
        _adjacentSong.value = null;
      });
      return;
    }
    _settleFrom = _dragOffset.value;
    _settleTo = 0;
    _settleCurve = Curves.elasticOut;
    _settleController.duration = const Duration(milliseconds: 500);
    _settleController.forward(from: 0);
  }

  void _scheduleReconcile() {
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final actual =
          _player?.currentSong ?? context.read<PlayerProvider>().currentSong;
      if (actual == null || actual.id == _displayedSong?.id) return;
      if (_settleController.isAnimating || _committing) return;
      setState(() {
        _displayedSong = actual;
        _dragOffset.value = 0;
        _adjacentSong.value = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Selector<PlayerProvider, _NowPlayingIdentity>(
      selector: (_, p) => _NowPlayingIdentity(
        song: p.currentSong,
        isPlaying: p.isPlaying,
        currentIndex: p.currentIndex,
        queueHash: Object.hashAllUnordered(p.queue.map((s) => s.id)),
      ),
      builder: (context, identity, _) {
        final player = context.read<PlayerProvider>();
        final song = identity.song;

        if (song == null) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Center(child: Text('No track playing')),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) {
                if (_vertSettleController.isAnimating) return;
              },
              onVerticalDragUpdate: _onVertDragUpdate,
              onVerticalDragEnd: _onVertDragEnd,
              child: AnimatedBuilder(
                animation: _vertOffset,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _vertOffset.value),
                  child: child,
                ),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _dragOffset,
                        _adjacentSong,
                        _settleController,
                      ]),
                      builder: (context, _) =>
                          _buildBackground(theme, player, song),
                    ),
                    Positioned.fill(child: _buildScrim(theme)),
                    SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final layout = resolveNowPlayingLayout(constraints);
                          final split = layout == NowPlayingLayout.split;
                          final padding = EdgeInsets.symmetric(
                            horizontal: split ? 32 : 20,
                          );
                          _viewportWidth = width - padding.horizontal;

                          return Column(
                            children: [
                              if (!_showQueue)
                                _buildDismissChrome(split: split),
                              Expanded(
                                child: _SectionSwitcher(
                                  section: _showQueue ? 1 : 0,
                                  child: _showQueue
                                      ? _buildQueuePanel(player)
                                      : LayoutBuilder(
                                          builder: (context, inner) {
                                            _viewportWidth =
                                                inner.maxWidth -
                                                padding.horizontal;
                                            return GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onHorizontalDragStart: (d) =>
                                                  _onDragStart(d, player),
                                              onHorizontalDragUpdate: (d) =>
                                                  _onDragUpdate(d, player),
                                              onHorizontalDragEnd: (d) =>
                                                  _onDragEnd(d, player),
                                              child: NowPlayingView(
                                                player: player,
                                                song: _displayedSong ?? song,
                                                adjacentSong:
                                                    _adjacentSong.value,
                                                dragOffset: _effectiveOffset,
                                                dragDirection: _direction.value,
                                                active: !_routeAnimating,
                                                isPlaying: player.isPlaying,
                                                onPrev: () =>
                                                    _commit(player, -1),
                                                onNext: () =>
                                                    _commit(player, 1),
                                                onToggleQueue: () => setState(
                                                  () => _showQueue = true,
                                                ),
                                                padding: EdgeInsets.only(
                                                  left: padding.left,
                                                  right: padding.right,
                                                  top: split ? 8 : 0,
                                                  bottom: split ? 8 : 0,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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

  /// A slim dismiss affordance. In the split composition it moves to the
  /// corner so it does not eat the height the artwork needs.
  Widget _buildDismissChrome({required bool split}) {
    final caret = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Icon(
          PhosphorIconsBold.caretDown,
          size: split ? 26 : 32,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );

    return SizedBox(
      height: split ? 40 : 44,
      child: split
          ? Align(alignment: Alignment.centerLeft, child: caret)
          : Center(child: caret),
    );
  }

  bool _hasArt(Song song) => song.albumId != null || song.filePath.isNotEmpty;

  Widget _buildBackground(ThemeData theme, PlayerProvider player, Song song) {
    final colorProv = context.watch<ColorProvider>();
    final displayed = _displayedSong ?? song;
    final bgColor =
        colorProv.dominantColor ??
        AppHelpers.generateArtColor('$displayed-$displayed');

    final adjacent = _adjacentSong.value;
    final progress = _travelWidth > 0
        ? (_effectiveOffset / _travelWidth).clamp(-1.0, 1.0).abs()
        : 0.0;
    final targetColor = adjacent != null
        ? AppHelpers.generateArtColor('$adjacent-$adjacent')
        : bgColor;
    final blended = Color.lerp(bgColor, targetColor, progress) ?? bgColor;

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: blended),
          if (_hasArt(displayed))
            Opacity(
              opacity: (1 - progress).clamp(0.0, 1.0),
              child: BlurredArtBackground(song: displayed),
            ),
          if (adjacent != null && _hasArt(adjacent))
            Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: BlurredArtBackground(song: adjacent),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  blended.withValues(alpha: 0.5),
                  theme.colorScheme.surface.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrim(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
        ),
      ),
    );
  }

  Widget _buildQueuePanel(PlayerProvider player) {
    final queue = player.queue;
    final theme = Theme.of(context);

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsBold.musicNotes,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Queue is empty',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add songs to see them here',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= AppConstants.nowPlayingSplitMinWidth;
        final gutter = wide ? 32.0 : 16.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Up Next',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${queue.length} song${queue.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showQueue = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsBold.caretLeft,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Now Playing',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: const QueueList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlayingIdentity {
  final Song? song;
  final bool isPlaying;
  final int currentIndex;
  final int queueHash;

  const _NowPlayingIdentity({
    required this.song,
    required this.isPlaying,
    required this.currentIndex,
    required this.queueHash,
  });

  @override
  bool operator ==(Object other) =>
      other is _NowPlayingIdentity &&
      other.song?.id == song?.id &&
      other.isPlaying == isPlaying &&
      other.currentIndex == currentIndex &&
      other.queueHash == queueHash;

  @override
  int get hashCode => Object.hash(song?.id, isPlaying, currentIndex, queueHash);
}

class _SectionSwitcher extends StatefulWidget {
  final int section;
  final Widget child;

  const _SectionSwitcher({required this.section, required this.child});

  @override
  State<_SectionSwitcher> createState() => _SectionSwitcherState();
}

class _SectionSwitcherState extends State<_SectionSwitcher>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 360);

  late final AnimationController _controller;
  late Widget _currentChild;
  Widget? _leavingChild;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _currentChild = widget.child;
    _controller =
        AnimationController(vsync: this, duration: _duration, value: 1)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _leavingChild = null);
            }
          });
  }

  @override
  void didUpdateWidget(_SectionSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _direction = widget.section > oldWidget.section ? 1 : -1;
      setState(() {
        _leavingChild = _currentChild;
        _currentChild = widget.child;
        _controller.forward(from: 0);
      });
    } else if (!_controller.isAnimating) {
      setState(() => _currentChild = widget.child);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final entering = Curves.easeOutCubic.transform(t);
            final leaving = Curves.easeInCubic.transform(t);

            return Stack(
              fit: StackFit.expand,
              children: [
                if (_leavingChild != null && t < 1.0)
                  Transform.translate(
                    offset: Offset(-_direction * width * leaving, 0),
                    child: Opacity(
                      opacity: 1 - t,
                      child: IgnorePointer(child: _leavingChild),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(_direction * width * (1 - entering), 0),
                  child: _currentChild,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

bool _nowPlayingOpen = false;

/// A shell that can host the player in place instead of pushing a route, e.g.
/// the tablet/desktop layout with its nav rail. [paneWidth] is how much width
/// the player itself would get there, which decides whether hosting beats
/// opening the full-screen player.
class WideNowPlayingHost {
  const WideNowPlayingHost({
    required this.paneWidth,
    required this.onOpen,
    this.preferInPlace = false,
  });

  final double paneWidth;
  final VoidCallback onOpen;

  /// Landscape tablets always have a side-by-side player and Up Next shell,
  /// even when the player pane is too narrow for its own art/controls split.
  /// Hosting there is better than pushing a route without that split.
  final bool preferInPlace;
}

WideNowPlayingHost? _wideHost;

void setWideNowPlayingHost(WideNowPlayingHost? host) => _wideHost = host;

void openNowPlaying(BuildContext context) {
  final host = _wideHost;
  if (host != null &&
      (host.preferInPlace ||
          host.paneWidth >= AppConstants.nowPlayingSplitMinWidth)) {
    host.onOpen();
    return;
  }

  if (_nowPlayingOpen) return;
  _nowPlayingOpen = true;
  FocusManager.instance.primaryFocus?.unfocus();
  Navigator.of(context)
      .push(
        PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => const NowPlayingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        ),
      )
      .then((_) {
        _nowPlayingOpen = false;
        FocusManager.instance.primaryFocus?.unfocus();
      });
}
