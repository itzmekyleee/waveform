import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/helpers.dart';

/// A slow-drifting aurora of radial-gradient blobs painted with a single
/// [CustomPainter], avoiding per-frame `ImageFilter` blur cost. Respects
/// [AppHelpers.reduceMotion].
class AuroraBackground extends StatefulWidget {
  final List<Color> colors;
  final double opacity;
  final bool active;

  const AuroraBackground({
    super.key,
    required this.colors,
    this.opacity = 0.55,
    this.active = true,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _syncActive();
  }

  @override
  void didUpdateWidget(AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncActive();
    }
  }

  void _syncActive() {
    if (widget.active && !AppHelpers.reduceMotion) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _resScale = 0.25;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final lowW = (size.width * _resScale).roundToDouble().clamp(1.0, 1024.0).toDouble();
            final lowH =
                (size.height * _resScale).roundToDouble().clamp(1.0, 1024.0).toDouble();
            return IgnorePointer(
              child: RepaintBoundary(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: lowW,
                      height: lowH,
                      child: CustomPaint(
                        size: Size(lowW, lowH),
                        painter: _AuroraPainter(
                          colors: widget.colors,
                          t: _controller.value,
                          opacity: widget.opacity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final List<Color> colors;
  final double t;
  final double opacity;

  _AuroraPainter({
    required this.colors,
    required this.t,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final blobs = [
      (
        offset: Offset(0.30, 0.25),
        radius: 0.65,
        color: colors.isEmpty ? Colors.transparent : colors[0],
        speed: 1.0,
      ),
      (
        offset: Offset(0.70, 0.40),
        radius: 0.55,
        color: colors.length > 1 ? colors[1] : colors[0],
        speed: 1.3,
      ),
      (
        offset: Offset(0.50, 0.80),
        radius: 0.70,
        color: colors.length > 2 ? colors[2] : colors[0],
        speed: 0.8,
      ),
    ];

    final maxDimension = math.max(size.width, size.height);
    // Quantize the phase so Blob shaders are reused across frames instead of
    // allocating a new gradient every repaint.
    final step = (t * 120).round() / 120;
    final phase = step * 2 * math.pi;

    for (var i = 0; i < blobs.length; i++) {
      final blob = blobs[i];
      final angle = phase * blob.speed + (i * 2.1);
      final dx = math.sin(angle) * 0.12;
      final dy = math.cos(angle * 1.3) * 0.10;

      final baseCenter = Offset(
        blob.offset.dx * size.width,
        blob.offset.dy * size.height,
      );
      final radius = blob.radius * maxDimension * 0.5;

      final paint = Paint()
        ..shader = _ShaderCache.of(
          color: blob.color,
          opacity: opacity,
          radius: radius,
          center: baseCenter,
        );

      canvas.save();
      canvas.translate(dx * size.width, dy * size.height);
      canvas.drawCircle(baseCenter, radius, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.opacity != opacity ||
        oldDelegate.colors != colors;
  }
}

class _ShaderCache {
  static final Map<String, Shader> _shaders = {};

  static Shader of({
    required Color color,
    required double opacity,
    required double radius,
    required Offset center,
  }) {
    final key =
        '${color.toARGB32()}|$opacity|${radius.toStringAsFixed(1)}'
        '|${center.dx.toStringAsFixed(1)}|${center.dy.toStringAsFixed(1)}';
    return _shaders.putIfAbsent(key, () {
      return RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    });
  }
}
