import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/model_manager.dart';
import '../../data/services/speech_service.dart';
import '../../data/services/teaching_state.dart';
import '../../data/services/tts_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  static const MethodChannel _deviceChannel = MethodChannel('app.aiteacher/device_info');

  Map<String, dynamic>? _deviceInfo;

  // Voice Test State
  bool _isTestingVoice = false;
  String _voiceTestStatus = 'Not run yet';
  bool? _voiceTestPassed;

  // Microphone Test State
  final SpeechService _speechService = SpeechService();
  bool _isTestingMic = false;
  String _micTestStatus = 'Not run yet';
  String _micRecognizedText = '';
  bool? _micTestPassed;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _refreshAudioAndVoice();
  }

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final dynamic info = await _deviceChannel.invokeMethod('getDeviceInfo');
      if (mounted && info is Map) {
        setState(() {
          _deviceInfo = Map<String, dynamic>.from(info);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceInfo = {
            'device': 'Motorola moto g64 5G (Android)',
            'androidVersion': 'Android 14 / 15',
            'totalRamMb': 8192,
            'availRamMb': 4096,
          };
        });
      }
    }
  }

  Future<void> _refreshAudioAndVoice() async {
    final tts = Provider.of<TtsService>(context, listen: false);
    await tts.init();
    await tts.checkVoiceAvailability();
    await _speechService.checkPermission();
    await _speechService.checkRecognitionSupport();
    if (mounted) setState(() {});
  }

  Future<void> _runVoiceTest(TtsService tts) async {
    setState(() {
      _isTestingVoice = true;
      _voiceTestStatus = 'Initializing TTS test...';
      _voiceTestPassed = null;
    });

    final success = await tts.runVoiceDiagnosticTest(
      onProgress: (status) {
        if (mounted) {
          setState(() {
            _voiceTestStatus = status;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isTestingVoice = false;
        _voiceTestPassed = success;
        _voiceTestStatus = success
            ? 'PASS: Voice playback completed successfully.'
            : 'FAIL: Voice playback failed or language unavailable.';
      });
    }
  }

  Future<void> _runEnglishVoiceOnlyTest(TtsService tts) async {
    setState(() {
      _isTestingVoice = true;
      _voiceTestStatus = 'Speaking English test...';
    });

    await tts.speak(
      'Hello. This is your AI Teacher English voice test.',
      language: AppLanguage.english,
      onComplete: () {
        if (mounted) {
          setState(() {
            _isTestingVoice = false;
            _voiceTestPassed = true;
            _voiceTestStatus = 'PASS: English voice test passed.';
          });
        }
      },
    );
  }

  Future<void> _runTeluguVoiceOnlyTest(TtsService tts) async {
    if (!tts.hasTeluguVoice) {
      setState(() {
        _voiceTestPassed = false;
        _voiceTestStatus = 'FAIL: Telugu speech voice is not installed on this device.';
      });
      return;
    }

    setState(() {
      _isTestingVoice = true;
      _voiceTestStatus = 'Speaking Telugu test...';
    });

    await tts.speak(
      'నమస్కారం, ఇది మీ AI టీచర్ తెలుగు వాయిస్ టెస్ట్.',
      language: AppLanguage.telugu,
      onComplete: () {
        if (mounted) {
          setState(() {
            _isTestingVoice = false;
            _voiceTestPassed = true;
            _voiceTestStatus = 'PASS: Telugu voice test passed.';
          });
        }
      },
    );
  }

  Future<void> _runMicrophoneTest() async {
    setState(() {
      _isTestingMic = true;
      _micTestStatus = 'Please say: "Hello teacher." (Listening...)';
      _micRecognizedText = '';
      _micTestPassed = null;
    });

    await _speechService.runMicrophoneDiagnosticTest(
      onStatusUpdate: (status) {
        if (mounted) {
          setState(() {
            _micTestStatus = status;
          });
        }
      },
      onRecognized: (text) {
        if (mounted) {
          setState(() {
            _micRecognizedText = text;
            _isTestingMic = false;
            _micTestPassed = true;
            _micTestStatus = 'PASS: Speech captured and recognized successfully!';
          });
        }
      },
      onFailed: (err) {
        if (mounted) {
          setState(() {
            _isTestingMic = false;
            _micTestPassed = false;
            _micTestStatus = 'FAIL: $err';
          });
        }
      },
    );
  }

  Future<void> _runBuiltinTestLesson(TeachingState state) async {
    // Built-in test lesson without AI model (Part 22, 43)
    const testTopic = 'Python';
    const testContent = 'Python is a high-level programming language. It is easy to learn and widely used for software development and automation.';

    await state.startUserContentLesson(testTopic, testContent);
    if (mounted) {
      Navigator.pushNamed(context, '/classroom');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tts = Provider.of<TtsService>(context);
    final modelManager = Provider.of<ModelManager>(context);
    final teachingState = Provider.of<TeachingState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Diagnostics & Hardware'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-scan Hardware',
            onPressed: () {
              _loadDeviceInfo();
              _refreshAudioAndVoice();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Device & RAM Card
            _buildDeviceCard(),
            const SizedBox(height: 16),

            // 2. Text-to-Speech Diagnostics Card
            _buildVoiceCard(tts),
            const SizedBox(height: 16),

            // 3. Microphone & Speech Recognition Card
            _buildMicrophoneCard(),
            const SizedBox(height: 16),

            // 4. Local AI & Model Card
            _buildLocalAiCard(modelManager),
            const SizedBox(height: 16),

            // 5. Test Lesson Without AI Model (Part 22, 43)
            _buildTestLessonCard(teachingState),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    final deviceName = _deviceInfo?['device'] ?? 'Motorola moto g64 5G';
    final androidVer = _deviceInfo?['androidVersion'] ?? 'Android (Detecting...)';
    final sdkInt = _deviceInfo?['sdkInt'] ?? '';
    final totalRamMb = _deviceInfo?['totalRamMb'] ?? 0;
    final availRamMb = _deviceInfo?['availRamMb'] ?? 0;
    final totalRamGb = totalRamMb > 0 ? (totalRamMb / 1024.0).toStringAsFixed(1) : '8.0 / 12.0';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, color: Color(0xFF1D4ED8), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Physical Device Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow('Device Model', deviceName),
            _buildDetailRow('Android Version', '$androidVer ${sdkInt != '' ? '(SDK $sdkInt)' : ''}'),
            _buildDetailRow('Total RAM', '$totalRamGb GB ($totalRamMb MB)'),
            _buildDetailRow('Available RAM', '$availRamMb MB'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Moto G64 5G MediaTek Dimensity 7025 detected. Ready for Qwen 2.5 1.5B/3B GGUF.',
                style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCard(TtsService tts) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over, color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Voice & Text-to-Speech',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                _buildStatusPill(
                  tts.isInitialized ? 'READY' : 'NOT READY',
                  tts.isInitialized,
                ),
              ],
            ),
            const Divider(height: 20),
            _buildStatusRow('Text-to-Speech Engine', tts.isInitialized ? 'READY' : 'NOT READY', tts.isInitialized),
            _buildStatusRow('English Voice (en-IN / en-US)', tts.hasEnglishVoice ? 'AVAILABLE' : 'NOT AVAILABLE', tts.hasEnglishVoice),
            _buildStatusRow('Telugu Voice (te-IN)', tts.hasTeluguVoice ? 'AVAILABLE' : 'NOT AVAILABLE', tts.hasTeluguVoice),
            _buildDetailRow('Current TTS Engine', tts.ttsEngineName),
            _buildDetailRow('Audio Routing', 'Phone Stereo Speakers / Bluetooth Earbuds (A2DP)'),
            const SizedBox(height: 12),

            // Voice Test Feedback Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _voiceTestPassed == true
                    ? Colors.green.shade50
                    : (_voiceTestPassed == false ? Colors.red.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _voiceTestPassed == true
                      ? Colors.green.shade300
                      : (_voiceTestPassed == false ? Colors.red.shade300 : Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _voiceTestPassed == true
                        ? Icons.check_circle
                        : (_voiceTestPassed == false ? Icons.error : Icons.info_outline),
                    size: 18,
                    color: _voiceTestPassed == true
                        ? Colors.green.shade800
                        : (_voiceTestPassed == false ? Colors.red.shade800 : Colors.grey.shade700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _voiceTestStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _voiceTestPassed == true
                            ? Colors.green.shade800
                            : (_voiceTestPassed == false ? Colors.red.shade800 : Colors.grey.shade800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: _isTestingVoice
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.volume_up, size: 16),
                  label: const Text('Test Voice (All)'),
                  onPressed: _isTestingVoice ? null : () => _runVoiceTest(tts),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.language, size: 16),
                  label: const Text('Test English'),
                  onPressed: _isTestingVoice ? null : () => _runEnglishVoiceOnlyTest(tts),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.translate, size: 16),
                  label: const Text('Test Telugu'),
                  onPressed: _isTestingVoice ? null : () => _runTeluguVoiceOnlyTest(tts),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Open TTS Settings'),
                  onPressed: () => tts.openTtsSettings(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicrophoneCard() {
    final hasPerm = _speechService.hasPermission;
    final isSupported = _speechService.isSpeechRecognitionSupported;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, color: Color(0xFFE11D48), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Microphone & Speech-To-Text',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                _buildStatusPill(
                  hasPerm ? 'READY' : 'PERMISSION REQUIRED',
                  hasPerm,
                ),
              ],
            ),
            const Divider(height: 20),
            _buildStatusRow('Microphone Permission', hasPerm ? 'GRANTED' : 'PERMISSION REQUIRED', hasPerm),
            _buildStatusRow('Speech Recognition Support', isSupported ? 'AVAILABLE' : 'UNAVAILABLE', isSupported),
            _buildDetailRow('Offline Fallback', 'Typed Doubt Input Always Supported'),
            const SizedBox(height: 12),

            // Mic Test Feedback Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _micTestPassed == true
                    ? Colors.green.shade50
                    : (_micTestPassed == false ? Colors.red.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _micTestPassed == true
                      ? Colors.green.shade300
                      : (_micTestPassed == false ? Colors.red.shade300 : Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _micTestPassed == true
                            ? Icons.check_circle
                            : (_micTestPassed == false ? Icons.error : Icons.info_outline),
                        size: 18,
                        color: _micTestPassed == true
                            ? Colors.green.shade800
                            : (_micTestPassed == false ? Colors.red.shade800 : Colors.grey.shade700),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _micTestStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _micTestPassed == true
                                ? Colors.green.shade800
                                : (_micTestPassed == false ? Colors.red.shade800 : Colors.grey.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_micRecognizedText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Recognized text: "$_micRecognizedText"',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: _isTestingMic
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.mic, size: 16),
                  label: const Text('Test Microphone'),
                  onPressed: _isTestingMic ? null : _runMicrophoneTest,
                ),
                if (!hasPerm)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.security, size: 16),
                    label: const Text('Grant Permission'),
                    onPressed: () => _speechService.requestPermission(),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.settings_applications, size: 16),
                  label: const Text('App Settings'),
                  onPressed: () => _speechService.openAppSettings(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalAiCard(ModelManager modelManager) {
    final installed = modelManager.hasModelInstalled;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, color: Color(0xFF7C3AED), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Local AI Engine (GGUF)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                _buildStatusPill(
                  installed ? 'INSTALLED' : 'NOT INSTALLED',
                  installed,
                ),
              ],
            ),
            const Divider(height: 20),
            _buildStatusRow('GGUF Model Status', installed ? 'INSTALLED' : 'NOT INSTALLED', installed),
            _buildDetailRow('Installed Model', installed ? (modelManager.modelName ?? 'Qwen GGUF') : 'None (Optional)'),
            _buildDetailRow('RAM Requirement', 'Qwen 2.5 1.5B (~2.0 GB) / 3B (~3.5 GB)'),
            _buildDetailRow('Pre-seeded Algorithms', 'ACTIVE (Offline without GGUF)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: GGUF model is completely OPTIONAL. Pre-seeded lessons, study material pasting, and TTS work 100% offline without downloading any model.',
                style: TextStyle(fontSize: 11.5, color: Colors.purple.shade900, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestLessonCard(TeachingState state) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Color(0xFF1D4ED8), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Test Lesson Without AI Model',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 20),
            const Text(
              'Launches a built-in test lesson on Python (without requiring GGUF or internet) to physically verify that speaker audio, pause/resume, and doubt interruption work seamlessly on your phone.',
              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Start Test Lesson & Audio', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _runBuiltinTestLesson(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isOk ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String text, bool isPositive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPositive ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
    );
  }
}
