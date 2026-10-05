import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/model_manager.dart';

class ModelSetupScreen extends StatefulWidget {
  final bool isFromSettings;

  const ModelSetupScreen({super.key, this.isFromSettings = false});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  bool _isImporting = false;

  Future<void> _pickModelFile(BuildContext context) async {
    setState(() => _isImporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final manager = Provider.of<ModelManager>(context, listen: false);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
        dialogTitle: 'Select a GGUF Quantized Model',
      );

      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        final success = await manager.setModelPath(path);

        if (mounted) {
          if (success) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Model loaded successfully! Ready for offline AI teaching.'),
                backgroundColor: Colors.green,
              ),
            );
            if (!widget.isFromSettings) {
              navigator.pushReplacementNamed('/home');
            }
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(manager.errorMessage ?? 'Failed to load model file.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelManager = Provider.of<ModelManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Model Setup'),
        leading: widget.isFromSettings
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(context, modelManager),
            const SizedBox(height: 24),

            // Import Button
            ElevatedButton.icon(
              onPressed: _isImporting ? null : () => _pickModelFile(context),
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open),
              label: Text(_isImporting ? 'Reading GGUF File...' : 'Import GGUF Model from Storage'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),

            if (!widget.isFromSettings) ...[
              OutlinedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('Continue Without AI (Study Notes & Quizzes)'),
              ),
              const SizedBox(height: 24),
            ],

            // Explanation Card
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade800, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This app runs 100% locally on your phone using quantized GGUF models. No cloud servers, no paid API keys, and no internet required.',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Recommended Models for Android',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Download any of these lightweight instruct models (Q4_K_M) on your phone or PC and import them above:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            ...AppConstants.recommendedModels.map((preset) => _buildPresetCard(preset)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ModelManager manager) {
    final hasModel = manager.hasModelInstalled;
    final color = hasModel ? Colors.green : Colors.amber.shade700;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasModel ? Icons.check_circle : Icons.warning_amber_rounded,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasModel ? 'AI Model Installed & Ready' : 'AI Model is Not Installed Yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasModel) ...[
            _infoRow('Model Name', manager.modelName ?? 'GGUF Model'),
            _infoRow('File Size', manager.formattedModelSize),
            _infoRow('Est. RAM', manager.estimatedRamRequirement),
            _infoRow('Target', manager.recommendedDeviceCapability),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => manager.removeModel(),
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                label: const Text('Remove Model', style: TextStyle(color: Colors.red)),
              ),
            ),
          ] else ...[
            const Text(
              'Import a small GGUF instruct model (1B to 3B parameters) to enable offline conversational teaching and doubt solving.',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(ModelInfoPreset preset) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    preset.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    preset.downloadSize,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              preset.description,
              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.memory, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Requires ${preset.requiredRam}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Text(preset.targetDevices, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
