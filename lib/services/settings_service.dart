import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Service for managing app settings including download paths.
class SettingsService extends ChangeNotifier {
  String _downloadPath = '';
  double _maxDownloadSpeed = 0; // 0 = unlimited (MB/s)
  bool _showNotifications = true;
  bool _startMinimized = false;
  int _maxConcurrentDownloads = 3;

  // Getters
  String get downloadPath => _downloadPath;
  double get maxDownloadSpeed => _maxDownloadSpeed;
  bool get showNotifications => _showNotifications;
  bool get startMinimized => _startMinimized;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  /// Initialize settings with default download path
  Future<void> initialize() async {
    _downloadPath = await _getDefaultDownloadPath();
    notifyListeners();
  }

  /// Get default download path based on platform
  Future<String> _getDefaultDownloadPath() async {
    try {
      if (Platform.isAndroid) {
        // Android - use external storage Downloads folder
        final dir = Directory('/storage/emulated/0/Download/TorrentDR');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      } else if (Platform.isWindows) {
        // Windows - use user's Downloads folder
        final userDir =
            Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
        final dir = Directory('$userDir\\Downloads\\TorrentDR');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      } else if (Platform.isLinux) {
        // Linux - use home Downloads folder
        final homeDir = Platform.environment['HOME'] ?? '/home';
        final dir = Directory('$homeDir/Downloads/TorrentDR');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      } else if (Platform.isMacOS) {
        // macOS - use Downloads folder
        final homeDir = Platform.environment['HOME'] ?? '/Users/default';
        final dir = Directory('$homeDir/Downloads/TorrentDR');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      } else {
        // Fallback - use app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final dir = Directory('${appDir.path}/TorrentDR');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      }
    } catch (e) {
      // Fallback if anything fails
      return '.';
    }
  }

  /// Set download path
  Future<void> setDownloadPath(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _downloadPath = path;
    notifyListeners();
    // TODO: Save to shared preferences for persistence
  }

  /// Set max download speed (0 = unlimited)
  void setMaxDownloadSpeed(double mbps) {
    _maxDownloadSpeed = mbps;
    notifyListeners();
  }

  /// Toggle notifications
  void setShowNotifications(bool value) {
    _showNotifications = value;
    notifyListeners();
  }

  /// Toggle start minimized
  void setStartMinimized(bool value) {
    _startMinimized = value;
    notifyListeners();
  }

  /// Set max concurrent downloads
  void setMaxConcurrentDownloads(int count) {
    _maxConcurrentDownloads = count.clamp(1, 10);
    notifyListeners();
  }

  /// Check if download path is valid and writable
  Future<bool> isDownloadPathValid() async {
    try {
      final dir = Directory(_downloadPath);
      if (!await dir.exists()) {
        return false;
      }
      // Try to create a test file
      final testFile = File('${dir.path}/.torrentdr_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get available space in download path (in bytes)
  Future<int> getAvailableSpace() async {
    // This would require platform-specific code
    // For now, return a placeholder
    return 0; // TODO: Implement with platform channels
  }
}
