import 'package:flutter_test/flutter_test.dart';
import 'package:parachute/models/recording.dart';
import 'package:parachute/repositories/recording_repository.dart';
import 'package:parachute/services/storage_service.dart';

void main() {
  group('RecordingRepository', () {
    late RecordingRepository repository;
    late StorageService storageService;

    setUp(() {
      storageService = StorageService();
      repository = RecordingRepository(storageService);
    });

    test('should create repository with storage service', () {
      expect(repository, isNotNull);
    });

    test('should provide clean API for data access', () {
      // Verify that repository exposes the expected methods
      expect(repository.getAllRecordings, isA<Function>());
      expect(repository.getRecordingById, isA<Function>());
      expect(repository.saveRecording, isA<Function>());
      expect(repository.updateRecording, isA<Function>());
      expect(repository.deleteRecording, isA<Function>());
      expect(repository.clearAll, isA<Function>());
    });

    // Note: Full integration tests would require mocking StorageService
    // or using test fixtures. These would be added in a full test suite.
  });
}
