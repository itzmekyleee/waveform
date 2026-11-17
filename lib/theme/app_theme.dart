import 'package:flutter/material.dart';

class WaveformColors {
  WaveformColors._();

  static const Color seed = Color(0xFF2B3A67);

  static const Color accentLight = Color(0xFF2B3A67);
  static const Color accentDark = Color(0xFF8FA3D9);
  static const Color accentVariantLight = Color(0xFFB58A26);
  static const Color accentVariantDark = Color(0xFFE0C25A);

  static const Color surfaceLight = Color(0xFFF2F2F7);
  static const Color surfaceDark = Color(0xFF000000);

  static const Color surfaceContainerDark = Color(0xFF1C1C1E);
  static const Color surfaceHighDark = Color(0xFF2C2C2E);

  static const Color errorLight = Color(0xFFFF3B30);
  static const Color errorDark = Color(0xFFFF453A);

  static const Color separatorLight = Color(0xFFC6C6C8);
  static const Color separatorDark = Color(0xFF38383A);

  static const Color systemGrayLight = Color(0xFF8E8E93);
  static const Color systemGrayDark = Color(0xFF8E8E93);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: WaveformColors.seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFF2F2F7),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF2F2F7),
      surfaceContainer: const Color(0xFFE5E5EA),
      surfaceContainerHigh: const Color(0xFFD1D1D6),
      surfaceContainerHighest: const Color(0xFFC7C7CC),
      primary: const Color(0xFF2B3A67),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFD9E1F2),
      onPrimaryContainer: const Color(0xFF15224A),
      secondary: const Color(0xFFB58A26),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFF6E9C0),
      onSecondaryContainer: const Color(0xFF6B5208),
      tertiary: const Color(0xFF5856D6),
      onTertiary: const Color(0xFFFFFFFF),
      error: WaveformColors.errorLight,
      outline: WaveformColors.separatorLight,
      outlineVariant: const Color(0xFFD1D1D6),
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: WaveformColors.seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF000000),
      surfaceContainerLowest: const Color(0xFF0A0A0A),
      surfaceContainerLow: const Color(0xFF0C0C0E),
      surfaceContainer: const Color(0xFF1C1C1E),
      surfaceContainerHigh: const Color(0xFF2C2C2E),
      surfaceContainerHighest: const Color(0xFF3A3A3C),
      primary: const Color(0xFF8FA3D9),
      onPrimary: const Color(0xFF172554),
      primaryContainer: const Color(0xFF273763),
      onPrimaryContainer: const Color(0xFFAFC1F0),
      secondary: const Color(0xFFE0C25A),
      onSecondary: const Color(0xFF3D3200),
      secondaryContainer: const Color(0xFF4A4012),
      onSecondaryContainer: const Color(0xFFF0D982),
      tertiary: const Color(0xFF8E9FD8),
      onTertiary: const Color(0xFF14204A),
      error: WaveformColors.errorDark,
      outline: WaveformColors.separatorDark,
      outlineVariant: const Color(0xFF38383A),
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 34,
          letterSpacing: -0.4,
        ),
        displayMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.3,
        ),
        displaySmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 22,
          letterSpacing: -0.2,
        ),
        headlineLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 32,
          letterSpacing: -0.5,
        ),
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 28,
          letterSpacing: -0.3,
        ),
        headlineSmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 22,
          letterSpacing: -0.2,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.1,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 17,
          letterSpacing: -0.1,
        ),
        titleSmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        bodyLarge: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 17,
        ),
        bodyMedium: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
        bodySmall: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        labelMedium: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        labelSmall: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ).apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: colorScheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.94)
            : const Color(0xFFF2F2F7).withValues(alpha: 0.94),
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: colorScheme.onPrimaryContainer,
            );
          }
          return TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: colorScheme.onPrimaryContainer,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.1),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colorScheme.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFF2F2F7),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        showDragHandle: true,
        dragHandleColor: isDark
            ? const Color(0xFF636366)
            : const Color(0xFFAEAEB2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? const Color(0xFF636366) : const Color(0xFFFFFFFF);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
        }),
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: colorScheme.primary.withValues(alpha: 0.04),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: _FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _FadeUpwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeUpwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
