import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class ColorProvider extends ChangeNotifier {
  Color? dominantColor;
  Color? vibrantColor;
  Color? mutedColor;
  String? _lastSongId;

  static const List<Color> _defaultPalette = [
    Color(0xFF8FA3D9),
    Color(0xFFE0C25A),
    Color(0xFF1C2333),
  ];

  List<Color> get paletteColors => [
        dominantColor ?? _defaultPalette[0],
        vibrantColor ?? _defaultPalette[1],
        mutedColor ?? _defaultPalette[2],
      ];

  Color get accentColor => dominantColor ?? _defaultPalette[0];
  Color get secondaryAccent => vibrantColor ?? _defaultPalette[1];

  Color lightModeTint(Color color) {
    final hsl = HSLColor.fromColor(color);
    return HSLColor.fromAHSL(
      1.0,
      hsl.hue,
      (hsl.saturation * 0.4).clamp(0.0, 1.0),
      (hsl.lightness * 0.5 + 0.45).clamp(0.0, 1.0),
    ).toColor();
  }

  Future<void> extractFromSong({
    required String songId,
    String? filePath,
    String? title,
    String? artist,
  }) async {
    if (songId == _lastSongId) return;
    _lastSongId = songId;

    try {
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          final generator = PaletteGenerator.fromImageProvider(
            FileImage(file),
            maximumColorCount: 5,
          );
          final palette = await generator;
          dominantColor = palette.dominantColor?.color;
          vibrantColor = palette.vibrantColor?.color;
          mutedColor = palette.mutedColor?.color;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    if (title != null && artist != null) {
      final colors = _generateGradientColors('$title$artist');
      dominantColor = colors[0];
      vibrantColor = colors[1];
      mutedColor = colors[0].withValues(alpha: 0.5);
      notifyListeners();
    }
  }

  List<Color> _generateGradientColors(String seed) {
    final hash = seed.hashCode;
    final h1 = (hash % 360).abs().toDouble();
    final h2 = ((hash ~/ 360) % 360).abs().toDouble();
    return [
      HSLColor.fromAHSL(1.0, h1, 0.55, 0.45).toColor(),
      HSLColor.fromAHSL(1.0, h2, 0.5, 0.35).toColor(),
    ];
  }

  void clear() {
    dominantColor = null;
    vibrantColor = null;
    mutedColor = null;
    _lastSongId = null;
    notifyListeners();
  }
}
