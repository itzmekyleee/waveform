import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/song_model.dart';
import 'models/playlist_model.dart';
import 'services/storage_service.dart';
import 'services/audio_handler.dart';
import 'services/scanner_service.dart';
import 'app.dart';

late WaveformAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
  ));

  FlutterError.onError = (details) {
    debugPrint('Flutter error: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  runZonedGuarded(() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SongAdapter());
    Hive.registerAdapter(PlaylistAdapter());

    final storage = StorageService();
    await storage.init();

    try {
      audioHandler = await AudioService.init<WaveformAudioHandler>(
        builder: () => WaveformAudioHandler(storage),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.waveform.audio',
          androidNotificationChannelName: 'Waveform Music',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationClickStartsActivity: true,
          androidResumeOnClick: true,
          androidNotificationIcon: 'drawable/ic_notification',
          notificationColor: Color(0xFF58A6FF),
          preloadArtwork: true,
        ),
      );
    } catch (e, stack) {
      // Audio service failed to start (e.g. invalid config in debug builds).
      // Surface the error loudly instead of swallowing it, and fall back to a
      // plain handler so playback still works without the media notification.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'audio_service',
          context: ErrorDescription('AudioService.init'),
        ),
      );
      audioHandler = WaveformAudioHandler(storage);
    }

    final scanner = ScannerService();

    runApp(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          Provider<WaveformAudioHandler>.value(value: audioHandler),
          Provider<ScannerService>.value(value: scanner),
        ],
        child: const WaveformApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  });
}
