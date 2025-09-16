import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  static const platform = MethodChannel('com.parachute.audio/background');
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

      // Start recording with optimized settings for long recordings
      // Lower bitrate and sample rate reduce file size and memory usage
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,  // Reduced from 128000 - still good quality for voice
          sampleRate: 22050,  // Reduced from 44100 - adequate for voice recording
          numChannels: 1,  // Mono recording uses half the memory/storage
          // iOS specific: ensures recording continues in background
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: path, // On web, this path is ignored but still required
      );

      _isRecording = true;
      _currentPath = path;

      // Start iOS background task for long recordings
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await platform.invokeMethod('startBackgroundTask');
          debugPrint('Background task started for long recording');
        } catch (e) {
          debugPrint('Failed to start background task: $e');
        }
      }

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

      // End iOS background task
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await platform.invokeMethod('endBackgroundTask');
          debugPrint('Background task ended');
        } catch (e) {
          debugPrint('Failed to end background task: $e');
        }
      }

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
