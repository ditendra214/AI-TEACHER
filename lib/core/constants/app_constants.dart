/// Core application constants, enums, and prompt configurations
class AppConstants {
  static const String appName = 'AI Teacher';
  static const String appTagline = 'Personal Exam Tutor';

  // Shared Preference Keys
  static const String prefLanguage = 'pref_app_language';
  static const String prefAiProvider = 'pref_ai_provider';
  static const String prefGeminiApiKey = 'pref_gemini_api_key';
  static const String prefModelPath = 'pref_local_model_path';
  static const String prefModelName = 'pref_local_model_name';
  static const String prefTemperature = 'pref_temperature';
  static const String prefMaxTokens = 'pref_max_tokens';
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefOnboardingCompleted = 'pref_onboarding_completed';

  // Recommended Small Mobile Models (1B - 3B range)
  static const List<ModelInfoPreset> recommendedModels = [
    ModelInfoPreset(
      name: 'SmolLM2-1.7B-Instruct (Q4_K_M)',
      filename: 'smollm2-1.7b-instruct-q4_k_m.gguf',
      parameterSize: '1.7 Billion',
      downloadSize: '~1.05 GB',
      requiredRam: '2.0 GB RAM',
      targetDevices: 'Standard Android (4GB+ Total RAM)',
      downloadUrl:
          'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf',
      description:
          'Fast, lightweight instruct model tailored for mobile devices. Highly capable for textbook comprehension, definitions, and step-by-step tutoring.',
    ),
    ModelInfoPreset(
      name: 'Llama-3.2-1B-Instruct (Q4_K_M)',
      filename: 'llama-3.2-1b-instruct-q4_k_m.gguf',
      parameterSize: '1.2 Billion',
      downloadSize: '~800 MB',
      requiredRam: '1.5 GB RAM',
      targetDevices: 'Entry to Mid-Range Phones (3GB+ Total RAM)',
      downloadUrl:
          'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      description:
          'Meta\'s compact 1B model. Ultra-fast inference on Android CPU, good at quick exam answers and short summaries.',
    ),
    ModelInfoPreset(
      name: 'Qwen2.5-1.5B-Instruct (Q4_K_M)',
      filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      parameterSize: '1.5 Billion',
      downloadSize: '~980 MB',
      requiredRam: '2.0 GB RAM',
      targetDevices: 'Mid-Range Android Phones (4GB+ Total RAM)',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      description:
          'Outstanding reasoning, technical explanations, step-by-step algorithms, and coding logic.',
    ),
  ];
}

enum TeachingMode {
  learn,
  doubt,
  exam,
  revision,
  quiz,
}

enum AppLanguage {
  english,
  telugu,
  teluguEnglish,
}

extension AppLanguageExtension on AppLanguage {
  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.telugu:
        return 'Telugu (తెలుగు)';
      case AppLanguage.teluguEnglish:
        return 'English + Telugu (Tanglish)';
    }
  }

  String get shortCode {
    switch (this) {
      case AppLanguage.english:
        return 'EN';
      case AppLanguage.telugu:
        return 'TE';
      case AppLanguage.teluguEnglish:
        return 'TE+EN';
    }
  }

  String get ttsLocale {
    switch (this) {
      case AppLanguage.english:
        return 'en-IN';
      case AppLanguage.telugu:
        return 'te-IN';
      case AppLanguage.teluguEnglish:
        return 'en-IN';
    }
  }
}

enum AiProviderType {
  localAi,
  gemini,
}

enum ModelStatus {
  notInstalled,
  downloading,
  installed,
  loading,
  ready,
  error,
}

class ModelInfoPreset {
  final String name;
  final String filename;
  final String parameterSize;
  final String downloadSize;
  final String requiredRam;
  final String targetDevices;
  final String downloadUrl;
  final String description;

  const ModelInfoPreset({
    required this.name,
    required this.filename,
    required this.parameterSize,
    required this.downloadSize,
    required this.requiredRam,
    required this.targetDevices,
    required this.downloadUrl,
    required this.description,
  });
}
