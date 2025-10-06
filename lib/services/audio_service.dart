import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:parachute/models/recording.dart';
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
      print('AudioService already initialized');
      return;
    }

    try {
      print('Initializing AudioService...');

      // Check if recording is supported
      if (await _recorder.hasPermission()) {
        print('Recording permissions granted');
      } else {
        print('Recording permissions not granted');
      }

      _isInitialized = true;
      print('AudioService initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing AudioService: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    _durationTimer?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    _isInitialized = false;
    print('AudioService disposed');
  }

  Future<bool> requestPermissions() async {
    try {
      // Use the record package's built-in permission handling
      // which works across all platforms including macOS
      final hasPermission = await _recorder.hasPermission();
      print('Recording permission check: $hasPermission');

      if (!hasPermission) {
        print('Microphone permission denied');

        // On Android, try to open settings if permission is denied
        if (Platform.isAndroid) {
          try {
            final micPermission = await Permission.microphone.status;
            if (micPermission.isPermanentlyDenied) {
              print('Opening app settings for permission...');
              await openAppSettings();
            }
          } catch (e) {
            print('Could not open settings: $e');
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
            print('Android Notification permission: $notificationPermission');
          }
        } catch (e) {
          print('Could not request notification permission: $e');
          // Not critical, continue anyway
        }
      }

      return true;
    } catch (e) {
      print('Error requesting permissions: $e');
      // If there's an error but the recorder says it has permission, trust it
      try {
        return await _recorder.hasPermission();
      } catch (e2) {
        print('Fallback permission check failed: $e2');
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
      print('Generated recording path: $path');
      return path;
    } catch (e) {
      print('Error getting recording path: $e');
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
    print('startRecording called, current state: $_recordingState');
    if (_recordingState != RecordingState.stopped) {
      print('Cannot start recording: state is $_recordingState');
      return false;
    }

    // Check and request permissions
    final hasPermission = await requestPermissions();
    print('Permission check result: $hasPermission');
    if (!hasPermission) {
      print('Permission denied, cannot start recording');
      return false;
    }

    try {
      // Ensure recorder is properly initialized
      if (!_isInitialized) {
        print('Recorder not initialized, initializing now...');
        await initialize();
      }

      // Check if already recording
      if (await _recorder.isRecording()) {
        print('Recorder is already recording');
        return false;
      }

      // Generate recording ID and path
      print('Generating recording ID...');
      final recordingId = DateTime.now().millisecondsSinceEpoch.toString();
      print('Recording ID: $recordingId');

      print('Getting recording path...');
      _currentRecordingPath = await _getRecordingPath(recordingId);
      print('Will record to: $_currentRecordingPath');

      // Start recording with M4A AAC format (compatible with Whisper API)
      print('Starting recorder...');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
      print('Recorder.start() completed');

      _recordingStartTime = DateTime.now();
      _recordingState = RecordingState.recording;
      _recordingDuration = Duration.zero;
      _pausedDuration = Duration.zero;
      _startDurationTimer();

      print('Recording started successfully');
      return true;
    } catch (e, stackTrace) {
      print('Error starting recording: $e');
      print('Stack trace: $stackTrace');
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
      print('Recording paused');
      return true;
    } catch (e) {
      print('Error pausing recording: $e');
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
      print('Recording resumed');
      return true;
    } catch (e) {
      print('Error resuming recording: $e');
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
          print('Recording stopped and saved: $path (size: ${size / 1024}KB)');
          return path;
        } else {
          print('Recording file not found at: $path');
        }
      }

      print('Recording stopped but file not found');
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      _recordingState = RecordingState.stopped;
      _durationTimer?.cancel();
      return null;
    }
  }

  Future<bool> playRecording(String filePath) async {
    try {
      if (filePath.isEmpty) {
        print('Cannot play: empty file path');
        return false;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        print('File not found: $filePath');
        return false;
      }

      await _player.setFilePath(filePath);
      await _player.play();

      print('Playing recording: $filePath');
      return true;
    } catch (e, stackTrace) {
      print('Error playing recording: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> stopPlayback() async {
    try {
      await _player.stop();
      print('Playback stopped');
      return true;
    } catch (e) {
      print('Error stopping playback: $e');
      return false;
    }
  }

  Future<bool> pausePlayback() async {
    try {
      await _player.pause();
      return true;
    } catch (e) {
      print('Error pausing playback: $e');
      return false;
    }
  }

  Future<bool> resumePlayback() async {
    try {
      await _player.play();
      return true;
    } catch (e) {
      print('Error resuming playback: $e');
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
      print('Error getting recording duration: $e');
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
      print('Error getting file size: $e');
      return 0;
    }
  }

  Future<bool> deleteRecordingFile(String filePath) async {
    try {
      if (filePath.isEmpty) {
        print('Cannot delete: empty file path');
        return false;
      }

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('Deleted recording file: $filePath');
        return true;
      }

      print('File not found for deletion: $filePath');
      return false;
    } catch (e) {
      print('Error deleting recording file: $e');
      return false;
    }
  }
}
