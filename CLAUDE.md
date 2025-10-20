# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Parachute** is a cross-platform Flutter voice recording application with file-based syncing, crystal-clear audio capture, and AI-powered transcription via OpenAI Whisper API.

## Development Commands

### Build and Run

```bash
# Get dependencies
flutter pub get

# Run on available device/simulator
flutter run

# Run on specific platform
flutter run -d ios
flutter run -d android

# Build for release
flutter build apk
flutter build ios
```

### Code Quality

```bash
# Run static analysis (0 errors expected)
flutter analyze

# Run tests (27 tests)
flutter test

# Run specific test suites
flutter test test/models/
flutter test test/utils/
flutter test test/repositories/

# Format code
dart format lib/
```

## Architecture

The app follows **Flutter 2025 best practices** with clean architecture:

### Layered Structure

```
Domain Layer
  └── Models (lib/models/recording.dart)
  └── Validators (lib/utils/validators.dart)

Data Layer
  └── Repositories (lib/repositories/recording_repository.dart)
  └── Services (lib/services/)

State Management
  └── Riverpod Providers (lib/providers/service_providers.dart)

Presentation Layer
  └── Screens (lib/screens/)
  └── Widgets (lib/widgets/)
```

### Core Services

All services use **Riverpod dependency injection** (no singletons):

1. **AudioService** (`lib/services/audio_service.dart`)
   - Audio recording/playback using `record` and `just_audio` packages
   - Auto-initialized via `audioServiceProvider`
   - Proper disposal handling

2. **StorageService** (`lib/services/storage_service.dart`)
   - File-based storage with markdown metadata
   - Syncs via user-configurable folder (iCloud, Syncthing, etc.)
   - Auto-initialized via `storageServiceProvider`

3. **WhisperService** (`lib/services/whisper_service.dart`)
   - OpenAI Whisper API integration for cloud transcription
   - API key management via StorageService
   - Accessed via `whisperServiceProvider`

4. **WhisperLocalService** (`lib/services/whisper_local_service.dart`)
   - Local on-device transcription using Whisper models
   - Offline, private, and free transcription
   - Progress tracking with callbacks
   - Accessed via `whisperLocalServiceProvider`

5. **WhisperModelManager** (`lib/services/whisper_model_manager.dart`)
   - Manages Whisper model downloads and lifecycle
   - Tracks download progress and storage usage
   - Accessed via `whisperModelManagerProvider`

6. **RecordingRepository** (`lib/repositories/recording_repository.dart`)
   - Repository pattern for data access
   - Clean CRUD API
   - Accessed via `recordingRepositoryProvider`

### State Management

- **Riverpod** for dependency injection and state management
- Screens extend `ConsumerStatefulWidget`
- Services injected via `ref.read(serviceProvider)`
- No singleton pattern - all dependencies managed by Riverpod

### Data Model

- **Recording** (`lib/models/recording.dart`)
  - Validated model with assertions
  - JSON serialization with null safety
  - Computed properties for formatting

### Screen Flow

1. **HomeScreen** → Lists recordings, refreshes on resume
2. **RecordingScreen** → Active recording with pause/resume/stop
3. **PostRecordingScreen** → Add title, tags, transcribe
4. **RecordingDetailScreen** → View/edit/delete recordings
5. **SettingsScreen** → Configure API key and sync folder

### Package Dependencies

**Active packages:**

- `flutter_riverpod ^2.6.1` - State management
- `record ^6.1.2` - Audio recording
- `just_audio ^0.9.42` - Audio playback
- `path_provider ^2.0.0` - File system access
- `shared_preferences ^2.0.0` - Settings persistence
- `http ^1.2.0` - Whisper API calls
- `whisper_ggml ^1.7.0` - Local Whisper transcription
- `google_fonts ^6.1.0` - Typography

**Dev packages:**

- `flutter_lints ^6.0.0` - Comprehensive linting
- `build_runner` & `riverpod_generator` - Code generation (future)

## Testing

**27 tests** covering:

- Recording model (validation, serialization)
- Input validators (title, API key, tags)
- Repository pattern

Run tests:

```bash
flutter test
```

## Transcription

The app supports **two transcription modes**:

### 1. OpenAI API (Cloud-based)

- Uses OpenAI's Whisper API
- Requires internet connection and API key
- Cost: ~$0.006 per minute
- Best quality and accuracy
- Configure API key in Settings

### 2. Local (On-device)

- Uses local Whisper models via `whisper_ggml`
- Completely offline and private
- Free (no API costs)
- Download models in Settings
- Available models:
  - **tiny** (75 MB) - Fast, good for real-time
  - **base** (142 MB) - Balanced speed and accuracy (recommended)
  - **small** (466 MB) - Better accuracy, slower
  - **medium** (1.5 GB) - High accuracy, much slower
  - **large** (2.9 GB) - Best quality, very slow

**Features**:

- Transcription mode selector (API vs Local)
- Auto-transcribe toggle (automatic transcription after recording)
- Progress tracking for local transcription
- Model download management with progress indicators
- Storage usage tracking

## Important Notes

- App uses **Riverpod** - access services via `ref.read(serviceProvider)`
- Recordings stored as `.m4a` (audio) + `.md` (metadata)
- Sample recordings created on first launch
- Transcription works offline with local models or via OpenAI API
- File-based sync for cross-device support
- Global error boundaries configured in main.dart
- Production-ready with comprehensive validation

## Omi Device Integration

The app supports integration with Omi wearable devices for voice recording via Bluetooth Low Energy (BLE).

### Firmware

**Location**: `firmware/`

The firmware is built on Zephyr RTOS for nRF52840 chips (Seeed XIAO nRF52840 Sense). Key features:

- Smart button controls (single/double/triple tap)
- Audio streaming over BLE (PCM8/16, Opus, μLaw codecs)
- LED status indicators (red=recording, blue=connected, green=charging)
- Over-the-air (OTA) firmware updates

**Current Version**: 2.0.12

**Building Firmware**:

```bash
cd firmware
./scripts/build-docker.sh              # Build only
./scripts/build-and-integrate.sh       # Build + copy to assets
```

See `firmware/README.md` for detailed firmware development guide.

### BLE Integration

**Services** (`lib/services/omi/`):

- `omi_bluetooth_service.dart` - Device scanning and connection
- `omi_connection.dart` - BLE GATT communication
- `omi_capture_service.dart` - Recording orchestration

**Providers** (`lib/providers/omi_providers.dart`):

- `omiBluetoothServiceProvider` - BLE service
- `omiCaptureServiceProvider` - Capture service
- `connectedOmiDeviceProvider` - Device state
- `lastPairedDeviceProvider` - Persistent pairing

**Button Tap Behavior**:

- Single tap to stop: Standard recording
- Double tap to stop: AI Query (future feature)
- Triple tap to stop: Knowledge Capture (future feature)

**Recording Flow**:

1. Device button pressed → BLE event to app
2. App starts capture service → Listens for audio stream
3. Device streams audio packets → App assembles into WAV file
4. Device button released (with tap count) → App stops recording
5. Recording saved with source=omiDevice, deviceId, buttonTapCount

### Platform Support

- **iOS/Android**: Full BLE support
- **macOS**: Gracefully degrades (shows "not supported" message)

Platform checks via `PlatformUtils.shouldShowOmiFeatures`

## Code Style

- Use `debugPrint()` not `print()`
- Use `withValues(alpha:)` not `withOpacity()`
- Always check `mounted` before using `BuildContext` after async
- Input validation required for user-facing fields
- Prefer `ConsumerStatefulWidget` for screens
