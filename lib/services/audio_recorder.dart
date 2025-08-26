import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  Future<bool> requestPermission() async {
    // For web platform, permissions are handled differently
    if (kIsWeb) {
      return true; // Web handles permissions via browser
    }
    
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<String?> startRecording() async {
    try {
      debugPrint('Starting recording...');
      
      // Check permission first
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('No recording permission');
        return null;
      }

      // Generate file path
      String path;
      if (kIsWeb) {
        // Web doesn't use file paths
        path = 'web_recording_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        path = '${directory.path}/recording_$timestamp.m4a';
      }

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path, // On web, this path is ignored but still required
      );

      _isRecording = true;
      _currentPath = path;
      debugPrint('Recording started: $path');
      return path;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      debugPrint('Stopping recording...');
      final path = await _recorder.stop();
      _isRecording = false;
      debugPrint('Recording stopped: $path');
      return path ?? _currentPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}