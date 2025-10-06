import 'package:flutter_test/flutter_test.dart';
import 'package:parachute/models/recording.dart';

void main() {
  group('Recording Model', () {
    test('should create a valid recording', () {
      final recording = Recording(
        id: 'test_123',
        title: 'Test Recording',
        filePath: '/path/to/file.m4a',
        timestamp: DateTime(2025, 1, 1),
        duration: const Duration(minutes: 5),
        tags: ['test', 'demo'],
        transcript: 'Test transcript',
        fileSizeKB: 1024.5,
      );

      expect(recording.id, 'test_123');
      expect(recording.title, 'Test Recording');
      expect(recording.duration, const Duration(minutes: 5));
      expect(recording.tags.length, 2);
    });

    test('should format duration correctly', () {
      final recording = Recording(
        id: 'test',
        title: 'Test',
        filePath: '/path',
        timestamp: DateTime.now(),
        duration: const Duration(minutes: 3, seconds: 45),
        tags: [],
        transcript: '',
        fileSizeKB: 0,
      );

      expect(recording.durationString, '03:45');
    });

    test('should format file size in KB', () {
      final recording = Recording(
        id: 'test',
        title: 'Test',
        filePath: '/path',
        timestamp: DateTime.now(),
        duration: Duration.zero,
        tags: [],
        transcript: '',
        fileSizeKB: 500.5,
      );

      expect(recording.formattedSize, '500.5KB');
    });

    test('should format file size in MB', () {
      final recording = Recording(
        id: 'test',
        title: 'Test',
        filePath: '/path',
        timestamp: DateTime.now(),
        duration: Duration.zero,
        tags: [],
        transcript: '',
        fileSizeKB: 2048.0,
      );

      expect(recording.formattedSize, '2.0MB');
    });

    test('should convert to JSON', () {
      final recording = Recording(
        id: 'test_123',
        title: 'Test',
        filePath: '/path',
        timestamp: DateTime(2025, 1, 1, 12, 0),
        duration: const Duration(seconds: 120),
        tags: ['tag1'],
        transcript: 'text',
        fileSizeKB: 100,
      );

      final json = recording.toJson();

      expect(json['id'], 'test_123');
      expect(json['title'], 'Test');
      expect(json['duration'], 120000); // milliseconds
      expect(json['tags'], ['tag1']);
    });

    test('should create from JSON', () {
      final json = {
        'id': 'test_123',
        'title': 'Test Recording',
        'filePath': '/path/to/file',
        'timestamp': '2025-01-01T12:00:00.000',
        'duration': 120000,
        'tags': ['tag1', 'tag2'],
        'transcript': 'Test text',
        'fileSizeKB': 512.0,
      };

      final recording = Recording.fromJson(json);

      expect(recording.id, 'test_123');
      expect(recording.title, 'Test Recording');
      expect(recording.duration, const Duration(seconds: 120));
      expect(recording.tags.length, 2);
    });

    test('should handle invalid JSON gracefully', () {
      final json = {
        'id': null,
        'title': null,
        'filePath': null,
        'timestamp': 'invalid',
        'duration': null,
        'tags': null,
        'transcript': null,
        'fileSizeKB': null,
      };

      // Should throw assertion error because ID would be empty
      expect(() => Recording.fromJson(json), throwsAssertionError);
    });

    test('should assert non-empty ID', () {
      expect(
        () => Recording(
          id: '',
          title: 'Test',
          filePath: '/path',
          timestamp: DateTime.now(),
          duration: Duration.zero,
          tags: [],
          transcript: '',
          fileSizeKB: 0,
        ),
        throwsAssertionError,
      );
    });

    test('should assert non-negative duration', () {
      expect(
        () => Recording(
          id: 'test',
          title: 'Test',
          filePath: '/path',
          timestamp: DateTime.now(),
          duration: const Duration(seconds: -1),
          tags: [],
          transcript: '',
          fileSizeKB: 0,
        ),
        throwsAssertionError,
      );
    });
  });
}
