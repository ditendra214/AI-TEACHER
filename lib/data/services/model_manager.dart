import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../../ai/ai_service.dart';

class ModelManager extends ChangeNotifier {
  final SharedPreferences prefs;
  final AiService aiService;

  ModelStatus _status = ModelStatus.notInstalled;
  String? _modelPath;
  String? _modelName;
  int _modelSizeBytes = 0;
  String? _errorMessage;

  ModelManager({
    required this.prefs,
    required this.aiService,
  }) {
    _loadSavedModel();
  }

  ModelStatus get status => _status;
  String? get modelPath => _modelPath;
  String? get modelName => _modelName;
  int get modelSizeBytes => _modelSizeBytes;
  String? get errorMessage => _errorMessage;

  bool get isModelReady => _status == ModelStatus.ready;
  bool get hasModelInstalled => _status == ModelStatus.installed || _status == ModelStatus.ready;

  String get formattedModelSize {
    if (_modelSizeBytes <= 0) return 'Unknown size';
    final mb = _modelSizeBytes / (1024 * 1024);
    if (mb > 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get estimatedRamRequirement {
    if (_modelSizeBytes <= 0) return '1.5 - 2.5 GB RAM';
    final gb = _modelSizeBytes / (1024 * 1024 * 1024);
    final estRam = (gb * 1.5).toStringAsFixed(1);
    return '~$estRam GB RAM';
  }

  String get recommendedDeviceCapability {
    if (_modelSizeBytes > 1.5 * 1024 * 1024 * 1024) {
      return 'Modern Android Phone (6GB+ RAM recommended)';
    } else if (_modelSizeBytes > 800 * 1024 * 1024) {
      return 'Standard Android Phone (4GB+ RAM recommended)';
    }
    return 'Entry-Level Android Phone (3GB+ RAM)';
  }

  void _loadSavedModel() {
    final savedPath = prefs.getString(AppConstants.prefModelPath);
    final savedName = prefs.getString(AppConstants.prefModelName);

    if (savedPath != null && savedPath.isNotEmpty) {
      final file = File(savedPath);
      if (file.existsSync()) {
        _modelPath = savedPath;
        _modelName = savedName ?? p.basename(savedPath);
        _modelSizeBytes = file.lengthSync();
        _status = ModelStatus.installed;

        aiService.configure(
          providerType: aiService.providerType,
          localModelPath: savedPath,
        );
      } else {
        _status = ModelStatus.notInstalled;
        prefs.remove(AppConstants.prefModelPath);
        prefs.remove(AppConstants.prefModelName);
      }
    } else {
      _status = ModelStatus.notInstalled;
    }
    notifyListeners();
  }

  /// Sets the active local GGUF model path
  Future<bool> setModelPath(String path) async {
    try {
      _status = ModelStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final file = File(path);
      if (!await file.exists()) {
        _status = ModelStatus.error;
        _errorMessage = 'Selected file not found: $path';
        notifyListeners();
        return false;
      }

      final ext = p.extension(path).toLowerCase();
      if (ext != '.gguf') {
        _status = ModelStatus.error;
        _errorMessage = 'File must be in .gguf format. Selected: $ext';
        notifyListeners();
        return false;
      }

      _modelPath = path;
      _modelName = p.basename(path);
      _modelSizeBytes = await file.length();
      _status = ModelStatus.ready;

      await prefs.setString(AppConstants.prefModelPath, path);
      await prefs.setString(AppConstants.prefModelName, _modelName!);

      aiService.configure(
        providerType: aiService.providerType,
        localModelPath: path,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _status = ModelStatus.error;
      _errorMessage = 'Failed to load model: $e';
      notifyListeners();
      return false;
    }
  }

  /// Removes the current model configuration
  Future<void> removeModel() async {
    _modelPath = null;
    _modelName = null;
    _modelSizeBytes = 0;
    _status = ModelStatus.notInstalled;
    _errorMessage = null;

    await prefs.remove(AppConstants.prefModelPath);
    await prefs.remove(AppConstants.prefModelName);

    aiService.configure(
      providerType: aiService.providerType,
      localModelPath: '',
    );

    notifyListeners();
  }
}
