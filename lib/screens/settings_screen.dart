import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import '../bloc/settings/settings_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Download Location
              _buildSectionTitle(context, 'Download Location'),
              _buildSettingCard(
                context: context,
                icon: Icons.folder_outlined,
                title: 'Download Folder',
                subtitle: state.downloadPath.isEmpty
                    ? 'Not set'
                    : state.downloadPath,
                onTap: () => _selectDownloadFolder(context),
              ),
              const SizedBox(height: 24),

              // Speed Limits
              _buildSectionTitle(context, 'Speed Limits'),
              _buildSettingCard(
                context: context,
                icon: Icons.download,
                title: 'Max Download Speed',
                subtitle: state.maxDownloadSpeed == 0
                    ? 'Unlimited'
                    : '${state.maxDownloadSpeed.toInt()} MB/s',
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: state.maxDownloadSpeed,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    onChanged: (value) => 
                        context.read<SettingsCubit>().setMaxDownloadSpeed(value),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildSettingCard(
                context: context,
                icon: Icons.layers,
                title: 'Max Concurrent Downloads',
                subtitle: '${state.maxConcurrentDownloads} torrents at once',
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: state.maxConcurrentDownloads.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (value) =>
                        context.read<SettingsCubit>().setMaxConcurrentDownloads(value.toInt()),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Behavior
              _buildSectionTitle(context, 'Behavior'),
              _buildSwitchSetting(
                context: context,
                icon: Icons.minimize,
                title: 'Start Minimized',
                subtitle: 'Start app in system tray',
                value: state.startMinimized,
                onChanged: (value) => 
                    context.read<SettingsCubit>().setStartMinimized(value),
              ),
              _buildSwitchSetting(
                context: context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Show when downloads complete',
                value: state.showNotifications,
                onChanged: (value) => 
                    context.read<SettingsCubit>().setShowNotifications(value),
              ),
              const SizedBox(height: 24),

              // About
              _buildSectionTitle(context, 'About'),
              _buildSettingCard(
                context: context,
                icon: Icons.info_outline,
                title: 'Torrent DR',
                subtitle: 'Version 1.0.0\nBuilt with Flutter + Rust\n— EVLF ERIS LAB —',
              ),
              const SizedBox(height: 16),
              _buildSettingCard(
                context: context,
                icon: Icons.code,
                title: 'Open Source',
                subtitle: 'github.com/ybsa/TorrentsDR',
                onTap: () {
                  // TODO: Open URL
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing ??
            (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchSetting({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _selectDownloadFolder(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // For Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE for full access
        // Or at least try to request it if standard storage is denied
        
        // Check current status
        var status = await Permission.storage.status;
        
        if (!status.isGranted) {
           status = await Permission.storage.request();
        }
        
        // If standard storage denied, try manageExternalStorage (Android 11+)
        if (!status.isGranted) {
           var manageStatus = await Permission.manageExternalStorage.status;
           if (!manageStatus.isGranted) {
              manageStatus = await Permission.manageExternalStorage.request();
           }
           
           if (manageStatus.isGranted) {
              status = PermissionStatus.granted;
           }
        }

        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Storage permission is required. Using default fallback.'),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () => openAppSettings(),
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Don't return, let picker try (it might work with system picker on some OS versions)
          // actually file_picker needs permission usually.
          return; 
        }
      }

      if (!context.mounted) return;
      final state = context.read<SettingsCubit>().state;
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Download Folder',
        initialDirectory: state.downloadPath.isEmpty ? null : state.downloadPath,
      );

      if (result != null && context.mounted) {
        // Verify we can write to it?
        context.read<SettingsCubit>().setDownloadPath(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download folder set to: $result'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
