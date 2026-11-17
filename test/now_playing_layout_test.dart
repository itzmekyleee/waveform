import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:waveform/models/song_model.dart';
import 'package:waveform/providers/player_provider.dart';
import 'package:waveform/providers/playlist_provider.dart';
import 'package:waveform/services/audio_handler.dart';
import 'package:waveform/services/scanner_service.dart';
import 'package:waveform/services/storage_service.dart';
import 'package:waveform/widgets/album_art.dart';
import 'package:waveform/widgets/now_playing_view.dart';

Song _song(int id) => Song(
  id: id,
  title: 'Track $id',
  artist: 'Artist $id',
  album: 'Album $id',
  genre: 'Test',
  durationMs: 240000,
  filePath: '/tmp/track$id.mp3',
  dateAdded: DateTime(2024),
  fileSize: 1024,
);

/// The boxes a tablet actually gives the player. The pane is narrower than
/// the window when the queue sidebar shares the shell.
const tabletBoxes = <String, Size>{
  'iPad 10.9 landscape': Size(1194, 834),
  'iPad 10.9 portrait': Size(834, 1194),
  'iPad 9.7 landscape': Size(1024, 768),
  'landscape 853x533': Size(853, 533),
  'landscape 960x600': Size(960, 600),
  'landscape 880x700': Size(880, 700),
  'phone landscape': Size(844, 390),
  'phone portrait': Size(390, 844),
};

void main() {
  group('resolveNowPlayingLayout', () {
    test('tablet landscape goes side by side', () {
      for (final entry in tabletBoxes.entries) {
        final size = entry.value;
        expect(
          resolveNowPlayingLayout(BoxConstraints.tight(size)),
          entry.key.contains('portrait')
              ? NowPlayingLayout.stacked
              : NowPlayingLayout.split,
          reason: entry.key,
        );
      }
    });

    test('a portrait or tall box stays stacked', () {
      expect(
        resolveNowPlayingLayout(BoxConstraints.tight(const Size(834, 1194))),
        NowPlayingLayout.stacked,
      );
      expect(
        resolveNowPlayingLayout(BoxConstraints.tight(const Size(390, 844))),
        NowPlayingLayout.stacked,
      );
    });

    test('too narrow for a split panel, even sideways', () {
      expect(
        resolveNowPlayingLayout(BoxConstraints.tight(const Size(560, 320))),
        NowPlayingLayout.stacked,
      );
    });
  });

  group('NowPlayingView', () {
    late Directory hiveDir;
    late StorageService storage;
    late WaveformAudioHandler handler;
    late PlayerProvider player;
    late PlaylistProvider playlist;

    setUpAll(() async {
      hiveDir = await Directory.systemTemp.createTemp('waveform_test');
      Hive.init(hiveDir.path);
      storage = StorageService();
      await storage.init();
      handler = WaveformAudioHandler(storage);
      player = PlayerProvider(handler, storage);
      playlist = PlaylistProvider(storage);
    });

    tearDownAll(() async {
      player.dispose();
      playlist.dispose();
      await Hive.close();
      await hiveDir.delete(recursive: true);
    });

    testWidgets('artwork stays square and nothing overflows', (tester) async {
      for (final entry in tabletBoxes.entries) {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PlayerProvider>.value(value: player),
              ChangeNotifierProvider<PlaylistProvider>.value(value: playlist),
              Provider<ScannerService>.value(value: ScannerService()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: NowPlayingView(
                  player: player,
                  song: _song(1),
                  active: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull, reason: entry.key);

        final box = tester.renderObject<RenderBox>(
          find.byType(AlbumArtWidget).first,
        );
        expect(
          box.size.width,
          closeTo(box.size.height, 0.5),
          reason: '${entry.key}: artwork must not be squashed',
        );
        expect(
          box.size.shortestSide,
          greaterThanOrEqualTo(140),
          reason: '${entry.key}: artwork collapsed',
        );

        // Transport is present in every layout.
        expect(
          find.byKey(const ValueKey('repeat_0')),
          findsOneWidget,
          reason: entry.key,
        );

        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
