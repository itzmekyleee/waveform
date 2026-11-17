import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class WaveformVisualizer extends StatefulWidget {
  final AudioPlayer player;
  final bool active;
  final Color? color;

  const WaveformVisualizer({
    super.key,
    required this.player,
    this.active = true,
    this.color,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 32;
  static const double _restLevel = 0.10;

  late final AnimationController _controller;
  final List<double> _display = List.filled(_barCount, _restLevel);
  final List<double> _target = List.filled(_barCount, _restLevel);
  final Random _random = Random();
  Timer? _targetTimer;
  StreamSubscription<bool>? _playingSub;
  bool _isPlaying = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.player.playing;
    _active = widget.active;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_tick);

    _playingSub = widget.player.playingStream.listen((playing) {
      _isPlaying = playing;
      if (!mounted) return;
      setState(_applyActive);
    });

    _applyActive();
  }

  @override
  void didUpdateWidget(WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _active = widget.active;
      _applyActive();
    }
  }

  void _applyActive() {
    if (!_active) {
      _stopTargetTimer();
      for (int i = 0; i < _barCount; i++) {
        _target[i] = _restLevel;
      }
      if (_controller.isAnimating) _controller.stop();
    } else if (_isPlaying) {
      if (!_controller.isAnimating) _controller.repeat();
      _startTargetTimer();
    } else {
      _stopTargetTimer();
      for (int i = 0; i < _barCount; i++) {
        _target[i] = _restLevel;
      }
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  void _startTargetTimer() {
    _targetTimer?.cancel();
    _targetTimer = Timer.periodic(const Duration(milliseconds: 240), (_) {
      _generateTargets();
    });
  }

  void _stopTargetTimer() {
    _targetTimer?.cancel();
    _targetTimer = null;
  }

  void _generateTargets() {
    if (!mounted) return;
    final beatIndex = _random.nextInt(_barCount);
    final beatStrength = 0.35 + _random.nextDouble() * 0.45;
    for (int i = 0; i < _barCount; i++) {
      final distance = (i - beatIndex).abs().toDouble();
      final falloff = max(0.0, 1.0 - distance / (_barCount * 0.4));
      final base = 0.12 + _random.nextDouble() * 0.28;
      _target[i] =
          (base + falloff * beatStrength * (0.6 + _random.nextDouble()))
              .clamp(0.08, 1.0);
    }
  }

  void _tick() {
    if (!mounted) return;
    var changed = false;
    for (int i = 0; i < _barCount; i++) {
      final next = _display[i] + (_target[i] - _display[i]) * 0.12;
      if ((next - _display[i]).abs() > 0.0004) {
        _display[i] = next;
        changed = true;
      } else {
        _display[i] = _target[i];
      }
    }

    if (changed) {
      setState(() {});
    } else if (!_isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _stopTargetTimer();
    _playingSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return CustomPaint(
      size: Size.infinite,
      painter: _WaveformPainter(
        amplitudes: List.of(_display),
        color: color,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  _WaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final spacing = size.width / amplitudes.length;
    final barWidth = spacing * 0.55;
    const verticalPadding = 2.0;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color,
        color.withValues(alpha: 0.45),
      ],
    );
    paint.shader = gradient.createShader(Offset.zero & size);

    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * spacing + spacing / 2;
      final barHeight = (amplitudes[i] * (size.height - verticalPadding * 2))
          .clamp(3.0, size.height - verticalPadding * 2);
      final y = size.height - verticalPadding - barHeight;

      final rect = Rect.fromLTWH(x - barWidth / 2, y, barWidth, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    if (old.amplitudes.length != amplitudes.length) return true;
    for (int i = 0; i < amplitudes.length; i++) {
      if (amplitudes[i] != old.amplitudes[i]) return true;
    }
    return false;
  }
}
