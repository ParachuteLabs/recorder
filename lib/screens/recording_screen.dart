import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/voice_note_provider.dart';
import '../models/voice_note.dart';
import 'note_detail_screen.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  late AnimationController _dotAnimationController;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  final TextEditingController _intentController = TextEditingController();
  bool _hasStartedRecording = false; // Ensure we only start once
  late List<Widget> _animatedDots; // Pre-build dots to avoid recreation

  @override
  void initState() {
    super.initState();
    _dotAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Pre-build animated dots once to avoid recreation
    _animatedDots = _buildAnimatedDots();

    _startTimer();

    // Start recording immediately after init, no need to wait for frame
    Future.microtask(() {
      if (!_hasStartedRecording && mounted) {
        final provider = Provider.of<VoiceNoteProvider>(context, listen: false);
        if (provider.state == RecordingState.recordingNote) {
          _hasStartedRecording = true;
          provider.startNoteRecording();
        }
      }
    });
  }

  void _startTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  @override
  void dispose() {
    _dotAnimationController.dispose();
    _recordingTimer?.cancel();
    _intentController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildAnimatedDots() {
    return List.generate(12, (index) {
      return AnimatedBuilder(
        animation: _dotAnimationController,
        builder: (context, child) {
          final angle = (index * 30) * (math.pi / 180);
          final animatedAngle = angle - (_dotAnimationController.value * 2 * math.pi);
          final radius = 70.0;
          final opacity = ((math.sin(_dotAnimationController.value * 2 * math.pi - angle) + 1) / 2) * 0.7 + 0.3;

          return Positioned(
            left: 100 + radius * math.cos(animatedAngle) - 6,
            top: 100 + radius * math.sin(animatedAngle) - 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(opacity),
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E4A),
      body: SafeArea(
        child: Consumer<VoiceNoteProvider>(
          builder: (context, provider, child) {
            // Handle navigation when recording is complete
            if (provider.state == RecordingState.complete) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (provider.notes.isNotEmpty) {
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          NoteDetailScreen(note: provider.notes.first),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                }
              });
              // Show a loading state while navigating
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            }

            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Parachute v0.5',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (provider.state == RecordingState.recordingNote ||
                          provider.state == RecordingState.recordingIntent)
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'recording...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      // Circular visualization
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background circle
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E4A),
                                shape: BoxShape.circle,
                              ),
                            ),

                            // Animated dots (pre-built to avoid recreation)
                            if (provider.isRecording)
                              ..._animatedDots,

                            // Play/Stop button
                            GestureDetector(
                              onTap: () {
                                if (provider.state == RecordingState.recordingNote) {
                                  provider.stopNoteRecording();
                                } else if (provider.state == RecordingState.recordingIntent) {
                                  provider.stopIntentRecording();
                                }
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: Icon(
                                  provider.isRecording ? Icons.stop : Icons.play_arrow,
                                  color: const Color(0xFF1B5E4A),
                                  size: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Live transcript
                      if (provider.state == RecordingState.recordingNote ||
                          provider.state == RecordingState.recordingIntent) ...[
                        const Text(
                          'Live Transcript',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(16),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              provider.state == RecordingState.recordingIntent
                                  ? (provider.currentIntentTranscription.isEmpty
                                      ? 'Listening for intent...'
                                      : provider.currentIntentTranscription)
                                  : (provider.currentNoteTranscription.isEmpty
                                      ? 'Start speaking...'
                                      : provider.currentNoteTranscription),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Intent capture UI
                      if (provider.state == RecordingState.waitingForIntent) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add context to your note',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _intentController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'e.g. "Meeting notes", "Project idea"',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    provider.saveNoteWithIntent(value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      // Timer/Status
                      if (provider.isRecording)
                        Text(
                          _formatDuration(_recordingSeconds),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      const Spacer(),

                      // Action buttons
                      if (provider.state == RecordingState.waitingForIntent) ...[
                        OutlinedButton(
                          onPressed: () => provider.startIntentRecording(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'record intent',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => provider.skipIntent(),
                          child: Text(
                            'skip',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ] else if (provider.state == RecordingState.recordingNote) ...[
                        OutlinedButton(
                          onPressed: () => provider.stopNoteRecording(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'finish & add context',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ),
                      ] else if (provider.state == RecordingState.recordingIntent) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
