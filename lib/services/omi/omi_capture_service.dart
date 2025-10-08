import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:parachute/models/recording.dart';
import 'package:parachute/services/omi/models.dart';
import 'package:parachute/services/omi/omi_bluetooth_service.dart';
import 'package:parachute/services/storage_service.dart';
import 'package:parachute/utils/audio/wav_bytes_util.dart';

/// Service for capturing audio recordings from Omi device
///
/// Handles:
/// - Button event listening
/// - Audio stream capture
/// - WAV file generation
/// - Recording persistence
/// - Background recording support
class OmiCaptureService {
  final OmiBluetoothService bluetoothService;
  final StorageService storageService;

  WavBytesUtil? _wavBytesUtil;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _buttonSubscription;

  bool _isRecording = false;
  DateTime? _recordingStartTime;
  int? _currentButtonTapCount;

  // Callbacks for UI updates
  Function(bool isRecording)? onRecordingStateChanged;
  Function(String message)? onStatusMessage;

  OmiCaptureService({
    required this.bluetoothService,
    required this.storageService,
  });

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get current recording duration
  Duration? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Start listening for button events from device
  Future<void> startListening() async {
    debugPrint('[OmiCaptureService] Starting button listener');

    final connection = bluetoothService.activeConnection;
    if (connection == null) {
      debugPrint('[OmiCaptureService] No active connection');
      return;
    }

    try {
      _buttonSubscription = await connection.getBleButtonListener(
        onButtonReceived: _onButtonEvent,
      );

      if (_buttonSubscription != null) {
        debugPrint('[OmiCaptureService] Button listener started');
      } else {
        debugPrint('[OmiCaptureService] Failed to start button listener');
      }
    } catch (e) {
      debugPrint('[OmiCaptureService] Error starting button listener: $e');
    }
  }

  /// Stop listening for button events
  Future<void> stopListening() async {
    debugPrint('[OmiCaptureService] Stopping button listener');

    await _buttonSubscription?.cancel();
    _buttonSubscription = null;

    // If recording, stop it
    if (_isRecording) {
      await stopRecording();
    }
  }

  /// Handle button event from device
  void _onButtonEvent(List<int> data) {
    if (data.isEmpty) return;

    final buttonCode = data[0];
    final buttonEvent = ButtonEvent.fromCode(buttonCode);

    debugPrint(
        '[OmiCaptureService] Button event: $buttonEvent (code: $buttonCode)');

    if (buttonEvent == ButtonEvent.unknown) {
      debugPrint('[OmiCaptureService] Unknown button event: $buttonCode');
      return;
    }

    // Toggle recording on button press
    if (_isRecording) {
      // Stop recording with tap count
      _stopRecordingWithTapCount(buttonEvent.toCode());
    } else {
      // Start recording
      _startRecordingWithTapCount(buttonEvent.toCode());
    }
  }

  /// Start recording from device
  Future<void> _startRecordingWithTapCount(int tapCount) async {
    if (_isRecording) {
      debugPrint('[OmiCaptureService] Already recording');
      return;
    }

    debugPrint('[OmiCaptureService] Starting recording (tap count: $tapCount)');
    _currentButtonTapCount = tapCount;

    final connection = bluetoothService.activeConnection;
    if (connection == null) {
      debugPrint('[OmiCaptureService] No active connection');
      onStatusMessage?.call('Device not connected');
      return;
    }

    try {
      // Get audio codec from device
      final codec = await connection.getAudioCodec();
      debugPrint('[OmiCaptureService] Audio codec: $codec');

      // Initialize WAV builder
      _wavBytesUtil = WavBytesUtil(codec: codec);

      // Start audio stream
      _audioSubscription = await connection.getBleAudioBytesListener(
        onAudioBytesReceived: _onAudioData,
      );

      if (_audioSubscription == null) {
        debugPrint('[OmiCaptureService] Failed to start audio stream');
        onStatusMessage?.call('Failed to start audio stream');
        _wavBytesUtil = null;
        return;
      }

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      onRecordingStateChanged?.call(true);
      onStatusMessage?.call('Recording started');

      debugPrint('[OmiCaptureService] Recording started successfully');
    } catch (e) {
      debugPrint('[OmiCaptureService] Error starting recording: $e');
      onStatusMessage?.call('Error starting recording: $e');
      _cleanup();
    }
  }

  /// Receive audio data from device
  void _onAudioData(List<int> data) {
    if (!_isRecording || _wavBytesUtil == null) return;

    // Store audio packet
    _wavBytesUtil!.storeFramePacket(data);
  }

  /// Stop recording and save
  Future<void> _stopRecordingWithTapCount(int tapCount) async {
    if (!_isRecording) {
      debugPrint('[OmiCaptureService] Not recording');
      return;
    }

    debugPrint('[OmiCaptureService] Stopping recording (tap count: $tapCount)');

    try {
      // Stop audio stream
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      // Build WAV file
      if (_wavBytesUtil == null || !_wavBytesUtil!.hasFrames) {
        debugPrint('[OmiCaptureService] No audio data captured');
        onStatusMessage?.call('No audio data captured');
        _cleanup();
        return;
      }

      final wavBytes = _wavBytesUtil!.buildWavFile();
      final duration = _wavBytesUtil!.duration;

      debugPrint(
          '[OmiCaptureService] Built WAV file: ${wavBytes.length} bytes, duration: $duration');

      // Save to file
      final filePath = await _saveWavFile(wavBytes);

      if (filePath == null) {
        debugPrint('[OmiCaptureService] Failed to save WAV file');
        onStatusMessage?.call('Failed to save recording');
        _cleanup();
        return;
      }

      // Create recording metadata
      final recordingId = DateTime.now().millisecondsSinceEpoch.toString();
      final device = bluetoothService.connectedDevice;

      final recording = Recording(
        id: recordingId,
        title: 'Omi Recording',
        filePath: filePath,
        timestamp: _recordingStartTime ?? DateTime.now(),
        duration: duration,
        tags: [],
        transcript: '',
        fileSizeKB: wavBytes.length / 1024,
        source: RecordingSource.omiDevice,
        deviceId: device?.id,
        buttonTapCount: _currentButtonTapCount ?? tapCount,
      );

      // Save recording metadata
      await storageService.saveRecording(recording);

      debugPrint('[OmiCaptureService] Recording saved: ${recording.id}');
      onStatusMessage?.call('Recording saved');

      _cleanup();
    } catch (e) {
      debugPrint('[OmiCaptureService] Error stopping recording: $e');
      onStatusMessage?.call('Error saving recording: $e');
      _cleanup();
    }
  }

  /// Manually start recording (for testing or UI control)
  Future<void> startRecording() async {
    await _startRecordingWithTapCount(1); // Default to single tap
  }

  /// Manually stop recording (for testing or UI control)
  Future<void> stopRecording() async {
    await _stopRecordingWithTapCount(_currentButtonTapCount ?? 1);
  }

  /// Save WAV file to storage
  Future<String?> _saveWavFile(Uint8List wavBytes) async {
    try {
      final syncFolder = await storageService.getSyncFolderPath();

      final now = DateTime.now();
      final dateStr = _formatDate(now);
      final recordingId = now.millisecondsSinceEpoch.toString();

      final fileName = '$dateStr-$recordingId.wav';
      final filePath = '$syncFolder/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(wavBytes);

      debugPrint('[OmiCaptureService] Saved WAV file: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[OmiCaptureService] Error saving WAV file: $e');
      return null;
    }
  }

  /// Format date for filename
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Clean up resources
  void _cleanup() {
    _isRecording = false;
    _recordingStartTime = null;
    _currentButtonTapCount = null;
    _wavBytesUtil = null;

    onRecordingStateChanged?.call(false);
  }

  /// Dispose service
  Future<void> dispose() async {
    await stopListening();
    _cleanup();
  }
}
