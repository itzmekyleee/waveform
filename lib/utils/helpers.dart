import 'package:flutter/material.dart';

class AppHelpers {
  AppHelpers._();

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static Color generateArtColor(String seed) {
    final hash = seed.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return       HSLColor.fromAHSL(1.0, hue, 0.65, 0.40).toColor();
  }

  static List<Color> generateArtGradient(String seed) {
    final hash = seed.hashCode;
    final h1 = (hash % 360).abs().toDouble();
    final h2 = ((hash ~/ 360) % 360).abs().toDouble();
    return [
      HSLColor.fromAHSL(1.0, h1, 0.75, 0.40).toColor(),
      HSLColor.fromAHSL(1.0, h2, 0.65, 0.30).toColor(),
    ];
  }

  static IconData getGenreIcon(String genre) {
    final g = genre.toLowerCase();
    if (g.contains('rock')) return Icons.electric_bolt;
    if (g.contains('pop')) return Icons.star;
    if (g.contains('jazz')) return Icons.music_note;
    if (g.contains('classical')) return Icons.auto_awesome;
    if (g.contains('hip') || g.contains('rap')) return Icons.mic;
    if (g.contains('electronic') || g.contains('dance')) return Icons.waves;
    if (g.contains('country')) return Icons.landscape;
    if (g.contains('r&b') || g.contains('soul')) return Icons.favorite;
    if (g.contains('metal')) return Icons.local_fire_department;
    if (g.contains('folk')) return Icons.nature;
    if (g.contains('reggae')) return Icons.sunny;
    return Icons.library_music;
  }

  static String getInitials(String text) {
    if (text.isEmpty) return '?';
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return text[0].toUpperCase();
  }

  static bool get reduceMotion {
    final window = WidgetsBinding.instance.platformDispatcher;
    return window.accessibilityFeatures.disableAnimations;
  }
}
