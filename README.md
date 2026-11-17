<div align="center">

# Waveform

**A glassmorphism-style offline music player for Android, built with Flutter.**

*My first Flutter application — scans your local audio library and presents it through a sleek, frosted-glass, dark-themed interface.*

</div>

---

## Overview

Waveform turns your phone's local music collection into a polished, modern listening experience — no accounts, no streaming, no ads. It scans your device for audio files, reads their metadata and embedded artwork, and organizes everything into a fast, searchable library wrapped in a frosted-glass UI that adapts its color palette to whatever album art is currently playing.

It was built as a personal project to learn Flutter from the ground up, with a focus on smooth animations, thoughtful gestures, and a UI that feels genuinely native rather than templated.

---

## Features

### Interface
- **Frosted glass UI** — blurred panels, translucent surfaces, and smooth animated transitions throughout
- **Dynamic theming** — accent colors adapt in real time to the currently playing album art using color extraction
- **Responsive navigation** — phones get a segmented top bar; tablets and desktop get a floating pill nav with a centred, width-capped content column
- **Landscape now playing** — on tablets in landscape the player and a permanent "Up Next" queue sit side by side, with no navigation on screen
- **Full-screen now playing view** — blurred, oversized album art as the background with drag-to-seek
- **System UI integration** — edge-to-edge display with transparent system bars
- **Animated list items** — staggered fade and slide animations when browsing your library

### Library & Playback
- **Automatic library scan** — detects local audio files and reads embedded metadata (title, artist, album, duration, artwork)
- **Search & sort** — instantly filter your library, sort by title, artist, album, date added, or duration
- **Swipeable tabs** — glide between Songs, Albums, Artists, Playlists, and Favorites
- **Gesture controls** — swipe between tabs, drag to skip tracks, swipe the mini player to change songs
- **Mini player** — persistent bottom bar with playback controls and quick track switching
- **Keyboard shortcuts** *(desktop)* — Space to play/pause, arrow keys to seek/skip, Ctrl+Space for quick control
- **Sleep timer** — set a timer to stop playback after a chosen duration

### Organization
- **Favorites** — save go-to tracks for instant access
- **Custom playlists** — create, reorder, rename, and manage your own playlists with drag-to-reorder
- **Smart playlists** — auto-generated collections:
  - Recently Added — last 50 songs by date added
  - Most Played — top played songs
  - Recently Played — songs with recent play history
  - Recent Albums — one per album from recently added songs
  - Recent Artists — one per artist from recently played songs
- **Album art in notifications** — currently playing album art displayed in the system notification

### Desktop & Tablet Support
- Floating navigation pill on wide screens instead of an edge-to-edge sidebar
- Content is capped at 1100px so it never stretches across very wide windows
- Landscape tablets show the player and Up Next queue together in one screen
- Keyboard shortcuts for all major playback controls
- Right-click context menus on song tiles

---

## Built With

- **Flutter** — cross-platform UI framework
- **on_audio_query** — audio metadata and library scanning
- **just_audio** — audio playback engine
- **audio_service** — background audio and notification support
- **hive** — lightweight local persistence for favorites, playlists, and settings
- **provider** — state management

---

## Getting Started

### Prerequisites
- Flutter SDK (3.x or later)
- An Android device or emulator running API 21+

### Installation

```bash
git clone https://github.com/itzmekyleee/Waveform.git
cd waveform
flutter pub get
flutter run
```

### Build Release

```bash
flutter build apk --release
```

The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Project Structure

```
waveform/
├── lib/
│   ├── main.dart                  # App entry point, edge-to-edge setup
│   ├── app.dart                   # MaterialApp, provider wiring, dynamic theming
│   ├── models/                    # Data models (Song, Playlist, SmartPlaylist)
│   ├── providers/                 # State management
│   │   ├── library_provider.dart  # Song library, search, sort, filtering
│   │   ├── player_provider.dart   # Playback, queue, sleep timer
│   │   ├── playlist_provider.dart # Playlists, favorites, smart playlists
│   │   ├── theme_provider.dart    # Dark/light/system theme
│   │   └── color_provider.dart    # Album art color extraction
│   ├── screens/                   # UI screens
│   │   ├── home_screen.dart       # Main scaffold with responsive navigation
│   │   ├── now_playing_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── splash_screen.dart
│   │   ├── permission_screen.dart
│   │   ├── search_screen.dart
│   │   └── library/               # Tab screens
│   ├── widgets/                   # Reusable components
│   │   ├── song_tile.dart
│   │   ├── album_art.dart
│   │   ├── mini_player.dart
│   │   └── empty_state.dart
│   ├── services/                  # Backend services
│   │   ├── scanner_service.dart   # Audio file scanning
│   │   ├── storage_service.dart   # Hive persistence
│   │   └── audio_handler.dart     # Audio playback and notifications
│   └── theme/                     # Theming
│       ├── app_theme.dart
│       └── glass_theme.dart       # GlassCard and GlassPanel widgets
├── assets/
│   ├── icons/                     # App icon assets
│   └── images/                    # Screenshots and images
└── pubspec.yaml
```

---

## Keyboard Shortcuts

| Key | Action |
|---|---|
| Space | Play / Pause |
| Ctrl+Space | Play / Pause |
| Left Arrow | Seek backward 5 seconds |
| Right Arrow | Seek forward 5 seconds |
| Up Arrow | Increase volume |
| Down Arrow | Decrease volume |

---

## Permissions

Waveform needs storage or media permissions to scan your device for local audio files. On first launch, the app will request the necessary permission. Without it, the library scan cannot proceed.

---

## License

MIT

---

<div align="center">

If you like this project, consider giving it a star.

</div>
