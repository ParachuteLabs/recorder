import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_note_provider.dart';
import '../widgets/recording_button.dart';
import '../widgets/notes_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _dotAnimationController;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _dotAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _dotAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<VoiceNoteProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // Header with Parachute branding and logo
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Parachute',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      _buildParachuteLogo(),
                    ],
                  ),
                ),
                
                // Search Intent field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search Intent',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                
                // Main content area
                Expanded(
                  child: provider.notes.isEmpty && 
                         provider.state == RecordingState.idle
                      ? _buildMainRecordingInterface(provider)
                      : provider.state != RecordingState.idle
                        ? _buildMainRecordingInterface(provider)
                        : NotesList(notes: provider.notes),
                ),
                
                // Bottom controls
                if (provider.state == RecordingState.idle || 
                    provider.state == RecordingState.waitingForIntent)
                  _buildBottomControls(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildParachuteLogo() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Stack(
        children: List.generate(8, (index) {
          final angle = (index * 45) * (3.14159 / 180);
          return Positioned(
            left: 14 + 8 * math.cos(angle),
            top: 14 + 8 * math.sin(angle),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMainRecordingInterface(VoiceNoteProvider provider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Circular recording visualization
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated dots around the circle
              ...List.generate(12, (index) {
                return AnimatedBuilder(
                  animation: _dotAnimationController,
                  builder: (context, child) {
                    final angle = (index * 30 - _dotAnimationController.value * 360) 
                        * (3.14159 / 180);
                    final radius = 90.0;
                    final isActive = provider.isRecording && 
                        (index / 12 - _dotAnimationController.value).abs() % 1 < 0.3;
                    
                    return Positioned(
                      left: 100 + radius * math.cos(angle) - 6,
                      top: 100 + radius * math.sin(angle) - 6,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive 
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Central play/recording button
              GestureDetector(
                onTap: provider.isRecording 
                    ? () => provider.state == RecordingState.recordingNote
                        ? provider.stopNoteRecording()
                        : provider.stopIntentRecording()
                    : () => provider.startNoteRecording(),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    provider.isRecording ? Icons.stop : Icons.play_arrow,
                    color: const Color(0xFF1B5E4A),
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Recording title and timer
        if (provider.state != RecordingState.idle) ...[
          const Text(
            'My Recording',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '00:00', // Placeholder - in real app would show actual time
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ],
        
        // Show current transcription
        if (provider.currentNoteTranscription.isNotEmpty ||
            provider.currentIntentTranscription.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              provider.state == RecordingState.recordingIntent
                  ? provider.currentIntentTranscription
                  : provider.currentNoteTranscription,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        
        // Intent categorization
        if (provider.state == RecordingState.waitingForIntent) ...[
          const SizedBox(height: 32),
          _buildIntentCategories(provider),
        ],
      ],
    );
  }

  Widget _buildIntentCategories(VoiceNoteProvider provider) {
    final categories = [
      'Meeting', 'Invoice', 'Interview', 'This', 'Example', 'Task'
    ];
    
    return Column(
      children: [
        const Text(
          'Intent',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: categories.map((category) {
              return GestureDetector(
                onTap: () {
                  // Save note with this category as intent
                  provider.skipIntent();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(VoiceNoteProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () => provider.startNoteRecording(),
                  child: const Center(
                    child: Text(
                      'Record',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: provider.isRecording 
                      ? () => provider.state == RecordingState.recordingNote
                          ? provider.stopNoteRecording()
                          : provider.stopIntentRecording()
                      : null,
                  child: Center(
                    child: Text(
                      'Pause',
                      style: TextStyle(
                        color: provider.isRecording 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}