import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _downloadPath = 'C:\\Users\\Downloads';
  double _maxDownloadSpeed = 0; // 0 = unlimited
  double _maxUploadSpeed = 0; // 0 = unlimited (we don't upload, but for future)
  bool _startMinimized = false;
  bool _showNotifications = true;

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Download Location
          _buildSectionTitle('Download Location'),
          _buildSettingCard(
            icon: Icons.folder_outlined,
            title: 'Download Folder',
            subtitle: _downloadPath,
            onTap: _selectDownloadFolder,
          ),
          const SizedBox(height: 24),

          // Speed Limits
          _buildSectionTitle('Speed Limits'),
          _buildSettingCard(
            icon: Icons.download,
            title: 'Max Download Speed',
            subtitle: _maxDownloadSpeed == 0 
                ? 'Unlimited' 
                : '${_maxDownloadSpeed.toInt()} MB/s',
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _maxDownloadSpeed,
                min: 0,
                max: 50,
                divisions: 50,
                onChanged: (value) => setState(() => _maxDownloadSpeed = value),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Behavior
          _buildSectionTitle('Behavior'),
          _buildSwitchSetting(
            icon: Icons.minimize,
            title: 'Start Minimized',
            subtitle: 'Start app in system tray',
            value: _startMinimized,
            onChanged: (value) => setState(() => _startMinimized = value),
          ),
          _buildSwitchSetting(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Show when downloads complete',
            value: _showNotifications,
            onChanged: (value) => setState(() => _showNotifications = value),
          ),
          const SizedBox(height: 24),

          // About
          _buildSectionTitle('About'),
          _buildSettingCard(
            icon: Icons.info_outline,
            title: 'Torrent DR',
            subtitle: 'Version 1.0.0\nBuilt with Flutter + Rust\nEVLF ER',
          ),
          const SizedBox(height: 16),
          _buildSettingCard(
            icon: Icons.code,
            title: 'Open Source',
            subtitle: 'github.com/ybsa/TorrentsDR',
            onTap: () {
              // TODO: Open URL
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
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
          style: TextStyle(color: Colors.white54),
        ),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchSetting({
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
          style: TextStyle(color: Colors.white54),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _selectDownloadFolder() async {
    // TODO: Implement folder picker
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Folder picker will be available after flutter_rust_bridge setup')),
    );
  }
}
