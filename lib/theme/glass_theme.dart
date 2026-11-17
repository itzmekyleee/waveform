import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurIntensity;
  final Color? tintColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final bool showBorder;
  final Border? border;
  final Color? backgroundColor;
  final Alignment? alignment;
  final bool blurEnabled;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurIntensity = 12,
    this.tintColor,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.boxShadow,
    this.showBorder = true,
    this.border,
    this.backgroundColor,
    this.alignment,
    this.blurEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultTint = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.85);
    final effectiveBg = backgroundColor ?? tintColor ?? defaultTint;

    final effectiveBorder =
        border ??
        (showBorder
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              )
            : Border.all(color: Colors.transparent, width: 0));

    final glossGradient = isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          )
        : null;

    Widget surface = Container(
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        border: effectiveBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      foregroundDecoration: glossGradient != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: glossGradient,
            )
          : null,
      child: child,
    );

    if (blurEnabled) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurIntensity,
          sigmaY: blurIntensity,
        ),
        child: surface,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: RepaintBoundary(child: surface),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: child,
    );
  }
}

BoxDecoration glassDecoration({
  double borderRadius = 14,
  Color? tintColor,
  double blur = 12,
  BuildContext? context,
}) {
  final isDark =
      context != null && Theme.of(context).brightness == Brightness.dark;

  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06);

  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: borderColor, width: 0.5),
  );
}
