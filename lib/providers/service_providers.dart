import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parachute/repositories/recording_repository.dart';
import 'package:parachute/services/audio_service.dart';
import 'package:parachute/services/storage_service.dart';
import 'package:parachute/services/whisper_service.dart';

/// Provider for AudioService
///
/// This manages audio recording and playback functionality.
/// The service is initialized on first access and kept alive for the app lifetime.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  // Initialize the service when first accessed
  service.initialize();

  // Dispose when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for StorageService
///
/// This manages file-based storage for recordings and metadata.
/// The service is initialized on first access.
final storageServiceProvider = Provider<StorageService>((ref) {
  final service = StorageService();
  // Initialize the service when first accessed
  service.initialize();

  return service;
});

/// Provider for WhisperService
///
/// This manages transcription via OpenAI's Whisper API.
final whisperServiceProvider = Provider<WhisperService>((ref) {
  // WhisperService depends on StorageService for API key management
  // Ensure StorageService is initialized first
  ref.watch(storageServiceProvider);
  return WhisperService();
});

/// Provider for RecordingRepository
///
/// This provides data access for recordings following the Repository Pattern.
/// It separates data access logic from business logic.
final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return RecordingRepository(storageService);
});
