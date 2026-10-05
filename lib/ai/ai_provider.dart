/// Abstract interface for AI text generation engines (Local GGUF, Gemini, Fallback)
abstract class AiProvider {
  String get name;
  bool get isReady;

  /// Generate a complete response
  Future<String> generate({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  });

  /// Stream response tokens as they are generated
  Stream<String> generateStream({
    required String prompt,
    double temperature = 0.7,
    int maxTokens = 512,
  });

  /// Dispose any active resources or model contexts
  Future<void> dispose();
}
