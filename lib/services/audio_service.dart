import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:parachute/services/storage_service.dart';

enum RecordingState {
  stopped,
  recording,
  paused,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final StorageService _storageService = StorageService();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  RecordingState _recordingState = RecordingState.stopped;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  Timer? _durationTimer;
  bool _isInitialized = false;

  RecordingState get recordingState => _recordingState;
  Duration get recordingDuration => _recordingDuration;
  bool get isPlaying => _player.playing;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('AudioService already initialized');
      return;
    }

    try {
      debugPrint('Initializing AudioService...');

      // Check if recording is supported
      if (await _recorder.hasPermission()) {
        debugPrint('Recording permissions granted');
      } else {
        debugPrint('Recording permissions not granted');
      }

      _isInitialized = true;
      debugPrint('AudioService initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Error initializing AudioService: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    _durationTimer?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    _isInitialized = false;
    debugPrint('AudioService disposed');
  }

  Future<bool> requestPermissions() async {
    try {
      // Use the record package's built-in permission handling
      // which works across all platforms including macOS
      final hasPermission = await _recorder.hasPermission();
      debugPrint('Recording permission check: $hasPermission');

      if (!hasPermission) {
        debugPrint('Microphone permission denied');

        // On Android, try to open settings if permission is denied
        if (Platform.isAndroid) {
          try {
            final micPermission = await Permission.microphone.status;
            if (micPermission.isPermanentlyDenied) {
              debugPrint('Opening app settings for permission...');
              await openAppSettings();
            }
          } catch (e) {
            debugPrint('Could not open settings: $e');
          }
        }

        return false;
      }

      // For Android 13+, also check notification permission for background recording
      if (Platform.isAndroid) {
        try {
          if (await Permission.notification.isDenied) {
            final notificationPermission =
                await Permission.notification.request();
            debugPrint('Android Notification permission: $notificationPermission');
          }
        } catch (e) {
          debugPrint('Could not request notification permission: $e');
          // Not critical, continue anyway
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // If there's an error but the recorder says it has permission, trust it
      try {
        return await _recorder.hasPermission();
      } catch (e2) {
        debugPrint('Fallback permission check failed: $e2');
        return false;
      }
    }
  }

  Future<String> _getRecordingPath(String recordingId) async {
    try {
      final syncFolder = await _storageService.getSyncFolderPath();

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Use M4A format for better compatibility (works with Whisper API)
      final path = '$syncFolder/$dateStr-$recordingId.m4a';
      debugPrint('Generated recording path: $path');
      return path;
    } catch (e) {
      debugPrint('Error getting recording path: $e');
      rethrow;
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recordingState == RecordingState.recording &&
          _recordingStartTime != null) {
        _recordingDuration =
            DateTime.now().difference(_recordingStartTime!) - _pausedDuration;
      }
    });
  }

  Future<bool> startRecording() async {
    debugPrint('startRecording called, current state: $_recordingState');
    if (_recordingState != RecordingState.stopped) {
      debugPrint('Cannot start recording: state is $_recordingState');
      return false;
    }

    // Check and request permissions
    final hasPermission = await requestPermissions();
    debugPrint('Permission check result: $hasPermission');
    if (!hasPermission) {
      debugPrint('Permission denied, cannot start recording');
      return false;
    }

    try {
      // Ensure recorder is properly initialized
      if (!_isInitialized) {
        debugPrint('Recorder not initialized, initializing now...');
        await initialize();
      }

      // Check if already recording
      if (await _recorder.isRecording()) {
        debugPrint('Recorder is already recording');
        return false;
      }

      // Generate recording ID and path
      debugPrint('Generating recording ID...');
      final recordingId = DateTime.now().millisecondsSinceEpoch.toString();
      debugPrint('Recording ID: $recordingId');

      debugPrint('Getting recording path...');
      _currentRecordingPath = await _getRecordingPath(recordingId);
      debugPrint('Will record to: $_currentRecordingPath');

      // Start recording with M4A AAC format (compatible with Whisper API)
      debugPrint('Starting recorder...');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
      debugPrint('Recorder.start() completed');

      _recordingStartTime = DateTime.now();
      _recordingState = RecordingState.recording;
      _recordingDuration = Duration.zero;
      _pausedDuration = Duration.zero;
      _startDurationTimer();

      debugPrint('Recording started successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error starting recording: $e');
      debugPrint('Stack trace: $stackTrace');
      _recordingState = RecordingState.stopped;
      _currentRecordingPath = null;
      return false;
    }
  }

  Future<bool> pauseRecording() async {
    if (_recordingState != RecordingState.recording) return false;

    try {
      await _recorder.pause();
      _recordingState = RecordingState.paused;
      _pauseStartTime = DateTime.now();
      _durationTimer?.cancel();
      debugPrint('Recording paused');
      return true;
    } catch (e) {
      debugPrint('Error pausing recording: $e');
      return false;
    }
  }

  Future<bool> resumeRecording() async {
    if (_recordingState != RecordingState.paused) return false;

    try {
      await _recorder.resume();
      _recordingState = RecordingState.recording;

      // Add the paused duration to total paused time
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }

      _startDurationTimer();
      debugPrint('Recording resumed');
      return true;
    } catch (e) {
      debugPrint('Error resuming recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (_recordingState == RecordingState.stopped) return null;

    try {
      _durationTimer?.cancel();

      final path = await _recorder.stop();
      _recordingState = RecordingState.stopped;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pauseStartTime = null;
      _pausedDuration = Duration.zero;

      // Verify file exists
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('Recording stopped and saved: $path (size: ${size / 1024}KB)');
          return path;
        } else {
          debugPrint('Recording file not found at: $path');
        }
      }

      debugPrint('Recording stopped but file not found');
      return null;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _recordingState = RecordingState.stopped;
      _durationTimer?.cancel();
      return null;
    }
  }

  Future<bool> playRecording(String filePath) async {
    try {
      if (filePath.isEmpty) {
        debugPrint('Cannot play: empty file path');
        return false;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File not found: $filePath');
        return false;
      }

      await _player.setFilePath(filePath);
      await _player.play();

      debugPrint('Playing recording: $filePath');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error playing recording: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> stopPlayback() async {
    try {
      await _player.stop();
      debugPrint('Playback stopped');
      return true;
    } catch (e) {
      debugPrint('Error stopping playback: $e');
      return false;
    }
  }

  Future<bool> pausePlayback() async {
    try {
      await _player.pause();
      return true;
    } catch (e) {
      debugPrint('Error pausing playback: $e');
      return false;
    }
  }

  Future<bool> resumePlayback() async {
    try {
      await _player.play();
      return true;
    } catch (e) {
      debugPrint('Error resuming playback: $e');
      return false;
    }
  }

  Future<Duration?> getRecordingDuration(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      await _player.setFilePath(filePath);
      return _player.duration;
    } catch (e) {
      debugPrint('Error getting recording duration: $e');
      return null;
    }
  }

  Future<double> getFileSizeKB(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        return size / 1024;
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return 0;
    }
  }

  Future<bool> deleteRecordingFile(String filePath) async {
    try {
      if (filePath.isEmpty) {
        debugPrint('Cannot delete: empty file path');
        return false;
      }

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted recording file: $filePath');
        return true;
      }

      debugPrint('File not found for deletion: $filePath');
      return false;
    } catch (e) {
      debugPrint('Error deleting recording file: $e');
      return false;
    }
  }
}
