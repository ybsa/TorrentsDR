import 'package:flutter/foundation.dart';
import '../models/torrent_item.dart';
import '../services/torrent_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;

/// Provider for managing torrent state across the app.
/// Uses ChangeNotifier for reactive updates.
class TorrentProvider extends ChangeNotifier {
  final List<TorrentItem> _torrents = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TorrentItem> get torrents => List.unmodifiable(_torrents);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeCount =>
      _torrents.where((t) => t.status == TorrentStatus.downloading).length;
  int get completedCount =>
      _torrents.where((t) => t.status == TorrentStatus.completed).length;

  double get totalDownloadSpeed => _torrents
      .where((t) => t.status == TorrentStatus.downloading)
      .fold(0.0, (sum, t) => sum + t.downloadSpeed);

  /// Add a torrent from a .torrent file path
  Future<void> addTorrentFile(String sourcePath) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Copy file to internal storage to ensure Rust can read it
      final appDir = await getApplicationDocumentsDirectory();
      // Use a simple sanitized filename to avoid character issues
      final fileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.torrent';
      final safePath = '${appDir.path}/$fileName';
      
      debugPrint('Downloading from source: $sourcePath');
      debugPrint('Target safe path: $safePath');
      
      // Copy the file
      final sourceFile = io.File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist: $sourcePath');
      }
      
      await sourceFile.copy(safePath);
      
      // Validate copy
      final cleanFile = io.File(safePath);
      if (!await cleanFile.exists()) {
         throw Exception('Copy failed: File not found at $safePath');
      }
      final len = await cleanFile.length();
      debugPrint('Copied file size: $len bytes');
      if (len == 0) {
        throw Exception('Copied file is empty!');
      }

      // Try to get torrent info from Rust core using the SAFE path
      TorrentFileInfo? info;
      try {
        info = await TorrentService.getTorrentInfo(safePath);
      } catch (e) {
        // Fall back to filename if Rust API not yet available
        debugPrint('TorrentService.getTorrentInfo error: $e');
      }

      final torrent = TorrentItem(
        name: info?.name ?? fileName,
        progress: 0.0,
        downloadSpeed: 0,
        peers: 0,
        totalSize: info?.totalSize.toDouble() ?? 0,
        status: TorrentStatus.queued,
      );

      _torrents.add(torrent);
      _isLoading = false;
      notifyListeners();

      // Start download using the SAFE path
      _startDownload(_torrents.length - 1, safePath);
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a torrent from a magnet link
  Future<void> addMagnetLink(String magnetUri) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate magnet link
      if (!magnetUri.startsWith('magnet:?')) {
        throw Exception('Invalid magnet link');
      }

      // Try to parse magnet info from Rust core
      String name = 'Unknown Torrent';

      try {
        final info = await TorrentService.parseMagnet(magnetUri);
        name = info.name ?? name;
        // infoHash available: info.infoHash
      } catch (e) {
        debugPrint('TorrentService.parseMagnet not available: $e');
        // Fallback validation
        final dnMatch = RegExp(r'dn=([^&]+)').firstMatch(magnetUri);
        if (dnMatch != null) {
          name = Uri.decodeComponent(dnMatch.group(1)!);
        }
      }

      final torrent = TorrentItem(
        name: name,
        progress: 0.0,
        downloadSpeed: 0,
        peers: 0,
        totalSize: 0,
        status: TorrentStatus.queued,
      );

      _torrents.add(torrent);
      _isLoading = false;
      notifyListeners();

      // Start download
      _startDownload(_torrents.length - 1, magnetUri);
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Start downloading a torrent
  Future<void> _startDownload(int index, String source) async {
    if (index < 0 || index >= _torrents.length) return;

    _torrents[index] = _torrents[index].copyWith(
      status: TorrentStatus.downloading,
    );
    notifyListeners();

    try {
      // Get valid download directory
      final appDir = await getApplicationDocumentsDirectory();
      final outputDir = appDir.path;
      
      // Start download in Rust
      TorrentService.startDownload(source, outputDir).listen(
        (status) {
          // Calculate progress (0.0 to 1.0)
          // Handle BigInt from Rust interface
          final pct = status.totalPieces.toInt() > 0 
              ? status.completedPieces.toInt() / status.totalPieces.toInt() 
              : 0.0;
          
          final state = pct >= 1.0 
              ? TorrentStatus.completed // Enum from models/torrent_item.dart (Warning: naming conflict!)
              : TorrentStatus.downloading;

          updateProgress(
            index,
            progress: pct, // 0.0 to 1.0
            downloadSpeed: status.speedMbps * 1048576, // MB/s to B/s for UI
            peers: status.peers.toInt(), // BigInt -> int
            status: state,
          );
        },
        onError: (e) {
          debugPrint('Download error: $e');
          _torrents[index] = _torrents[index].copyWith(
            status: TorrentStatus.error,
            error: e.toString(),
          );
          notifyListeners();
        },
        onDone: () {
            debugPrint('Download stream closed');
        }
      );
      
    } catch (e) {
      debugPrint('Start download failed: $e');
      _torrents[index] = _torrents[index].copyWith(
        status: TorrentStatus.error,
        error: 'Failed to get download path: $e',
      );
      notifyListeners();
    }
  }

  /// Pause a torrent
  void pauseTorrent(int index) {
    if (index < 0 || index >= _torrents.length) return;

    final current = _torrents[index];
    _torrents[index] = current.copyWith(
      status: current.status == TorrentStatus.paused
          ? TorrentStatus.downloading
          : TorrentStatus.paused,
      downloadSpeed:
          current.status == TorrentStatus.paused ? current.downloadSpeed : 0,
    );
    notifyListeners();

    // TODO: Call Rust core to pause/resume
  }

  /// Remove a torrent
  void removeTorrent(int index, {bool deleteFiles = false}) {
    if (index < 0 || index >= _torrents.length) return;

    // TODO: Call Rust core to stop download and optionally delete files
    _torrents.removeAt(index);
    notifyListeners();
  }

  /// Update torrent progress (called by Rust core)
  void updateProgress(
    int index, {
    double? progress,
    double? downloadSpeed,
    int? peers,
    TorrentStatus? status,
  }) {
    if (index < 0 || index >= _torrents.length) return;

    _torrents[index] = _torrents[index].copyWith(
      progress: progress,
      downloadSpeed: downloadSpeed,
      peers: peers,
      status: status,
    );
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
