import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:parachute/providers/service_providers.dart';
import 'package:flutter/services.dart';
import 'package:parachute/models/recording.dart';
import 'package:parachute/widgets/playback_controls.dart';

class RecordingDetailScreen extends ConsumerStatefulWidget {
  final Recording recording;

  const RecordingDetailScreen({
    super.key,
    required this.recording,
  });

  @override
  ConsumerState<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends ConsumerState<RecordingDetailScreen> {
  late Recording _recording;

  @override
  void initState() {
    super.initState();
    _recording = widget.recording;
  }

  void _copyToClipboard() {
    if (_recording.transcript.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _recording.transcript));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transcript copied to clipboard')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcript available')),
      );
    }
  }

  void _addToCalendar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calendar integration coming soon')),
    );
  }

  void _showEditDialog() {
    final titleController = TextEditingController(text: _recording.title);
    final transcriptController =
        TextEditingController(text: _recording.transcript);
    final tagsController =
        TextEditingController(text: _recording.tags.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Recording'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: transcriptController,
                decoration: const InputDecoration(
                  labelText: 'Transcript',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final updatedRecording = Recording(
                id: _recording.id,
                title: titleController.text.trim(),
                filePath: _recording.filePath,
                timestamp: _recording.timestamp,
                duration: _recording.duration,
                tags: tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList(),
                transcript: transcriptController.text.trim(),
                fileSizeKB: _recording.fileSizeKB,
              );

              final success =
                  await ref.read(storageServiceProvider).updateRecording(updatedRecording);
              if (success && mounted) {
                setState(() {
                  _recording = updatedRecording;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recording updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _shareRecording() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _shareRecording();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Recording'),
          content: const Text(
              'Are you sure you want to delete this recording? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final success =
                    await ref.read(storageServiceProvider).deleteRecording(_recording.id);
                if (success && mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recording deleted')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_recording.title),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showMoreOptions,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playback controls
            PlaybackControls(
              filePath: _recording.filePath,
              duration: _recording.duration,
              onDelete: () async {
                final success =
                    await ref.read(storageServiceProvider).deleteRecording(_recording.id);
                if (success && mounted) {
                  Navigator.of(context).pop(true);
                }
              },
            ),

            const SizedBox(height: 24),

            // Recording info
            _buildInfoSection(),

            const SizedBox(height: 24),

            // Tags
            if (_recording.tags.isNotEmpty) ...[
              _buildTagsSection(),
              const SizedBox(height: 24),
            ],

            // Transcript section
            _buildTranscriptSection(),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recording Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard('Duration', _recording.durationString),
            const SizedBox(width: 12),
            _buildStatCard('Size', _recording.formattedSize),
            const SizedBox(width: 12),
            _buildStatCard('Date', _recording.timeAgo),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recording.tags.map((tag) {
            return Chip(
              label: Text(tag),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTranscriptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transcript',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            IconButton(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy transcript',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            _recording.transcript.isNotEmpty
                ? _recording.transcript
                : 'No transcript available',
            style: TextStyle(
              height: 1.5,
              color: _recording.transcript.isNotEmpty
                  ? null
                  : Colors.grey.withOpacity(0.7),
              fontStyle:
                  _recording.transcript.isEmpty ? FontStyle.italic : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _addToCalendar,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Add to Calendar'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareRecording,
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
