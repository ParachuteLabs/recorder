# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Parachute** is a cross-platform Flutter voice recording application designed for seamless background operation and crystal-clear audio capture. The app is currently in prototype phase with placeholder implementations for audio recording functionality.

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
flutter run -d chrome

# Build for release
flutter build apk
flutter build ios
flutter build web
```

### Code Quality
```bash
# Run static analysis
flutter analyze

# Run tests (when available)
flutter test

# Format code
dart format lib/
```

### Icons Generation
```bash
# Generate app icons from assets/icons/dreamflow_icon.jpg
flutter pub run flutter_launcher_icons
```

## Architecture

### Core Services (Singleton Pattern)

1. **AudioService** (`lib/services/audio_service.dart`): Handles all audio recording operations. Currently uses placeholder implementations with TODO comments for actual audio package integrations (`flutter_sound`, `permission_handler`).

2. **StorageService** (`lib/services/storage_service.dart`): Manages recording persistence. Currently uses in-memory storage with TODO comments for `shared_preferences` integration.

### Data Model

- **Recording** (`lib/models/recording.dart`): Core data model with JSON serialization, containing fields for id, title, filePath, timestamp, duration, tags, transcript, and file size.

### Screen Flow

1. **HomeScreen** → Lists all recordings, entry point to recording
2. **RecordingScreen** → Active recording interface with pause/resume/stop controls
3. **PostRecordingScreen** → Post-recording metadata entry (title, tags)
4. **RecordingDetailScreen** → View/edit individual recording details

### State Management

The app uses StatefulWidget for local state management. Services use singleton pattern for app-wide state sharing.

### Package Dependencies

Current dependencies with pending integrations:
- `flutter_sound`: Audio recording/playback (TODO: uncommented in services)
- `permission_handler`: Microphone permissions (TODO: uncommented)
- `path_provider`: File system access (TODO: uncommented)
- `shared_preferences`: Persistent storage (TODO: uncommented)
- `google_fonts`: Typography styling (active)
- `cupertino_icons`: iOS-style icons (active)

## Important Notes

- The app name is "parachute" (lowercase in package name)
- Audio functionality currently returns mock data - actual recording packages need to be integrated
- Sample recordings are automatically created on first launch for demo purposes
- Using Flutter 3.35.3 with Dart 3.9.2
- Linting configured via `flutter_lints` package