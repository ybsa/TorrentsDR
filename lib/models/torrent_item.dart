enum TorrentStatus {
  downloading,
  paused,
  completed,
  error,
  queued,
}

class TorrentItem {
  final String name;
  final double progress; // 0.0 to 1.0
  final double downloadSpeed; // bytes per second
  final int peers;
  final double totalSize; // bytes
  final TorrentStatus status;
  final String? error;

  TorrentItem({
    required this.name,
    required this.progress,
    required this.downloadSpeed,
    required this.peers,
    required this.totalSize,
    required this.status,
    this.error,
  });

  TorrentItem copyWith({
    String? name,
    double? progress,
    double? downloadSpeed,
    int? peers,
    double? totalSize,
    TorrentStatus? status,
    String? error,
  }) {
    return TorrentItem(
      name: name ?? this.name,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      peers: peers ?? this.peers,
      totalSize: totalSize ?? this.totalSize,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  double get downloadedSize => totalSize * progress;

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  String get formattedTotalSize {
    if (totalSize >= 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (totalSize >= 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (totalSize >= 1024) {
      return '${(totalSize / 1024).toStringAsFixed(0)} KB';
    }
    return '${totalSize.toStringAsFixed(0)} B';
  }

  String get formattedSpeed {
    if (downloadSpeed >= 1024 * 1024) {
      return '${(downloadSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (downloadSpeed >= 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${downloadSpeed.toStringAsFixed(0)} B/s';
  }

  String get eta {
    if (downloadSpeed <= 0 || progress >= 1.0) return '--';
    final remaining = totalSize * (1 - progress);
    final seconds = (remaining / downloadSpeed).round();

    if (seconds >= 3600) {
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    } else if (seconds >= 60) {
      return '${seconds ~/ 60}m ${seconds % 60}s';
    }
    return '${seconds}s';
  }
}
