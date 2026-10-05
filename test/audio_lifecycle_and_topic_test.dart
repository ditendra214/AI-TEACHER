import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_teacher/core/constants/app_constants.dart';
import 'package:ai_teacher/ai/ai_service.dart';
import 'package:ai_teacher/data/models/topic_model.dart';
import 'package:ai_teacher/data/models/lesson_progress_model.dart';
import 'package:ai_teacher/data/services/content_understanding_service.dart';
import 'package:ai_teacher/data/services/teaching_state.dart';
import 'package:ai_teacher/data/services/tts_service.dart';
import 'package:ai_teacher/data/repositories/app_repository.dart';
import 'package:ai_teacher/ai/fallback_teacher_provider.dart';

class _TestRepository extends AppRepository {
  final Map<int, LessonProgress> progressMap = {};

  @override
  Future<void> saveProgress({
    required int subjectId,
    required int topicId,
    required int currentSectionIndex,
    required int totalSections,
    bool isCompleted = false,
  }) async {
    progressMap[topicId] = LessonProgress(
      id: topicId,
      subjectId: subjectId,
      topicId: topicId,
      subjectTitle: 'Test Subject',
      topicTitle: 'Topic $topicId',
      currentSectionIndex: currentSectionIndex,
      totalSections: totalSections,
      isCompleted: isCompleted,
      lastStudiedAt: DateTime.now(),
    );
  }

  @override
  Future<LessonProgress?> getProgressForTopic(int topicId) async {
    return progressMap[topicId];
  }

  @override
  Future<Topic?> findTopicByTitle(String query) async {
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllChunks() async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _TestRepository repository;
  late AiService aiService;
  late TtsService ttsService;
  late TeachingState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _TestRepository();
    aiService = AiService();
    ttsService = TtsService(mockMode: true);
    await ttsService.init();

    state = TeachingState(
      repository: repository,
      aiService: aiService,
      prefs: prefs,
      tts: ttsService,
    );
  });

  group('A. Audio Lifecycle & Background Speech Prevention', () {
    test('1. Calling leaveTeachingScreen() cancels audio session, stops TTS, and keeps progress', () async {
      await state.startTopicOnlyLesson('Python');
      expect(state.sections.length, equals(14));

      // Simulate playing audio
      await state.playCurrentSectionAudio();
      expect(ttsService.isSpeaking, isTrue);

      // Student presses Back / navigates to Home
      state.leaveTeachingScreen();

      // Audio must be strictly stopped and session invalidated
      expect(ttsService.isStopped, isTrue);
      expect(ttsService.isSpeaking, isFalse);

      // Lesson progress must be preserved
      expect(state.currentSectionIndex, equals(0));
      expect(state.activeTopic?.title, equals('Python'));
    });

    test('2. TTS cancellation increments session ID and aborts in-flight segment playback', () async {
      final initialSessionId = ttsService.sessionId;
      ttsService.cancelSession();
      expect(ttsService.sessionId, greaterThan(initialSessionId));
      expect(ttsService.isStopped, isTrue);
    });

    test('3. Speech rate defaults to 0.48 and pitch to 1.0 for enhanced voice clarity', () {
      expect(ttsService.speechRate, equals(0.48));
      expect(ttsService.speechPitch, equals(1.0));

      ttsService.setSpeechRate(0.52);
      expect(ttsService.speechRate, equals(0.52));

      ttsService.setPitch(1.1);
      expect(ttsService.speechPitch, equals(1.1));
    });
  });

  group('B. Topic-Only Mode Instant Structured Curriculum', () {
    test('4. Topic-only Python generates 14-section comprehensive syllabus', () async {
      final success = await state.startTopicOnlyLesson('Python');
      expect(success, isTrue);
      expect(state.sections.length, equals(14));
      expect(state.sections[0].title, contains('What is Python'));
      expect(state.sections[1].title, contains('Why Python'));
      expect(state.sections[13].title, contains('Summary'));
    });

    test('5. Topic-only API generates 9-section REST & API architecture syllabus', () async {
      final success = await state.startTopicOnlyLesson('API');
      expect(success, isTrue);
      expect(state.sections.length, equals(9));
      expect(state.sections[0].title, contains('What is an API'));
      expect(state.sections[1].title, contains('Why Do We Need APIs'));
      expect(state.sections[8].title, contains('Summary'));
    });

    test('6. Topic-only generic/unlisted topic generates multi-section structured curriculum', () async {
      final success = await state.startTopicOnlyLesson('Compiler Design and Lexical Analysis');
      expect(success, isTrue);
      expect(state.sections.length, greaterThanOrEqualTo(4));
      expect(state.sections.first.title, contains('Foundational Concept'));
      expect(state.topicErrorMessage, isNull);
    });
  });

  group('C. Voice Clarity, Speech Chunking & Code Conversion', () {
    test('7. toSpeechFriendlyText transforms code snippets and math symbols to spoken words', () {
      const codeInput = 'Here is the function:\n```\ndef add(x, y):\n  return x + y\n```\nNow O(n^2) complexity.';
      final spoken = TtsService.toSpeechFriendlyText(codeInput);

      expect(spoken, isNot(contains('def add')));
      expect(spoken, contains('In the code:'));
      expect(spoken, contains('Order of n squared'));
    });

    test('8. splitIntoSpeechSegments divides long text into short natural spoken sentences', () {
      const longLecture = 'API stands for Application Programming Interface. It connects two applications. Think of a restaurant waiter taking orders. When you order food, the waiter goes to the kitchen.';
      final segments = ContentUnderstandingService.splitIntoSpeechSegments(longLecture);

      expect(segments.length, equals(4));
      expect(segments[0], contains('API stands for'));
      expect(segments[2], contains('restaurant waiter'));
    });
  });

  group('D. Natural Classroom Telugu + English (Tanglish) Delivery', () {
    test('9. Telugu + English generator uses conversational classroom teacher style', () {
      final script = ContentUnderstandingService.generateClassroomScript(
        sectionTitle: 'What is an API?',
        explanation: 'An API connects the frontend to backend servers.',
        example: 'Restaurant waiter carrying orders.',
        teluguExplanation: 'Browser page ki server ki madhyalo service path.',
        examPoints: 'Define REST and state HTTP verbs.',
        language: AppLanguage.teluguEnglish,
        topicTitle: 'API',
      );

      // Must be natural conversational classroom language with technical terms in English
      expect(script, contains('API'));
      expect(script, contains('Okay, ippudu manam'));
      expect(script, contains('Browser page ki server ki madhyalo service path'));
      expect(script, contains('Exam point of view lo idi chala important'));
    });

    test('10. FallbackTeacherProvider provides rich Tanglish explanations for common subjects', () async {
      final provider = FallbackTeacherProvider();

      final apiResponse = await provider.generate(prompt: 'Explain what is an API and REST architecture');
      expect(apiResponse, contains('Application Programming Interface'));
      expect(apiResponse, contains('Restaurant Waiter'));
      expect(apiResponse, contains('Telugu + English'));

      final pythonResponse = await provider.generate(prompt: 'Tell me about Python data types and GIL');
      expect(pythonResponse, contains('Python Programming'));
      expect(pythonResponse, contains('List Comprehension'));
      expect(pythonResponse, contains('Telugu + English'));
    });
  });

  group('E. Doubt Interruption & Exact Sentence Resumption', () {
    test('11. Doubt interruption preserves exact section and unspoken segment index', () async {
      await state.startTopicOnlyLesson('API');
      await state.nextSection(); // Section 1 (REST Architecture)

      // Simulate teacher playing segment 1 of section 1
      state.ttsService.speakSegments(
        ['First sentence.', 'Second sentence.', 'Third sentence.'],
        startSegment: 1,
        language: AppLanguage.teluguEnglish,
      );

      // Student interrupts with a doubt
      state.enterClassroomDoubt();

      expect(state.isInDoubtInterruption, isTrue);
      expect(state.doubtSnapshotStack.length, equals(1));

      final snapshot = state.doubtSnapshotStack.last;
      expect(snapshot.sectionIndex, equals(1));
      expect(snapshot.sectionTitle, contains('Why Do We Need APIs'));

      // Resuming from doubt
      await state.continueFromDoubt();
      expect(state.isInDoubtInterruption, isFalse);
      expect(state.currentSectionIndex, equals(1));
      expect(state.currentSection?.title, contains('Why Do We Need APIs'));
    });
  });
}
