import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
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
    on<LoadRestoredTorrents>(_onLoadRestoredTorrents);
    
    add(const LoadRestoredTorrents());
  }

  Future<void> _onAddTorrentFile(
    AddTorrentFile event,
    Emitter<TorrentState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // Copy torrent file to app's persistent storage for resume capability
      final appDir = await getApplicationDocumentsDirectory();
      final torrentsDir = io.Directory('${appDir.path}/torrents');
      if (!torrentsDir.existsSync()) {
        torrentsDir.createSync(recursive: true);
      }
      
      final originalFile = io.File(event.filePath);
      final fileName = event.filePath.split(io.Platform.pathSeparator).last;
      final persistentPath = '${torrentsDir.path}/$fileName';
      
      // Copy file to persistent location
      await originalFile.copy(persistentPath);
      // debugPrint('Copied torrent file to: $persistentPath');
      
      // Get torrent info from Rust
      final info = await TorrentService.getTorrentInfo(persistentPath);

      final torrent = TorrentItem(
        name: info.name,
        totalSize: info.totalSize,
        status: TorrentItemStatus.queued,
        source: persistentPath, // Use persistent path for restore
      );

      final newTorrents = [...state.torrents, torrent];
      emit(state.copyWith(
        torrents: newTorrents,
        isLoading: false,
        activeTorrents: state.activeTorrents + 1,
      ));

      // Start download
      _startDownload(state.torrents.length - 1, persistentPath, event.selectedFileIndices, event.savePath);
      _saveTorrentsToPrefs(state.torrents);
    } catch (e) {
      // debugPrint('Error adding torrent file: $e');
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddMagnetLink(
    AddMagnetLink event,
    Emitter<TorrentState> emit,
  ) async {
    // debugPrint('Bloc: processing AddMagnetLink event. URI: ${event.magnetUri}');
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
      _startDownload(state.torrents.length - 1, event.magnetUri, event.selectedFileIndices, event.savePath);
      _saveTorrentsToPrefs(state.torrents);
    } catch (e) {
      debugPrint('Bloc Error in AddMagnetLink: $e');
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _startDownload(int index, String source, [List<int>? selectedFileIndices, String? savePath]) async {
    try {
      // Use provided path or read configured download path from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String outputDir = savePath ?? prefs.getString('download_path') ?? '';
      
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

      // debugPrint('Starting download for index $index: $source');
      debugPrint('Output directory: $outputDir');
      
      // Ensure directory exists
      try {
        final dir = io.Directory(outputDir);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
      } catch (e) {
        debugPrint('Error creating directory: $e');
      }

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
            totalSize: status.totalBytes.toInt(),
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
      totalSize: event.totalSize,
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
    _saveTorrentsToPrefs(updatedTorrents);
  }

  void _onClearCompleted(ClearCompleted event, Emitter<TorrentState> emit) {
    final activeTorrents = state.torrents
        .where((t) => t.status != TorrentItemStatus.completed)
        .toList();
    emit(state.copyWith(
      torrents: activeTorrents,
      completedTorrents: 0,
    ));
    _saveTorrentsToPrefs(activeTorrents);
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

  Future<void> _onLoadRestoredTorrents(
    LoadRestoredTorrents event,
    Emitter<TorrentState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? torrentsJson = prefs.getString('saved_torrents');
      
      if (torrentsJson != null) {
        final List<dynamic> decoded = jsonDecode(torrentsJson);
        final List<TorrentItem> restoredTorrents = decoded
            .map((item) => TorrentItem.fromMap(item))
            .toList();
            
        emit(state.copyWith(
          torrents: restoredTorrents,
          activeTorrents: restoredTorrents.length, // approximation
        ));
        
        // Wait for librqbit session to fully initialize
        await Future.delayed(const Duration(seconds: 2));
        
        // Re-attach download streams for incomplete torrents
        for (int i = 0; i < restoredTorrents.length; i++) {
          final torrent = restoredTorrents[i];
          if (torrent.source != null && 
              torrent.status != TorrentItemStatus.completed &&
              torrent.status != TorrentItemStatus.error) {
            // debugPrint('Restoring download stream for: ${torrent.name}');
            try {
              _startDownload(i, torrent.source!);
            } catch (e) {
              debugPrint('Error restoring torrent $i: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to restore torrents: $e');
    }
  }

  Future<void> _saveTorrentsToPrefs(List<TorrentItem> torrents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> maps = torrents
          .map((t) => t.toMap())
          .toList();
      await prefs.setString('saved_torrents', jsonEncode(maps));
    } catch (e) {
      debugPrint('Failed to save torrents: $e');
    }
  }

  @override
  Future<void> close() {
    for (final sub in _downloadSubscriptions.values) {
      sub.cancel();
    }
    return super.close();
  }
}
