import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../utils/constants.dart';
import 'queue_list.dart';

class QueueSidebar extends StatelessWidget {
  final bool compact;
  final double? width;

  const QueueSidebar({super.key, this.compact = false, this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolved =
        width ??
        (compact
            ? AppConstants.queueSidebarWidthCompact
            : AppConstants.queueSidebarWidthMedium);

    return Container(
      width: resolved,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.6)
            : const Color(0xFFF2F2F7).withValues(alpha: 0.6),
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsBold.queue,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Up Next',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _QueueBody(compact: compact)),
          ],
        ),
      ),
    );
  }
}

class _QueueBody extends StatelessWidget {
  final bool compact;

  const _QueueBody({required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = context.watch<PlayerProvider>().queue;

    if (queue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsBold.musicNotes,
                size: 32,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Queue is empty',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // The sidebar is a peek, not a workbench: no swipe-to-remove, no drag
    // handles. Reordering lives in the full queue panel.
    return QueueList(
      artSize: compact ? 32 : 40,
      dismissible: false,
      reorderable: false,
    );
  }
}
