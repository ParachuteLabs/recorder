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
        onError: (error) => debugPrint('Speech error: $error'),
      );
      debugPrint('Speech recognition initialized: $_speechEnabled');
      return _speechEnabled;
    } catch (e) {
      debugPrint('Failed to initialize speech: $e');
      return false;
    }
  }
  
  /// Start listening for speech
  Future<void> startListening({Function(String)? onResult}) async {
    if (!_speechEnabled) {
      debugPrint('Speech not enabled, initializing...');
      await initialize();
    }
    
    _onResult = onResult;
    _lastWords = '';
    
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
      ),
    );
    
    debugPrint('Started listening');
  }
  
  /// Stop listening
  Future<void> stopListening() async {
    await _speechToText.stop();
    debugPrint('Stopped listening. Final result: $_lastWords');
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
    debugPrint('Recognition result: $_lastWords (final: ${result.finalResult})');
    
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