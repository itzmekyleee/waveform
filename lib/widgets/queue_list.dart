import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../providers/player_provider.dart';
import 'album_art.dart';

/// The queue contents, shared by the in-screen queue panel and the wide queue
/// sidebar so a song looks the same wherever the queue is shown.
class QueueList extends StatelessWidget {
  final double artSize;
  final bool showArt;
  final bool showTrackNumber;
  final bool dismissible;
  final bool reorderable;
  final EdgeInsets padding;

  const QueueList({
    super.key,
    this.artSize = 40,
    this.showArt = true,
    this.showTrackNumber = true,
    this.dismissible = true,
    this.reorderable = true,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;

    return ReorderableListView.builder(
      padding: padding,
      itemCount: queue.length,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      onReorderItem: (oldIndex, newIndex) =>
          player.reorderQueue(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final song = queue[index];
        final isCurrent = index == player.currentIndex;

        final tile = _QueueTile(
          song: song,
          index: index,
          isCurrent: isCurrent,
          artSize: artSize,
          showArt: showArt,
          showTrackNumber: showTrackNumber,
          dragEnabled: reorderable,
          onTap: () => player.playAtQueueIndex(index),
        );

        if (!dismissible) return tile;

        return Dismissible(
          key: ValueKey('${song.id}_$index'),
          direction: isCurrent
              ? DismissDirection.none
              : DismissDirection.endToStart,
          onDismissed: (_) => player.removeFromQueue(index),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              PhosphorIconsBold.trash,
              color: Colors.white,
              size: 20,
            ),
          ),
          child: tile,
        );
      },
    );
  }
}

class _QueueTile extends StatefulWidget {
  final Song song;
  final int index;
  final bool isCurrent;
  final double artSize;
  final bool showArt;
  final bool showTrackNumber;
  final bool dragEnabled;
  final VoidCallback onTap;

  const _QueueTile({
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.artSize,
    required this.showArt,
    required this.showTrackNumber,
    required this.dragEnabled,
    required this.onTap,
  });

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artSize = widget.artSize;
    final radius = artSize * 0.2;
    final titleSize = artSize * 0.325;
    final artistSize = artSize * 0.275;

    Widget leading() {
      if (!widget.showArt) {
        return SizedBox(
          width: artSize,
          height: artSize,
          child: Center(
            child: Text(
              '${widget.index + 1}',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: widget.isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      }

      return SizedBox(
        width: artSize,
        height: artSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AlbumArtWidget(
              albumId: widget.song.albumId,
              title: widget.song.displayTitle,
              artist: widget.song.displayArtist,
              filePath: widget.song.filePath,
              contentUri: widget.song.contentUri,
              size: artSize,
              borderRadius: radius,
            ),
            if (widget.showTrackNumber && !widget.isCurrent)
              Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      fontSize: titleSize * 0.95,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: widget.isCurrent
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : _hovered
                ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                : null,
          ),
          child: Row(
            children: [
              leading(),
              SizedBox(width: artSize * 0.25),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.song.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: widget.isCurrent
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: widget.isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      widget.song.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: artistSize,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.dragEnabled)
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      PhosphorIconsBold.dotsSixVertical,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      size: artSize * 0.45,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return KeyedSubtree(
      key: ValueKey('${widget.song.id}_${widget.index}'),
      child: row,
    );
  }
}
