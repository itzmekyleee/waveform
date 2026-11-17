import 'package:flutter/material.dart';
import '../utils/helpers.dart';

/// Animated equalizer bars used to indicate the currently-playing track.
class NowPlayingBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;
  final double barWidth;

  const NowPlayingBars({
    super.key,
    this.isPlaying = true,
    required this.color,
    this.height = 16,
    this.barWidth = 3,
  });

  @override
  State<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends State<NowPlayingBars>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 3;

  late final AnimationController _controller;
  late final List<Animation<double>> _bars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bars = List.generate(_barCount, (i) {
      final phase = i / _barCount;
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.25, end: 1.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.35), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 0.35, end: 0.6), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.25), weight: 1),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(phase, phase + 0.9, curve: Curves.easeInOut),
        ),
      );
    });
    _syncAnimation();
  }

  @override
  void didUpdateWidget(NowPlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isPlaying && !AppHelpers.reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restHeight = widget.height * 0.25;
    final spacing = widget.barWidth * 0.7;

    return SizedBox(
      width: _barCount * widget.barWidth + spacing * (_barCount - 1),
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barCount, (i) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: AnimatedBuilder(
              animation: _bars[i],
              builder: (context, _) {
                final t = widget.isPlaying && !AppHelpers.reduceMotion
                    ? _bars[i].value
                    : restHeight / widget.height;
                return Container(
                  width: widget.barWidth,
                  height: widget.height * t,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(widget.barWidth),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
