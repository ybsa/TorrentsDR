import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

// State
class SettingsState extends Equatable {
  final String downloadPath;
  final double maxDownloadSpeed;
  final int maxConcurrentDownloads;
  final bool startMinimized;
  final bool showNotifications;
  
  const SettingsState({
    required this.downloadPath,
    this.maxDownloadSpeed = 0,
    this.maxConcurrentDownloads = 3,
    this.startMinimized = false,
    this.showNotifications = true,
  });
  
  SettingsState copyWith({
    String? downloadPath,
    double? maxDownloadSpeed,
    int? maxConcurrentDownloads,
    bool? startMinimized,
    bool? showNotifications,
  }) {
    return SettingsState(
      downloadPath: downloadPath ?? this.downloadPath,
      maxDownloadSpeed: maxDownloadSpeed ?? this.maxDownloadSpeed,
      maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      startMinimized: startMinimized ?? this.startMinimized,
      showNotifications: showNotifications ?? this.showNotifications,
    );
  }
  
  @override
  List<Object?> get props => [
    downloadPath,
    maxDownloadSpeed,
    maxConcurrentDownloads,
    startMinimized,
    showNotifications,
  ];
}

// Cubit
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState(downloadPath: ''));
  
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Default download path - prefer public Downloads directory
    String downloadPath = prefs.getString('download_path') ?? '';
    if (downloadPath.isEmpty) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          downloadPath = downloadsDir.path;
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          downloadPath = docDir.path;
        }
      } catch (_) {
        final docDir = await getApplicationDocumentsDirectory();
        downloadPath = docDir.path;
      }
    }
    
    emit(SettingsState(
      downloadPath: downloadPath,
      maxDownloadSpeed: prefs.getDouble('max_download_speed') ?? 0,
      maxConcurrentDownloads: prefs.getInt('max_concurrent_downloads') ?? 3,
      startMinimized: prefs.getBool('start_minimized') ?? false,
      showNotifications: prefs.getBool('show_notifications') ?? true,
    ));
  }
  
  Future<void> setDownloadPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_path', path);
    emit(state.copyWith(downloadPath: path));
  }
  
  Future<void> setMaxDownloadSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('max_download_speed', speed);
    emit(state.copyWith(maxDownloadSpeed: speed));
  }
  
  Future<void> setMaxConcurrentDownloads(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_concurrent_downloads', count);
    emit(state.copyWith(maxConcurrentDownloads: count));
  }
  
  Future<void> setStartMinimized(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('start_minimized', value);
    emit(state.copyWith(startMinimized: value));
  }
  
  Future<void> setShowNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_notifications', value);
    emit(state.copyWith(showNotifications: value));
  }
}
