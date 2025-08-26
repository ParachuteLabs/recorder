import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_note_provider.dart';
import '../widgets/recording_button.dart';
import '../widgets/notes_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Voice Notes', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Consumer<VoiceNoteProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Expanded(
                child: provider.notes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic_none, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No voice notes yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button below to record',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : NotesList(notes: provider.notes),
              ),
              const RecordingButton(),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}