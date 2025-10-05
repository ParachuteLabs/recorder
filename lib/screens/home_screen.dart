import 'package:flutter/material.dart';
import 'package:parachute/models/recording.dart';
import 'package:parachute/services/storage_service.dart';
import 'package:parachute/screens/recording_screen.dart';
import 'package:parachute/screens/recording_detail_screen.dart';
import 'package:parachute/screens/settings_screen.dart';
import 'package:parachute/widgets/recording_tile.dart';
import 'package:parachute/utils/sample_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  List<Recording> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecordings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRecordings();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when screen gains focus
    if (ModalRoute.of(context)?.isCurrent == true) {
      _refreshRecordings();
    }
  }

  Future<void> _loadRecordings() async {
    final recordings = await _storageService.getRecordings();

    // Add sample data if no recordings exist (for demo purposes)
    if (recordings.isEmpty) {
      final sampleRecordings = SampleData.getSampleRecordings();
      for (final recording in sampleRecordings) {
        await _storageService.saveRecording(recording);
      }
      final updatedRecordings = await _storageService.getRecordings();
      if (mounted) {
        setState(() {
          _recordings = updatedRecordings;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _recordings = recordings;
          _isLoading = false;
        });
      }
    }
  }

  void _refreshRecordings() {
    setState(() {
      _isLoading = true;
    });
    _loadRecordings();
  }

  Future<void> _startRecording() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RecordingScreen()),
    );

    // Always refresh when returning from recording flow
    _refreshRecordings();
  }

  void _openRecordingDetail(Recording recording) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => RecordingDetailScreen(recording: recording),
          ),
        )
        .then((_) => _refreshRecordings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parachute'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
              ? _buildEmptyState()
              : _buildRecordingsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _startRecording,
        child: const Icon(Icons.mic),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the microphone button to start recording',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Past recordings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recordings.length,
            itemBuilder: (context, index) {
              final recording = _recordings[index];
              return RecordingTile(
                recording: recording,
                onTap: () => _openRecordingDetail(recording),
              );
            },
          ),
        ),
      ],
    );
  }
}
