import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/voice_note.dart';
import '../services/audio_recorder.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

enum RecordingState {
  idle,
  recordingNote,
  waitingForIntent,
  recordingIntent,
  complete
}

class VoiceNoteProvider extends ChangeNotifier {
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  final SpeechService _speechService = SpeechService();
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  RecordingState _state = RecordingState.idle;
  String? _currentNotePath;
  String _currentNoteTranscription = '';
  String? _currentIntentPath;
  String _currentIntentTranscription = '';
  List<VoiceNote> _notes = [];
  String? _errorMessage;
  Position? _currentPosition;
  bool _isStartingRecording = false; // Prevent multiple simultaneous starts
  DateTime? _recordingStartTime; // Track when recording started
  DateTime? _recordingEndTime; // Track when main recording ended

  RecordingState get state => _state;
  List<VoiceNote> get notes => _notes;
  String get currentNoteTranscription => _currentNoteTranscription;
  String get currentIntentTranscription => _currentIntentTranscription;
  bool get isRecording => _state == RecordingState.recordingNote ||
                           _state == RecordingState.recordingIntent;
  String? get errorMessage => _errorMessage;

  VoiceNoteProvider() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize speech recognition
    final speechAvailable = await _speechService.initialize();
    if (!speechAvailable) {
      debugPrint('Speech recognition not available');
    }

    // Load existing notes from database
    await loadNotes();
  }

  Future<void> loadNotes() async {
    try {
      _notes = await _databaseService.getAllNotes();
      notifyListeners();
      debugPrint('Loaded ${_notes.length} notes from database');
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
  }

  // Phase 1: Just set state to trigger navigation
  void prepareForRecording() {
    debugPrint('Provider: Preparing for recording');
    _errorMessage = null;
    _currentNoteTranscription = '';
    _recordingStartTime = null; // Clear any previous recording time
    _state = RecordingState.recordingNote;
    notifyListeners();
  }

  // Phase 2: Actually start recording (called after navigation)
  Future<void> startNoteRecording() async {
    // Prevent multiple simultaneous recording starts
    if (_isStartingRecording) {
      debugPrint('Provider: Already starting recording, skipping duplicate call');
      return;
    }

    // Check if already recording
    if (_audioRecorder.isRecording) {
      debugPrint('Provider: Already recording, skipping duplicate start');
      return;
    }

    _isStartingRecording = true;
    debugPrint('Provider: Starting actual recording');

    // Get current location while starting recording
    _currentPosition = await _locationService.getCurrentLocation();
    if (_currentPosition != null) {
      debugPrint('Recording at location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    }

    // Start both recording and speech recognition
    _currentNotePath = await _audioRecorder.startRecording();

    if (_currentNotePath == null) {
      debugPrint('Provider: Failed to start recording');
      _errorMessage = 'Failed to start recording. Please check permissions.';
      _state = RecordingState.idle;
      notifyListeners();
      return;
    }

    // Track when recording started
    _recordingStartTime = DateTime.now();
    debugPrint('Provider: 🕐 Recording START TIME set: $_recordingStartTime');

    // Start speech recognition with live updates
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

  Future<void> stopNoteRecording() async {
    debugPrint('Provider: Stopping note recording');
    debugPrint('Provider: Current live transcription before stop: "$_currentNoteTranscription"');

    // Make sure we're actually recording before trying to stop
    if (_state != RecordingState.recordingNote) {
      debugPrint('Provider: Not in recording state, skipping stop');
      return;
    }

    // Capture the end time for the main recording
    _recordingEndTime = DateTime.now();
    debugPrint('Provider: Recording ended at $_recordingEndTime');
    if (_recordingStartTime != null) {
      final duration = _recordingEndTime!.difference(_recordingStartTime!);
      debugPrint('Provider: Main recording duration: ${duration.inSeconds}s');
    } else {
      debugPrint('Provider: WARNING - No recording start time!');
    }

    // Stop speech recognition first to get final words
    await _speechService.stopListening();

    // Get final transcription - prefer lastWords if available
    final finalWords = _speechService.lastWords;
    debugPrint('Provider: Final words from speech service: "$finalWords"');

    // Only overwrite if we got something from speech service, otherwise keep live transcription
    if (finalWords.isNotEmpty) {
      _currentNoteTranscription = finalWords;
    } else if (_currentNoteTranscription.isEmpty) {
      // If both are empty, check if speech was working at all
      debugPrint('Provider: WARNING - No transcription captured from speech service');
    }

    debugPrint('Provider: Final transcription to be saved: "$_currentNoteTranscription"');

    // Now stop the audio recording
    await _audioRecorder.stopRecording();

    // Move to waiting for intent state
    _state = RecordingState.waitingForIntent;
    notifyListeners();
  }

  Future<void> startIntentRecording() async {
    debugPrint('Provider: Starting intent recording');
    _currentIntentTranscription = '';
    _state = RecordingState.recordingIntent;
    notifyListeners();

    // Start recording and speech recognition for intent
    _currentIntentPath = await _audioRecorder.startRecording();

    if (_currentIntentPath == null) {
      // Save note without intent
      debugPrint('Provider: Failed to start intent recording, saving without intent');
      await _saveNote();
      _state = RecordingState.complete;
      notifyListeners();
      _resetAfterDelay();
      return;
    }

    // Start speech recognition for intent
    try {
      await _speechService.startListening(
        onResult: (text) {
          // Only update if we get actual text, not error messages
          if (!text.startsWith('[Speech')) {
            _currentIntentTranscription = text;
          } else {
            debugPrint('Provider: Intent speech error received: $text');
          }
          notifyListeners();
        },
      );
      debugPrint('Provider: Intent speech recognition started successfully');
    } catch (e) {
      debugPrint('Provider: Failed to start intent speech recognition: $e');
      // Continue recording even if speech fails
    }

    // For web testing - add sample intent text after delay
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_state == RecordingState.recordingIntent && _currentIntentTranscription.isEmpty) {
          _currentIntentTranscription = 'Project planning discussion';
          notifyListeners();
          debugPrint('Added sample intent for web testing');
        }
      });
    }
  }

  Future<void> stopIntentRecording() async {
    debugPrint('Provider: Stopping intent recording');

    // Stop speech recognition first to get final words
    await _speechService.stopListening();

    // Get final transcription before stopping audio
    _currentIntentTranscription = _speechService.lastWords;
    debugPrint('Provider: Final intent transcription from speech service: $_currentIntentTranscription');

    // Now stop the audio recording
    await _audioRecorder.stopRecording();

    if (_currentIntentTranscription.isNotEmpty) {
      debugPrint('Provider: Intent transcription: $_currentIntentTranscription');
      await _saveNote(intentDescription: _currentIntentTranscription);
    } else {
      await _saveNote();
    }

    _state = RecordingState.complete;
    notifyListeners();
    _resetAfterDelay();
  }

  Future<void> skipIntent() async {
    debugPrint('Provider: Skipping intent');
    await _saveNote();
    _state = RecordingState.complete;
    notifyListeners();
    _resetAfterDelay();
  }

  Future<void> saveNoteWithIntent(String intent) async {
    debugPrint('Provider: Saving note with typed intent: $intent');
    await _saveNote(intentDescription: intent);
    _state = RecordingState.complete;
    notifyListeners();
    _resetAfterDelay();
  }

  Future<void> _saveNote({String? intentDescription}) async {
    if (_currentNotePath != null) {
      // Allow saving even if transcription is empty (for web where speech might fail)
      final transcription = _currentNoteTranscription.isEmpty
          ? 'No transcription available'
          : _currentNoteTranscription;

      // Calculate recording duration
      int? durationSeconds;
      if (_recordingStartTime != null && _recordingEndTime != null) {
        final duration = _recordingEndTime!.difference(_recordingStartTime!);
        durationSeconds = duration.inSeconds;
        debugPrint('Provider: Calculating final duration:');
        debugPrint('  - Recording started at $_recordingStartTime');
        debugPrint('  - Recording ended at $_recordingEndTime');
        debugPrint('  - Duration: ${durationSeconds}s (${duration.toString()})');
      } else {
        debugPrint('Provider: WARNING - Missing timing data!');
        debugPrint('  - Start time: $_recordingStartTime');
        debugPrint('  - End time: $_recordingEndTime');
      }

      debugPrint('Provider: Saving note with transcription: "$transcription"');
      debugPrint('Provider: Intent: "$intentDescription"');

      final note = VoiceNote(
        audioPath: _currentNotePath!,
        transcription: transcription,
        intentDescription: intentDescription,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        locationName: _currentPosition != null
          ? _locationService.getLocationName(
              _currentPosition!.latitude,
              _currentPosition!.longitude
            )
          : null,
        durationSeconds: durationSeconds,
      );

      try {
        // Save to database
        await _databaseService.insertNote(note);

        // Add to local list AT THE BEGINNING - this is important for navigation
        _notes.insert(0, note); // Insert at beginning for newest first

        debugPrint('Provider: Note saved to database with${intentDescription != null ? '' : 'out'} intent');
        debugPrint('Provider: Transcription in saved note: "${note.transcription}"');
        debugPrint('Audio file saved at: ${note.audioPath}');
        if (note.latitude != null) {
          debugPrint('Location: ${note.locationName}');
        }

        notifyListeners();
      } catch (e) {
        debugPrint('Error saving note to database: $e');
        _errorMessage = 'Failed to save note';
      }
    } else {
      debugPrint('Provider: Warning - no audio path available, cannot save note');
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _databaseService.deleteNote(id);
      _notes.removeWhere((note) => note.id == id);
      notifyListeners();
      debugPrint('Note deleted: $id');
    } catch (e) {
      debugPrint('Error deleting note: $e');
    }
  }

  Future<List<VoiceNote>> searchNotes(String query) async {
    try {
      return await _databaseService.searchNotes(query);
    } catch (e) {
      debugPrint('Error searching notes: $e');
      return [];
    }
  }

  void _resetAfterDelay() {
    Future.delayed(const Duration(seconds: 1)).then((_) {
      _reset();
    });
  }

  void _reset() {
    debugPrint('Provider: Resetting state');
    _state = RecordingState.idle;
    _currentNotePath = null;
    _currentNoteTranscription = '';
    _currentIntentPath = null;
    _currentIntentTranscription = '';
    _currentPosition = null;
    _errorMessage = null;
    _recordingStartTime = null;
    _recordingEndTime = null;
    _isStartingRecording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _speechService.dispose();
    _databaseService.close();
    super.dispose();
  }
}
