import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class TranscriptionService {
  static final TranscriptionService _instance =
      TranscriptionService._internal();
  factory TranscriptionService() => _instance;
  TranscriptionService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _transcription = '';
  StreamController<String>? _transcriptionController;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get transcription => _transcription;
  Stream<String>? get transcriptionStream => _transcriptionController?.stream;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('Requesting speech recognition permissions...');
      _isInitialized = await _speechToText.initialize(
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'notListening' && _isListening) {
            print(
                'Speech recognition stopped unexpectedly, may have timed out');
          }
        },
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
          print('Error type: ${error.permanent}');
        },
        debugLogging: true,
      );

      if (_isInitialized) {
        print('TranscriptionService initialized successfully');

        // Get available locales
        final locales = await _speechToText.locales();
        print(
            'Available locales: ${locales.map((l) => l.localeId).join(', ')}');

        // Check if the system locale is available
        final systemLocale = await _speechToText.systemLocale();
        print('System locale: ${systemLocale?.localeId}');
      } else {
        print(
            'TranscriptionService initialization failed - permission denied or not available');
      }

      return _isInitialized;
    } catch (e) {
      print('Error initializing TranscriptionService: $e');
      return false;
    }
  }

  Future<void> startListening({
    Function(String)? onResult,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      print('Cannot start listening: not initialized');
      return;
    }

    if (_isListening) {
      print('Already listening, skipping startListening call');
      return;
    }

    _transcription = '';
    _transcriptionController = StreamController<String>.broadcast();

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _transcription = result.recognizedWords;

          print(
              'Transcription result: $_transcription (final: ${result.finalResult})');

          // Emit the transcription through the stream
          _transcriptionController?.add(_transcription);

          // Call the callback if provided
          onResult?.call(_transcription);

          // If this is the final result, we might want to restart listening
          // to continue transcribing (for long recordings)
          if (result.finalResult && _isListening) {
            // Automatically restart listening for continuous transcription
            _restartListening(onResult: onResult, localeId: localeId);
          }
        },
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        localeId: localeId,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );

      _isListening = true;
      print('Started listening for speech');
    } catch (e) {
      print('Error starting speech recognition: $e');
      _isListening = false;
    }
  }

  Future<void> _restartListening({
    Function(String)? onResult,
    String? localeId,
  }) async {
    // Small delay before restarting
    await Future.delayed(const Duration(milliseconds: 100));

    if (_isListening) {
      try {
        await _speechToText.listen(
          onResult: (SpeechRecognitionResult result) {
            // Append to existing transcription with a space
            _transcription = _transcription.isEmpty
                ? result.recognizedWords
                : '$_transcription ${result.recognizedWords}';

            _transcriptionController?.add(_transcription);
            onResult?.call(_transcription);

            if (result.finalResult && _isListening) {
              _restartListening(onResult: onResult, localeId: localeId);
            }
          },
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 10),
          partialResults: true,
          localeId: localeId,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        );
      } catch (e) {
        print('Error restarting speech recognition: $e');
      }
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      _transcriptionController?.close();
      _transcriptionController = null;
      print('Stopped listening for speech');
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  Future<void> pauseListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      print('Paused listening for speech');
    } catch (e) {
      print('Error pausing speech recognition: $e');
    }
  }

  Future<void> resumeListening({
    Function(String)? onResult,
    String? localeId,
  }) async {
    if (_isListening) return; // Already listening

    // Don't clear transcription on resume, keep accumulating
    if (_transcriptionController == null ||
        _transcriptionController!.isClosed) {
      _transcriptionController = StreamController<String>.broadcast();
    }

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          // Append to existing transcription
          final newWords = result.recognizedWords;
          if (newWords.isNotEmpty) {
            _transcription =
                _transcription.isEmpty ? newWords : '$_transcription $newWords';
            _transcriptionController?.add(_transcription);
            onResult?.call(_transcription);
          }

          if (result.finalResult && _isListening) {
            _restartListening(onResult: onResult, localeId: localeId);
          }
        },
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        localeId: localeId,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
      _isListening = true;
      print('Resumed listening for speech');
    } catch (e) {
      print('Error resuming speech recognition: $e');
      _isListening = false;
    }
  }

  String getFinalTranscription() {
    return _transcription;
  }

  void clearTranscription() {
    _transcription = '';
    _transcriptionController?.add('');
  }

  Future<void> dispose() async {
    await stopListening();
    _transcriptionController?.close();
    _isInitialized = false;
  }

  Future<bool> hasPermission() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isInitialized;
  }
}
