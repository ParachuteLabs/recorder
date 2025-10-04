import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parachute/models/recording.dart';
import 'package:parachute/services/audio_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _recordingsKey = 'recordings';
  static const String _hasInitializedKey = 'has_initialized';
  static const String _openaiApiKeyKey = 'openai_api_key';
  final AudioService _audioService = AudioService();

  Future<List<Recording>> getRecordings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if this is first launch
      final hasInitialized = prefs.getBool(_hasInitializedKey) ?? false;
      if (!hasInitialized) {
        // Create sample recordings for demo on first launch
        await _createSampleRecordings();
        await prefs.setBool(_hasInitializedKey, true);
      }

      final recordingsJson = prefs.getStringList(_recordingsKey) ?? [];

      return recordingsJson
          .map((json) => Recording.fromJson(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      print('Error getting recordings: $e');
      return [];
    }
  }

  Future<bool> saveRecording(Recording recording) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordings = await getRecordings();
      recordings.add(recording);

      final recordingsJson = recordings
          .map((recording) => jsonEncode(recording.toJson()))
          .toList();

      return await prefs.setStringList(_recordingsKey, recordingsJson);
    } catch (e) {
      print('Error saving recording: $e');
      return false;
    }
  }

  Future<bool> updateRecording(Recording updatedRecording) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordings = await getRecordings();

      final index = recordings.indexWhere((r) => r.id == updatedRecording.id);
      if (index == -1) return false;

      recordings[index] = updatedRecording;

      final recordingsJson = recordings
          .map((recording) => jsonEncode(recording.toJson()))
          .toList();

      return await prefs.setStringList(_recordingsKey, recordingsJson);
    } catch (e) {
      print('Error updating recording: $e');
      return false;
    }
  }

  Future<bool> deleteRecording(String recordingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordings = await getRecordings();

      // Find the recording to delete
      final recordingToDelete = recordings.firstWhere(
        (r) => r.id == recordingId,
        orElse: () => throw Exception('Recording not found'),
      );

      // Delete the associated audio file
      await _audioService.deleteRecordingFile(recordingToDelete.filePath);

      // Remove from list
      recordings.removeWhere((r) => r.id == recordingId);

      final recordingsJson = recordings
          .map((recording) => jsonEncode(recording.toJson()))
          .toList();

      return await prefs.setStringList(_recordingsKey, recordingsJson);
    } catch (e) {
      print('Error deleting recording: $e');
      return false;
    }
  }

  Future<Recording?> getRecording(String recordingId) async {
    final recordings = await getRecordings();
    try {
      return recordings.firstWhere((r) => r.id == recordingId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _createSampleRecordings() async {
    // Create sample recordings for demo purposes
    final now = DateTime.now();
    final sampleRecordings = [
      Recording(
        id: 'sample_1',
        title: 'Welcome to Parachute',
        filePath: '',
        timestamp: now.subtract(const Duration(hours: 2)),
        duration: const Duration(minutes: 1, seconds: 30),
        tags: ['welcome', 'tutorial'],
        transcript:
            'Welcome to Parachute, your personal voice recording assistant. '
            'This app helps you capture thoughts, ideas, and important moments with ease.',
        fileSizeKB: 450,
      ),
      Recording(
        id: 'sample_2',
        title: 'Meeting Notes',
        filePath: '',
        timestamp: now.subtract(const Duration(days: 1)),
        duration: const Duration(minutes: 15, seconds: 45),
        tags: ['work', 'meeting', 'project-alpha'],
        transcript: 'Today we discussed the new features for Project Alpha. '
            'Key decisions: 1) Move deadline to next quarter, 2) Add two more developers to the team, '
            '3) Focus on mobile-first approach.',
        fileSizeKB: 2340,
      ),
      Recording(
        id: 'sample_3',
        title: 'Quick Reminder',
        filePath: '',
        timestamp: now.subtract(const Duration(days: 3)),
        duration: const Duration(seconds: 45),
        tags: ['personal', 'reminder'],
        transcript:
            'Remember to call the dentist tomorrow morning to schedule the appointment. '
            'Also, pick up groceries on the way home.',
        fileSizeKB: 180,
      ),
    ];

    final prefs = await SharedPreferences.getInstance();
    final recordingsJson = sampleRecordings
        .map((recording) => jsonEncode(recording.toJson()))
        .toList();
    await prefs.setStringList(_recordingsKey, recordingsJson);
  }

  Future<void> clearAllRecordings() async {
    final recordings = await getRecordings();

    // Delete all audio files
    for (final recording in recordings) {
      if (recording.filePath.isNotEmpty) {
        await _audioService.deleteRecordingFile(recording.filePath);
      }
    }

    // Clear from storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordingsKey);
  }

  // OpenAI API Key Management
  Future<String?> getOpenAIApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_openaiApiKeyKey);
    } catch (e) {
      print('Error getting OpenAI API key: $e');
      return null;
    }
  }

  Future<bool> saveOpenAIApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_openaiApiKeyKey, apiKey.trim());
    } catch (e) {
      print('Error saving OpenAI API key: $e');
      return false;
    }
  }

  Future<bool> deleteOpenAIApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_openaiApiKeyKey);
    } catch (e) {
      print('Error deleting OpenAI API key: $e');
      return false;
    }
  }

  Future<bool> hasOpenAIApiKey() async {
    final apiKey = await getOpenAIApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }
}
