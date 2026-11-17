import 'package:flutter/material.dart';

enum SmartPlaylistType {
  recentlyAdded,
  mostPlayed,
  recentlyPlayed,
  recentAlbums,
  recentArtists,
}

class SmartPlaylist {
  final SmartPlaylistType type;
  final String name;
  final IconData icon;
  final String description;

  const SmartPlaylist({
    required this.type,
    required this.name,
    required this.icon,
    required this.description,
  });

  static const List<SmartPlaylist> all = [
    SmartPlaylist(
      type: SmartPlaylistType.recentlyAdded,
      name: 'Recently Added',
      icon: Icons.history_rounded,
      description: 'Songs added most recently',
    ),
    SmartPlaylist(
      type: SmartPlaylistType.mostPlayed,
      name: 'Most Played',
      icon: Icons.trending_up_rounded,
      description: 'Your top played songs',
    ),
    SmartPlaylist(
      type: SmartPlaylistType.recentlyPlayed,
      name: 'Recently Played',
      icon: Icons.replay_rounded,
      description: 'Songs you played recently',
    ),
    SmartPlaylist(
      type: SmartPlaylistType.recentAlbums,
      name: 'Recent Albums',
      icon: Icons.album_rounded,
      description: 'Albums with recently added songs',
    ),
    SmartPlaylist(
      type: SmartPlaylistType.recentArtists,
      name: 'Recent Artists',
      icon: Icons.person_rounded,
      description: 'Artists you played recently',
    ),
  ];
}
