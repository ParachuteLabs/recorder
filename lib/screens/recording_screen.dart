import 'package:flutter/material.dart';
import 'package:parachute/services/audio_service.dart';
import 'package:parachute/screens/post_recording_screen.dart';
import 'package:parachute/widgets/recording_visualizer.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioService _audioService = AudioService();
  RecordingState _recordingState = RecordingState.stopped;
  Duration _recordingDuration = Duration.zero;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _startRecording();
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
  }

  Future<void> _startRecording() async {
    final success = await _audioService.startRecording();
    if (success) {
      _startTimer();
      setState(() {
        _recordingState = RecordingState.recording;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start recording. Please check permissions.'),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_recordingState == RecordingState.recording && mounted) {
        setState(() {
          _recordingDuration = _audioService.recordingDuration;
        });
        _startTimer();
      }
    });
  }

  Future<void> _pauseRecording() async {
    if (_recordingState == RecordingState.recording) {
      final success = await _audioService.pauseRecording();
      if (success) {
        setState(() {
          _recordingState = RecordingState.paused;
        });
      }
    } else if (_recordingState == RecordingState.paused) {
      final success = await _audioService.resumeRecording();
      if (success) {
        setState(() {
          _recordingState = RecordingState.recording;
        });
        _startTimer();
      }
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioService.stopRecording();
    if (path != null && mounted) {
      _recordingPath = path;
      _navigateToPostRecording();
    }
  }

  void _navigateToPostRecording() {
    if (_recordingPath != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PostRecordingScreen(
            recordingPath: _recordingPath!,
            duration: _recordingDuration,
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
                  : 'Paused',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _recordingState == RecordingState.recording 
                    ? Theme.of(context).colorScheme.primary
                    : Colors.orange,
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
            
            const Spacer(),
            
            // Control buttons
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pause/Resume button
                  FloatingActionButton(
                    onPressed: _pauseRecording,
                    backgroundColor: Colors.orange,
                    child: Icon(
                      _recordingState == RecordingState.recording
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                  
                  // Stop button
                  FloatingActionButton(
                    onPressed: _stopRecording,
                    backgroundColor: Colors.red,
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            const Text('Finish & add context'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}