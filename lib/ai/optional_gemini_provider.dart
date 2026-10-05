import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_provider.dart';

class OptionalGeminiProvider implements AiProvider {
  final String apiKey;
  final String modelName;
  GenerativeModel? _model;
  bool _isReady = false;

  OptionalGeminiProvider({
    required this.apiKey,
    this.modelName = 'gemini-1.5-flash',
  }) {
    if (apiKey.trim().isNotEmpty) {
      _model = GenerativeModel(model: modelName, apiKey: apiKey.trim());
      _isReady = true;
    }
  }

  @override
  String get name => 'Optional Gemini ($modelName)';

  @override
  bool get isReady => _isReady && _model != null;

  @override
  Future<String> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async {
    if (!isReady) {
      throw Exception('Gemini API key is not configured.');
    }

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(
        content,
        generationConfig: GenerationConfig(
          temperature: temperature,
          maxOutputTokens: maxTokens,
        ),
      );
      return response.text ?? 'No response returned by Gemini.';
    } catch (e) {
      throw Exception('Gemini API error: $e');
    }
  }

  @override
  Stream<String> generateStream({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  }) async* {
    if (!isReady) {
      throw Exception('Gemini API key is not configured.');
    }

    try {
      final content = [Content.text(prompt)];
      final responseStream = _model!.generateContentStream(
        content,
        generationConfig: GenerationConfig(
          temperature: temperature,
          maxOutputTokens: maxTokens,
        ),
      );

      await for (final response in responseStream) {
        if (response.text != null && response.text!.isNotEmpty) {
          yield response.text!;
        }
      }
    } catch (e) {
      throw Exception('Gemini streaming error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _model = null;
    _isReady = false;
  }
}
