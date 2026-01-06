import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/torrent_service.dart';
import 'torrent_event.dart';
import 'torrent_state.dart';

class TorrentBloc extends Bloc<TorrentEvent, TorrentState> {
  final Map<int, StreamSubscription> _downloadSubscriptions = {};

  TorrentBloc() : super(TorrentState.initial()) {
    on<AddTorrentFile>(_onAddTorrentFile);
    on<AddMagnetLink>(_onAddMagnetLink);
    on<UpdateTorrentProgress>(_onUpdateProgress);
    on<PauseTorrent>(_onPauseTorrent);
    on<ResumeTorrent>(_onResumeTorrent);
    on<RemoveTorrent>(_onRemoveTorrent);
    on<ClearCompleted>(_onClearCompleted);
    on<TorrentError>(_onTorrentError);
  }

  Future<void> _onAddTorrentFile(
    AddTorrentFile event,
    Emitter<TorrentState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // Get torrent info from Rust
      final info = await TorrentService.getTorrentInfo(event.filePath);

      final torrent = TorrentItem(
        name: info.name,
        totalSize: info.totalSize,
        status: TorrentItemStatus.queued,
        source: event.filePath,
      );

      final newTorrents = [...state.torrents, torrent];
      emit(state.copyWith(
        torrents: newTorrents,
        isLoading: false,
        activeTorrents: state.activeTorrents + 1,
      ));

      // Start download
      _startDownload(state.torrents.length - 1, event.filePath, event.selectedFileIndices);
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddMagnetLink(
    AddMagnetLink event,
    Emitter<TorrentState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      if (!event.magnetUri.startsWith('magnet:?')) {
        throw Exception('Invalid magnet link');
      }

      // Try to parse magnet info
      String name = 'Unknown Torrent';
      try {
        final info = await TorrentService.parseMagnet(event.magnetUri);
        name = info.name ?? name;
      } catch (e) {
        // Fallback: extract dn parameter
        final dnMatch = RegExp(r'dn=([^&]+)').firstMatch(event.magnetUri);
        if (dnMatch != null) {
          name = Uri.decodeComponent(dnMatch.group(1)!);
        }
      }

      final torrent = TorrentItem(
        name: name,
        status: TorrentItemStatus.queued,
        source: event.magnetUri,
      );

      final newTorrents = [...state.torrents, torrent];
      emit(state.copyWith(
        torrents: newTorrents,
        isLoading: false,
        activeTorrents: state.activeTorrents + 1,
      ));

      // Start download
      _startDownload(state.torrents.length - 1, event.magnetUri);
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _startDownload(int index, String source, [List<int>? selectedFileIndices]) async {
    try {
      // Read configured download path from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String outputDir = prefs.getString('download_path') ?? '';
      
      // Fallback to Downloads directory or app documents
      if (outputDir.isEmpty) {
        try {
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            outputDir = downloadsDir.path;
          } else {
            final appDir = await getApplicationDocumentsDirectory();
            outputDir = appDir.path;
          }
        } catch (_) {
          final appDir = await getApplicationDocumentsDirectory();
          outputDir = appDir.path;
        }
      }

      debugPrint('Starting download for index $index: $source');
      debugPrint('Output directory: $outputDir');

      final subscription = TorrentService.startDownload(source, outputDir).listen(
        (status) {
          final progress = status.totalPieces.toInt() > 0
              ? status.completedPieces.toInt() / status.totalPieces.toInt()
              : 0.0;

          final itemStatus = progress >= 1.0
              ? TorrentItemStatus.completed
              : TorrentItemStatus.downloading;

          add(UpdateTorrentProgress(
            index: index,
            progress: progress,
            downloadSpeed: status.speedMbps * 1048576, // MB/s to B/s
            peers: status.peers.toInt(),
            status: itemStatus,
          ));
        },
        onError: (e) {
          debugPrint('Download error: $e');
          add(TorrentError(index, e.toString()));
        },
        onDone: () {
          debugPrint('Download stream closed for index $index');
        },
      );

      _downloadSubscriptions[index] = subscription;
    } catch (e) {
      debugPrint('Failed to start download: $e');
      add(TorrentError(index, e.toString()));
    }
  }

  void _onUpdateProgress(
    UpdateTorrentProgress event,
    Emitter<TorrentState> emit,
  ) {
    if (event.index < 0 || event.index >= state.torrents.length) return;

    final updatedTorrents = List<TorrentItem>.from(state.torrents);
    updatedTorrents[event.index] = updatedTorrents[event.index].copyWith(
      progress: event.progress,
      downloadSpeed: event.downloadSpeed,
      peers: event.peers,
      status: event.status,
    );

    // Calculate stats
    int active = 0;
    int completed = 0;
    double totalSpeed = 0;

    for (final t in updatedTorrents) {
      if (t.status == TorrentItemStatus.downloading) {
        active++;
        totalSpeed += t.downloadSpeed;
      } else if (t.status == TorrentItemStatus.completed) {
        completed++;
      }
    }

    emit(state.copyWith(
      torrents: updatedTorrents,
      activeTorrents: active,
      completedTorrents: completed,
      totalSpeed: totalSpeed,
    ));
  }

  void _onPauseTorrent(PauseTorrent event, Emitter<TorrentState> emit) {
    if (event.index < 0 || event.index >= state.torrents.length) return;

    // Cancel subscription
    _downloadSubscriptions[event.index]?.cancel();
    _downloadSubscriptions.remove(event.index);

    final updatedTorrents = List<TorrentItem>.from(state.torrents);
    updatedTorrents[event.index] = updatedTorrents[event.index].copyWith(
      status: TorrentItemStatus.paused,
      downloadSpeed: 0,
    );

    emit(state.copyWith(torrents: updatedTorrents));
  }

  void _onResumeTorrent(ResumeTorrent event, Emitter<TorrentState> emit) {
    if (event.index < 0 || event.index >= state.torrents.length) return;

    final torrent = state.torrents[event.index];
    if (torrent.source != null) {
      _startDownload(event.index, torrent.source!);
    }

    final updatedTorrents = List<TorrentItem>.from(state.torrents);
    updatedTorrents[event.index] = updatedTorrents[event.index].copyWith(
      status: TorrentItemStatus.downloading,
    );

    emit(state.copyWith(torrents: updatedTorrents));
  }

  void _onRemoveTorrent(RemoveTorrent event, Emitter<TorrentState> emit) {
    if (event.index < 0 || event.index >= state.torrents.length) return;

    // Cancel subscription
    _downloadSubscriptions[event.index]?.cancel();
    _downloadSubscriptions.remove(event.index);

    final updatedTorrents = List<TorrentItem>.from(state.torrents);
    updatedTorrents.removeAt(event.index);

    emit(state.copyWith(torrents: updatedTorrents));
  }

  void _onClearCompleted(ClearCompleted event, Emitter<TorrentState> emit) {
    final activeTorrents = state.torrents
        .where((t) => t.status != TorrentItemStatus.completed)
        .toList();

    emit(state.copyWith(
      torrents: activeTorrents,
      completedTorrents: 0,
    ));
  }

  void _onTorrentError(TorrentError event, Emitter<TorrentState> emit) {
    if (event.index < 0 || event.index >= state.torrents.length) return;

    final updatedTorrents = List<TorrentItem>.from(state.torrents);
    updatedTorrents[event.index] = updatedTorrents[event.index].copyWith(
      status: TorrentItemStatus.error,
      error: event.error,
      downloadSpeed: 0,
    );

    emit(state.copyWith(torrents: updatedTorrents));
  }

  @override
  Future<void> close() {
    for (final sub in _downloadSubscriptions.values) {
      sub.cancel();
    }
    return super.close();
  }
}
