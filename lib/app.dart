import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/storage_service.dart';
import 'services/audio_handler.dart';
import 'services/scanner_service.dart';
import 'services/widget_updater.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/color_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

class WaveformApp extends StatefulWidget {
  const WaveformApp({super.key});

  @override
  State<WaveformApp> createState() => _WaveformAppState();
}

class _WaveformAppState extends State<WaveformApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasBackgrounded = false;
  bool _splashShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _wasBackgrounded = true;
        break;
      case AppLifecycleState.resumed:
        if (_wasBackgrounded) {
          _wasBackgrounded = false;
          _showSplashOverlay();
        }
        break;
      default:
        break;
    }
  }

  void _showSplashOverlay() {
    if (_splashShowing || SplashScreen.isVisible) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final navCtx = _navigatorKey.currentContext;
    if (navCtx != null) {
      final player = navCtx.read<PlayerProvider>();
      if (player.currentSong != null && player.isPlaying) {
        return;
      }
    }
    _splashShowing = true;
    navigator
        .push(
          PageRouteBuilder(
            opaque: true,
            transitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (_, _, _) => const SplashScreen(isOverlay: true),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        )
        .whenComplete(() => _splashShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final audioHandler = context.read<WaveformAudioHandler>();
    final scanner = context.read<ScannerService>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(storage)),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(scanner, storage),
        ),
        ChangeNotifierProvider(
          create: (ctx) => PlayerProvider(
            audioHandler,
            storage,
            ctx.read<LibraryProvider>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => PlaylistProvider(storage)),
        ChangeNotifierProvider(create: (_) => ColorProvider()),
      ],
      child: _ColorSync(
        child: Consumer2<ThemeProvider, ColorProvider>(
          builder: (context, themeProvider, colorProvider, _) {
            final dynamicColors = colorProvider.paletteColors;
            return MaterialApp(
              title: 'Waveform',
              debugShowCheckedModeBanner: false,
              navigatorKey: _navigatorKey,
              theme: AppTheme.lightTheme.copyWith(
                colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
                  primary: dynamicColors[0],
                  secondary: dynamicColors[1],
                  primaryContainer: dynamicColors[0].withValues(alpha: 0.12),
                  onPrimaryContainer: dynamicColors[0],
                ),
              ),
              darkTheme: AppTheme.darkTheme.copyWith(
                colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
                  primary: dynamicColors[0],
                  secondary: dynamicColors[1],
                  primaryContainer: dynamicColors[0].withValues(alpha: 0.12),
                  onPrimaryContainer: dynamicColors[0],
                ),
              ),
              themeMode: themeProvider.themeMode,
              builder: (context, child) => DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  decoration: TextDecoration.none,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
              home: const SplashScreen(),
            );
          },
        ),
      ),
    );
  }
}

class _ColorSync extends StatelessWidget {
  final Widget child;
  const _ColorSync({required this.child});

  static String? _lastWidgetKey;

  static void _updateNowPlaying({
    int? id,
    String? title,
    String? artist,
    required bool isPlaying,
    int? albumId,
  }) {
    final key = '${id ?? -1}|$isPlaying|$albumId|null';
    if (key == _lastWidgetKey) return;
    _lastWidgetKey = key;
    WidgetUpdater.updateNowPlaying(
      title: title,
      artist: artist,
      isPlaying: isPlaying,
      albumId: albumId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowPlaying = context
        .select<
          PlayerProvider,
          ({
            int? id,
            String filePath,
            String title,
            String artist,
            int? albumId,
            bool isPlaying,
          })
        >((p) {
          final song = p.currentSong;
          return (
            id: song?.id,
            filePath: song?.filePath ?? '',
            title: song?.displayTitle ?? '',
            artist: song?.displayArtist ?? '',
            albumId: song?.albumId,
            isPlaying: p.isPlaying,
          );
        });

    if (nowPlaying.id != null) {
      final colorProv = context.read<ColorProvider>();
      colorProv.extractFromSong(
        songId: '${nowPlaying.id}',
        filePath: nowPlaying.filePath,
        title: nowPlaying.title,
        artist: nowPlaying.artist,
      );
    }

    _updateNowPlaying(
      id: nowPlaying.id,
      title: nowPlaying.title,
      artist: nowPlaying.artist,
      isPlaying: nowPlaying.isPlaying,
      albumId: nowPlaying.albumId,
    );

    return child;
  }
}
