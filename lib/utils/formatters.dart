/// Utility functions for formatting file sizes, speeds, and times.
class Formatters {
  /// Format bytes to human readable size (KB, MB, GB, TB)
  static String fileSize(double bytes) {
    if (bytes >= 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
    } else if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${bytes.toStringAsFixed(0)} B';
  }

  /// Format bytes per second to human readable speed
  static String speed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }

  /// Format seconds to human readable duration (ETA)
  static String duration(int seconds) {
    if (seconds < 0) return '--';

    if (seconds >= 86400) {
      final days = seconds ~/ 86400;
      final hours = (seconds % 86400) ~/ 3600;
      return '${days}d ${hours}h';
    } else if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    } else if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes}m ${secs}s';
    }
    return '${seconds}s';
  }

  /// Format progress percentage
  static String progress(double progress) {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  /// Format peer count
  static String peers(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k peers';
    }
    return '$count peers';
  }

  /// Calculate ETA from remaining bytes and speed
  static String eta(double remainingBytes, double speedBytesPerSecond) {
    if (speedBytesPerSecond <= 0) return '--';
    final seconds = (remainingBytes / speedBytesPerSecond).round();
    return duration(seconds);
  }

  /// Truncate filename for display
  static String truncateFilename(String filename, {int maxLength = 30}) {
    if (filename.length <= maxLength) return filename;

    final extension =
        filename.contains('.') ? '.${filename.split('.').last}' : '';
    final nameWithoutExt =
        filename.substring(0, filename.length - extension.length);
    final truncateAt = maxLength - extension.length - 3; // 3 for "..."

    return '${nameWithoutExt.substring(0, truncateAt)}...$extension';
  }
}
