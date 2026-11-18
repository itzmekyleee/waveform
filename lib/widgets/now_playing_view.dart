import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_handler.dart';
import '../services/scanner_service.dart';
import '../utils/constants.dart';
import 'album_art.dart';
import 'app_toast.dart';
import 'pressable_scale.dart';
import 'song_actions_sheet.dart';
import 'track_progress.dart';
import 'waveform_visualizer.dart';

enum NowPlayingLayout { stacked, split }

/// Lets a host share its drag notifiers with [NowPlayingView] so the artwork and
/// transport can follow a swipe without rebuilding the rest of the screen.
class SongCarouselController {
  const SongCarouselController({
    required this.offset,
    required this.adjacent,
    required this.direction,
  });

  final ValueNotifier<double> offset;
  final ValueNotifier<Song?> adjacent;
  final ValueNotifier<int> direction;

  Listenable get listenable => Listenable.merge([
    offset,
    adjacent,
    direction,
  ]);
}

/// Picks the composition from the box the player actually gets, not from the
/// window size. A short landscape box (tablet held sideways, a phone on its
/// side, a freeform window) goes side by side so the width is used instead of
/// squeezing the artwork into what little height is left.
NowPlayingLayout resolveNowPlayingLayout(BoxConstraints constraints) {
  final wide = constraints.maxWidth >= AppConstants.nowPlayingSplitMinWidth;
  final landscape =
      constraints.maxWidth >
      constraints.maxHeight * AppConstants.nowPlayingSplitAspect;
  return wide && landscape ? NowPlayingLayout.split : NowPlayingLayout.stacked;
}

/// The player composition, shared by the full-screen route and the in-shell
/// wide pane so both look and behave the same on every size.
///
/// It owns the swipe carousel, the artwork, the metadata, the transport and the
/// secondary row. Background, dismissal gestures and the queue live in the host.
class NowPlayingView extends StatelessWidget {
  final PlayerProvider player;

  /// The song shown in place; during a swipe this is the outgoing song until
  /// the host commits.
  final Song song;

  /// The song sliding in from the other side, if any.
  final Song? adjacentSong;

  /// Shared notifiers from the host. When supplied, they drive the carousel
  /// instead of the static values below, so a drag only repaints the slides.
  final SongCarouselController? carousel;

  final double dragOffset;
  final int dragDirection;

  /// Drives the waveform animation. Hosts turn it off while something is
  /// animating on top of the player.
  final bool active;

  final bool isPlaying;

  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// Rendered in the secondary row when provided.
  final VoidCallback? onToggleQueue;

  final EdgeInsets padding;

  const NowPlayingView({
    super.key,
    required this.player,
    required this.song,
    this.adjacentSong,
    this.carousel,
    this.dragOffset = 0,
    this.dragDirection = 1,
    this.active = true,
    this.isPlaying = true,
    this.onPrev,
    this.onNext,
    this.onToggleQueue,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final shared = carousel;

          Widget composition(
            Song s, {
            required bool isCurrent,
            required bool playing,
          }) {
            return RepaintBoundary(
              child: NowPlayingComposition(
                player: player,
                song: s,
                layout: resolveNowPlayingLayout(constraints),
                constraints: constraints,
                active: isCurrent && active,
                isPlaying: playing,
                onPrev: onPrev,
                onNext: onNext,
                onToggleQueue: onToggleQueue,
              ),
            );
          }

          Widget buildSlides(Song? next, double offset, int direction) {
            final currentChild = composition(
              song,
              isCurrent: true,
              playing: isPlaying,
            );
            final nextChild = next == null
                ? null
                : composition(next, isCurrent: false, playing: false);

            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (nextChild != null)
                  Transform.translate(
                    offset: Offset(offset + direction * width, 0),
                    child: nextChild,
                  ),
                Transform.translate(
                  offset: Offset(offset, 0),
                  child: currentChild,
                ),
              ],
            );
          }

          // The compositions are built once per song; only their transforms
          // follow the notifiers, so a drag never rebuilds artwork or controls.
          if (shared != null) {
            return ValueListenableBuilder<Song?>(
              valueListenable: shared.adjacent,
              builder: (context, next, _) {
                return AnimatedBuilder(
                  animation: Listenable.merge([
                    shared.offset,
                    shared.direction,
                  ]),
                  builder: (context, _) => buildSlides(
                    next,
                    shared.offset.value,
                    shared.direction.value,
                  ),
                );
              },
            );
          }

          return buildSlides(adjacentSong, dragOffset, dragDirection);
        },
      ),
    );
  }
}

/// Artwork plus metadata and transport, arranged for the resolved layout.
class NowPlayingComposition extends StatelessWidget {
  final PlayerProvider player;
  final Song song;
  final NowPlayingLayout layout;
  final BoxConstraints constraints;
  final bool active;
  final bool isPlaying;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onToggleQueue;

  const NowPlayingComposition({
    super.key,
    required this.player,
    required this.song,
    required this.layout,
    required this.constraints,
    this.active = true,
    this.isPlaying = true,
    this.onPrev,
    this.onNext,
    this.onToggleQueue,
  });

  bool get _isSplit => layout == NowPlayingLayout.split;

  /// The artwork is sized off both axes and never off a hard floor: a box that
  /// cannot hold a square simply gets a smaller square, so the art can never be
  /// squashed by its parent.
  double _artSide(double availableWidth, double availableHeight, double cap) {
    final side = math.min(availableWidth, availableHeight);
    return side.clamp(0.0, cap).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return _isSplit ? _buildSplit(context) : _buildStacked(context);
  }

  Widget _buildSplit(BuildContext context) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    final panelWidth = ((width - AppConstants.nowPlayingSplitGutter) / 2).clamp(
      AppConstants.nowPlayingPanelMinWidth,
      AppConstants.nowPlayingPanelMaxWidth,
    );
    final artSlotWidth =
        width - panelWidth - AppConstants.nowPlayingSplitGutter;
    final side = _artSide(
      artSlotWidth,
      height - AppConstants.nowPlayingArtShadowBleed * 2,
      AppConstants.nowPlayingArtMax,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: side, height: side, child: _art(context, side)),
        const SizedBox(width: AppConstants.nowPlayingSplitGutter),
        Expanded(
          child: Center(
            // scaleDown keeps the panel whole on short landscape boxes instead
            // of overflowing it, and never steals the carousel's drag.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: panelWidth,
                child: _panel(context, compact: false),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStacked(BuildContext context) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    final showVisualizer =
        height >=
        AppConstants.nowPlayingMetadataHeight +
            AppConstants.nowPlayingControlsHeight +
            AppConstants.nowPlayingArtGap;
    final metadataHeight = showVisualizer
        ? AppConstants.nowPlayingMetadataHeight
        : AppConstants.nowPlayingMetadataCompactHeight;
    final artHeight =
        height -
        metadataHeight -
        AppConstants.nowPlayingControlsHeight -
        AppConstants.nowPlayingArtGap;
    final side = _artSide(
      width * AppConstants.nowPlayingArtWidthShare,
      artHeight,
      AppConstants.nowPlayingArtSmall,
    );

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: side, height: side, child: _art(context, side)),
              const SizedBox(height: AppConstants.nowPlayingArtGap),
              _metadata(context, showVisualizer: showVisualizer),
              _panel(context, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _art(BuildContext context, double side) {
    final radius = _isSplit ? 20.0 : 16.0;
    return Hero(
      tag: 'album_art_${song.id}',
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.96,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: _isSplit ? 60 : 40,
                offset: Offset(0, _isSplit ? 20 : 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: _isSplit ? 100 : 80,
                offset: Offset(0, _isSplit ? 40 : 32),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: AlbumArtWidget(
              albumId: song.albumId,
              title: song.displayTitle,
              artist: song.displayArtist,
              filePath: song.filePath,
              contentUri: song.contentUri,
              size: side,
              borderRadius: radius,
              isPlaying: isPlaying,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metadata(BuildContext context, {required bool showVisualizer}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.displayTitle,
          style:
              (_isSplit
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          song.displayArtist,
          style:
              (_isSplit
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.bodyLarge)
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          song.displayAlbum,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showVisualizer) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: WaveformVisualizer(
              player: player.audioHandler.player,
              active: active,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _panel(BuildContext context, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 4 : 0,
        compact ? 12 : 20,
        compact ? 4 : 0,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TrackProgress(interactive: true, showTimes: true),
          SizedBox(height: _isSplit ? 18 : 12),
          _transport(context),
          SizedBox(height: _isSplit ? 12 : 8),
          _secondary(context),
        ],
      ),
    );
  }

  Widget _transport(BuildContext context) {
    final isFavorite = context.select<PlaylistProvider, bool>(
      (p) => p.isFavorite(song.id),
    );
    final playSize = _isSplit ? 68.0 : 58.0;
    final navSize = _isSplit ? 32.0 : 30.0;

    Widget toggle({required Widget child, required VoidCallback onTap}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              toggle(
                onTap: () async {
                  await player.toggleShuffle();
                  if (context.mounted) {
                    showAppToast(
                      context,
                      player.isShuffle ? 'Shuffle on' : 'Shuffle off',
                      icon: PhosphorIconsBold.shuffle,
                    );
                  }
                },
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        PhosphorIconsBold.shuffle,
                        key: ValueKey('shuffle_${player.isShuffle}'),
                        size: 24,
                        color: player.isShuffle
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              _AnimatedNavButton(
                icon: PhosphorIconsBold.skipBack,
                onPressed: onPrev ?? () => player.skipToPrevious(),
                size: navSize,
                color: Colors.white,
              ),
            ],
          ),
        ),
        PressableScale(
          pressedScale: 0.9,
          onTap: () => player.togglePlayPause(),
          child: Container(
            width: playSize,
            height: playSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              player.isPlaying
                  ? PhosphorIconsBold.pause
                  : PhosphorIconsBold.play,
              size: playSize * 0.5,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AnimatedNavButton(
                icon: PhosphorIconsBold.skipForward,
                onPressed: onNext ?? () => player.skipToNext(),
                size: navSize,
                color: Colors.white,
              ),
              _FavoriteToggleButton(
                isFavorite: isFavorite,
                onTap: () =>
                    context.read<PlaylistProvider>().toggleFavorite(song.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _secondary(BuildContext context) {
    final iconSize = _isSplit ? 24.0 : 20.0;

    Widget slot(Widget child) =>
        SizedBox(width: 48, height: 48, child: Center(child: child));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showSleepTimerSheet(context, player),
          child: slot(
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                PhosphorIconsRegular.timer,
                key: ValueKey(
                  'timer_${player.sleepTimerSecondsRemaining != null}',
                ),
                size: iconSize,
                color: player.sleepTimerSecondsRemaining != null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await player.toggleMute();
            if (!context.mounted) return;
            showAppToast(
              context,
              player.isMuted ? 'Muted' : 'Sound on',
              icon: player.isMuted
                  ? PhosphorIconsBold.speakerNone
                  : PhosphorIconsBold.speakerHigh,
            );
          },
          child: slot(
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                player.isMuted
                    ? PhosphorIconsBold.speakerNone
                    : PhosphorIconsBold.speakerHigh,
                key: ValueKey('mute_${player.isMuted}'),
                size: iconSize,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        if (onToggleQueue != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleQueue,
            child: slot(
              Icon(
                PhosphorIconsBold.queue,
                size: iconSize,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await player.cycleRepeat();
            if (!context.mounted) return;
            final message = switch (player.repeatMode) {
              AudioRepeatMode.off => 'Repeat off',
              AudioRepeatMode.one => 'Repeat one',
              AudioRepeatMode.all => 'Repeat all',
            };
            showAppToast(context, message, icon: PhosphorIconsBold.repeat);
          },
          child: slot(
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                player.repeatMode == AudioRepeatMode.one
                    ? PhosphorIconsBold.repeatOnce
                    : PhosphorIconsBold.repeat,
                key: ValueKey('repeat_${player.repeatMode.index}'),
                size: iconSize,
                color: player.repeatMode != AudioRepeatMode.off
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showSleepTimerSheet(BuildContext context, PlayerProvider player) {
  final options = [
    (label: '15 minutes', seconds: 15 * 60),
    (label: '30 minutes', seconds: 30 * 60),
    (label: '45 minutes', seconds: 45 * 60),
    (label: '1 hour', seconds: 60 * 60),
    (label: '2 hours', seconds: 2 * 60 * 60),
  ];

  return showGlassBottomSheet(
    context,
    maxWidth: 420,
    builder: (ctx) => ListenableBuilder(
      listenable: player,
      builder: (buildContext, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              'Sleep Timer',
              style: Theme.of(
                buildContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (player.sleepTimerSecondsRemaining != null)
            _buildTimerOption(
              buildContext,
              icon: PhosphorIconsBold.clock,
              label: 'Cancel Timer',
              subtitle:
                  '${(player.sleepTimerSecondsRemaining! ~/ 60)}:${(player.sleepTimerSecondsRemaining! % 60).toString().padLeft(2, '0')} remaining',
              onTap: () {
                player.cancelSleepTimer();
                Navigator.pop(buildContext);
              },
            ),
          ...options.map(
            (opt) => _buildTimerOption(
              buildContext,
              icon: PhosphorIconsRegular.timer,
              label: opt.label,
              onTap: () {
                player.startSleepTimer(opt.seconds);
                Navigator.pop(buildContext);
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

Widget _buildTimerOption(
  BuildContext context, {
  required IconData icon,
  required String label,
  String? subtitle,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Art-derived backdrop. Cached by song id so swiping does not re-decode.
class BlurredArtBackground extends StatefulWidget {
  final Song song;
  const BlurredArtBackground({super.key, required this.song});

  @override
  State<BlurredArtBackground> createState() => _BlurredArtBackgroundState();
}

class _BlurredArtBackgroundState extends State<BlurredArtBackground> {
  static const int _maxCacheEntries = 16;
  static final double _blurSigma = 40;

  static final Map<int, ui.Image> _blurCache = {};

  Future<ui.Image?>? _blurFuture;

  @override
  void initState() {
    super.initState();
    _loadBlur();
  }

  @override
  void didUpdateWidget(BlurredArtBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _loadBlur();
    }
  }

  void _loadBlur() {
    final cached = _blurCache[widget.song.id];
    if (cached != null) {
      _blurFuture = Future.value(cached);
      return;
    }
    _blurFuture = _renderBlur();
  }

  Future<ui.Image?> _renderBlur() async {
    final scanner = context.read<ScannerService>();
    final bytes = await _resolveArt(scanner);
    if (bytes == null || bytes.isEmpty) return null;

    final image = await _decode(bytes);
    if (image == null) return null;

    try {
      const width = 432;
      if (image.width <= 0) {
        image.dispose();
        return null;
      }
      final height = ((image.height * width) / image.width).round().clamp(
        1,
        432 * 4,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _blurSigma,
          sigmaY: _blurSigma,
        )
        ..filterQuality = FilterQuality.low;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        paint,
      );
      final picture = recorder.endRecording();
      final blurred = await picture.toImage(width, height);
      picture.dispose();
      image.dispose();

      if (_blurCache.length >= _maxCacheEntries) {
        _blurCache.remove(_blurCache.keys.first)?.dispose();
      }
      _blurCache[widget.song.id] = blurred;
      return blurred;
    } catch (_) {
      image.dispose();
      return null;
    }
  }

  Future<ui.Image?> _decode(Uint8List bytes) {
    final completer = Completer<ui.Image?>();
    var errored = false;
    try {
      ui.decodeImageFromList(bytes, (image) {
        if (!errored && !completer.isCompleted) completer.complete(image);
      });
    } catch (_) {
      errored = true;
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  Future<Uint8List?> _resolveArt(ScannerService scanner) async {
    final song = widget.song;
    final albumId = song.albumId;
    if (albumId != null && albumId > 0) {
      final art = await scanner.getAlbumArt(albumId, size: 1024);
      if (art != null && art.isNotEmpty) return art;
    }
    if (song.filePath.isNotEmpty) {
      final art = await scanner.getSongArtwork(
        song.filePath,
        contentUri: song.contentUri,
      );
      if (art != null && art.isNotEmpty) return art;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image?>(
      future: _blurFuture,
      builder: (context, snapshot) {
        final img = snapshot.data;
        if (img == null) return const SizedBox.shrink();
        return RepaintBoundary(
          child: RawImage(image: img, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _AnimatedNavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color color;

  const _AnimatedNavButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.color,
  });

  @override
  State<_AnimatedNavButton> createState() => _AnimatedNavButtonState();
}

class _AnimatedNavButtonState extends State<_AnimatedNavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.75), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.1), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() {
    _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: IconButton(
        onPressed: _handlePress,
        icon: Icon(widget.icon, size: widget.size, color: widget.color),
      ),
    );
  }
}

class _FavoriteToggleButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteToggleButton({required this.isFavorite, required this.onTap});

  @override
  State<_FavoriteToggleButton> createState() => _FavoriteToggleButtonState();
}

class _FavoriteToggleButtonState extends State<_FavoriteToggleButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _popController;
  late final AnimationController _sparkleController;
  late final AnimationController _burstController;
  late final Animation<double> _sparkle;
  bool _wasAdding = true;

  static const List<Color> _particleColors = [
    Color(0xFFFF5D8F),
    Color(0xFFFF8FA3),
    Color(0xFFFFC2D1),
    Color(0xFFFF6B6B),
    Color(0xFFFFA07A),
    Color(0xFFF472B6),
  ];

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _sparkleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            _sparkleController.reverse();
          }
        });
    _sparkle = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOutCubic,
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void didUpdateWidget(_FavoriteToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _wasAdding = widget.isFavorite;
      _popController.forward(from: 0);
      if (_wasAdding) {
        _sparkleController.forward(from: 0);
        _burstController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _popController.dispose();
    _sparkleController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFav = widget.isFavorite;

    final pressScale =
        1.0 - 0.18 * Curves.easeOut.transform(_pressController.value);
    final popValue = _popController.value;
    final popScale = _wasAdding
        ? 1.0 + 0.4 * math.sin(popValue * math.pi)
        : 1.0 - 0.15 * math.sin(popValue * math.pi);
    final scale = pressScale * popScale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pressController,
          _popController,
          _sparkleController,
          _burstController,
        ]),
        builder: (context, _) {
          final burst = Curves.easeOutCubic.transform(_burstController.value);
          final burstOpacity = math
              .sin(_burstController.value * math.pi)
              .clamp(0.0, 1.0);
          final sparkleScale = 0.6 + (_sparkle.value * 0.8);
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 6; i++)
                    Positioned(
                      left:
                          24 +
                          math.cos(i * math.pi / 3) *
                              (13 + (i % 3) * 3) *
                              burst -
                          4,
                      top:
                          24 +
                          math.sin(i * math.pi / 3) *
                              (13 + (i % 3) * 3) *
                              burst -
                          4,
                      child: Opacity(
                        opacity: burstOpacity,
                        child: Transform.scale(
                          scale: 0.4 + burst * 0.6,
                          child: Icon(
                            PhosphorIconsFill.heart,
                            size: 8,
                            color: _particleColors[i],
                          ),
                        ),
                      ),
                    ),
                  if (_sparkleController.value > 0) ...[
                    Positioned(
                      top: 2,
                      left: 12,
                      child: Opacity(
                        opacity: _sparkleController.value,
                        child: Transform.scale(
                          scale: sparkleScale,
                          child: Icon(
                            PhosphorIconsBold.sparkle,
                            size: 10,
                            color: Colors.amber.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 4,
                      child: Opacity(
                        opacity: _sparkleController.value,
                        child: Transform.scale(
                          scale: sparkleScale * 0.8,
                          child: Icon(
                            PhosphorIconsBold.sparkle,
                            size: 9,
                            color: Colors.orange.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Icon(
                    isFav
                        ? PhosphorIconsFill.heart
                        : PhosphorIconsRegular.heart,
                    size: 24,
                    color: isFav
                        ? Colors.red
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
