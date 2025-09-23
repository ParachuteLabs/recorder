import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parachute/services/audio_service.dart';
import 'package:parachute/services/transcription_service.dart';
import 'package:parachute/screens/post_recording_screen.dart';
import 'package:parachute/widgets/recording_visualizer.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioService _audioService = AudioService();
  final TranscriptionService _transcriptionService = TranscriptionService();
  RecordingState _recordingState = RecordingState.stopped;
  Duration _recordingDuration = Duration.zero;
  Duration _pausedDuration = Duration.zero;
  DateTime? _startTime;
  DateTime? _pauseStartTime;
  Timer? _timer;
  String? _recordingPath;
  String _currentTranscription = '';
  bool _transcriptionAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializeAndStartRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.dispose();
    _transcriptionService.dispose();
    super.dispose();
  }

  Future<void> _initializeAndStartRecording() async {
    try {
      // Initialize audio service (required)
      print('Initializing audio service...');
      await _audioService.initialize();
      print('Audio service initialized');

      // Start audio recording
      print('Starting audio recording...');
      final success = await _audioService.startRecording();

      if (success) {
        print('Audio recording started successfully');
        _startTime = DateTime.now();
        _startTimer();

        if (mounted) {
          setState(() {
            _recordingState = RecordingState.recording;
          });
        }

        // Try to initialize transcription (optional, non-blocking)
        _initializeTranscription();
      } else {
        print('Failed to start audio recording');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to start recording. Please check permissions.'),
              duration: Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error in initializeAndStartRecording: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _initializeTranscription() async {
    try {
      print('Attempting to initialize transcription service...');
      final initialized = await _transcriptionService.initialize();

      if (initialized) {
        print('Transcription service initialized successfully');
        _transcriptionAvailable = true;

        // Start listening for transcription
        await _transcriptionService.startListening(
          onResult: (text) {
            if (mounted) {
              setState(() {
                _currentTranscription = text;
              });
            }
          },
        );
        print('Transcription listening started');
      } else {
        print('Transcription service not available on this device');
        _transcriptionAvailable = false;
      }
    } catch (e) {
      print('Transcription error (non-fatal): $e');
      _transcriptionAvailable = false;
      // Don't show error to user - transcription is optional
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_recordingState == RecordingState.recording && _startTime != null) {
        setState(() {
          // Calculate total duration minus paused time
          final totalElapsed = DateTime.now().difference(_startTime!);
          _recordingDuration = totalElapsed - _pausedDuration;
        });
      } else if (_recordingState == RecordingState.stopped) {
        timer.cancel();
      }
    });
  }

  Future<void> _pauseRecording() async {
    if (_recordingState == RecordingState.recording) {
      final success = await _audioService.pauseRecording();
      if (success) {
        _pauseStartTime = DateTime.now();
        _timer?.cancel();

        // Pause transcription if available
        if (_transcriptionAvailable) {
          try {
            await _transcriptionService.pauseListening();
          } catch (e) {
            print('Error pausing transcription: $e');
          }
        }

        setState(() {
          _recordingState = RecordingState.paused;
        });
      }
    } else if (_recordingState == RecordingState.paused) {
      final success = await _audioService.resumeRecording();
      if (success) {
        // Add the paused duration to total paused time
        if (_pauseStartTime != null) {
          _pausedDuration += DateTime.now().difference(_pauseStartTime!);
          _pauseStartTime = null;
        }

        // Resume transcription if available
        if (_transcriptionAvailable) {
          try {
            await _transcriptionService.resumeListening(
              onResult: (text) {
                if (mounted) {
                  setState(() {
                    _currentTranscription = text;
                  });
                }
              },
            );
          } catch (e) {
            print('Error resuming transcription: $e');
          }
        }

        setState(() {
          _recordingState = RecordingState.recording;
        });
        _startTimer();
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    setState(() {
      _recordingState = RecordingState.stopped;
    });

    // Stop transcription if available and get final text
    String transcription = '';
    if (_transcriptionAvailable) {
      try {
        await _transcriptionService.stopListening();
        transcription = _transcriptionService.getFinalTranscription();
        print('Final transcription: $transcription');
      } catch (e) {
        print('Error stopping transcription: $e');
      }
    }

    final path = await _audioService.stopRecording();
    if (path != null && mounted) {
      _recordingPath = path;

      // Calculate final duration
      if (_startTime != null) {
        final totalElapsed = DateTime.now().difference(_startTime!);
        _recordingDuration = totalElapsed - _pausedDuration;
      }

      _navigateToPostRecording(transcription);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save recording'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _navigateToPostRecording(String transcription) {
    if (_recordingPath != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PostRecordingScreen(
            recordingPath: _recordingPath!,
            duration: _recordingDuration,
            initialTranscript: transcription.isNotEmpty ? transcription : null,
          ),
        ),
      );
    }
  }

  String get _formattedDuration {
    final minutes = _recordingDuration.inMinutes;
    final seconds = _recordingDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Recording'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Recording status
            Text(
              _recordingState == RecordingState.recording
                  ? 'Recording...'
                  : _recordingState == RecordingState.paused
                      ? 'Paused'
                      : 'Initializing...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _recordingState == RecordingState.recording
                        ? Theme.of(context).colorScheme.primary
                        : _recordingState == RecordingState.paused
                            ? Colors.orange
                            : Colors.grey,
                  ),
            ),

            const SizedBox(height: 20),

            // Recording visualizer
            RecordingVisualizer(
              isRecording: _recordingState == RecordingState.recording,
            ),

            const SizedBox(height: 30),

            // Duration display
            Text(
              _formattedDuration,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
            ),

            const SizedBox(height: 20),

            // Recording indicator
            if (_recordingState == RecordingState.recording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('recording...'),
                ],
              ),

            const SizedBox(height: 20),

            // Live transcription preview (only show if transcription is working)
            if (_currentTranscription.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                constraints: const BoxConstraints(maxHeight: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mic,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Live Transcription',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          _currentTranscription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Control buttons
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pause/Resume button
                  FloatingActionButton(
                    onPressed: _recordingState != RecordingState.stopped
                        ? _pauseRecording
                        : null,
                    backgroundColor: _recordingState != RecordingState.stopped
                        ? Colors.orange
                        : Colors.grey,
                    child: Icon(
                      _recordingState == RecordingState.recording
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),

                  // Stop button
                  FloatingActionButton(
                    onPressed: _recordingState != RecordingState.stopped
                        ? _stopRecording
                        : null,
                    backgroundColor: _recordingState != RecordingState.stopped
                        ? Colors.red
                        : Colors.grey,
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const Text('Tap stop to finish recording'),
          ],
        ),
      ),
    );
  }
}
