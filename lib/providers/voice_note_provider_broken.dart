import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/voice_note.dart';
import '../services/audio_recorder.dart';
import '../services/database_service.dart';
import '../services/speech_service.dart';

enum RecordingState {
  idle,
  recordingIntent,
  recordingNote,

class VoiceNoteProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  final SpeechService _speechService = SpeechService();

  List<VoiceNote> _notes = [];
  RecordingState _state = RecordingState.idle;
  String _currentIntent = '';
  String _currentNoteTranscription = '';
  String? _currentAudioPath;
  DateTime? _recordingStartTime;
  DateTime? _recordingEndTime;
  Duration? _finalRecordingDuration;
  bool _isInitialized = false;
  bool _isStartingRecording = false;
  String? _permissionError;

  // Getters
  List<VoiceNote> get notes => _notes;
  RecordingState get state => _state;
  String get currentIntent => _currentIntent;
  String get currentNoteTranscription => _currentNoteTranscription;
  String? get currentAudioPath => _currentAudioPath;
  bool get isRecording => _state != RecordingState.idle;
  bool get isInitialized => _isInitialized;
  String? get permissionError => _permissionError;

  // New getter for recording duration
  Duration? get recordingDuration {
    if (_recordingStartTime == null) return null;
    final endTime = _recordingEndTime ?? DateTime.now();
    return endTime.difference(_recordingStartTime!);
  }

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Database initialized in constructor;
    await loadNotes();
    await // AudioRecorder initialized;
    
    // Initialize speech service with permission error handler
    await _speechService.initialize(
      onPermissionError: (error) {
        _permissionError = error;
        notifyListeners();
        debugPrint('Provider: Permission error: $error');
      },
    );
    
    _isInitialized = true;
    notifyListeners();
  }

  // Load notes from database
  Future<void> loadNotes() async {
    _notes = await _databaseService.getAllNotes();
    notifyListeners();
  }

  // Start recording intent
  void startIntentRecording() {
    if (_state != RecordingState.idle) return;

    _state = RecordingState.recordingIntent;
    _currentIntent = '';
    _permissionError = null; // Clear any previous permission error
    notifyListeners();
    debugPrint('Provider: Intent recording started');
  }

  // Skip intent and go directly to note recording
  void skipIntent() {
    if (_state != RecordingState.idle) return;

    _currentIntent = '';
    _permissionError = null; // Clear any previous permission error
    startNoteRecording();
    debugPrint('Provider: Skipping intent');
  }

  // Save the intent and transition to note recording
  void saveIntent(String intent) {
    if (_state != RecordingState.recordingIntent) return;

    _currentIntent = intent;
    debugPrint('Provider: Intent saved: "$intent"');
    startNoteRecording();
  }

  // Start recording note
  Future<void> startNoteRecording() async {
    // Prevent multiple simultaneous recording attempts
    if (_isStartingRecording || _state == RecordingState.recordingNote) {
      debugPrint('Provider: Already starting/recording, skipping duplicate call');
      return;
    }

    _isStartingRecording = true;
    _state = RecordingState.recordingNote;
    _currentNoteTranscription = '';
    _permissionError = null; // Clear any previous permission error
    notifyListeners();

    debugPrint('Provider: Starting note recording');

    // Start audio recording first
    final path = await _audioRecorder.startRecording();
    _currentAudioPath = path;
    debugPrint('Provider: Audio recording started at path: $path');

    // Track when recording started
    _recordingStartTime = DateTime.now();
    debugPrint('Provider: 🕐 Recording START TIME set: $_recordingStartTime');

    // Start speech recognition with live updates and permission error handling
    try {
      await _speechService.startListening(
        onResult: (text) {
          // Only update if we get actual text, not error messages
          if (!text.startsWith('[Speech')) {
            _currentNoteTranscription = text;
          } else {
            debugPrint('Provider: Speech error received: $text');
          }
          notifyListeners();
        },
        onPermissionError: (error) {
          _permissionError = error;
          notifyListeners();
          debugPrint('Provider: Permission error during recording: $error');
        },
      );
      debugPrint('Provider: Speech recognition started successfully');
    } catch (e) {
      debugPrint('Provider: Failed to start speech recognition: $e');
      // Continue recording even if speech fails
    }

    debugPrint('Provider: Recording started (speech may or may not be active)');

    // Clear the flag after setup is complete
    _isStartingRecording = false;

    // For web testing - add sample text after delay if speech recognition fails
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_state == RecordingState.recordingNote && _currentNoteTranscription.isEmpty) {
          _currentNoteTranscription = 'Sample note: Remember to test the voice recording feature on mobile device for actual speech-to-text';
          notifyListeners();
          debugPrint('Added sample text for web testing');
        }
      });
    }
  }

  // Stop recording and save the note
  Future<void> stopNoteRecording() async {
    if (_state != RecordingState.recordingNote) {
      debugPrint('Provider: Not recording, cannot stop');
      return;
    }

    debugPrint('Provider: Stopping note recording');

    // Track when recording ended
    _recordingEndTime = DateTime.now();
    debugPrint('Provider: 🕐 Recording END TIME set: $_recordingEndTime');

    // Store current live transcription before stopping
    final liveTranscription = _currentNoteTranscription;
    debugPrint('Provider: Current live transcription before stop: "$liveTranscription"');

    // Stop audio recording
    final path = await _audioRecorder.stopRecording();
    debugPrint('Provider: Recording ended at ${_recordingEndTime}');
    
    if (path != null) {
      debugPrint('Provider: Audio file saved at: $path');
      // Only update path if we got a valid one
      _currentAudioPath = path;
    }

    // Stop speech recognition and get final result
    await _speechService.stopListening();
    
    // Use the speech service's final result if available, otherwise use live transcription
    final finalWords = _speechService.lastWords;
    debugPrint('Provider: Final words from speech service: "$finalWords"');

    if (finalWords.isNotEmpty && !finalWords.startsWith('[Speech')) {
      _currentNoteTranscription = finalWords;
    } else if (liveTranscription.isEmpty || liveTranscription.startsWith('[Speech')) {
      debugPrint('Provider: WARNING - No transcription captured from speech service');
      _currentNoteTranscription = '';
    }

    debugPrint('Provider: Final transcription to be saved: "$_currentNoteTranscription"');

    // Calculate final duration
    if (_recordingStartTime != null && _recordingEndTime != null) {
      _finalRecordingDuration = _recordingEndTime!.difference(_recordingStartTime!);
      debugPrint('Provider: Calculating final duration:');
      debugPrint('  - Recording started at ${_recordingStartTime}');
      debugPrint('  - Recording ended at ${_recordingEndTime}');
      debugPrint('  - Duration: ${_finalRecordingDuration!.inSeconds}s (${_formatDuration(_finalRecordingDuration!)})');
    }

    notifyListeners();
  }

  // Start recording note with intent
  Future<void> startNoteRecordingWithIntent(String intent) async {
    if (_state != RecordingState.idle) return;

    _currentIntent = intent;
    _permissionError = null; // Clear any previous permission error
    debugPrint('Provider: Starting note recording with intent: "$intent"');

    // Start audio recording
    final path = await _audioRecorder.startRecording();
    _currentAudioPath = path;

    // Track when recording started
    _recordingStartTime = DateTime.now();
    debugPrint('Provider: Recording started at $_recordingStartTime');

    // Start speech recognition with live updates and permission error handling
    await _speechService.startListening(
      onResult: (text) {
        _currentNoteTranscription = text;
        notifyListeners();
        debugPrint('Provider: Live transcription update: "$text"');
      },
      onPermissionError: (error) {
        _permissionError = error;
        notifyListeners();
        debugPrint('Provider: Permission error during recording: $error');
      },
    );

    _state = RecordingState.recordingNote;
    notifyListeners();
  }

  // Cancel the current recording without saving
  Future<void> cancelRecording() async {
    debugPrint('Provider: Canceling recording');

    // Cancel audio recording
    await _audioRecorder.stopRecording();

    // Cancel speech recognition
    await _speechService.cancelListening();

    // Clear recording timestamps
    _recordingStartTime = null;
    _recordingEndTime = null;
    _finalRecordingDuration = null;

    // Reset state
    _state = RecordingState.idle;
    _currentIntent = '';
    _currentNoteTranscription = '';
    _currentAudioPath = null;
    _permissionError = null;
    notifyListeners();
  }

  // Save the current note to database
  Future<void> saveCurrentNote() async {
    // Set a default transcription if none was captured
    String finalTranscription = _currentNoteTranscription.isEmpty
        ? 'No transcription available'
        : _currentNoteTranscription;

    // Use pre-calculated duration or calculate now
    Duration? duration = _finalRecordingDuration;
    if (duration == null && _recordingStartTime != null && _recordingEndTime != null) {
      duration = _recordingEndTime!.difference(_recordingStartTime!);
    }

    final note = VoiceNote(
      audioPath: _currentAudioPath ?? "",
      transcription: finalTranscription,
      intentDescription: _currentIntent.isEmpty ? null : _currentIntent,
      durationSeconds: duration?.inSeconds,
    );
    await _databaseService.insertNote(note);
    debugPrint('Note saved to database: ${note.id}');

    if (_currentIntent.isEmpty) {
      debugPrint('Provider: Note saved to database without intent');
    } else {
      debugPrint('Provider: Note saved with intent: "$_currentIntent"');
    }
    debugPrint('Provider: Transcription in saved note: "${note.transcription}"');

    if (duration != null) {
      debugPrint('Provider: Duration in saved note: ${duration.inSeconds} seconds');
    }

    // Load notes to refresh the list
    await loadNotes();

    // Reset state after successful save
    resetState();
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  // Reset recording state
  void resetState() {
    debugPrint('Provider: Resetting state');
    _state = RecordingState.idle;
    _currentIntent = '';
    _currentNoteTranscription = '';
    _currentAudioPath = null;
    _recordingStartTime = null;
    _recordingEndTime = null;
    _finalRecordingDuration = null;
    _permissionError = null;
    notifyListeners();
  }

  // Delete a note
  Future<void> deleteNote(String id) async {
    await _databaseService.deleteNote(id);
    
    // Also delete the audio file if it exists
    final note = _notes.firstWhere((n) => n.id == id);
    if (note.audioPath != null) {
      final file = File(note.audioPath!);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Audio file deleted: ${note.audioPath}');
      }
    }
    
    await loadNotes();
  }

  // Update a note
  Future<void> updateNote(VoiceNote note) async {
    await _databaseService.updateNote(note);
    await loadNotes();
  }

  // Clear permission error
  void clearPermissionError() {
    _permissionError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _speechService.dispose();
    super.dispose();
  }

  // Additional methods for compatibility

  // Prepare for recording - transitions to recordingIntent state
  void prepareForRecording() {
    startIntentRecording();
  }

  // Stop intent recording
  void stopIntentRecording() {
    if (_state == RecordingState.recordingIntent) {
      // Save the intent and transition to note recording
      saveIntent(_currentIntent);
    }
  }

  // Save note with the provided intent
  void saveNoteWithIntent(String intent) {
    saveIntent(intent);

  // Additional methods for compatibility

  // Prepare for recording - transitions to recordingIntent state
  void prepareForRecording() {
    startIntentRecording();
  }

  // Stop intent recording
  void stopIntentRecording() {
    if (_state == RecordingState.recordingIntent) {
      // Save the intent and transition to note recording
      saveIntent(_currentIntent);
    }
  }

  // Save note with the provided intent
  void saveNoteWithIntent(String intent) {
    saveIntent(intent);
  }
}
