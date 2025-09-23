import 'package:flutter_test/flutter_test.dart';
import 'package:parachute/services/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  group('AudioService Tests', () {
    late AudioService audioService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      audioService = AudioService();
      await audioService.initialize();
    });

    tearDownAll(() async {
      await audioService.dispose();
    });

    test('Service initializes correctly', () {
      expect(audioService.recordingState, RecordingState.stopped);
      expect(audioService.recordingDuration, Duration.zero);
      expect(audioService.isPlaying, false);
    });

    test('Request permissions returns a boolean', () async {
      // This will return true in tests as we're mocking the platform
      final result = await audioService.requestPermissions();
      expect(result, isA<bool>());
    });

    group('Recording Operations', () {
      String? recordingPath;

      tearDown(() async {
        // Clean up any test recordings
        if (recordingPath != null) {
          await audioService.deleteRecordingFile(recordingPath!);
          recordingPath = null;
        }
      });

      test('Start recording returns true when successful', () async {
        // Skip this test if running on CI or without proper setup
        if (!Platform.environment.containsKey('CI')) {
          final success = await audioService.startRecording();

          if (success) {
            expect(audioService.recordingState, RecordingState.recording);
            recordingPath = await audioService.stopRecording();
          }
        }
      }, skip: 'Requires device/emulator with microphone');

      test('Cannot start recording when already recording', () async {
        if (!Platform.environment.containsKey('CI')) {
          await audioService.startRecording();
          final secondStart = await audioService.startRecording();
          expect(secondStart, false);

          recordingPath = await audioService.stopRecording();
        }
      }, skip: 'Requires device/emulator with microphone');

      test('Pause and resume recording works correctly', () async {
        if (!Platform.environment.containsKey('CI')) {
          await audioService.startRecording();

          // Test pause
          final pauseSuccess = await audioService.pauseRecording();
          expect(pauseSuccess, true);
          expect(audioService.recordingState, RecordingState.paused);

          // Test resume
          final resumeSuccess = await audioService.resumeRecording();
          expect(resumeSuccess, true);
          expect(audioService.recordingState, RecordingState.recording);

          recordingPath = await audioService.stopRecording();
        }
      }, skip: 'Requires device/emulator with microphone');

      test('Stop recording returns file path', () async {
        if (!Platform.environment.containsKey('CI')) {
          await audioService.startRecording();
          await Future.delayed(const Duration(seconds: 1));

          recordingPath = await audioService.stopRecording();
          expect(recordingPath, isNotNull);
          expect(recordingPath, contains('recording_'));
          expect(recordingPath, endsWith('.aac'));
        }
      }, skip: 'Requires device/emulator with microphone');
    });

    group('File Operations', () {
      test('Get file size returns valid size', () async {
        // Create a mock file path for testing
        final size = await audioService.getFileSizeKB('/nonexistent/file.aac');
        expect(size, 0);
      });

      test('Delete non-existent file returns false', () async {
        final result =
            await audioService.deleteRecordingFile('/nonexistent/file.aac');
        expect(result, false);
      });
    });

    group('Playback Operations', () {
      test('Play non-existent file returns false', () async {
        final success =
            await audioService.playRecording('/nonexistent/file.aac');
        expect(success, false);
      });

      test('Stop playback when not playing returns true', () async {
        final success = await audioService.stopPlayback();
        expect(success, true);
      });

      test('Pause and resume playback', () async {
        // These should not throw even when nothing is playing
        final pauseSuccess = await audioService.pausePlayback();
        expect(pauseSuccess, true);

        final resumeSuccess = await audioService.resumePlayback();
        expect(resumeSuccess, true);
      });
    });

    group('Duration Operations', () {
      test('Get duration of non-existent file returns null', () async {
        final duration =
            await audioService.getRecordingDuration('/nonexistent/file.aac');
        expect(duration, isNull);
      });
    });
  });
}
