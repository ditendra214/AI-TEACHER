import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/retrieval_scorer.dart';
import '../../ai/prompt_builder.dart';
import '../../ai/ai_service.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/chat_message_model.dart';
import '../models/teaching_segment_model.dart';
import '../repositories/app_repository.dart';
import 'content_understanding_service.dart';
import 'tts_service.dart';

enum LessonSourceType {
  preSeeded,
  topicOnly,
  userContent,
  lineByLine,
  document,
}

/// Comprehensive lesson snapshot captured during doubt interruption
class TeachingSnapshot {
  final int? subjectId;
  final int? topicId;
  final String? topicTitle;
  final int sectionIndex;
  final String sectionTitle;
  final String currentExplanation;
  final String? currentSubsection;
  final int teachingPosition;
  final int currentSegmentIndex; // Exact speech segment/sentence index
  final String? currentSpokenText; // Text of current sentence
  final String? sourceContent;
  final AppLanguage language;
  final double scrollOffset;
  final DateTime timestamp;
  final String? originalText;
  final int? paragraphIndex;
  final int? lineIndex;
  final String? segmentId;
  final LessonSourceType? sourceType;

  TeachingSnapshot({
    this.subjectId,
    this.topicId,
    this.topicTitle,
    required this.sectionIndex,
    required this.sectionTitle,
    required this.currentExplanation,
    this.currentSubsection,
    this.teachingPosition = 0,
    this.currentSegmentIndex = 0,
    this.currentSpokenText,
    this.sourceContent,
    required this.language,
    this.scrollOffset = 0.0,
    DateTime? timestamp,
    this.originalText,
    this.paragraphIndex,
    this.lineIndex,
    this.segmentId,
    this.sourceType,
  }) : timestamp = timestamp ?? DateTime.now();
}

class TeachingState extends ChangeNotifier {
  final AppRepository repository;
  final AiService aiService;
  final SharedPreferences prefs;
  final TtsService ttsService;
  late final ContentUnderstandingService _contentService;

  // Active Lesson Context
  Subject? _activeSubject;
  Topic? _activeTopic;
  List<LessonSection> _sections = [];
  int _currentSectionIndex = 0;
  int _currentSegmentIndex = 0; // Sentence/speech segment in current section
  int _teachingPosition = 0;
  TeachingMode _currentMode = TeachingMode.learn;
  LessonSourceType _sourceType = LessonSourceType.preSeeded;
  String? _sourceContent;

  // Saved Snapshot Stack for Multiple Doubt Interruptions
  final List<TeachingSnapshot> _doubtSnapshotStack = [];
  int? _interruptedSubjectId;
  int? _interruptedTopicId;
  int _interruptedSectionIndex = 0;
  String? _interruptedSectionTitle;
  bool _isInDoubtInterruption = false;

  // Audio & Classroom Playback
  bool _autoAdvance = false;

  // Doubt Answering State
  String? _activeDoubtQuestion;
  String? _activeDoubtAnswer;
  String? _topicErrorMessage;

  // Settings & Language
  AppLanguage _language = AppLanguage.english;
  AiProviderType _providerType = AiProviderType.localAi;
  String _geminiKey = '';

  // Chat & Generation State
  List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  String _streamingBuffer = '';
  StreamSubscription<String>? _generationSubscription;

  TeachingState({
    required this.repository,
    required this.aiService,
    required this.prefs,
    TtsService? tts,
  }) : ttsService = tts ?? TtsService() {
    _contentService = ContentUnderstandingService(repository: repository);
    _loadSettings();
    ttsService.addListener(_onTtsServiceUpdate);
  }

  void _onTtsServiceUpdate() {
    notifyListeners();
  }

  // Getters
  Subject? get activeSubject => _activeSubject;
  Topic? get activeTopic => _activeTopic;
  List<LessonSection> get sections => _sections;
  int get currentSectionIndex => _currentSectionIndex;
  int get currentSegmentIndex => _currentSegmentIndex;
  int get teachingPosition => _teachingPosition;
  TeachingMode get currentMode => _currentMode;
  LessonSourceType get sourceType => _sourceType;
  String? get sourceContent => _sourceContent;
  bool get isInDoubtInterruption => _isInDoubtInterruption;
  int? get interruptedSubjectId => _interruptedSubjectId;
  int? get interruptedTopicId => _interruptedTopicId;
  int get interruptedSectionIndex => _interruptedSectionIndex;
  String? get interruptedSectionTitle => _interruptedSectionTitle;
  List<TeachingSnapshot> get doubtSnapshotStack => List.unmodifiable(_doubtSnapshotStack);
  bool get isSpeaking => ttsService.isSpeaking;
  bool get isPaused => ttsService.isPaused;
  bool get hasPlaybackError => ttsService.hasPlaybackError;
  String? get ttsErrorMessage => ttsService.lastErrorMessage;
  bool get hasTeluguVoice => ttsService.hasTeluguVoice;
  bool get hasEnglishVoice => ttsService.hasEnglishVoice;
  bool get autoAdvance => _autoAdvance;
  String? get activeDoubtQuestion => _activeDoubtQuestion;
  String? get activeDoubtAnswer => _activeDoubtAnswer;
  String? get topicErrorMessage => _topicErrorMessage;
  AppLanguage get language => _language;
  AiProviderType get providerType => _providerType;
  List<ChatMessage> get messages => _messages;
  bool get isGenerating => _isGenerating;
  String get streamingBuffer => _streamingBuffer;
  bool get isLineByLineMode => _sourceType == LessonSourceType.lineByLine;
  TeachingSegment? get currentLineSegment => currentSection?.segment;
  List<TeachingSegment> get lineSegments => _sections
      .where((s) => s.segment != null)
      .map((s) => s.segment!)
      .toList();

  LessonSection? get currentSection {
    if (_sections.isEmpty || _currentSectionIndex < 0 || _currentSectionIndex >= _sections.length) {
      return null;
    }
    return _sections[_currentSectionIndex];
  }

  bool get hasNextSection => _currentSectionIndex < _sections.length - 1;
  bool get hasPreviousSection => _currentSectionIndex > 0;

  List<String> get currentSectionSegments {
    final script = currentSpokenScript;
    if (script.isEmpty) return [];
    return ContentUnderstandingService.splitIntoSpeechSegments(script);
  }

  void _loadSettings() {
    final savedLang = prefs.getString(AppConstants.prefLanguage);
    if (savedLang != null) {
      _language = AppLanguage.values.firstWhere(
        (l) => l.name == savedLang,
        orElse: () => AppLanguage.english,
      );
    }

    final providerIndex = prefs.getInt(AppConstants.prefAiProvider) ?? 0;
    if (providerIndex >= 0 && providerIndex < AiProviderType.values.length) {
      _providerType = AiProviderType.values[providerIndex];
    }

    _geminiKey = prefs.getString(AppConstants.prefGeminiApiKey) ?? '';
    _autoAdvance = prefs.getBool('classroom_auto_advance') ?? false;

    aiService.configure(
      providerType: _providerType,
      geminiApiKey: _geminiKey,
    );
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    await prefs.setString(AppConstants.prefLanguage, lang.name);
    notifyListeners();
  }

  Future<void> setAiProvider(AiProviderType provider) async {
    _providerType = provider;
    await prefs.setInt(AppConstants.prefAiProvider, provider.index);
    aiService.configure(providerType: provider);
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String key) async {
    _geminiKey = key;
    await prefs.setString(AppConstants.prefGeminiApiKey, key);
    aiService.configure(providerType: _providerType, geminiApiKey: key);
    notifyListeners();
  }

  void setAutoAdvance(bool value) {
    _autoAdvance = value;
    prefs.setBool('classroom_auto_advance', value);
    notifyListeners();
  }

  // ================= MODE A: TOPIC-ONLY TEACHING =================
  Future<bool> startTopicOnlyLesson(String topicTitle) async {
    _topicErrorMessage = null;
    if (topicTitle.trim().isEmpty) {
      _topicErrorMessage = 'Please enter a topic name to start teaching.';
      notifyListeners();
      return false;
    }
    final topic = await _contentService.buildLessonFromTopicOnly(
      topicTitle: topicTitle,
      language: _language,
      aiService: aiService,
    );

    if (topic == null || topic.sections.isEmpty) {
      _topicErrorMessage =
          "I don't have enough reliable local information for this topic.\n\nYou can:\n• paste your study material\n• install a supported local AI model\n• enable the optional cloud AI provider";
      notifyListeners();
      return false;
    }

    _activeSubject = Subject(
      id: topic.subjectId,
      title: topic.subjectId == 1 ? 'Design & Analysis of Algorithms' : 'Computer Science',
      code: 'CS',
      description: 'Classroom Course',
      createdAt: DateTime.now(),
    );
    _activeTopic = topic;
    _sections = topic.sections;
    _currentSectionIndex = 0;
    _currentSegmentIndex = 0;
    _teachingPosition = 0;
    _sourceType = LessonSourceType.topicOnly;
    _sourceContent = null;
    _currentMode = TeachingMode.learn;
    _isInDoubtInterruption = false;
    _doubtSnapshotStack.clear();

    await _saveCurrentProgress();
    notifyListeners();

    // Begin speaking the lesson automatically
    await playCurrentSectionAudio();
    return true;
  }

  // ================= MODE B: USER STUDY MATERIAL (PRIMARY SOURCE) =================
  Future<bool> startUserContentLesson(String? topicTitle, String content) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) return false;

    _topicErrorMessage = null;
    final resolvedTopic = (topicTitle != null && topicTitle.trim().isNotEmpty)
        ? topicTitle.trim()
        : ContentUnderstandingService.inferTopicTitle(cleanContent);

    final topic = _contentService.buildLessonFromUserContent(
      topicTitle: resolvedTopic,
      content: cleanContent,
      language: _language,
    );

    _activeSubject = Subject(
      id: 0,
      title: 'Custom Study Material',
      code: 'USER',
      description: 'Primary Source Material',
      createdAt: DateTime.now(),
    );
    _activeTopic = topic;
    _sections = topic.sections;
    _currentSectionIndex = 0;
    _currentSegmentIndex = 0;
    _teachingPosition = 0;
    _sourceType = LessonSourceType.userContent;
    _sourceContent = cleanContent;
    _currentMode = TeachingMode.learn;
    _isInDoubtInterruption = false;
    _doubtSnapshotStack.clear();

    notifyListeners();

    // Begin speaking the lesson automatically
    await playCurrentSectionAudio();
    return true;
  }

  // ================= MODE C: TEACH MY NOTES LINE-BY-LINE =================
  Future<bool> startLineByLineLesson(String? topicTitle, String content) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) return false;

    _topicErrorMessage = null;
    final resolvedTopic = (topicTitle != null && topicTitle.trim().isNotEmpty)
        ? topicTitle.trim()
        : ContentUnderstandingService.inferTopicTitle(cleanContent);

    final topic = _contentService.buildLineByLineLesson(
      topicTitle: resolvedTopic,
      content: cleanContent,
      language: _language,
    );

    _activeSubject = Subject(
      id: 0,
      title: 'Line-by-Line Study Notes',
      code: 'NOTES',
      description: 'Sequential Student Notes',
      createdAt: DateTime.now(),
    );
    _activeTopic = topic;
    _sections = topic.sections;
    _currentSectionIndex = 0;
    _currentSegmentIndex = 0;
    _teachingPosition = 0;
    _sourceType = LessonSourceType.lineByLine;
    _sourceContent = cleanContent;
    _autoAdvance = true;
    _currentMode = TeachingMode.learn;
    _isInDoubtInterruption = false;
    _doubtSnapshotStack.clear();

    notifyListeners();

    // Begin speaking the first line
    await playCurrentSectionAudio();
    return true;
  }

  // ================= STANDARD LESSON LOADING =================
  Future<void> loadTopicLesson(Topic topic, Subject subject) async {
    _activeSubject = subject;
    _activeTopic = topic;
    _sourceType = LessonSourceType.preSeeded;
    _sourceContent = null;
    _sections = await repository.getSectionsForTopic(topic.id ?? 0);

    // If sections don't have classroom script, enrich them
    _sections = _sections.map((s) {
      if (s.classroomScript != null && s.classroomScript!.isNotEmpty) return s;
      final script = ContentUnderstandingService.generateClassroomScript(
        sectionTitle: s.title,
        explanation: s.explanation,
        example: s.example,
        teluguExplanation: s.teluguExplanation,
        examPoints: s.examPoints,
        language: _language,
        topicTitle: topic.title,
      );
      return s.copyWith(classroomScript: script);
    }).toList();

    // Retrieve saved progress
    final progress = await repository.getProgressForTopic(topic.id ?? 0);
    if (progress != null && progress.currentSectionIndex < _sections.length) {
      _currentSectionIndex = progress.currentSectionIndex;
    } else {
      _currentSectionIndex = 0;
    }

    _currentSegmentIndex = 0;
    _teachingPosition = 0;
    _currentMode = TeachingMode.learn;
    _isInDoubtInterruption = false;
    _doubtSnapshotStack.clear();
    await _loadChatForSession('topic_${topic.id}');
    notifyListeners();
  }

  // ================= CLASSROOM AUDIO CONTROLS =================
  String get currentSpokenScript {
    final section = currentSection;
    if (section == null) return '';

    if (section.classroomScript != null && section.classroomScript!.isNotEmpty) {
      return section.classroomScript!;
    }

    return ContentUnderstandingService.generateClassroomScript(
      sectionTitle: section.title,
      explanation: section.explanation,
      example: section.example,
      teluguExplanation: section.teluguExplanation,
      examPoints: section.examPoints,
      language: _language,
      topicTitle: _activeTopic?.title ?? 'Lesson',
    );
  }

  /// Speaks the current section in sentence-by-sentence segments,
  /// allowing exact resumption upon doubt interruptions.
  Future<void> playCurrentSectionAudio({int startSegment = 0}) async {
    final segments = currentSectionSegments;
    if (segments.isEmpty) return;

    _currentSegmentIndex = (startSegment >= 0 && startSegment < segments.length)
        ? startSegment
        : 0;
    notifyListeners();

    await ttsService.speakSegments(
      segments,
      startSegment: _currentSegmentIndex,
      language: _language,
      onSegmentChanged: (index) {
        _currentSegmentIndex = index;
        _teachingPosition = index;
        notifyListeners();
      },
      onComplete: () {
        notifyListeners();
        if (_autoAdvance && hasNextSection) {
          nextSection();
        }
      },
    );
  }

  Future<void> pauseTeachingAudio() async {
    await ttsService.pause();
    notifyListeners();
  }

  Future<void> resumeTeachingAudio() async {
    await ttsService.resume();
    notifyListeners();
  }

  Future<void> stopTeachingAudio() async {
    await ttsService.stop();
    notifyListeners();
  }

  /// Safely leaves the teaching screen: immediately terminates TTS playback,
  /// cancels speech queue & async callbacks, aborts active generation,
  /// and saves the exact lesson progress.
  Future<void> leaveTeachingScreen() async {
    debugPrint('[TEACHING] TEACHER_DISPOSED / TEACHER_STOPPED: Leaving lesson screen');
    ttsService.cancelSession();
    stopGeneration();
    await _saveCurrentProgress();
    notifyListeners();
  }

  Future<void> replayTeachingAudio() async {
    await ttsService.stop();
    await playCurrentSectionAudio(startSegment: 0);
  }

  Future<bool> openTtsSettings() async {
    return await ttsService.openTtsSettings();
  }

  void resetPlaybackError() {
    ttsService.resetError();
    notifyListeners();
  }

  // ================= NAVIGATION =================
  Future<void> nextSection() async {
    if (hasNextSection) {
      await ttsService.stop();
      _currentSectionIndex++;
      _currentSegmentIndex = 0;
      _teachingPosition = 0;
      await _saveCurrentProgress();
      notifyListeners();
      await playCurrentSectionAudio(startSegment: 0);
    }
  }

  Future<void> previousSection() async {
    if (hasPreviousSection) {
      await ttsService.stop();
      _currentSectionIndex--;
      _currentSegmentIndex = 0;
      _teachingPosition = 0;
      await _saveCurrentProgress();
      notifyListeners();
      await playCurrentSectionAudio(startSegment: 0);
    }
  }

  Future<void> jumpToSection(int index) async {
    if (index >= 0 && index < _sections.length) {
      await ttsService.stop();
      _currentSectionIndex = index;
      _currentSegmentIndex = 0;
      _teachingPosition = 0;
      await _saveCurrentProgress();
      notifyListeners();
      await playCurrentSectionAudio(startSegment: 0);
    }
  }

  Future<void> _saveCurrentProgress() async {
    if (_activeSubject?.id == null || _activeTopic?.id == null || _activeTopic!.id == 0) return;
    await repository.saveProgress(
      subjectId: _activeSubject!.id!,
      topicId: _activeTopic!.id!,
      currentSectionIndex: _currentSectionIndex,
      totalSections: _sections.isNotEmpty ? _sections.length : 1,
      isCompleted: _currentSectionIndex == _sections.length - 1,
    );
  }

  // ================= DOUBT INTERRUPTION SYSTEM =================
  /// Immediately pauses teaching and audio, captures an exact snapshot, and opens Doubt Mode
  void enterClassroomDoubt() {
    pauseTeachingAudio();

    final segments = currentSectionSegments;
    final currentSegmentText = (_currentSegmentIndex >= 0 && _currentSegmentIndex < segments.length)
        ? segments[_currentSegmentIndex]
        : null;

    final snapshot = TeachingSnapshot(
      subjectId: _activeSubject?.id,
      topicId: _activeTopic?.id,
      topicTitle: _activeTopic?.title ?? 'Classroom Lesson',
      sectionIndex: _currentSectionIndex,
      sectionTitle: currentSection?.title ?? 'General Lesson',
      currentExplanation: currentSection?.explanation ?? '',
      currentSubsection: currentSection?.title,
      teachingPosition: _teachingPosition,
      currentSegmentIndex: _currentSegmentIndex,
      currentSpokenText: currentSegmentText,
      sourceContent: _sourceContent,
      language: _language,
      originalText: currentSection?.originalText ?? currentSection?.segment?.originalText,
      paragraphIndex: currentSection?.segment?.paragraphIndex,
      lineIndex: currentSection?.segment?.lineIndex ?? _currentSectionIndex,
      segmentId: currentSection?.segment?.segmentId,
      sourceType: _sourceType,
    );

    _doubtSnapshotStack.add(snapshot);
    _interruptedSubjectId = snapshot.subjectId;
    _interruptedTopicId = snapshot.topicId;
    _interruptedSectionIndex = snapshot.sectionIndex;
    _interruptedSectionTitle = snapshot.sectionTitle;
    _isInDoubtInterruption = true;
    _currentMode = TeachingMode.doubt;

    notifyListeners();
  }

  /// Legacy helper method preserved for backwards compatibility
  void enterDoubtMode({String? initialQuestion}) {
    enterClassroomDoubt();
    if (initialQuestion != null && initialQuestion.trim().isNotEmpty) {
      askQuestion(initialQuestion);
    }
  }

  /// Returns to exact teaching position and resumes teaching audio from the exact segment
  Future<void> continueFromDoubt() async {
    await ttsService.stop(); // Stop any active doubt speech

    int resumeSegment = 0;
    if (_doubtSnapshotStack.isNotEmpty) {
      final snapshot = _doubtSnapshotStack.removeLast();
      _currentSectionIndex = snapshot.sectionIndex;
      _teachingPosition = snapshot.teachingPosition;
      _currentSegmentIndex = snapshot.currentSegmentIndex;
      resumeSegment = snapshot.currentSegmentIndex;
      _language = snapshot.language;
    }

    if (_doubtSnapshotStack.isEmpty) {
      _isInDoubtInterruption = false;
      _activeDoubtQuestion = null;
      _activeDoubtAnswer = null;
    } else {
      final prev = _doubtSnapshotStack.last;
      _interruptedSubjectId = prev.subjectId;
      _interruptedTopicId = prev.topicId;
      _interruptedSectionIndex = prev.sectionIndex;
      _interruptedSectionTitle = prev.sectionTitle;
    }

    _currentMode = TeachingMode.learn;
    notifyListeners();

    // Resume from the exact segment where the teacher was interrupted!
    await playCurrentSectionAudio(startSegment: resumeSegment);
  }

  /// Legacy helper method preserved for backwards compatibility
  Future<void> returnToLesson() async {
    await continueFromDoubt();
  }

  // ================= CLASSROOM DOUBT ANSWERING =================
  Future<void> askClassroomDoubt(String question) async {
    if (question.trim().isEmpty || _isGenerating) return;

    _activeDoubtQuestion = question.trim();
    _activeDoubtAnswer = null;

    final sessionId = _activeTopic != null ? 'topic_${_activeTopic!.id}' : 'classroom';
    final sectionTag = currentSection?.title ?? _interruptedSectionTitle ?? 'Classroom';

    // 1. Add student message
    final userMsg = ChatMessage(
      sessionId: sessionId,
      role: 'user',
      content: question.trim(),
      timestamp: DateTime.now(),
      isDoubt: true,
      contextTag: sectionTag,
    );
    _messages.add(userMsg);
    await repository.insertChatMessage(userMsg);

    _isGenerating = true;
    _streamingBuffer = '';
    notifyListeners();

    try {
      // 2. Perform offline keyword retrieval on document chunks
      final allChunks = await repository.getAllChunks();
      final topChunks = RetrievalScorer.retrieveTopChunks(question, allChunks, topK: 2);
      final chunkTexts = topChunks.map((c) => c.content).toList();

      if (_sourceContent != null && _sourceContent!.isNotEmpty) {
        chunkTexts.insert(0, _sourceContent!);
      }

      // 3. Build exam-teacher system prompt grounded in active section and source
      String? sectionContext;
      if (isLineByLineMode && currentSection != null) {
        final lineNum = (currentSection!.segment?.lineIndex ?? _currentSectionIndex) + 1;
        sectionContext = '[CURRENT LINE BEING TAUGHT - Line $lineNum]:\n'
            'Original text: "${currentSection!.originalText ?? currentSection!.definition}"\n'
            'Teacher explanation: "${currentSection!.explanation}"';
      } else if (currentSection != null) {
        sectionContext = '${currentSection!.title}: ${currentSection!.definition} | ${currentSection!.explanation}';
      }

      final systemPrompt = PromptBuilder.buildSystemPrompt(
        language: _language,
        mode: TeachingMode.doubt,
        subjectTitle: _activeSubject?.title,
        topicTitle: _activeTopic?.title,
        sectionContext: sectionContext,
        retrievedChunks: chunkTexts,
      );

      final fullPrompt = '$systemPrompt\n\n${PromptBuilder.buildUserPrompt(question)}';

      // 4. Stream response from AI service
      final stream = aiService.streamResponse(fullPrompt);
      _generationSubscription = stream.listen(
        (token) {
          _streamingBuffer += token;
          notifyListeners();
        },
        onError: (error) {
          _streamingBuffer += '\n\n*(Error generating answer: $error)*';
          _finalizeAssistantMessage(sessionId, sectionTag);
        },
        onDone: () async {
          _activeDoubtAnswer = _streamingBuffer.trim();
          await _finalizeAssistantMessage(sessionId, sectionTag);

          // Speak the doubt answer aloud using TTS
          if (_activeDoubtAnswer != null && _activeDoubtAnswer!.isNotEmpty) {
            await ttsService.speak(_activeDoubtAnswer!, language: _language);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      _streamingBuffer = 'Sorry, could not process doubt: $e';
      _activeDoubtAnswer = _streamingBuffer;
      await _finalizeAssistantMessage(sessionId, sectionTag);
    }
  }

  // ================= CHAT & QUESTION ANSWERING =================
  Future<void> _loadChatForSession(String sessionId) async {
    _messages = await repository.getChatMessages(sessionId);
    notifyListeners();
  }

  Future<void> clearCurrentChat() async {
    final sessionId = _activeTopic != null ? 'topic_${_activeTopic!.id}' : 'classroom';
    await repository.clearChatHistory(sessionId);
    _messages.clear();
    notifyListeners();
  }

  void stopGeneration() {
    _generationSubscription?.cancel();
    _isGenerating = false;
    _streamingBuffer = '';
    notifyListeners();
  }

  Future<void> askQuestion(String question) async {
    await askClassroomDoubt(question);
  }

  Future<void> _finalizeAssistantMessage(String sessionId, String? sectionTag) async {
    _isGenerating = false;
    final finalContent = _streamingBuffer.trim();

    if (finalContent.isNotEmpty) {
      final assistantMsg = ChatMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: finalContent,
        timestamp: DateTime.now(),
        isDoubt: true,
        contextTag: sectionTag,
      );
      _messages.add(assistantMsg);
      await repository.insertChatMessage(assistantMsg);
    }

    _streamingBuffer = '';
    notifyListeners();
  }

  @override
  void dispose() {
    ttsService.removeListener(_onTtsServiceUpdate);
    _generationSubscription?.cancel();
    super.dispose();
  }
}
