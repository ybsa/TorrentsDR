import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../bloc/torrent/torrent_state.dart';
import '../bloc/torrent/torrent_event.dart';

class TorrentCard extends StatelessWidget {
  final TorrentItem torrent;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;

  const TorrentCard({
    super.key,
    required this.torrent,
    this.onPause,
    this.onResume,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(context),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    torrent.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action buttons
                IconButton(
                  icon: Icon(
                    torrent.status == TorrentItemStatus.paused
                        ? Icons.play_arrow
                        : Icons.pause,
                    size: 20,
                  ),
                  onPressed: torrent.status == TorrentItemStatus.paused ? onResume : onPause,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            LinearPercentIndicator(
              lineHeight: 8,
              percent: torrent.progress.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.surface,
              progressColor: _getProgressColor(context),
              barRadius: const Radius.circular(4),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Progress percentage
                Text(
                  torrent.progressPercent,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Status info
                if (torrent.status == TorrentItemStatus.downloading)
                  Row(
                    children: [
                      const Icon(
                        Icons.download,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        torrent.formattedSpeed,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${torrent.peers}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        torrent.eta,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  )
                else
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: _getStatusColor(context),
                    ),
                  ),

                // Total size
                Text(
                  torrent.formattedSize, // Changed from formattedTotalSize
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (torrent.status) {
      case TorrentItemStatus.downloading:
        return Icons.download;
      case TorrentItemStatus.paused:
        return Icons.pause_circle_outline;
      case TorrentItemStatus.completed:
        return Icons.check_circle_outline;
      case TorrentItemStatus.error:
        return Icons.error_outline;
      case TorrentItemStatus.queued:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (torrent.status) {
      case TorrentItemStatus.downloading:
        return Theme.of(context).colorScheme.primary;
      case TorrentItemStatus.paused:
        return Colors.orange;
      case TorrentItemStatus.completed:
        return Colors.green;
      case TorrentItemStatus.error:
        return Colors.red;
      case TorrentItemStatus.queued:
        return Colors.white54;
    }
  }

  Color _getProgressColor(BuildContext context) {
    switch (torrent.status) {
      case TorrentItemStatus.downloading:
        return Theme.of(context).colorScheme.primary;
      case TorrentItemStatus.paused:
        return Colors.orange;
      case TorrentItemStatus.completed:
        return Colors.green;
      case TorrentItemStatus.error:
        return Colors.red;
      case TorrentItemStatus.queued:
        return Colors.white38;
    }
  }

  String _getStatusText() {
    // If downloading but total size is 0, we are fetching metadata
    if (torrent.status == TorrentItemStatus.downloading && torrent.totalSize == 0) {
      return 'Fetching Metadata...';
    }

    switch (torrent.status) {
      case TorrentItemStatus.downloading:
        return 'Downloading';
      case TorrentItemStatus.paused:
        return 'Paused';
      case TorrentItemStatus.completed:
        return 'Completed';
      case TorrentItemStatus.error:
        return torrent.error ?? 'Error';
      case TorrentItemStatus.queued:
        return 'Queued';
    }
  }
}
