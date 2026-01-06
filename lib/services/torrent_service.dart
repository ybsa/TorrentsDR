import 'dart:typed_data';
import '../src/rust/api/simple.dart' as rust_api;
import '../src/rust/frb_generated.dart';
import '../src/rust/lib.dart';

/// Service for interacting with the Rust torrent core.
/// This wraps the Flutter Rust Bridge generated code.
class TorrentService {
  static bool _initialized = false;

  /// Initialize the Rust library. Must be called before any other methods.
  static Future<void> initialize() async {
    if (_initialized) return;
    await RustLib.init();
    _initialized = true;
  }

  /// Test the Rust bridge connection
  static Future<void> testBridge() async {
    // Bridge test - just ensure we can call a Rust function
    // greet was removed, using parseMagnet as a simple test
    await rust_api.parseMagnet(uri: 'magnet:?xt=urn:btih:0000000000000000000000000000000000000000');
  }

  /// Get information about a torrent file
  /// Returns TorrentInfo with name, size, files, etc.
  static Future<TorrentFileInfo> getTorrentInfo(String filePath) async {
    final info = await rust_api.getTorrentInfoFile(path: filePath);
    
    // Map Rust struct to Dart struct
    return TorrentFileInfo(
      name: info.name,
      totalSize: info.totalSize.toInt(),
      pieceCount: info.pieceCount.toInt(),
      pieceLength: info.pieceLength.toInt(),
      files: info.files.map((f) => FileItem(
        path: f.path, 
        size: f.size.toInt()
      )).toList(),
      infoHash: info.infoHash,
      announce: info.announce,
    );
  }

  /// Parse a magnet link and extract information
  static Future<MagnetLinkInfo> parseMagnet(String magnetUri) async {
    final info = await rust_api.parseMagnet(uri: magnetUri);
    
    return MagnetLinkInfo(
      name: info.name,
      infoHash: info.infoHash,
      trackers: info.trackers,
    );
  }

  /// Start downloading a torrent
  static Stream<rust_api.AppTorrentStatus> startDownload(String source, String outputDir) {
    return rust_api.startDownload(source: source, outputDir: outputDir);
  }

  /// Fetch metadata for a magnet link without starting download
  /// Used for preview screen before user confirms
  /// 
  /// NOTE: This is a fallback implementation using parseMagnet.
  /// Full metadata (file sizes, piece count) requires the full Rust API.
  /// TODO: Once flutter_rust_bridge codegen works, use rust_api.fetchMagnetMetadata()
  static Future<TorrentFileInfo> fetchMagnetMetadata(String magnetUri, {int timeoutSecs = 120}) async {
    final info = await rust_api.fetchMagnetMetadata(
        magnetUri: magnetUri, 
        timeoutSecs: timeoutSecs
    );
    
    return TorrentFileInfo(
      name: info.name,
      totalSize: info.totalSize.toInt(),
      pieceCount: info.pieceCount.toInt(),
      pieceLength: info.pieceLength.toInt(),
      files: info.files.map((f) => FileItem(
        path: f.path, 
        size: f.size.toInt()
      )).toList(),
      infoHash: info.infoHash,
      announce: info.announce,
    );
  }
}

/// Information about a torrent file (mirrors Rust TorrentInfo)
class TorrentFileInfo {
  final String name;
  final int totalSize;
  final int pieceCount;
  final int pieceLength;
  final List<FileItem> files;
  final String infoHash;
  final String announce;

  TorrentFileInfo({
    required this.name,
    required this.totalSize,
    required this.pieceCount,
    required this.pieceLength,
    required this.files,
    required this.infoHash,
    required this.announce,
  });
}

/// Information about a file in the torrent (mirrors Rust FileInfo)
class FileItem {
  final String path;
  final int size;

  FileItem({required this.path, required this.size});
}

/// Parsed magnet link information (mirrors Rust MagnetInfo)
class MagnetLinkInfo {
  final String? name;
  final String infoHash;
  final List<String> trackers;

  MagnetLinkInfo({
    this.name,
    required this.infoHash,
    required this.trackers,
  });
}
