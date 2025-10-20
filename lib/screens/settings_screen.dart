import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:parachute/models/whisper_models.dart';
import 'package:parachute/providers/omi_providers.dart';
import 'package:parachute/providers/service_providers.dart';
import 'package:parachute/screens/device_pairing_screen.dart';
import 'package:parachute/utils/platform_utils.dart';
import 'package:parachute/widgets/whisper_model_download_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  bool _hasApiKey = false;
  String _syncFolderPath = '';

  // Local Whisper settings
  TranscriptionMode _transcriptionMode = TranscriptionMode.api;
  WhisperModelType _preferredModel = WhisperModelType.base;
  bool _autoTranscribe = false;
  String _storageInfo = '0 MB used';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    setState(() => _isLoading = true);

    final apiKey = await ref.read(storageServiceProvider).getOpenAIApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKeyController.text = apiKey;
      _hasApiKey = true;
    }

    _syncFolderPath =
        await ref.read(storageServiceProvider).getSyncFolderPath();

    // Load local whisper settings
    await _loadLocalWhisperSettings();

    setState(() => _isLoading = false);
  }

  Future<void> _loadLocalWhisperSettings() async {
    final storageService = ref.read(storageServiceProvider);
    final modelManager = ref.read(whisperModelManagerProvider);

    // Load transcription mode
    final modeString = await storageService.getTranscriptionMode();
    _transcriptionMode =
        TranscriptionMode.fromString(modeString) ?? TranscriptionMode.api;

    // Load preferred model
    final modelString = await storageService.getPreferredWhisperModel();
    _preferredModel = WhisperModelType.fromString(modelString ?? 'base') ??
        WhisperModelType.base;

    // Load auto-transcribe setting
    _autoTranscribe = await storageService.getAutoTranscribe();

    // Load storage info
    _storageInfo = await modelManager.getStorageInfo();
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Basic validation: OpenAI keys start with 'sk-'
    if (!apiKey.startsWith('sk-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid API key format. OpenAI keys start with "sk-"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success =
        await ref.read(storageServiceProvider).saveOpenAIApiKey(apiKey);

    setState(() => _isSaving = false);

    if (success) {
      setState(() => _hasApiKey = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save API key'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key?'),
        content: const Text(
          'Are you sure you want to remove your OpenAI API key? '
          'You won\'t be able to use transcription until you add a new key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(storageServiceProvider).deleteOpenAIApiKey();
      if (success) {
        _apiKeyController.clear();
        setState(() => _hasApiKey = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API key deleted'),
            ),
          );
        }
      }
    }
  }

  Future<void> _openApiKeyHelp() async {
    final url = Uri.parse('https://platform.openai.com/api-keys');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _chooseSyncFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final success = await ref
          .read(storageServiceProvider)
          .setSyncFolderPath(selectedDirectory);
      if (success) {
        setState(() => _syncFolderPath = selectedDirectory);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sync folder updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update sync folder'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _setTranscriptionMode(TranscriptionMode mode) async {
    await ref.read(storageServiceProvider).setTranscriptionMode(mode.name);
    setState(() => _transcriptionMode = mode);
  }

  Future<void> _setPreferredModel(WhisperModelType model) async {
    await ref
        .read(storageServiceProvider)
        .setPreferredWhisperModel(model.modelName);
    setState(() => _preferredModel = model);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${model.displayName} model set as active'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _setAutoTranscribe(bool enabled) async {
    await ref.read(storageServiceProvider).setAutoTranscribe(enabled);
    setState(() => _autoTranscribe = enabled);
  }

  Widget _buildOmiDeviceCard() {
    final connectedDeviceAsync = ref.watch(connectedOmiDeviceProvider);
    final connectedDevice = connectedDeviceAsync.value;
    final isConnected = connectedDevice != null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DevicePairingScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConnected
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConnected ? Colors.green : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: isConnected ? Colors.green : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'Connected' : 'Not Connected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isConnected ? Colors.green : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConnected
                        ? connectedDevice.name
                        : 'Tap to pair your device',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sync Folder Section
                const Text(
                  'Sync Folder',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose where to store your recordings for syncing with iCloud, Syncthing, etc.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.folder_open, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Current folder',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _syncFolderPath,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _chooseSyncFolder,
                        icon: const Icon(Icons.folder),
                        label: const Text('Choose Folder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),

                // Omi Device Section
                if (PlatformUtils.shouldShowOmiFeatures) ...[
                  const Text(
                    'Omi Device',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect your Omi wearable device to record with a button tap',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildOmiDeviceCard(),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                ],

                // Transcription Settings Header
                const Text(
                  'Transcription',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Transcription Mode Selector
                const Text(
                  'Transcription Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how to transcribe your recordings',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Mode selector cards
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(TranscriptionMode.api),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModeCard(TranscriptionMode.local),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Auto-transcribe toggle
                SwitchListTile(
                  title: const Text('Auto-transcribe recordings'),
                  subtitle: const Text(
                      'Automatically transcribe after recording stops'),
                  value: _autoTranscribe,
                  onChanged: _setAutoTranscribe,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),

                // Local Whisper Models Section (only show if local mode selected)
                if (_transcriptionMode == TranscriptionMode.local) ...[
                  const Text(
                    'Local Whisper Models',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Download models for offline transcription. Smaller models are faster but less accurate.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Storage info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.storage, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Storage: $_storageInfo',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Model cards
                  ...WhisperModelType.values.map(
                    (model) => WhisperModelDownloadCard(
                      modelType: model,
                      isPreferred: model == _preferredModel,
                      onSetPreferred: () => _setPreferredModel(model),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                ],

                // OpenAI API Header (only show if API mode selected)
                if (_transcriptionMode == TranscriptionMode.api) ...[
                  const Text(
                    'OpenAI API Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure your OpenAI API key to enable AI-powered transcription',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _hasApiKey
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasApiKey ? Colors.green : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasApiKey ? Icons.check_circle : Icons.warning,
                          color: _hasApiKey ? Colors.green : Colors.orange,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasApiKey
                                    ? 'API Key Configured'
                                    : 'No API Key',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _hasApiKey ? Colors.green : Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _hasApiKey
                                    ? 'Transcription is enabled'
                                    : 'Add an API key to enable transcription',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // API Key Input
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'OpenAI API Key',
                      hintText: 'sk-...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveApiKey,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_hasApiKey) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _deleteApiKey,
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Help Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'How to get an API key',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '1. Visit platform.openai.com/api-keys\n'
                          '2. Sign in or create an account\n'
                          '3. Click "Create new secret key"\n'
                          '4. Copy the key (starts with "sk-")\n'
                          '5. Paste it above and tap Save',
                          style: TextStyle(fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _openApiKeyHelp,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open OpenAI Dashboard'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pricing Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            const Text(
                              'Pricing',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Transcription costs \$0.006 per minute\n'
                          '• 1 min recording = \$0.006\n'
                          '• 10 min recording = \$0.06\n'
                          '• 1 hour recording = \$0.36',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ], // Close the if (_transcriptionMode == TranscriptionMode.api) block
              ],
            ),
    );
  }

  Widget _buildModeCard(TranscriptionMode mode) {
    final isSelected = _transcriptionMode == mode;

    return InkWell(
      onTap: () => _setTranscriptionMode(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mode == TranscriptionMode.api
                      ? Icons.cloud
                      : Icons.phone_android,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mode.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[800],
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mode.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
