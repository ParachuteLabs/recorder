import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  Function(String)? _onResult;

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _speechEnabled;
  String get lastWords => _lastWords;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (error) {
          debugPrint('Speech error: $error');
          debugPrint('Error type: ${error.errorMsg}');
          debugPrint('Permanent: ${error.permanent}');
        },
        debugLogging: true,
      );

      if (_speechEnabled) {
        debugPrint('Speech recognition initialized successfully');
        // Check if microphone is available
        final micAvailable = await _speechToText.hasPermission;
        debugPrint('Microphone permission: $micAvailable');
      } else {
        debugPrint('Speech recognition not available');
      }

      return _speechEnabled;
    } catch (e) {
      debugPrint('Failed to initialize speech: $e');
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({Function(String)? onResult}) async {
    // Set the callback first so we can report errors
    _onResult = onResult;
    _lastWords = '';

    if (!_speechEnabled) {
      debugPrint('Speech not enabled, initializing...');
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('ERROR: Failed to initialize speech recognition!');
        if (_onResult != null) {
          _onResult!('[Speech recognition failed to initialize]');
        }
        return;
      }
    }

    try {
      // Check browser compatibility for web
      if (kIsWeb) {
        debugPrint('Running on web - checking browser compatibility');
        // Web Speech API is best supported in Chrome/Edge
      }

      // The listen() method might return void on some platforms
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false, // Don't cancel on error
          autoPunctuation: true,
        ),
      );

      // Check if actually listening
      if (_speechToText.isListening) {
        debugPrint('Started listening successfully');
      } else {
        debugPrint('ERROR: Failed to start listening - not in listening state');
        if (_onResult != null) {
          _onResult!('[Speech recognition failed to start]');
        }
      }
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      if (_onResult != null) {
        _onResult!('[Speech error: $e]');
      }
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
      debugPrint('Stopped listening. Final result: $_lastWords');
    } else {
      debugPrint('Speech service was not listening');
    }
  }

  /// Cancel listening without getting results
  Future<void> cancelListening() async {
    await _speechToText.cancel();
    _lastWords = '';
    debugPrint('Cancelled listening');
  }

  /// Handle speech recognition results
  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    debugPrint('Recognition result: "$_lastWords" (final: ${result.finalResult}, confidence: ${result.confidence})');

    if (_onResult != null) {
      _onResult!(_lastWords);
    }
  }

  /// Get available locales
  Future<List<LocaleName>> getLocales() async {
    try {
      final locales = await _speechToText.locales();
      return locales;
    } catch (e) {
      debugPrint('Error getting locales: $e');
      return [];
    }
  }

  void dispose() {
    _speechToText.cancel();
  }
}
