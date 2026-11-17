import 'dart:async';
import 'package:flutter/material.dart';

/// Severity of an app toast, controlling its tint color and default icon.
enum ToastSeverity { info, success, error, warning }

extension _ToastSeverityStyle on ToastSeverity {
  IconData get icon => switch (this) {
    ToastSeverity.info => Icons.info_rounded,
    ToastSeverity.success => Icons.check_rounded,
    ToastSeverity.error => Icons.error_rounded,
    ToastSeverity.warning => Icons.warning_amber_rounded,
  };

  Color get color => switch (this) {
    ToastSeverity.info => const Color(0xFF3B82F6),
    ToastSeverity.success => const Color(0xFF34C759),
    ToastSeverity.error => const Color(0xFFFF453A),
    ToastSeverity.warning => const Color(0xFFFFB340),
  };
}

OverlayEntry? _currentToast;

/// Shows a compact, glassy pill toast above all routes. Any previously
/// visible app toast is replaced. The toast auto-dismisses after ~1.1s and
/// never blocks touches. When [icon] is null, the severity's default icon
/// is shown.
void showAppToast(
  BuildContext context,
  String message, {
  IconData? icon,
  ToastSeverity severity = ToastSeverity.info,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _currentToast?.remove();

  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (_) => _AppToast(
      message: message,
      icon: icon ?? severity.icon,
      severity: severity,
      onDismissed: () {
        if (_currentToast == entry) _currentToast = null;
        entry?.remove();
      },
    ),
  );
  _currentToast = entry;
  overlay.insert(entry);
}

class _AppToast extends StatefulWidget {
  final String message;
  final IconData? icon;
  final ToastSeverity severity;
  final VoidCallback onDismissed;

  const _AppToast({
    required this.message,
    this.icon,
    required this.severity,
    required this.onDismissed,
  });

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast>
    with SingleTickerProviderStateMixin {
  static const Duration _hold = Duration(milliseconds: 1100);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
          reverseDuration: const Duration(milliseconds: 180),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed && mounted) {
            widget.onDismissed();
          }
        });
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(curved);
    _controller.forward();
    _holdTimer = Timer(_hold, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.severity.color;
    final maxWidth = MediaQuery.of(context).size.width - 48;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Color.alphaBlend(
                              accent.withValues(alpha: 0.18),
                              const Color(0xFF2C2C2E),
                            )
                          : Color.alphaBlend(
                              accent.withValues(alpha: 0.10),
                              const Color(0xFFF2F2F7),
                            ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 16, color: accent),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
