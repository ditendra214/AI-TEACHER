import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SpeechServiceState {
  idle,
  requestingPermission,
  listening,
  processing,
  result,
  error,
}

/// Offline-first Speech-To-Text service for microphone voice doubt input
/// with explicit native runtime permission handling, SpeechRecognizer detection,
/// and graceful typed fallback.
class SpeechService extends ChangeNotifier {
  static const MethodChannel _settingsChannel = MethodChannel('app.aiteacher/settings');

  stt.SpeechToText? _speech;
  SpeechServiceState _state = SpeechServiceState.idle;
  bool _isAvailable = false;
  bool _hasPermissionError = false;
  bool _hasPermission = false;
  bool _isSpeechRecognitionSupported = true;
  String _recognizedWords = '';
  String? _lastErrorMessage;
  final bool mockMode;

  SpeechServiceState get state => _state;
  bool get isAvailable => _isAvailable;
  bool get isListening => _state == SpeechServiceState.listening;
  bool get isProcessing => _state == SpeechServiceState.processing;
  bool get hasPermissionError => _hasPermissionError;
  bool get hasPermission => _hasPermission;
  bool get isSpeechRecognitionSupported => _isSpeechRecognitionSupported;
  String get recognizedWords => _recognizedWords;
  String? get lastErrorMessage => _lastErrorMessage;

  SpeechService({this.mockMode = false});

  Future<bool> checkPermission() async {
    if (mockMode) {
      _hasPermission = true;
      _hasPermissionError = false;
      return true;
    }

    try {
      final granted = await _settingsChannel.invokeMethod<bool>('checkMicrophonePermission');
      _hasPermission = granted ?? false;
      _hasPermissionError = !_hasPermission;
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[SPEECH] Permission check error: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (mockMode) {
      _hasPermission = true;
      _hasPermissionError = false;
      return true;
    }

    _state = SpeechServiceState.requestingPermission;
    notifyListeners();

    try {
      final granted = await _settingsChannel.invokeMethod<bool>('requestMicrophonePermission');
      _hasPermission = granted ?? false;
      _hasPermissionError = !_hasPermission;
      if (!_hasPermission) {
        _state = SpeechServiceState.error;
        _lastErrorMessage = 'Microphone permission is required for voice doubts.';
      } else {
        _state = SpeechServiceState.idle;
        _lastErrorMessage = null;
      }
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      _hasPermission = false;
      _hasPermissionError = true;
      _state = SpeechServiceState.error;
      _lastErrorMessage = 'Could not request microphone permission: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkRecognitionSupport() async {
    if (mockMode) {
      _isSpeechRecognitionSupported = true;
      return true;
    }

    try {
      final supported = await _settingsChannel.invokeMethod<bool>('isSpeechRecognitionAvailable');
      _isSpeechRecognitionSupported = supported ?? true;
      notifyListeners();
      return _isSpeechRecognitionSupported;
    } catch (e) {
      _isSpeechRecognitionSupported = true;
      return true;
    }
  }

  Future<bool> init() async {
    if (mockMode) {
      _isAvailable = true;
      _hasPermission = true;
      _hasPermissionError = false;
      return true;
    }

    try {
      await checkPermission();
      await checkRecognitionSupport();

      _speech = stt.SpeechToText();
      _isAvailable = await _speech!.initialize(
        onError: (error) {
          debugPrint('[SPEECH] Error: ${error.errorMsg}');
          _state = SpeechServiceState.error;
          _lastErrorMessage = error.errorMsg;
          if (error.errorMsg.toLowerCase().contains('permission')) {
            _hasPermissionError = true;
          }
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('[SPEECH] Status: $status');
          if (status == 'listening') {
            _state = SpeechServiceState.listening;
            notifyListeners();
          } else if (status == 'notListening' || status == 'done') {
            if (_state == SpeechServiceState.listening) {
              _state = SpeechServiceState.processing;
            }
            notifyListeners();
          }
        },
      );

      final hasPerm = await _speech!.hasPermission;
      if (hasPerm) {
        _hasPermission = true;
        _hasPermissionError = false;
      }
      notifyListeners();
      return _isAvailable;
    } catch (e) {
      debugPrint('[SPEECH] Init error: $e');
      _isAvailable = false;
      _state = SpeechServiceState.error;
      _lastErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(String error, bool isPermissionError) onError,
  }) async {
    _recognizedWords = '';
    _lastErrorMessage = null;

    if (mockMode) {
      _state = SpeechServiceState.listening;
      notifyListeners();
      return;
    }

    // 1. Explicitly check / request native Android runtime permission
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        onError('Microphone permission is required for voice doubts.', true);
        return;
      }
    }

    // 2. Initialize speech-to-text engine if not already initialized
    if (!_isAvailable || _speech == null) {
      final available = await init();
      if (!available) {
        if (_hasPermissionError) {
          onError('Microphone permission is required for voice doubts.', true);
        } else {
          onError('Voice input is unavailable offline on this device. You can type your doubt.', false);
        }
        return;
      }
    }

    try {
      _state = SpeechServiceState.listening;
      notifyListeners();

      await _speech?.listen(
        onResult: (result) {
          _recognizedWords = result.recognizedWords;
          if (result.finalResult || _recognizedWords.isNotEmpty) {
            _state = SpeechServiceState.result;
            onResult(_recognizedWords);
          }
          notifyListeners();
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      _state = SpeechServiceState.error;
      _lastErrorMessage = e.toString();
      notifyListeners();
      onError('Voice input is unavailable offline on this device. You can type your doubt.', false);
    }
  }

  Future<void> stopListening() async {
    if (mockMode) {
      _state = SpeechServiceState.idle;
      notifyListeners();
      return;
    }

    try {
      await _speech?.stop();
    } catch (e) {
      debugPrint('[SPEECH] Stop error: $e');
    }
    _state = SpeechServiceState.idle;
    notifyListeners();
  }

  Future<void> openAppSettings() async {
    try {
      await _settingsChannel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('[SPEECH] Open settings error: $e');
    }
  }

  /// Runs the diagnostic microphone test requested in Part 19, 21, 44
  Future<void> runMicrophoneDiagnosticTest({
    required Function(String status) onStatusUpdate,
    required Function(String recognizedText) onRecognized,
    required Function(String errorReason) onFailed,
  }) async {
    onStatusUpdate('Checking microphone permission...');
    final hasPerm = await checkPermission();
    if (!hasPerm) {
      final granted = await requestPermission();
      if (!granted) {
        onFailed('Microphone permission denied by user.');
        return;
      }
    }

    onStatusUpdate('Checking speech recognition support...');
    final supported = await checkRecognitionSupport();
    if (!supported) {
      onFailed('Android Speech Recognition service is not available on this device.');
      return;
    }

    onStatusUpdate('Initializing speech recognizer...');
    final ready = await init();
    if (!ready) {
      onFailed('Could not initialize speech recognizer. Ensure Google Speech Services is enabled.');
      return;
    }

    onStatusUpdate('Please say: "Hello teacher." (Listening...)');
    await startListening(
      onResult: (text) {
        onRecognized(text);
      },
      onError: (err, isPerm) {
        onFailed(err);
      },
    );
  }

  void resetError() {
    _hasPermissionError = false;
    _lastErrorMessage = null;
    _state = SpeechServiceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
