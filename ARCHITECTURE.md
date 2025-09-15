# Parachute Audio - Architecture Documentation

## Overview

Parachute Audio is a Flutter-based voice recording application with real-time speech-to-text transcription, location tagging, and intent capture capabilities. The app follows a clean, layered architecture optimized for performance and cross-platform compatibility.

## Architecture Patterns

### Model-View-Provider (MVP)
- **Models**: Data structures with serialization logic (`VoiceNote`)
- **Views**: Reactive UI components using `Consumer<VoiceNoteProvider>`
- **Provider**: Central state management coordinating services and UI updates

### Service Layer Pattern
Each service handles a specific domain responsibility:
- `AudioRecorderService`: Audio recording management
- `SpeechService`: Speech-to-text integration
- `DatabaseService`: SQLite persistence with migration support
- `LocationService`: GPS location capture and formatting

## State Management

### Recording State Machine
```
idle → recordingNote → waitingForIntent → recordingIntent/complete → idle
```

### Provider Architecture
- Single source of truth via `VoiceNoteProvider`
- Reactive updates with `ChangeNotifier`
- Complex workflow management with state machine
- Error handling with user-friendly messages

## Performance Optimizations

### 1. Startup Performance
```dart
// Parallel service initialization
final futures = await Future.wait([
  _speechService.initialize(),
  _audioRecorder.requestPermission(),
  loadNotes(),
]);
```

### 2. UI Responsiveness
- **Pre-built animations**: Dots created once in `initState()` to avoid recreation
- **Immediate state updates**: UI updates before heavy operations complete
- **Optimized rebuilds**: Strategic use of `Consumer` widgets
- **Smart navigation**: Uses `Future.microtask()` for responsive transitions

### 3. Recording Flow Optimizations
- **Duplicate prevention**: `_isStartingRecording` flag prevents multiple starts
- **Parallel operations**: Stop services simultaneously with `Future.wait()`
- **Live transcription**: Streaming updates for real-time feedback
- **Background processing**: Heavy operations moved off main thread

### 4. Animation Performance
```dart
// Pre-build animated dots to prevent frame drops
_animatedDots = _buildAnimatedDots();
```

## Database Schema

### Current Schema (v2)
```sql
CREATE TABLE notes(
  id TEXT PRIMARY KEY,
  audioPath TEXT NOT NULL,
  transcription TEXT NOT NULL,
  intentDescription TEXT,
  createdAt TEXT NOT NULL,
  latitude REAL,
  longitude REAL,
  locationName TEXT,
  durationSeconds INTEGER  -- Added in v2
)
```

### Migration Strategy
- Versioned database with automatic migrations
- Backward-compatible schema changes
- Web platform fallback to in-memory storage

## Key Features

### Core Functionality
- **Voice Recording**: High-quality audio capture with duration tracking
- **Speech-to-Text**: Real-time transcription with live updates
- **Intent Capture**: Secondary recording for note context
- **Location Tagging**: Automatic GPS location capture
- **Cross-Platform**: iOS, Android, and Web support

### User Experience
- **Instant response**: Stop button updates UI immediately
- **Visual feedback**: Animated recording indicators
- **Smart titles**: Auto-generated from first 3 words
- **Scrollable transcripts**: Handle long content gracefully

## Project Structure

```
lib/
├── main.dart                    # App entry with service pre-initialization
├── models/
│   └── voice_note.dart         # Data model with serialization
├── providers/
│   └── voice_note_provider.dart # Central state management
├── screens/
│   ├── home_screen.dart        # Main list view
│   ├── recording_screen.dart   # Recording interface
│   └── note_detail_screen.dart # Note details view
├── services/
│   ├── audio_recorder.dart     # Platform audio recording
│   ├── speech_service.dart     # Speech recognition
│   ├── database_service.dart   # SQLite persistence
│   └── location_service.dart   # GPS functionality
└── widgets/
    ├── animated_button.dart    # Custom button with animations
    ├── notes_list.dart        # Efficient list rendering
    └── recording_button.dart  # Recording control widget
```

## Cross-Platform Considerations

### Web Support
- In-memory storage fallback when SQLite unavailable
- Sample text generation for testing when speech API unavailable
- Platform-specific permission handling

### Mobile (iOS/Android)
- Native audio recording with high quality settings
- Full speech recognition support
- SQLite database with migrations
- Location services with permission handling

## Future Improvements

### Potential Refactoring
1. **Dependency Injection**: Consider `get_it` for service registration
2. **Repository Pattern**: Abstract database operations
3. **Stream Architecture**: Use `StreamBuilder` for real-time updates
4. **Error Recovery**: Add retry mechanisms for failed operations
5. **Configuration**: Extract hardcoded values to config files

### Performance Enhancements
1. **Lazy Loading**: Implement pagination for large note lists
2. **Audio Compression**: Reduce storage requirements
3. **Background Processing**: Move transcription to isolates
4. **Caching**: Implement intelligent caching strategies

## Development Guidelines

### Code Style
- Minimal comments (self-documenting code)
- Consistent formatting with Flutter conventions
- Clear separation of concerns
- Reactive UI patterns

### Testing Strategy
- Services are mockable and isolated
- Provider pattern enables easy unit testing
- UI components testable with widget tests

### Performance Best Practices
1. Update UI state immediately for perceived speed
2. Use `Future.wait()` for parallel operations
3. Pre-build static widgets to avoid recreation
4. Minimize rebuilds with targeted `Consumer` usage
5. Handle permissions and initialization at app startup

## Troubleshooting

### Common Issues
1. **Slow first recording**: Services now pre-initialized at startup
2. **Animation stuttering**: Fixed with pre-built animated widgets
3. **Database migrations**: Require app restart, not hot reload
4. **Speech recognition**: Check microphone permissions and device support

### Debug Logging
Extensive debug logging throughout for troubleshooting:
- Service initialization status
- Recording state transitions
- Transcription updates
- Database operations
- Performance metrics (duration tracking)