import 'package:flutter_test/flutter_test.dart';
import 'package:parachute/services/storage_service.dart';
import 'package:parachute/models/recording.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService Tests', () {
    late StorageService storageService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      storageService = StorageService();
    });

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Service initializes with sample recordings on first launch',
        () async {
      SharedPreferences.setMockInitialValues({});

      final recordings = await storageService.getRecordings();

      // Should have sample recordings on first launch
      expect(recordings.length, greaterThan(0));
      expect(recordings.first.title, isNotEmpty);
    });

    test('Service returns empty list after clearing', () async {
      SharedPreferences.setMockInitialValues({'has_initialized': true});

      final recordings = await storageService.getRecordings();
      expect(recordings, isEmpty);
    });

    group('CRUD Operations', () {
      final testRecording = Recording(
        id: 'test_123',
        title: 'Test Recording',
        filePath: '/test/path/recording.aac',
        timestamp: DateTime.now(),
        duration: const Duration(minutes: 2, seconds: 30),
        tags: ['test', 'unit-test'],
        transcript: 'This is a test transcript',
        fileSizeKB: 500,
      );

      setUp(() async {
        // Start with empty recordings
        SharedPreferences.setMockInitialValues({'has_initialized': true});
      });

      test('Save recording adds to storage', () async {
        final success = await storageService.saveRecording(testRecording);
        expect(success, true);

        final recordings = await storageService.getRecordings();
        expect(recordings.length, 1);
        expect(recordings.first.id, testRecording.id);
        expect(recordings.first.title, testRecording.title);
      });

      test('Get recording by ID returns correct recording', () async {
        await storageService.saveRecording(testRecording);

        final retrieved = await storageService.getRecording(testRecording.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, testRecording.id);
        expect(retrieved.title, testRecording.title);
      });

      test('Get non-existent recording returns null', () async {
        final retrieved = await storageService.getRecording('non_existent_id');
        expect(retrieved, isNull);
      });

      test('Update recording modifies existing recording', () async {
        await storageService.saveRecording(testRecording);

        final updatedRecording = Recording(
          id: testRecording.id,
          title: 'Updated Title',
          filePath: testRecording.filePath,
          timestamp: testRecording.timestamp,
          duration: testRecording.duration,
          tags: ['updated', 'modified'],
          transcript: 'Updated transcript',
          fileSizeKB: testRecording.fileSizeKB,
        );

        final success = await storageService.updateRecording(updatedRecording);
        expect(success, true);

        final retrieved = await storageService.getRecording(testRecording.id);
        expect(retrieved!.title, 'Updated Title');
        expect(retrieved.tags, ['updated', 'modified']);
        expect(retrieved.transcript, 'Updated transcript');
      });

      test('Update non-existent recording returns false', () async {
        final nonExistentRecording = Recording(
          id: 'non_existent',
          title: 'Does not exist',
          filePath: '/fake/path.aac',
          timestamp: DateTime.now(),
          duration: Duration.zero,
          tags: [],
          transcript: '',
          fileSizeKB: 0,
        );

        final success =
            await storageService.updateRecording(nonExistentRecording);
        expect(success, false);
      });

      test('Delete recording removes from storage', () async {
        await storageService.saveRecording(testRecording);

        final recordings = await storageService.getRecordings();
        expect(recordings.length, 1);

        final success = await storageService.deleteRecording(testRecording.id);
        expect(success, true);

        final afterDelete = await storageService.getRecordings();
        expect(afterDelete, isEmpty);
      });

      test('Delete non-existent recording handles gracefully', () async {
        final success = await storageService.deleteRecording('non_existent_id');
        expect(success, false);
      });
    });

    group('Multiple Recordings', () {
      test('Recordings are sorted by timestamp (newest first)', () async {
        SharedPreferences.setMockInitialValues({'has_initialized': true});

        final now = DateTime.now();
        final recordings = [
          Recording(
            id: 'old',
            title: 'Old Recording',
            filePath: '/old.aac',
            timestamp: now.subtract(const Duration(days: 2)),
            duration: Duration.zero,
            tags: [],
            transcript: '',
            fileSizeKB: 0,
          ),
          Recording(
            id: 'new',
            title: 'New Recording',
            filePath: '/new.aac',
            timestamp: now,
            duration: Duration.zero,
            tags: [],
            transcript: '',
            fileSizeKB: 0,
          ),
          Recording(
            id: 'middle',
            title: 'Middle Recording',
            filePath: '/middle.aac',
            timestamp: now.subtract(const Duration(days: 1)),
            duration: Duration.zero,
            tags: [],
            transcript: '',
            fileSizeKB: 0,
          ),
        ];

        for (final recording in recordings) {
          await storageService.saveRecording(recording);
        }

        final retrieved = await storageService.getRecordings();
        expect(retrieved.length, 3);
        expect(retrieved[0].id, 'new');
        expect(retrieved[1].id, 'middle');
        expect(retrieved[2].id, 'old');
      });
    });

    test('Clear all recordings removes everything', () async {
      SharedPreferences.setMockInitialValues({'has_initialized': true});

      // Add some recordings
      for (int i = 0; i < 5; i++) {
        await storageService.saveRecording(
          Recording(
            id: 'recording_$i',
            title: 'Recording $i',
            filePath: '/path_$i.aac',
            timestamp: DateTime.now(),
            duration: Duration.zero,
            tags: [],
            transcript: '',
            fileSizeKB: 0,
          ),
        );
      }

      final beforeClear = await storageService.getRecordings();
      expect(beforeClear.length, 5);

      await storageService.clearAllRecordings();

      final afterClear = await storageService.getRecordings();
      expect(afterClear, isEmpty);
    });
  });
}
