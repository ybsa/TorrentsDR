import 'package:flutter/material.dart';
import '../widgets/torrent_card.dart';
import '../models/torrent_item.dart';
import 'add_torrent_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Sample data - will be replaced with real data from Rust core
  final List<TorrentItem> _torrents = [
    TorrentItem(
      name: 'Example.Movie.2024.1080p.mkv',
      progress: 0.78,
      downloadSpeed: 2.5 * 1024 * 1024, // 2.5 MB/s
      peers: 24,
      totalSize: 2.5 * 1024 * 1024 * 1024, // 2.5 GB
      status: TorrentStatus.downloading,
    ),
    TorrentItem(
      name: 'Music.Album.FLAC',
      progress: 0.35,
      downloadSpeed: 0,
      peers: 0,
      totalSize: 500 * 1024 * 1024, // 500 MB
      status: TorrentStatus.paused,
    ),
  ];

  void _showAddTorrentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTorrentScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.bolt,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'TorrentX',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Open settings
            },
          ),
        ],
      ),
      body: _torrents.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _torrents.len(),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TorrentCard(
                    torrent: _torrents[index],
                    onPause: () {
                      setState(() {
                        _torrents[index] = _torrents[index].copyWith(
                          status: _torrents[index].status == TorrentStatus.paused
                              ? TorrentStatus.downloading
                              : TorrentStatus.paused,
                        );
                      });
                    },
                    onDelete: () {
                      setState(() {
                        _torrents.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTorrentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Torrent'),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_download_outlined,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            'No Torrents',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white54,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a torrent file or magnet link',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalSpeed = _torrents
        .where((t) => t.status == TorrentStatus.downloading)
        .fold(0.0, (sum, t) => sum + t.downloadSpeed);
    
    final activeCount = _torrents
        .where((t) => t.status == TorrentStatus.downloading)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.download,
            label: 'Speed',
            value: _formatSpeed(totalSpeed),
          ),
          _buildStatItem(
            icon: Icons.play_arrow,
            label: 'Active',
            value: activeCount.toString(),
          ),
          _buildStatItem(
            icon: Icons.check_circle_outline,
            label: 'Completed',
            value: _torrents.where((t) => t.progress >= 1.0).length.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }
}
