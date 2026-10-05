import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/services/model_manager.dart';
import '../../data/services/teaching_state.dart';
import '../model_setup/model_setup_screen.dart';
import 'diagnostics_screen.dart';
import '../home/help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppRepository _repository = AppRepository();
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final teachingState = Provider.of<TeachingState>(context, listen: false);
    _apiKeyController.text = teachingState.providerType == AiProviderType.gemini
        ? (Provider.of<TeachingState>(context, listen: false).messages.isNotEmpty ? '' : '')
        : '';
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TeachingState>(context);
    final modelManager = Provider.of<ModelManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Teaching & Language
            _buildSectionHeader('Teaching & Language'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Teaching Language', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(state.language.displayName),
                    trailing: DropdownButton<AppLanguage>(
                      value: state.language,
                      underline: const SizedBox(),
                      onChanged: (lang) {
                        if (lang != null) state.setLanguage(lang);
                      },
                      items: AppLanguage.values.map((l) {
                        return DropdownMenuItem(
                          value: l,
                          child: Text(l.displayName),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hardware Diagnostics & Help (Part 20 & 41)
            _buildSectionHeader('Diagnostics & Guide'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.troubleshoot, color: Color(0xFF1D4ED8)),
                    title: const Text('Hardware Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Test Voice, Microphone, Bluetooth, and Moto G64 RAM'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Color(0xFF16A34A)),
                    title: const Text('Help / How to Use', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('20-step guide for personal classroom teaching'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: AI & Voice Models (Requested in Spec 28)
            _buildSectionHeader('AI & Voice Models'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Local AI Model
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.memory, color: Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Local AI Model',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: modelManager.hasModelInstalled ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: modelManager.hasModelInstalled ? Colors.green.shade300 : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            modelManager.hasModelInstalled ? 'Installed' : 'Not Installed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: modelManager.hasModelInstalled ? Colors.green.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      modelManager.hasModelInstalled
                          ? '${modelManager.modelName} (${modelManager.formattedModelSize})'
                          : 'Recommended: Qwen 2.5 3B Instruct GGUF or 1.5B (Optional for richer offline teaching).',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.file_upload_outlined, size: 16),
                      label: Text(modelManager.hasModelInstalled ? 'Change Model' : 'Import Model'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const ModelSetupScreen(isFromSettings: true),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 28),

                    // B. Speech Recognition
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.mic, color: Color(0xFFE11D48), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Speech Recognition',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Uses Android SpeechRecognizer with offline voice pack support and optional Whisper model bridge.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                    const Divider(height: 28),

                    // C. Text To Speech
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over, color: Color(0xFF059669), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Text To Speech',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('English Voice: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(
                          state.hasEnglishVoice ? 'Available' : 'Missing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: state.hasEnglishVoice ? Colors.green.shade700 : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Telugu Voice: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(
                          state.hasTeluguVoice ? 'Available' : 'Missing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: state.hasTeluguVoice ? Colors.green.shade700 : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.settings_voice, size: 16),
                      label: const Text('Open Android Voice Settings'),
                      onPressed: () => state.openTtsSettings(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: AI Engine & Provider
            _buildSectionHeader('AI Engine & Inference'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.psychology, color: Color(0xFF1D4ED8)),
                    title: const Text('Active AI Provider', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      state.providerType == AiProviderType.localAi
                          ? 'Local AI (llama.cpp / GGUF - Offline & Free)'
                          : 'Optional Cloud Gemini',
                    ),
                  ),
                  RadioGroup<AiProviderType>(
                    groupValue: state.providerType,
                    onChanged: (val) {
                      if (val == AiProviderType.gemini) {
                        _showGeminiKeyDialog(state);
                      } else if (val != null) {
                        state.setAiProvider(val);
                      }
                    },
                    child: Column(
                      children: const [
                        RadioListTile<AiProviderType>(
                          title: Text('Local AI (Default - 100% Offline & Free)'),
                          subtitle: Text('Uses GGUF quantized models directly on your Android CPU'),
                          value: AiProviderType.localAi,
                        ),
                        RadioListTile<AiProviderType>(
                          title: Text('Optional Gemini (Online Fallback)'),
                          subtitle: Text('Use only if you wish to connect a free Gemini API key'),
                          value: AiProviderType.gemini,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Data Management
            _buildSectionHeader('Data Management'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: const Text('Clear All User Data', style: TextStyle(color: Colors.red)),
                    subtitle: const Text('Reset quiz scores, documents, and progress'),
                    onTap: () => _confirmClearData(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: App Information
            _buildSectionHeader('About'),
            Card(
              child: Column(
                children: const [
                  ListTile(
                    title: Text('App Version'),
                    trailing: Text('1.0.0+1', style: TextStyle(color: Colors.grey)),
                  ),
                  ListTile(
                    title: Text('Architecture'),
                    trailing: Text('100% Offline & Private', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  void _showGeminiKeyDialog(TeachingState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gemini is an optional online fallback. Get a free API key at aistudio.google.com.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              state.setGeminiApiKey(_apiKeyController.text);
              state.setAiProvider(AiProviderType.gemini);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all progress, quizzes, uploaded documents, and chat history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await _repository.clearAllData();
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('All data cleared successfully.')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
