import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_note_provider.dart';

class RecordingButton extends StatelessWidget {
  const RecordingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceNoteProvider>(
      builder: (context, provider, child) {
        final state = provider.state;
        
        // Show error if any
        if (provider.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                const SizedBox(height: 8),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(color: Colors.red[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.startNoteRecording(),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
        
        // Show success checkmark
        if (state == RecordingState.complete) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 72,
                  color: Colors.green[600],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note saved!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }
        
        // Show intent recording options
        if (state == RecordingState.waitingForIntent) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Show the transcribed note
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_quote, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text('Your note:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.currentNoteTranscription,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                const Icon(Icons.psychology, size: 48, color: Colors.blue),
                const SizedBox(height: 12),
                const Text(
                  "What's the intent of this note?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  '(Optional: helps with searching later)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => provider.skipIntent(),
                      child: const Text('Skip'),
                    ),
                    const SizedBox(width: 24),
                    _buildRecordButton(
                      context,
                      isRecording: false,
                      onPressed: () => provider.startIntentRecording(),
                      size: 56,
                      label: 'Record Intent',
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        
        // Show recording intent state with live transcription
        if (state == RecordingState.recordingIntent) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildRecordButton(
                  context,
                  isRecording: true,
                  onPressed: () => provider.stopIntentRecording(),
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recording intent... Tap to stop',
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
                if (provider.currentIntentTranscription.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.currentIntentTranscription,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        
        // Show recording note state with live transcription
        if (state == RecordingState.recordingNote) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildRecordButton(
                  context,
                  isRecording: true,
                  onPressed: () => provider.stopNoteRecording(),
                  size: 72,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recording... Tap to stop',
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
                if (provider.currentNoteTranscription.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.currentNoteTranscription,
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        
        // Default idle state - main recording button
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildRecordButton(
                context,
                isRecording: false,
                onPressed: () => provider.startNoteRecording(),
                size: 72,
                label: 'Tap to Record',
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to start recording',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildRecordButton(
    BuildContext context, {
    required bool isRecording,
    required VoidCallback onPressed,
    required double size,
    String? label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? Colors.red : Colors.blue,
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? Colors.red : Colors.blue).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (isRecording) ...[
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isRecording)
                  AnimatedContainer(
                    duration: const Duration(seconds: 1),
                    width: size * 0.9,
                    height: size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              ],
            ),
          ),
        ),
        if (label != null && !isRecording) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}