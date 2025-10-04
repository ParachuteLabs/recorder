import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:parachute/models/recording.dart';

enum RecordingState {
  stopped,
  recording,
  paused,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  RecordingState _recordingState = RecordingState.stopped;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  StreamSubscription? _recordingDataSubscription;
  StreamSubscription? _playerSubscription;
  bool _isInitialized = false;

  RecordingState get recordingState => _recordingState;
  Duration get recordingDuration => _recordingDuration;
  bool get isPlaying => _player?.isPlaying ?? false;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('AudioService already initialized');
      return;
    }

    try {
      print('Initializing AudioService...');
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      // Open the audio session with proper error handling
      await _recorder!.openRecorder();
      print('Recorder opened successfully');

      await _player!.openPlayer();
      print('Player opened successfully');

      // Set up recording data stream
      _recordingDataSubscription = _recorder!.onProgress!.listen((event) {
        if (_recordingState == RecordingState.recording) {
          _recordingDuration = event.duration ?? Duration.zero;
        }
      });

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
    await _recordingDataSubscription?.cancel();
    await _playerSubscription?.cancel();
    await _recorder?.closeRecorder();
    await _player?.closePlayer();
    _recorder = null;
    _player = null;
    _isInitialized = false;
    print('AudioService disposed');
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final micPermission = await Permission.microphone.request();
        print('iOS Microphone permission: $micPermission');
        return micPermission.isGranted;
      } else if (Platform.isAndroid) {
        // Request microphone permission
        final micPermission = await Permission.microphone.request();
        print('Android Microphone permission: $micPermission');

        if (!micPermission.isGranted) {
          // Check if permission is permanently denied
          if (micPermission.isPermanentlyDenied) {
            print(
                'Microphone permission permanently denied. Opening settings...');
            await openAppSettings();
          }
          return false;
        }

        // For Android 13+ we might need notification permission for background recording
        if (await Permission.notification.isDenied) {
          final notificationPermission =
              await Permission.notification.request();
          print('Android Notification permission: $notificationPermission');
        }

        return true;
      }
      return true; // For other platforms
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<String> _getRecordingPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
        print('Created recordings directory: ${recordingsDir.path}');
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Use M4A format for better compatibility (works with Whisper API)
      final path = '${recordingsDir.path}/recording_$timestamp.m4a';
      print('Generated recording path: $path');
      return path;
    } catch (e) {
      print('Error getting recording path: $e');
      rethrow;
    }
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
      if (!_isInitialized || _recorder == null) {
        print('Recorder not initialized, initializing now...');
        await initialize();
      }

      // Check if recorder is in a valid state
      if (_recorder!.isRecording) {
        print('Recorder is already recording');
        return false;
      }

      // Generate recording path
      _currentRecordingPath = await _getRecordingPath();
      print('Will record to: $_currentRecordingPath');

      // Start recording with M4A AAC format (compatible with Whisper API)
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacMP4,
      );

      _recordingStartTime = DateTime.now();
      _recordingState = RecordingState.recording;
      _recordingDuration = Duration.zero;
      _pausedDuration = Duration.zero;

      print('Recording started successfully');
      return true;
    } catch (e, stackTrace) {
      print('Error starting recording: $e');
      print('Stack trace: $stackTrace');

      // Reset state on error
      _recordingState = RecordingState.stopped;
      _currentRecordingPath = null;

      // Try to reinitialize for next attempt
      try {
        await dispose();
        await initialize();
      } catch (reinitError) {
        print('Error reinitializing after failure: $reinitError');
      }

      return false;
    }
  }

  Future<bool> pauseRecording() async {
    if (_recordingState != RecordingState.recording) return false;

    try {
      await _recorder!.pauseRecorder();
      _recordingState = RecordingState.paused;
      _pauseStartTime = DateTime.now();
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
      await _recorder!.resumeRecorder();
      _recordingState = RecordingState.recording;

      // Add the paused duration to total paused time
      if (_pauseStartTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }

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
      await _recorder!.stopRecorder();
      _recordingState = RecordingState.stopped;

      final path = _currentRecordingPath;
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

      // Ensure player is initialized
      if (_player == null || !_isInitialized) {
        print('Player not initialized, initializing now...');
        _player = FlutterSoundPlayer();
        await _player!.openPlayer();
      }

      await _player!.startPlayer(
        fromURI: filePath,
        codec: Codec.aacMP4,
        whenFinished: () {
          print('Playback finished');
        },
      );

      print('Playing recording: $filePath');
      return true;
    } catch (e, stackTrace) {
      print('Error playing recording: $e');
      print('Stack trace: $stackTrace');

      // Try to reinitialize player for next attempt
      try {
        _player = FlutterSoundPlayer();
        await _player!.openPlayer();
      } catch (reinitError) {
        print('Error reinitializing player: $reinitError');
      }

      return false;
    }
  }

  Future<bool> stopPlayback() async {
    try {
      await _player!.stopPlayer();
      print('Playback stopped');
      return true;
    } catch (e) {
      print('Error stopping playback: $e');
      return false;
    }
  }

  Future<bool> pausePlayback() async {
    try {
      await _player!.pausePlayer();
      return true;
    } catch (e) {
      print('Error pausing playback: $e');
      return false;
    }
  }

  Future<bool> resumePlayback() async {
    try {
      await _player!.resumePlayer();
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

      // For now, return null as flutter_sound v9 doesn't have a direct duration method
      // The actual duration is captured during recording
      return null;
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
