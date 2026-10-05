import 'dart:async';
import 'dart:io';
import 'package:flutter_llama/flutter_llama.dart';
import 'ai_provider.dart';

class LocalAiProvider implements AiProvider {
  final String modelPath;
  bool _isReady = false;

  LocalAiProvider({required this.modelPath});

  @override
  String get name => 'Local AI (llama.cpp / GGUF)';

  @override
  bool get isReady => _isReady && FlutterLlama.instance.isModelLoaded;

  /// Loads the GGUF model from the specified file path
  Future<bool> loadModel({
    int nThreads = 4,
    int nGpuLayers = 0,
    int contextSize = 2048,
  }) async {
    final file = File(modelPath);
    if (!await file.exists()) {
      _isReady = false;
      throw Exception('GGUF model file does not exist at: $modelPath');
    }

    final config = LlamaConfig(
      modelPath: modelPath,
      nThreads: nThreads,
      nGpuLayers: nGpuLayers,
      contextSize: contextSize,
      useGpu: false, // Default CPU inference for maximum mobile stability
      verbose: false,
    );

    final success = await FlutterLlama.instance.loadModel(config);
    _isReady = success;
    return success;
  }

  @override
  Future<String> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async {
    if (!isReady) {
      final loaded = await loadModel();
      if (!loaded) {
        throw Exception('Failed to load local GGUF model from $modelPath');
      }
    }

    final params = GenerationParams(
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    final response = await FlutterLlama.instance.generate(params);
    return response.text;
  }

  @override
  Stream<String> generateStream({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async* {
    if (!isReady) {
      final loaded = await loadModel();
      if (!loaded) {
        throw Exception('Failed to initialize local GGUF model');
      }
    }

    final params = GenerationParams(
      prompt: prompt,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    yield* FlutterLlama.instance.generateStream(params);
  }

  @override
  Future<void> dispose() async {
    try {
      if (FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.unloadModel();
      }
      _isReady = false;
    } catch (_) {}
  }
}
