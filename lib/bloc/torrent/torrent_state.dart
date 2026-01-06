import 'package:equatable/equatable.dart';
import 'torrent_event.dart';

/// Torrent state
class TorrentState extends Equatable {
  final List<TorrentItem> torrents;
  final bool isLoading;
  final String? error;
  final int activeTorrents;
  final int completedTorrents;
  final double totalSpeed;
  
  const TorrentState({
    this.torrents = const [],
    this.isLoading = false,
    this.error,
    this.activeTorrents = 0,
    this.completedTorrents = 0,
    this.totalSpeed = 0.0,
  });
  
  /// Initial state
  factory TorrentState.initial() => const TorrentState();
  
  /// Copy with method for immutable updates
  TorrentState copyWith({
    List<TorrentItem>? torrents,
    bool? isLoading,
    String? error,
    int? activeTorrents,
    int? completedTorrents,
    double? totalSpeed,
  }) {
    return TorrentState(
      torrents: torrents ?? this.torrents,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeTorrents: activeTorrents ?? this.activeTorrents,
      completedTorrents: completedTorrents ?? this.completedTorrents,
      totalSpeed: totalSpeed ?? this.totalSpeed,
    );
  }

  @override
  List<Object?> get props => [
    torrents,
    isLoading,
    error,
    activeTorrents,
    completedTorrents,
    totalSpeed,
  ];
}

/// Individual torrent item
class TorrentItem extends Equatable {
  final String name;
  final double progress; // 0.0 to 1.0
  final double downloadSpeed; // bytes per second
  final int peers;
  final int totalSize; // bytes
  final TorrentItemStatus status;
  final String? error;
  final String? source; // File path or magnet URI
  
  const TorrentItem({
    required this.name,
    this.progress = 0.0,
    this.downloadSpeed = 0,
    this.peers = 0,
    this.totalSize = 0,
    this.status = TorrentItemStatus.queued,
    this.error,
    this.source,
  });
  
  TorrentItem copyWith({
    String? name,
    double? progress,
    double? downloadSpeed,
    int? peers,
    int? totalSize,
    TorrentItemStatus? status,
    String? error,
    String? source,
  }) {
    return TorrentItem(
      name: name ?? this.name,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      peers: peers ?? this.peers,
      totalSize: totalSize ?? this.totalSize,
      status: status ?? this.status,
      error: error ?? this.error,
      source: source ?? this.source,
    );
  }
  
  /// Format download speed for display
  String get formattedSpeed {
    if (downloadSpeed < 1024) {
      return '${downloadSpeed.toStringAsFixed(0)} B/s';
    } else if (downloadSpeed < 1024 * 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(downloadSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }
  
  /// Format total size for display
  String get formattedSize {
    if (totalSize < 1024) {
      return '$totalSize B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    } else if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
  
  /// Progress as percentage string
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';
  
  /// ETA estimate
  String get eta {
    if (downloadSpeed <= 0 || progress >= 1.0) return '--';
    final remaining = totalSize * (1 - progress);
    final seconds = remaining / downloadSpeed;
    if (seconds < 60) return '${seconds.toInt()}s';
    if (seconds < 3600) return '${(seconds / 60).toInt()}m ${(seconds % 60).toInt()}s';
    return '${(seconds / 3600).toInt()}h ${((seconds % 3600) / 60).toInt()}m';
  }

  @override
  List<Object?> get props => [
    name,
    progress,
    downloadSpeed,
    peers,
    totalSize,
    status,
    error,
    source,
  ];
}
