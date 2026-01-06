import 'package:flutter/material.dart';
import '../models/torrent_item.dart';

/// Screen to show download queue and manage priority.
class DownloadQueueScreen extends StatefulWidget {
  final List<TorrentItem> torrents;
  final Function(int oldIndex, int newIndex) onReorder;

  const DownloadQueueScreen({
    super.key,
    required this.torrents,
    required this.onReorder,
  });

  @override
  State<DownloadQueueScreen> createState() => _DownloadQueueScreenState();
}

class _DownloadQueueScreenState extends State<DownloadQueueScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Queue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: widget.torrents.isEmpty
          ? _buildEmptyState()
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.torrents.length,
              onReorder: widget.onReorder,
              itemBuilder: (context, index) {
                final torrent = widget.torrents[index];
                return Card(
                  key: ValueKey(torrent.name + index.toString()),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: _buildStatusIcon(torrent.status),
                    title: Text(
                      torrent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${torrent.progressPercent} • ${torrent.formattedTotalSize}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle, color: Colors.white38),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.queue_outlined,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            'Queue Empty',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white54,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add torrents to see them here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(TorrentStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case TorrentStatus.downloading:
        icon = Icons.download;
        color = Theme.of(context).colorScheme.primary;
        break;
      case TorrentStatus.paused:
        icon = Icons.pause_circle_outline;
        color = Colors.orange;
        break;
      case TorrentStatus.completed:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case TorrentStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
      case TorrentStatus.queued:
        icon = Icons.schedule;
        color = Colors.white54;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
