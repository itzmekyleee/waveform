class AppConstants {
  AppConstants._();

  static const String appName = 'Waveform';

  static const String songBox = 'songs';
  static const String playlistBox = 'playlists';
  static const String settingsBox = 'settings';
  static const String playHistoryBox = 'play_history';
  static const String favoritesBox = 'favorites';

  static const String settingThemeMode = 'theme_mode';
  static const String settingVolume = 'volume';
  static const String settingLastTrackId = 'last_track_id';
  static const String settingLastPosition = 'last_position';
  static const String settingLastQueue = 'last_queue';
  static const String settingScannedFolders = 'scanned_folders';
  static const String settingHasCompletedOnboarding = 'has_onboarding';
  static const String settingShuffleMode = 'shuffle_mode';
  static const String settingRepeatMode = 'repeat_mode';
  static const String settingShowQueueSidebar = 'show_queue_sidebar';
  static const String settingHideSidebarOnNowPlaying = 'hide_sidebar_on_now_playing';

  static const int hiveSongTypeId = 0;
  static const int hivePlaylistTypeId = 1;

  static const Duration searchDebounce = Duration(milliseconds: 400);

  static const List<String> supportedExtensions = [
    'mp3', 'wav', 'm4a', 'flac', 'ogg', 'aac', 'wma', 'opus',
  ];

  static const double breakpointTablet = 720.0;
  static const double breakpointTabletWide = 900.0;
  static const double breakpointDesktop = 1200.0;

  /// Widest the Now Playing composition ever gets, so it does not drift apart
  /// on a wide window.
  static const double nowPlayingMaxWidth = 1000.0;

  /// Artwork ceiling for the stacked (phone / portrait) composition.
  static const double nowPlayingArtSmall = 260.0;

  /// Artwork ceiling once the player has a landscape split to live in.
  static const double nowPlayingArtMax = 440.0;

  /// Share of the column the stacked artwork may occupy, leaving a gutter.
  static const double nowPlayingArtWidthShare = 0.92;

  /// Room the artwork's drop shadow needs so it never clips at the edge.
  static const double nowPlayingArtShadowBleed = 12.0;

  /// The composition switches to the landscape split (art left, text and
  /// transport right) once the box is at least this wide.
  static const double nowPlayingSplitMinWidth = 640.0;

  /// ...and meaningfully wider than it is tall. Without the aspect term a
  /// portrait tablet would split its artwork into a thin strip.
  static const double nowPlayingSplitAspect = 1.1;

  /// Gutter between the artwork and the control panel in the split.
  static const double nowPlayingSplitGutter = 40.0;

  static const double nowPlayingPanelMinWidth = 280.0;
  static const double nowPlayingPanelMaxWidth = 440.0;

  /// Vertical budgets used to decide what still fits: title (2 lines) + artist
  /// + album + waveform, with and without the waveform, and the transport
  /// block under them.
  static const double nowPlayingMetadataHeight = 210.0;
  static const double nowPlayingMetadataCompactHeight = 154.0;
  static const double nowPlayingControlsHeight = 190.0;

  /// Gap between the artwork and the text/transport block.
  static const double nowPlayingArtGap = 24.0;

  static const double navRailWidth = 180.0;

  /// Widest the library column gets on tablets and desktop. Past this the
  /// content would run to the window edges and read as stretched.
  static const double contentMaxWidth = 1100.0;

  /// Compact, elevated navigation pill used on tablets and desktop.
  static const double floatingNavMaxWidth = 460.0;

  /// The Up Next pane that sits beside the player on landscape tablets.
  static const double landscapeQueuePaneMinWidth = 280.0;
  static const double landscapeQueuePaneMaxWidth = 420.0;

  /// Content pane side padding. The wide layout matches the nav rail's own
  /// outer padding so the whole window shares one left margin.
  static const double contentGutterWide = 20.0;
  static const double contentGutterCompact = 16.0;

  static const double queueSidebarWidthCompact = 200.0;
  static const double queueSidebarWidthMedium = 260.0;
  static const double queueSidebarWidthExpanded = 320.0;
}
