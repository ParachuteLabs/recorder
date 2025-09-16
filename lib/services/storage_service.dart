import 'dart:convert';
// TODO: Uncomment when packages are available
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:parachute/models/recording.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _recordingsKey = 'recordings';
  static final List<Recording> _recordings = []; // In-memory storage for demo

  Future<List<Recording>> getRecordings() async {
    // TODO: Use SharedPreferences when available
    // final prefs = await SharedPreferences.getInstance();
    // final recordingsJson = prefs.getStringList(_recordingsKey) ?? [];
    
    // return recordingsJson
    //     .map((json) => Recording.fromJson(jsonDecode(json)))
    //     .toList()
    //   ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Using in-memory storage for demo
    _recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List<Recording>.from(_recordings);
  }

  Future<bool> saveRecording(Recording recording) async {
    try {
      // TODO: Use SharedPreferences when available
      // final prefs = await SharedPreferences.getInstance();
      // final recordings = await getRecordings();
      // recordings.add(recording);
      
      // final recordingsJson = recordings
      //     .map((recording) => jsonEncode(recording.toJson()))
      //     .toList();
      
      // return await prefs.setStringList(_recordingsKey, recordingsJson);
      
      // Using in-memory storage for demo
      _recordings.add(recording);
      return true;
    } catch (e) {
      print('Error saving recording: $e');
      return false;
    }
  }

  Future<bool> updateRecording(Recording updatedRecording) async {
    try {
      // TODO: Use SharedPreferences when available
      // final prefs = await SharedPreferences.getInstance();
      // final recordings = await getRecordings();
      
      // final index = recordings.indexWhere((r) => r.id == updatedRecording.id);
      // if (index == -1) return false;
      
      // recordings[index] = updatedRecording;
      
      // final recordingsJson = recordings
      //     .map((recording) => jsonEncode(recording.toJson()))
      //     .toList();
      
      // return await prefs.setStringList(_recordingsKey, recordingsJson);
      
      // Using in-memory storage for demo
      final index = _recordings.indexWhere((r) => r.id == updatedRecording.id);
      if (index == -1) return false;
      _recordings[index] = updatedRecording;
      return true;
    } catch (e) {
      print('Error updating recording: $e');
      return false;
    }
  }

  Future<bool> deleteRecording(String recordingId) async {
    try {
      // TODO: Use SharedPreferences when available
      // final prefs = await SharedPreferences.getInstance();
      // final recordings = await getRecordings();
      
      // recordings.removeWhere((r) => r.id == recordingId);
      
      // final recordingsJson = recordings
      //     .map((recording) => jsonEncode(recording.toJson()))
      //     .toList();
      
      // return await prefs.setStringList(_recordingsKey, recordingsJson);
      
      // Using in-memory storage for demo
      _recordings.removeWhere((r) => r.id == recordingId);
      return true;
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
}