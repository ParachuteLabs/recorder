import 'package:flutter/material.dart';
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

  Future<void> startNoteRecording() async {
    debugPrint('Provider: Starting note recording');
    _errorMessage = null;
    _currentNoteTranscription = '';
    _state = RecordingState.recordingNote;
    notifyListeners();

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

    // Start speech recognition with live updates
    await _speechService.startListening(
      onResult: (text) {
        _currentNoteTranscription = text;
        notifyListeners();
      },
    );

    debugPrint('Provider: Recording and speech recognition started');
  }

  Future<void> stopNoteRecording() async {
    debugPrint('Provider: Stopping note recording');

    // Stop both recording and speech recognition
    await _speechService.stopListening();
    await _audioRecorder.stopRecording();

    // Get final transcription
    _currentNoteTranscription = _speechService.lastWords;

    // Don't overwrite with "No speech detected" - handle empty in _saveNote
    // if (_currentNoteTranscription.isEmpty) {
    //   _currentNoteTranscription = 'No speech detected';
    // }

    debugPrint('Provider: Final transcription: $_currentNoteTranscription');

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
    await _speechService.startListening(
      onResult: (text) {
        _currentIntentTranscription = text;
        notifyListeners();
      },
    );
  }

  Future<void> stopIntentRecording() async {
    debugPrint('Provider: Stopping intent recording');

    // Stop both recording and speech recognition
    await _speechService.stopListening();
    await _audioRecorder.stopRecording();

    // Get final transcription
    _currentIntentTranscription = _speechService.lastWords;

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

  void skipIntent() {
    debugPrint('Provider: Skipping intent');
    _saveNote();
    _state = RecordingState.complete;
    notifyListeners();
    _resetAfterDelay();
  }

  void saveNoteWithIntent(String intent) {
    debugPrint('Provider: Saving note with typed intent: $intent');
    _saveNote(intentDescription: intent);
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
      );

      try {
        // Save to database
        await _databaseService.insertNote(note);

        // Add to local list
        _notes.insert(0, note); // Insert at beginning for newest first

        debugPrint('Provider: Note saved to database with${intentDescription != null ? '' : 'out'} intent');
        debugPrint('Audio file saved at: ${note.audioPath}');
        if (note.latitude != null) {
          debugPrint('Location: ${note.locationName}');
        }

        notifyListeners();
      } catch (e) {
        debugPrint('Error saving note to database: $e');
        _errorMessage = 'Failed to save note';
      }
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
    Future.delayed(const Duration(seconds: 2)).then((_) {
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
