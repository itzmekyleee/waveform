import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/library_provider.dart';
import '../../models/song_model.dart';
import '../../widgets/empty_state.dart';

class SearchScreen extends StatelessWidget {
  final String searchQuery;

  const SearchScreen({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryProvider>();

    return FutureBuilder<List<Song>>(
      future: Future(() {
        final q = searchQuery.toLowerCase();
        return library.allSongs.where((s) {
          return s.displayTitle.toLowerCase().contains(q) ||
              s.displayArtist.toLowerCase().contains(q) ||
              s.displayAlbum.toLowerCase().contains(q) ||
              s.genre.toLowerCase().contains(q);
        }).toList();
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SkeletonLoader(itemCount: 8, itemHeight: 64);
        }

        final results = snapshot.data!;
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'No results for "$searchQuery"',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final song = results[index];
            return ListTile(
              leading: Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              title: Text(
                song.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${song.displayArtist} • ${song.displayAlbum}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }
}
