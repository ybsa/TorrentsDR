import 'package:flutter/material.dart';
import '../services/torrent_service.dart';

/// Flud-style torrent preview screen with INFORMATION and FILES tabs
class TorrentPreviewScreen extends StatefulWidget {
  final String source; // Magnet URI or file path
  final bool isMagnet;
  final TorrentFileInfo? preloadedInfo; // For .torrent files (already parsed)

  const TorrentPreviewScreen({
    super.key,
    required this.source,
    required this.isMagnet,
    this.preloadedInfo,
  });

  @override
  State<TorrentPreviewScreen> createState() => _TorrentPreviewScreenState();
}

class _TorrentPreviewScreenState extends State<TorrentPreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TorrentFileInfo? _info;
  bool _isLoading = true;
  String? _error;
  String _storagePath = '/storage/emulated/0/Download/TorrentsDigger';
  Set<int> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    if (widget.preloadedInfo != null) {
      // Already have info from .torrent file
      _info = widget.preloadedInfo;
      _isLoading = false;
      _selectedFiles = Set.from(List.generate(_info!.files.length, (i) => i));
    } else if (widget.isMagnet) {
      // Need to fetch metadata for magnet
      _fetchMagnetMetadata();
    }
  }

  Future<void> _fetchMagnetMetadata() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // This calls the new Rust function
      final info = await TorrentService.fetchMagnetMetadata(widget.source);
      
      if (mounted) {
        setState(() {
          _info = info;
          _isLoading = false;
          _selectedFiles = Set.from(List.generate(info.files.length, (i) => i));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _startDownload() {
    // Return selected file indices to the caller
    Navigator.pop(context, _selectedFiles.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add torrent'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _info != null ? _startDownload : null,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'INFORMATION'),
            Tab(text: 'FILES'),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInformationTab(),
                    _buildFilesTab(),
                  ],
                ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Fetching Metadata...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Connecting to peers to get torrent info',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to fetch metadata',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchMagnetMetadata,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationTab() {
    final info = _info!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          _buildInfoSection('NAME', info.name, editable: true),
          const Divider(),
          
          // Storage Path
          _buildInfoSection('STORAGE PATH', _storagePath, 
            subtitle: '${_formatSize(_getAvailableSpace())} free',
            editable: true,
          ),
          const Divider(),
          
          // Size and File Count Row
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('TOTAL SIZE', _formatSize(info.totalSize)),
              ),
              Expanded(
                child: _buildInfoItem('NUMBER OF FILES', '${info.files.length}'),
              ),
            ],
          ),
          const Divider(),
          
          // Torrent Settings
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'TORRENT SETTINGS',
              style: TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          CheckboxListTile(
            title: const Text('Enable sequential download'),
            value: false,
            onChanged: (v) {},
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: const Text('Download first and last pieces first'),
            value: false,
            onChanged: (v) {},
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          
          // Hash
          _buildInfoItem('HASH', info.infoHash),
          const Divider(),
          
          // Creation Date (if available)
          _buildInfoItem('TORRENT CREATION DATE', _getCurrentDate()),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    final info = _info!;
    
    return Column(
      children: [
        // Search and filter buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.video_library, size: 18),
                label: const Text('Video'),
              ),
            ],
          ),
        ),
        
        // Select all / none header
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text(
                'SELECT FILES TO DOWNLOAD',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFiles = Set.from(
                      List.generate(info.files.length, (i) => i),
                    );
                  });
                },
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFiles.clear();
                  });
                },
                child: const Text('Select none'),
              ),
            ],
          ),
        ),
        
        // File list
        Expanded(
          child: ListView.builder(
            itemCount: info.files.length,
            itemBuilder: (context, index) {
              final file = info.files[index];
              final isSelected = _selectedFiles.contains(index);
              
              return CheckboxListTile(
                value: isSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedFiles.add(index);
                    } else {
                      _selectedFiles.remove(index);
                    }
                  });
                },
                title: Text(
                  file.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatSize(file.size)),
                secondary: _getFileIcon(file.path),
                controlAffinity: ListTileControlAffinity.trailing,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String label, String value, {
    String? subtitle,
    bool editable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(value),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (editable)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.teal),
              onPressed: () {},
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(value),
        ],
      ),
    );
  }

  Widget _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    IconData icon;
    Color color;
    
    if (['mp4', 'mkv', 'avi', 'mov', 'wmv'].contains(ext)) {
      icon = Icons.movie;
      color = Colors.purple;
    } else if (['mp3', 'flac', 'wav', 'aac', 'ogg'].contains(ext)) {
      icon = Icons.music_note;
      color = Colors.orange;
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(ext)) {
      icon = Icons.image;
      color = Colors.green;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      icon = Icons.folder_zip;
      color = Colors.brown;
    } else if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) {
      icon = Icons.description;
      color = Colors.blue;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  int _getAvailableSpace() {
    // TODO: Get actual available space from storage
    return 72 * 1024 * 1024 * 1024; // 72 GB placeholder
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${_monthName(now.month)} ${now.day}, ${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
