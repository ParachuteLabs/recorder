import 'package:flutter/material.dart';
import 'package:parachute/models/recording.dart';
import 'package:parachute/services/audio_service.dart';
import 'package:parachute/services/storage_service.dart';
import 'package:parachute/services/whisper_service.dart';
import 'package:parachute/screens/settings_screen.dart';

class PostRecordingScreen extends StatefulWidget {
  final String recordingPath;
  final Duration duration;
  final String? initialTranscript;

  const PostRecordingScreen({
    super.key,
    required this.recordingPath,
    required this.duration,
    this.initialTranscript,
  });

  @override
  State<PostRecordingScreen> createState() => _PostRecordingScreenState();
}

class _PostRecordingScreenState extends State<PostRecordingScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _transcriptController = TextEditingController();
  final StorageService _storageService = StorageService();
  final AudioService _audioService = AudioService();
  final WhisperService _whisperService = WhisperService();

  final List<String> _predefinedTags = [
    'Project A',
    'To Do',
    'Meeting',
    'Interview',
    'Idea',
    'Note',
    'Important'
  ];
  final Set<String> _selectedTags = {};
  bool _isPlaying = false;
  bool _isSaving = false;
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    // Generate a default title with date and time
    final now = DateTime.now();
    final dateStr =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _titleController.text = 'Recording $dateStr';

    // Use the transcription from the recording if available
    _transcriptController.text = widget.initialTranscript ?? '';
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioService.stopPlayback();
      setState(() => _isPlaying = false);
    } else {
      final success = await _audioService.playRecording(widget.recordingPath);
      if (success) {
        setState(() => _isPlaying = true);
        // Auto-stop after duration (simplified)
        Future.delayed(widget.duration, () {
          if (mounted && _isPlaying) {
            setState(() => _isPlaying = false);
          }
        });
      }
    }
  }

  Future<void> _transcribeRecording() async {
    if (_isTranscribing) return;

    // Check if API key is configured
    final isConfigured = await _whisperService.isConfigured();
    if (!isConfigured) {
      if (!mounted) return;

      // Show dialog to navigate to settings
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Key Required'),
          content: const Text(
            'To use transcription, you need to configure your OpenAI API key in Settings.\n\n'
            'Would you like to go to Settings now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );

      if (goToSettings == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
      }
      return;
    }

    setState(() => _isTranscribing = true);

    try {
      final transcript = await _whisperService.transcribeAudio(
        widget.recordingPath,
      );

      if (mounted) {
        _transcriptController.text = transcript;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcription completed!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on WhisperException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription failed: ${e.message}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  Future<void> _saveRecording() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final fileSizeKB =
          await _audioService.getFileSizeKB(widget.recordingPath);

      final recording = Recording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Untitled Recording',
        filePath: widget.recordingPath,
        timestamp: DateTime.now(),
        duration: widget.duration,
        tags: _selectedTags.toList(),
        transcript: _transcriptController.text.trim(),
        fileSizeKB: fileSizeKB,
      );

      final success = await _storageService.saveRecording(recording);

      if (success && mounted) {
        // Show success message first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved successfully')),
        );

        // Small delay to ensure the recording is saved
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate back to home screen and trigger refresh
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save recording')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving recording')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Context'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playback controls
            _buildPlaybackSection(),

            const SizedBox(height: 24),

            // Title input
            _buildTitleSection(),

            const SizedBox(height: 24),

            // Transcript section
            _buildTranscriptSection(),

            const SizedBox(height: 24),

            // Tags section
            _buildTagsSection(),

            const SizedBox(height: 32),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            IconButton(
              onPressed: _togglePlayback,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleController.text,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${widget.duration.inMinutes}:${(widget.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (_isPlaying)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Enter recording title',
            border: OutlineInputBorder(),
          ),
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
            ElevatedButton.icon(
              onPressed: _isTranscribing ? null : _transcribeRecording,
              icon: _isTranscribing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_isTranscribing ? 'Transcribing...' : 'Transcribe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: TextField(
            controller: _transcriptController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Add notes or transcript here (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you want to tag this?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _predefinedTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Record more content button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement record more content
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Record more content - Coming soon!')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Record more content'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
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
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRecording,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }
}
