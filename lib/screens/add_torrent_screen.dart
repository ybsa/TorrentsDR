import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/torrent/torrent_bloc.dart';
import '../bloc/torrent/torrent_event.dart';
import '../services/torrent_service.dart';
import '../widgets/file_selection_dialog.dart';
import 'torrent_preview_screen.dart';

class AddTorrentScreen extends StatefulWidget {
  const AddTorrentScreen({super.key});

  @override
  State<AddTorrentScreen> createState() => _AddTorrentScreenState();
}

class _AddTorrentScreenState extends State<AddTorrentScreen> {
  final _magnetController = TextEditingController();
  bool _isLoading = false;

  Future<void> _pickTorrentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null && mounted) {
          // Get info and show dialog
          try {
             setState(() => _isLoading = true);
             final info = await TorrentService.getTorrentInfo(filePath);
             setState(() => _isLoading = false);
             
             if (!mounted) return;
             
             // Show dialog
             final selectedIndices = await showDialog<List<int>>(
               context: context,
               builder: (context) => FileSelectionDialog(files: info.files),
             );
             
             if (selectedIndices != null && mounted) {
                // Add torrent from file via Bloc with selected indices
                context.read<TorrentBloc>().add(AddTorrentFile(filePath, selectedIndices));
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Adding: ${result.files.first.name}'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
             }
          } catch (e) {
             setState(() => _isLoading = false);
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error reading torrent: $e'), backgroundColor: Colors.red),
                );
             }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMagnetLink() async {
    final magnet = _magnetController.text.trim();

    if (magnet.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a magnet link'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!magnet.startsWith('magnet:?')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid magnet link'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Close bottom sheet and navigate to preview screen
    Navigator.pop(context);
    
    // Navigate to preview screen
    final selectedFiles = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) => TorrentPreviewScreen(
          source: magnet,
          isMagnet: true,
        ),
      ),
    );
    
    // If user confirmed (selected files), start download
    if (selectedFiles != null && mounted) {
      context.read<TorrentBloc>().add(AddMagnetLink(magnet, selectedFiles));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Download starting...'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Add Torrent',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),

            // Torrent file button
            OutlinedButton.icon(
              onPressed: _pickTorrentFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose .torrent file'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Divider with "OR"
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),

            // Magnet link input
            TextField(
              controller: _magnetController,
              decoration: const InputDecoration(
                hintText: 'Paste magnet link here...',
                prefixIcon: Icon(Icons.link),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),

            // Add magnet button
            ElevatedButton(
              onPressed: _isLoading ? null : _addMagnetLink,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Magnet Link'),
            ),
            const SizedBox(height: 8),
          ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _magnetController.dispose();
    super.dispose();
  }
}
