import 'dart:async';
import '../core/constants/app_constants.dart';
import 'local_ai_provider.dart';
import 'optional_gemini_provider.dart';
import 'fallback_teacher_provider.dart';

class AiService {
  AiProviderType _selectedProviderType = AiProviderType.localAi;
  String? _localModelPath;
  String? _geminiApiKey;
  double _temperature = 0.7;
  int _maxTokens = 512;

  LocalAiProvider? _localProvider;
  OptionalGeminiProvider? _geminiProvider;
  final FallbackTeacherProvider _fallbackProvider = FallbackTeacherProvider();

  AiProviderType get providerType => _selectedProviderType;
  String? get localModelPath => _localModelPath;
  String? get geminiApiKey => _geminiApiKey;

  bool get hasLocalModel => _localModelPath != null && _localModelPath!.isNotEmpty;
  bool get hasGeminiKey => _geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty;

  void configure({
    required AiProviderType providerType,
    String? localModelPath,
    String? geminiApiKey,
    double? temperature,
    int? maxTokens,
  }) {
    _selectedProviderType = providerType;
    if (localModelPath != null) {
      _localModelPath = localModelPath;
      if (localModelPath.isNotEmpty) {
        _localProvider = LocalAiProvider(modelPath: localModelPath);
      } else {
        _localProvider = null;
      }
    }

    if (geminiApiKey != null) {
      _geminiApiKey = geminiApiKey;
      if (geminiApiKey.trim().isNotEmpty) {
        _geminiProvider = OptionalGeminiProvider(apiKey: geminiApiKey.trim());
      } else {
        _geminiProvider = null;
      }
    }

    if (temperature != null) _temperature = temperature;
    if (maxTokens != null) _maxTokens = maxTokens;
  }

  /// Streams token-by-token response with graceful automatic fallback
  Stream<String> streamResponse(String fullPrompt) async* {
    // 1. Try Gemini if selected and configured
    if (_selectedProviderType == AiProviderType.gemini && _geminiProvider != null && _geminiProvider!.isReady) {
      try {
        yield* _geminiProvider!.generateStream(
          prompt: fullPrompt,
          temperature: _temperature,
          maxTokens: _maxTokens,
        );
        return;
      } catch (e) {
        yield '\n*[Note: Gemini unavailable ($e). Falling back to offline tutor mode.]*\n\n';
      }
    }

    // 2. Try Local AI if selected or as fallback
    if (_localProvider != null) {
      try {
        yield* _localProvider!.generateStream(
          prompt: fullPrompt,
          temperature: _temperature,
          maxTokens: _maxTokens,
        );
        return;
      } catch (e) {
        yield '\n*[Note: Local model inference error ($e). Using offline teacher knowledge-base.]*\n\n';
      }
    }

    // 3. Guaranteed reliable offline fallback tutor
    yield* _fallbackProvider.generateStream(
      prompt: fullPrompt,
      temperature: _temperature,
      maxTokens: _maxTokens,
    );
  }

  /// Non-streaming complete generation with graceful automatic fallback
  Future<String> generateResponse(String fullPrompt) async {
    // 1. Try Gemini if configured
    if (_selectedProviderType == AiProviderType.gemini && _geminiProvider != null && _geminiProvider!.isReady) {
      try {
        return await _geminiProvider!.generate(
          prompt: fullPrompt,
          temperature: _temperature,
          maxTokens: _maxTokens,
        );
      } catch (_) {
        // Fall back to local
      }
    }

    // 2. Try Local AI
    if (_localProvider != null) {
      try {
        return await _localProvider!.generate(
          prompt: fullPrompt,
          temperature: _temperature,
          maxTokens: _maxTokens,
        );
      } catch (_) {
        // Fall back to rule-based tutor
      }
    }

    // 3. Fallback tutor
    return await _fallbackProvider.generate(
      prompt: fullPrompt,
      temperature: _temperature,
      maxTokens: _maxTokens,
    );
  }

  Future<void> dispose() async {
    await _localProvider?.dispose();
    await _geminiProvider?.dispose();
    await _fallbackProvider.dispose();
  }
}
