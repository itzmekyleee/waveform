import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../utils/helpers.dart';

class TrackProgress extends StatefulWidget {
  final bool interactive;
  final bool showTimes;
  final double thinBarHeight;
  final Color? color;

  const TrackProgress({
    super.key,
    this.interactive = false,
    this.showTimes = false,
    this.thinBarHeight = 2,
    this.color,
  });

  @override
  State<TrackProgress> createState() => _TrackProgressState();
}

class _TrackProgressState extends State<TrackProgress> {
  static const double _trackInset = 12;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double? _dragValue;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerProvider>().audioHandler.player;
    _position = player.position;
    _duration = player.duration ?? Duration.zero;
    _positionSub = player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _durationSub = player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  double get _maxMs =>
      _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;

  double get _positionMs =>
      _position.inMilliseconds.toDouble().clamp(0.0, _maxMs);

  double get _displayMs => _dragValue ?? _positionMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    if (!widget.interactive) {
      return LinearProgressIndicator(
        value: _maxMs > 1 ? (_displayMs / _maxMs).clamp(0.0, 1.0) : 0.0,
        minHeight: widget.thinBarHeight,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: color,
            inactiveTrackColor: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: _trackInset),
          ),
          child: Slider(
            value: _displayMs,
            max: _maxMs,
            onChangeStart: (_) => setState(() => _dragValue = _positionMs),
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              setState(() => _dragValue = null);
              context
                  .read<PlayerProvider>()
                  .seek(Duration(milliseconds: v.toInt()));
            },
          ),
        ),
        if (widget.showTimes) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _trackInset),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppHelpers.formatDuration(
                      Duration(milliseconds: _displayMs.toInt())),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.4)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  AppHelpers.formatDuration(_duration),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.4)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
