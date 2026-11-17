import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/aurora_background.dart';
import 'home_screen.dart';
import 'permission_screen.dart';
import '../services/permission_service.dart';

class SplashScreen extends StatefulWidget {
  /// Whether this splash was pushed on top of an already-running app (when the
  /// app is brought back from the background) instead of being the initial
  /// launch screen. Overlay splashes just play the animation and pop
  /// themselves instead of navigating to the home screen.
  final bool isOverlay;

  const SplashScreen({super.key, this.isOverlay = false});

  /// True while any [SplashScreen] is currently mounted (used to avoid stacking
  /// a second splash on top of the launch splash when resuming mid-splash).
  static bool get isVisible => _SplashScreenState._activeCount > 0;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static int _activeCount = 0;

  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late final TickerFuture _introFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _activeCount++;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5)),
    );
    _scaleUp = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOut),
      ),
    );
    _introFuture = _controller.forward();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.isOverlay) {
        await _introFuture;
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final permService = PermissionService();
      final library = context.read<LibraryProvider>();
      final hasPermission = await permService.checkAndRequestPermissions();

      // Keep the opening animation fully visible before leaving the splash.
      await _introFuture;

      if (!mounted) return;

      if (!hasPermission) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PermissionScreen()),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );

      await library.loadLibrary();
    } catch (e) {
      if (mounted) {
        if (widget.isOverlay) {
          Navigator.of(context).pop();
          return;
        }
        setState(() => _error = e.toString());
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _activeCount--;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D1117),
              const Color(0xFF161B22),
              theme.colorScheme.primary.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AuroraBackground(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
                theme.colorScheme.surface,
              ],
              opacity: 0.4,
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.scale(
                    scale: _scaleUp.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icons/waveform-official.png',
                          width: 128,
                          height: 128,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.graphic_eq_rounded,
                            size: 128,
                            color: theme.colorScheme.primary.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Opacity(
                          opacity: _titleFade.value,
                          child: Text(
                            'Waveform',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: _subtitleFade.value,
                          child: Text(
                            'Your music, your way',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        if (_error != null)
                          Text(
                            'Setup error — opening app...',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          )
                        else
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
