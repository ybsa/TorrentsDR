import 'package:flutter/material.dart';
import '../services/torrent_service.dart';

class FileSelectionDialog extends StatefulWidget {
  final List<FileItem> files;

  const FileSelectionDialog({Key? key, required this.files}) : super(key: key);

  @override
  _FileSelectionDialogState createState() => _FileSelectionDialogState();
}

class _FileSelectionDialogState extends State<FileSelectionDialog> {
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.generate(widget.files.length, (_) => true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Files'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.files.length,
          itemBuilder: (context, index) {
            final file = widget.files[index];
            return CheckboxListTile(
              title: Text(file.path),
              subtitle: Text(_formatBytes(file.size)),
              value: _selected[index],
              onChanged: (bool? value) {
                setState(() {
                  _selected[index] = value ?? false;
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Return list of selected indices
            final selectedIndices = <int>[];
            for (int i = 0; i < _selected.length; i++) {
              if (_selected[i]) {
                selectedIndices.add(i);
              }
            }
            Navigator.pop(context, selectedIndices);
          },
          child: const Text('Download'),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
