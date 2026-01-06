import 'package:equatable/equatable.dart';

/// Base class for all torrent events
abstract class TorrentEvent extends Equatable {
  const TorrentEvent();
  
  @override
  List<Object?> get props => [];
}

/// Add a torrent from a file path
class AddTorrentFile extends TorrentEvent {
  final String filePath;
  final List<int>? selectedFileIndices;
  
  const AddTorrentFile(this.filePath, [this.selectedFileIndices]);
  
  @override
  List<Object?> get props => [filePath, selectedFileIndices];
}

/// Add a torrent from a magnet link
class AddMagnetLink extends TorrentEvent {
  final String magnetUri;
  final List<int>? selectedFileIndices;
  
  const AddMagnetLink(this.magnetUri, [this.selectedFileIndices]);
  
  @override
  List<Object?> get props => [magnetUri, selectedFileIndices];
}

/// Update torrent progress
class UpdateTorrentProgress extends TorrentEvent {
  final int index;
  final double progress;
  final double downloadSpeed;
  final int peers;
  final TorrentItemStatus status;
  
  const UpdateTorrentProgress({
    required this.index,
    required this.progress,
    required this.downloadSpeed,
    required this.peers,
    required this.status,
  });
  
  @override
  List<Object?> get props => [index, progress, downloadSpeed, peers, status];
}

/// Pause a torrent
class PauseTorrent extends TorrentEvent {
  final int index;
  
  const PauseTorrent(this.index);
  
  @override
  List<Object?> get props => [index];
}

/// Resume a torrent
class ResumeTorrent extends TorrentEvent {
  final int index;
  
  const ResumeTorrent(this.index);
  
  @override
  List<Object?> get props => [index];
}

/// Remove a torrent
class RemoveTorrent extends TorrentEvent {
  final int index;
  
  const RemoveTorrent(this.index);
  
  @override
  List<Object?> get props => [index];
}

/// Clear all completed torrents
class ClearCompleted extends TorrentEvent {
  const ClearCompleted();
}

/// Torrent download error
class TorrentError extends TorrentEvent {
  final int index;
  final String error;
  
  const TorrentError(this.index, this.error);
  
  @override
  List<Object?> get props => [index, error];
}

/// Enum for torrent status (defined here to avoid circular imports)
enum TorrentItemStatus {
  queued,
  downloading,
  paused,
  completed,
  error,
}
