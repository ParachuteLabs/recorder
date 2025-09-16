# Parachute Audio 🎙️

A high-performance Flutter voice recording app with real-time transcription, location tagging, and intelligent note organization.

## Features

- 🎤 **Voice Recording**: High-quality audio capture with duration tracking
- 🗣️ **Live Transcription**: Real-time speech-to-text with streaming updates
- 📍 **Location Tagging**: Automatic GPS location capture for each note
- 🎯 **Intent Capture**: Optional context recording for better organization
- 📱 **Cross-Platform**: Runs on iOS, Android, and Web
- ⚡ **Optimized Performance**: Instant UI response with background processing

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on iOS/Android
flutter run

# Run on Web
flutter run -d chrome
```

## Architecture

This app follows a clean, layered architecture with Provider state management. For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

### Key Components
- **Provider Pattern**: Centralized state management with `VoiceNoteProvider`
- **Service Layer**: Isolated services for audio, speech, database, and location
- **State Machine**: Complex recording workflow management
- **Performance Optimized**: Pre-built animations, parallel initialization, responsive UI

## Performance Optimizations

### Recent Improvements
1. **Instant Stop Button**: UI updates immediately while services stop in background
2. **Smooth Animations**: Pre-built animated dots prevent frame drops
3. **Fast Startup**: Services initialized in parallel at app launch
4. **Responsive Navigation**: State changes trigger immediate UI updates

### Benchmarks
- First recording start: ~500ms (down from ~2s)
- Stop button response: <50ms (down from ~1s)
- Animation frame rate: Consistent 60fps
- Database operations: <100ms for typical queries

## Development

### Prerequisites
- Flutter 3.0+
- iOS 12.0+ / Android API 21+
- Microphone permissions configured

### Project Structure
```
lib/
├── models/       # Data models
├── providers/    # State management
├── screens/      # UI screens
├── services/     # Business logic
└── widgets/      # Reusable components
```

### Database Schema
The app uses SQLite for local storage with automatic migrations:
- Version 1: Basic note storage
- Version 2: Added duration tracking

### Testing
```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## Platform Support

### iOS & Android
- Full speech recognition support
- Native audio recording
- SQLite database persistence
- GPS location services

### Web
- Limited speech recognition (Chrome/Edge)
- In-memory storage
- Sample data for testing
- No location services

## Contributing

1. Follow Flutter style guidelines
2. Maintain clean architecture patterns
3. Add tests for new features
4. Update documentation as needed

## License

Private - Parachute Studios

## Support

For issues or questions, contact the Parachute development team.

flutter build ios --release
open ios/Runner.xcworkspace, then CMD+R
