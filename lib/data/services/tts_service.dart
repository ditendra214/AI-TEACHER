import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';

enum TtsPlaybackState {
  idle,
  initializing,
  stopped,
  playing,
  paused,
  completed,
  error,
}

/// Offline Android Text-To-Speech service with native AudioAttributes (USAGE_MEDIA),
/// Bluetooth earbud/stereo speaker routing, segmented speech tracking, bilingual voice routing,
/// and real hardware-level callbacks.
class TtsService extends ChangeNotifier {
  static const MethodChannel _settingsChannel = MethodChannel('app.aiteacher/settings');
  static const MethodChannel _nativeAudioChannel = MethodChannel('app.aiteacher/native_audio');

  FlutterTts? _flutterTts;
  TtsPlaybackState _playbackState = TtsPlaybackState.stopped;
  String _lastSpokenText = '';
  AppLanguage _lastLanguage = AppLanguage.english;
  VoidCallback? _onCompletionCallback;
  bool _isInitialized = false;
  final bool mockMode;
  bool _useNativeBridge = true;

  // Error & Voice Availability Tracking
  bool _hasPlaybackError = false;
  String? _lastErrorMessage;
  bool _hasTeluguVoice = false;
  bool _hasEnglishVoice = true;
  String _ttsEngineName = 'Android Native TTS';

  // Session & Safety Tracking
  int _sessionId = 0;
  double _speechRate = 0.48; // Educational speed
  double _speechPitch = 1.0; // Natural pitch

  // Granular Segment Playback Tracking
  List<String> _currentSegments = [];
  int _currentSegmentIndex = 0;
  bool _isSegmentedMode = false;
  Function(int index)? _onSegmentChangedCallback;
  Completer<void>? _segmentCompleter;

  int get activeSessionId => _sessionId;
  int get sessionId => _sessionId;
  double get speechRate => _speechRate;
  double get speechPitch => _speechPitch;

  TtsPlaybackState get playbackState => _playbackState;
  bool get isSpeaking => _playbackState == TtsPlaybackState.playing;
  bool get isPaused => _playbackState == TtsPlaybackState.paused;
  bool get isStopped => _playbackState == TtsPlaybackState.stopped || _playbackState == TtsPlaybackState.idle;
  bool get isCompleted => _playbackState == TtsPlaybackState.completed;
  bool get hasPlaybackError => _hasPlaybackError;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get isInitialized => _isInitialized;
  bool get hasTeluguVoice => _hasTeluguVoice;
  bool get hasEnglishVoice => _hasEnglishVoice;
  String get ttsEngineName => _ttsEngineName;
  int get currentSegmentIndex => _currentSegmentIndex;
  List<String> get currentSegments => List.unmodifiable(_currentSegments);

  bool _callbacksConfigured = false;

  TtsService({this.mockMode = false});

  /// Starts a new isolated teaching session and invalidates any previous async work
  int startSession() {
    _sessionId++;
    debugPrint('[TTS] SESSION_CREATED: id=$_sessionId');
    return _sessionId;
  }

  /// Cancels any queued speech, background callbacks, and stops audio
  void cancelSession() {
    _sessionId++;
    debugPrint('[TTS] SESSION_CANCELLED: id=$_sessionId');
    stop();
  }

  void cancelQueue() => cancelSession();

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.3, 1.0);
    if (_flutterTts != null) {
      await _flutterTts!.setSpeechRate(_speechRate);
    }
    notifyListeners();
  }

  Future<void> setSpeechPitch(double pitch) async {
    _speechPitch = pitch.clamp(0.5, 2.0);
    if (_flutterTts != null) {
      await _flutterTts!.setPitch(_speechPitch);
    }
    notifyListeners();
  }

  Future<void> setPitch(double pitch) => setSpeechPitch(pitch);

  void _safeCompleteSegment() {
    if (_segmentCompleter != null && !_segmentCompleter!.isCompleted) {
      _segmentCompleter!.complete();
    }
  }

  void _setupNativeCallbacks() {
    if (_callbacksConfigured || mockMode) return;
    try {
      _nativeAudioChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onStart':
          final utteranceId = call.arguments?['utteranceId'];
          debugPrint('[TTS] TTS_START: utteranceId=$utteranceId');
          _playbackState = TtsPlaybackState.playing;
          _hasPlaybackError = false;
          _lastErrorMessage = null;
          notifyListeners();
          break;

        case 'onDone':
          final utteranceId = call.arguments?['utteranceId'];
          debugPrint('[TTS] TTS_COMPLETE: utteranceId=$utteranceId');
          _safeCompleteSegment();
          if (!_isSegmentedMode) {
            _playbackState = TtsPlaybackState.completed;
            notifyListeners();
            _onCompletionCallback?.call();
          }
          break;

        case 'onError':
          final utteranceId = call.arguments?['utteranceId'];
          final errorCode = call.arguments?['errorCode'];
          final msg = call.arguments?['message'] ?? 'Playback error code: $errorCode';
          debugPrint('[TTS] TTS_ERROR: utteranceId=$utteranceId, error=$msg');
          _playbackState = TtsPlaybackState.error;
          _hasPlaybackError = true;
          _lastErrorMessage = msg.toString();
          _safeCompleteSegment();
          notifyListeners();
          break;

        case 'onActivityStopped':
          debugPrint('[TTS] TEACHER_STOPPED: Activity stopped, cancelling TTS speech immediately');
          cancelSession();
          break;

        case 'onAudioFocusLost':
          debugPrint('[TTS] TTS_AUDIO_FOCUS: focus lost, pausing TTS speech');
          pause();
          break;

        case 'onLanguageUnavailable':
          final requested = call.arguments?['requested'];
          final reason = call.arguments?['reason'];
          debugPrint('[TTS] LANGUAGE UNAVAILABLE: $requested, $reason');
          _hasPlaybackError = true;
          _lastErrorMessage = 'Telugu voice is not installed on this phone.';
          _hasTeluguVoice = false;
          notifyListeners();
          break;

        case 'onEngineReady':
          final ready = call.arguments?['ready'] == true;
          final engine = call.arguments?['engine'] ?? 'Default';
          _isInitialized = ready;
          _ttsEngineName = engine.toString();
          debugPrint('[TTS] TTS_INIT: ready=$ready, engine=$_ttsEngineName');
          checkVoiceAvailability();
          break;
      }
    });
    _callbacksConfigured = true;
    } catch (e) {
      debugPrint('[TTS] setupNativeCallbacks warning: $e');
    }
  }

  Future<void> init() async {
    if (mockMode) {
      _isInitialized = true;
      return;
    }

    _setupNativeCallbacks();

    if (_isInitialized) {
      return;
    }

    _playbackState = TtsPlaybackState.initializing;
    notifyListeners();

    try {
      // 1. Try initializing Native Audio Bridge first
      final bool nativeReady = await _nativeAudioChannel.invokeMethod<bool>('init') ?? false;
      if (nativeReady) {
        _useNativeBridge = true;
        _isInitialized = true;
        await checkVoiceAvailability();
        _playbackState = TtsPlaybackState.idle;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[TTS] Native bridge init fallback to flutter_tts: $e');
      _useNativeBridge = false;
    }

    // 2. Fallback to flutter_tts if native bridge is not reachable
    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setSpeechRate(0.48);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.setQueueMode(0); // QUEUE_FLUSH
      await _flutterTts!.awaitSpeakCompletion(true);

      _flutterTts!.setStartHandler(() {
        debugPrint('[TTS] flutter_tts START CALLBACK');
        _playbackState = TtsPlaybackState.playing;
        _hasPlaybackError = false;
        _lastErrorMessage = null;
        notifyListeners();
      });

      _flutterTts!.setCompletionHandler(() {
        debugPrint('[TTS] flutter_tts COMPLETE CALLBACK');
        if (_segmentCompleter != null && !_segmentCompleter!.isCompleted) {
          _segmentCompleter!.complete();
        }
        if (!_isSegmentedMode) {
          _playbackState = TtsPlaybackState.completed;
          notifyListeners();
          _onCompletionCallback?.call();
        }
      });

      _flutterTts!.setCancelHandler(() {
        _playbackState = TtsPlaybackState.stopped;
        notifyListeners();
      });

      _flutterTts!.setPauseHandler(() {
        _playbackState = TtsPlaybackState.paused;
        notifyListeners();
      });

      _flutterTts!.setContinueHandler(() {
        _playbackState = TtsPlaybackState.playing;
        notifyListeners();
      });

      _flutterTts!.setErrorHandler((msg) {
        debugPrint('[TTS] flutter_tts Error: $msg');
        _playbackState = TtsPlaybackState.error;
        _hasPlaybackError = true;
        _lastErrorMessage = msg.toString();
        if (_segmentCompleter != null && !_segmentCompleter!.isCompleted) {
          _segmentCompleter!.complete();
        }
        notifyListeners();
      });

      _isInitialized = true;
      _playbackState = TtsPlaybackState.idle;
      await checkVoiceAvailability();
    } catch (e) {
      debugPrint('[TTS] Initialization warning: $e');
      _isInitialized = true;
      _playbackState = TtsPlaybackState.idle;
    }
  }

  /// Checks if Telugu and English voices are installed on the device
  Future<Map<String, dynamic>> checkVoiceAvailability() async {
    if (mockMode) {
      _hasTeluguVoice = true;
      _hasEnglishVoice = true;
      notifyListeners();
      return {'hasEnglishVoice': true, 'hasTeluguVoice': true};
    }

    try {
      if (_useNativeBridge) {
        final dynamic raw = await _nativeAudioChannel.invokeMethod('checkVoices');
        if (raw is Map) {
          _hasEnglishVoice = raw['hasEnglishVoice'] == true;
          _hasTeluguVoice = raw['hasTeluguVoice'] == true;
          _ttsEngineName = raw['engine']?.toString() ?? _ttsEngineName;
          debugPrint('[TTS] AVAILABLE LANGUAGES: English=$_hasEnglishVoice, Telugu=$_hasTeluguVoice, Engine=$_ttsEngineName');
          notifyListeners();
          return Map<String, dynamic>.from(raw);
        }
      }

      if (_flutterTts != null) {
        final dynamic languages = await _flutterTts!.getLanguages;
        if (languages is List) {
          final lowerLangs = languages.map((e) => e.toString().toLowerCase()).toList();
          _hasEnglishVoice = lowerLangs.any((l) => l.contains('en'));
          _hasTeluguVoice = lowerLangs.any((l) => l.contains('te'));
          debugPrint('[TTS] flutter_tts AVAILABLE LANGUAGES: English=$_hasEnglishVoice, Telugu=$_hasTeluguVoice');
        }
        notifyListeners();
        return {'hasEnglishVoice': _hasEnglishVoice, 'hasTeluguVoice': _hasTeluguVoice};
      }
    } catch (e) {
      debugPrint('[TTS] Voice check warning: $e');
    }

    return {'hasEnglishVoice': _hasEnglishVoice, 'hasTeluguVoice': _hasTeluguVoice};
  }

  /// Opens the Android system Text-To-Speech settings
  Future<bool> openTtsSettings() async {
    try {
      final res = await _settingsChannel.invokeMethod<bool>('openTtsSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('Could not open TTS settings: $e');
      return false;
    }
  }

  /// Speaks a complete text block with Android audio focus and Bluetooth routing
  Future<void> speak(
    String text, {
    required AppLanguage language,
    VoidCallback? onComplete,
  }) async {
    final cleanText = toSpeechFriendlyText(text.trim());
    if (cleanText.isEmpty) return;

    final session = startSession();
    _lastSpokenText = cleanText;
    _lastLanguage = language;
    _onCompletionCallback = onComplete;
    _isSegmentedMode = false;

    if (mockMode) {
      _playbackState = TtsPlaybackState.playing;
      _hasPlaybackError = false;
      notifyListeners();
      return;
    }

    await init();
    if (session != _sessionId) return; // Cancelled while initializing

    _hasPlaybackError = false;
    _lastErrorMessage = null;

    final locale = _resolveLocaleForText(cleanText, language);
    debugPrint('[TTS] TTS_START: sessionId=$session, textLength=${cleanText.length}, locale=$locale, rate=$_speechRate, pitch=$_speechPitch');

    // Check if Telugu is requested but unavailable
    if (locale == 'te-IN' && !_hasTeluguVoice) {
      debugPrint('[TTS] TTS_ERROR: Telugu voice requested but not installed.');
      _hasPlaybackError = true;
      _lastErrorMessage = 'Telugu speech voice is not installed on this phone.';
      _playbackState = TtsPlaybackState.error;
      notifyListeners();
      return;
    }

    if (_useNativeBridge) {
      try {
        final success = await _nativeAudioChannel.invokeMethod<bool>('speak', {
          'text': cleanText,
          'locale': locale,
          'utteranceId': 'utt_${session}_${DateTime.now().millisecondsSinceEpoch}',
          'rate': _speechRate,
          'pitch': _speechPitch,
          'volume': 1.0,
        });

        debugPrint('[TTS] Native speak return: $success');
        if (success != true) {
          _playbackState = TtsPlaybackState.error;
          _hasPlaybackError = true;
          _lastErrorMessage = 'Voice playback failed on device. Check TTS engine settings.';
          notifyListeners();
          onComplete?.call();
        }
        return;
      } catch (e) {
        debugPrint('[TTS] Native speak failed, falling back to flutter_tts: $e');
      }
    }

    // Fallback to flutter_tts
    try {
      if (_flutterTts != null) {
        await _flutterTts!.setLanguage(locale);
        await _flutterTts!.setSpeechRate(_speechRate);
        await _flutterTts!.setPitch(_speechPitch);
        final dynamic result = await _flutterTts!.speak(cleanText, focus: true);
        debugPrint('[TTS] flutter_tts speak return: $result');
        if (result == 0) {
          _playbackState = TtsPlaybackState.error;
          _hasPlaybackError = true;
          _lastErrorMessage = 'Unable to start voice playback. Ensure TTS engine is installed.';
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[TTS] TTS_ERROR flutter_tts speak failed: $e');
      _playbackState = TtsPlaybackState.error;
      _hasPlaybackError = true;
      _lastErrorMessage = e.toString();
      notifyListeners();
      onComplete?.call();
    }
  }

  /// Speaks structured speech segments sequentially, tracking current segment index.
  /// Allows resuming from the exact sentence when interrupted.
  Future<void> speakSegments(
    List<String> segments, {
    int startSegment = 0,
    required AppLanguage language,
    Function(int index)? onSegmentChanged,
    VoidCallback? onComplete,
  }) async {
    final validSegments = segments
        .map((s) => toSpeechFriendlyText(s).trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (validSegments.isEmpty) {
      onComplete?.call();
      return;
    }

    final session = startSession();
    _currentSegments = validSegments;
    _currentSegmentIndex = (startSegment >= 0 && startSegment < validSegments.length)
        ? startSegment
        : 0;
    _lastLanguage = language;
    _isSegmentedMode = true;
    _onSegmentChangedCallback = onSegmentChanged;
    _onCompletionCallback = onComplete;

    if (mockMode) {
      _playbackState = TtsPlaybackState.playing;
      _hasPlaybackError = false;
      _onSegmentChangedCallback?.call(_currentSegmentIndex);
      notifyListeners();
      return;
    }

    await init();
    if (session != _sessionId) return;
    _playSegmentLoop(session);
  }

  Future<void> _playSegmentLoop(int session) async {
    while (session == _sessionId &&
        _isSegmentedMode &&
        _currentSegmentIndex < _currentSegments.length &&
        _playbackState != TtsPlaybackState.stopped &&
        _playbackState != TtsPlaybackState.paused) {
      final segmentText = _currentSegments[_currentSegmentIndex];
      _onSegmentChangedCallback?.call(_currentSegmentIndex);
      notifyListeners();

      final locale = _resolveLocaleForText(segmentText, _lastLanguage);
      _lastSpokenText = segmentText;

      _segmentCompleter = Completer<void>();

      bool callSuccess = false;
      if (_useNativeBridge) {
        try {
          final res = await _nativeAudioChannel.invokeMethod<bool>('speak', {
            'text': segmentText,
            'locale': locale,
            'utteranceId': 'seg_${session}_${_currentSegmentIndex}_${DateTime.now().millisecondsSinceEpoch}',
            'rate': _speechRate,
            'pitch': _speechPitch,
            'volume': 1.0,
          });
          callSuccess = res == true;
        } catch (e) {
          callSuccess = false;
        }
      }

      if (!callSuccess && _flutterTts != null) {
        try {
          await _flutterTts!.setLanguage(locale);
          await _flutterTts!.setSpeechRate(_speechRate);
          await _flutterTts!.setPitch(_speechPitch);
          final dynamic res = await _flutterTts!.speak(segmentText, focus: true);
          callSuccess = res != 0;
        } catch (e) {
          callSuccess = false;
        }
      }

      if (!callSuccess) {
        if (session != _sessionId) return;
        _playbackState = TtsPlaybackState.error;
        _hasPlaybackError = true;
        _lastErrorMessage = 'Unable to play speech segment $_currentSegmentIndex.';
        notifyListeners();
        return;
      }

      // Wait for segment utterance completion callback from native engine
      try {
        await _segmentCompleter!.future.timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('[TTS] Segment timeout or interrupted: $e');
      }

      // Verify that this loop still belongs to the active session
      if (session != _sessionId) {
        debugPrint('[TTS] SESSION_ABORTED: loop cancelled because sessionId changed (old=$session, current=$_sessionId)');
        return;
      }

      if (_playbackState == TtsPlaybackState.playing || _playbackState == TtsPlaybackState.completed) {
        _currentSegmentIndex++;
      } else {
        // Interrupted or paused
        break;
      }
    }

    if (session == _sessionId && _isSegmentedMode && _currentSegmentIndex >= _currentSegments.length) {
      _playbackState = TtsPlaybackState.completed;
      _isSegmentedMode = false;
      notifyListeners();
      _onCompletionCallback?.call();
    }
  }

  /// Determines whether to use Telugu or English voice for the given text segment
  String _resolveLocaleForText(String text, AppLanguage language) {
    if (language == AppLanguage.english) {
      return 'en-IN';
    }

    // Check if the segment contains Telugu Unicode characters (\u0C00 - \u0C7F)
    final hasTeluguScript = RegExp(r'[\u0C00-\u0C7F]').hasMatch(text);

    if (language == AppLanguage.telugu) {
      return (hasTeluguScript || _hasTeluguVoice) ? 'te-IN' : 'en-IN';
    }

    // AppLanguage.teluguEnglish (Tanglish / bilingual)
    if (hasTeluguScript && _hasTeluguVoice) {
      return 'te-IN';
    } else {
      return 'en-IN';
    }
  }

  Future<void> pause() async {
    if (_playbackState != TtsPlaybackState.playing) return;

    debugPrint('[TTS] TTS_PAUSE: Pausing playback at segment $_currentSegmentIndex');
    _playbackState = TtsPlaybackState.paused;
    _safeCompleteSegment();
    notifyListeners();

    if (mockMode) return;

    try {
      if (_useNativeBridge) {
        await _nativeAudioChannel.invokeMethod('stop');
      } else {
        await _flutterTts?.stop();
      }
    } catch (e) {
      debugPrint('[TTS] TTS_ERROR pause error: $e');
    }
  }

  Future<void> resume() async {
    if (_playbackState != TtsPlaybackState.paused) return;

    debugPrint('[TTS] TTS_RESUME: Resuming playback from segment $_currentSegmentIndex');
    final session = startSession();
    _playbackState = TtsPlaybackState.playing;
    notifyListeners();

    if (mockMode) return;

    if (_isSegmentedMode && _currentSegments.isNotEmpty) {
      _playSegmentLoop(session);
    } else if (_lastSpokenText.isNotEmpty) {
      await speak(_lastSpokenText, language: _lastLanguage, onComplete: _onCompletionCallback);
    }
  }

  Future<void> stop() async {
    debugPrint('[TTS] TTS_STOP: Stopping playback and clearing speech queue');
    _sessionId++;
    _isSegmentedMode = false;
    _onCompletionCallback = null;
    _safeCompleteSegment();
    _playbackState = TtsPlaybackState.stopped;
    notifyListeners();

    if (mockMode) return;

    try {
      if (_useNativeBridge) {
        await _nativeAudioChannel.invokeMethod('stop');
      } else {
        await _flutterTts?.stop();
      }
    } catch (e) {
      debugPrint('[TTS] TTS_ERROR stop error: $e');
    }
  }

  Future<void> replay() async {
    if (_isSegmentedMode && _currentSegments.isNotEmpty) {
      await stop();
      await speakSegments(
        _currentSegments,
        startSegment: 0,
        language: _lastLanguage,
        onSegmentChanged: _onSegmentChangedCallback,
        onComplete: _onCompletionCallback,
      );
    } else if (_lastSpokenText.isNotEmpty) {
      await stop();
      await speak(
        _lastSpokenText,
        language: _lastLanguage,
        onComplete: _onCompletionCallback,
      );
    }
  }

  /// Diagnostic Voice Test: Speaks English test sentence, then Telugu test
  Future<bool> runVoiceDiagnosticTest({
    required Function(String stepMessage) onProgress,
  }) async {
    try {
      await init();
      onProgress('Testing Text-To-Speech engine initialization...');
      if (!_isInitialized) {
        onProgress('TTS engine initialization failed.');
        return false;
      }

      onProgress('Speaking: "Hello. This is your AI Teacher voice test."');
      await speak(
        'Hello. This is your AI Teacher voice test.',
        language: AppLanguage.english,
      );

      await Future.delayed(const Duration(milliseconds: 2500));

      if (_hasTeluguVoice) {
        onProgress('Speaking Telugu test voice: "నమస్కారం, ఇది మీ AI టీచర్ తెలుగు వాయిస్ టెస్ట్."');
        await speak(
          'నమస్కారం, ఇది మీ AI టీచర్ తెలుగు వాయిస్ టెస్ట్.',
          language: AppLanguage.telugu,
        );
      } else {
        onProgress('Telugu voice is not installed on this phone.');
      }

      return true;
    } catch (e) {
      onProgress('Voice diagnostic test failed: $e');
      return false;
    }
  }

  void resetError() {
    _hasPlaybackError = false;
    _lastErrorMessage = null;
    notifyListeners();
  }

  /// Converts text with code, equations, or symbols into natural educational spoken English/Telugu
  static String toSpeechFriendlyText(String input) {
    if (input.trim().isEmpty) return '';
    var text = input;

    // 1. Convert code blocks ```code``` to speech-friendly explanation
    text = text.replaceAllMapped(
      RegExp(r'```(?:python|java|c\+\+|c|dart|javascript)?\s*([\s\S]*?)```', caseSensitive: false),
      (m) => _convertCodeToSpoken(m.group(1)?.trim() ?? ''),
    );

    // 2. Convert inline code `code` to natural speech
    text = text.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => _convertInlineCodeToSpoken(m.group(1)?.trim() ?? ''),
    );

    // 3. Mathematical & Complexity notations
    text = text.replaceAll(RegExp(r'\$O\(1\)\$|O\(1\)', caseSensitive: false), 'Order of 1');
    text = text.replaceAll(RegExp(r'\$O\(log\s*n\)\$|O\(log\s*n\)', caseSensitive: false), 'Order of log n');
    text = text.replaceAll(RegExp(r'\$O\(n\s*log\s*n\)\$|O\(n\s*log\s*n\)', caseSensitive: false), 'Order of n log n');
    text = text.replaceAll(RegExp(r'\$O\(n\^2\)\$|\$O\(n²\)\$|O\(n²\)|O\(n\^2\)', caseSensitive: false), 'Order of n squared');
    text = text.replaceAll(RegExp(r'\$O\(n\)\$|O\(n\)', caseSensitive: false), 'Order of n');
    text = text.replaceAll(RegExp(r'\$O\(2\^n\)\$|\$O\(2ⁿ\)\$|O\(2ⁿ\)|O\(2\^n\)', caseSensitive: false), 'Order of 2 to the power n');
    text = text.replaceAll(RegExp(r'\\Theta|\bTheta\b|Θ', caseSensitive: false), 'Theta');
    text = text.replaceAll(RegExp(r'\\Omega|\bOmega\b|Ω', caseSensitive: false), 'Omega');
    text = text.replaceAll(r'\le', 'less than or equal to');
    text = text.replaceAll(r'\ge', 'greater than or equal to');
    text = text.replaceAll(r'\in', 'in');
    text = text.replaceAll(r'\to', 'approaches');
    text = text.replaceAll(r'\cdot', 'times');
    text = text.replaceAll(r'\infty', 'infinity');
    text = text.replaceAll(RegExp(r'\$([^\$]+)\$'), r' $1 ');

    // 4. Clean Markdown formatting (headings, asterisks, bullet points)
    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[\*\-•]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    text = text.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    text = text.replaceAll(RegExp(r'_([^_]+)_'), r'$1');

    // 5. Clean up code brackets & symbols that sound awkward in speech
    text = text.replaceAll(RegExp(r'[\[\]{}<>]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  static String _convertCodeToSpoken(String code) {
    if (code.isEmpty) return '';
    final lines = code.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length > 5) {
      return 'Here we have a code snippet. For example, ${lines.first}. ';
    }
    final buffer = StringBuffer('In the code: ');
    for (final line in lines) {
      if (line.startsWith('def ') || line.contains('function ')) {
        final funcName = line.replaceAll(RegExp(r'def\s+|\(.*\)|:'), '').trim();
        buffer.write('We define function $funcName. ');
      } else if (line.startsWith('print(')) {
        final arg = line.replaceAll(RegExp(r'print\(|\)|"|\047'), '').trim();
        buffer.write('We print $arg. ');
      } else if (line.startsWith('return ')) {
        buffer.write('It returns ${line.substring(7)}. ');
      } else {
        buffer.write('$line. ');
      }
    }
    return buffer.toString();
  }

  static String _convertInlineCodeToSpoken(String code) {
    var clean = code.trim();
    if (clean.startsWith('def ')) {
      clean = clean.substring(4).trim();
    }
    if (clean.contains('(') && clean.contains(')')) {
      final name = clean.substring(0, clean.indexOf('('));
      return 'function $name';
    }
    return clean;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
