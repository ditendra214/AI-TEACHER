import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_teacher/core/constants/app_constants.dart';
import 'package:ai_teacher/ai/ai_service.dart';
import 'package:ai_teacher/data/models/topic_model.dart';
import 'package:ai_teacher/data/repositories/app_repository.dart';
import 'package:ai_teacher/data/services/teaching_state.dart';
import 'package:ai_teacher/data/services/tts_service.dart';
import 'package:ai_teacher/data/services/speech_service.dart';
import 'package:ai_teacher/data/services/content_understanding_service.dart';
import 'package:ai_teacher/data/models/chat_message_model.dart';

class MockAppRepository extends AppRepository {
  @override
  Future<Topic?> findTopicByTitle(String query) async {
    if (query.toLowerCase().contains('python')) {
      return null; // Will trigger curated or user content
    }
    return null;
  }

  @override
  Future<List<LessonSection>> getSectionsForTopic(int topicId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getAllChunks() async => [];

  @override
  Future<void> saveProgress({
    required int subjectId,
    required int topicId,
    required int currentSectionIndex,
    required int totalSections,
    bool isCompleted = false,
  }) async {}

  @override
  Future<List<ChatMessage>> getChatMessages(String sessionId) async => [];

  @override
  Future<int> insertChatMessage(ChatMessage message) async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MockAppRepository repository;
  late AiService aiService;
  late TtsService ttsService;
  late TeachingState teachingState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = MockAppRepository();
    aiService = AiService();
    ttsService = TtsService(mockMode: true); // Mock mode for headless testing
    teachingState = TeachingState(
      repository: repository,
      aiService: aiService,
      prefs: prefs,
      tts: ttsService,
    );
  });

  group('Part 4 & 9 & 10: Material Understanding & Optional Topic', () {
    test('Automatically infers topic when topic title is omitted', () {
      const content = 'Python is a high-level programming language. It is widely used in data science and web development.';
      final detected = ContentUnderstandingService.inferTopicTitle(content);
      expect(detected, contains('Python'));
    });

    test('Uses explicit topic when provided by student', () {
      const explicitTopic = 'Object Oriented Python';
      const content = 'Encapsulation wraps data and methods into a single class unit.';
      final topic = ContentUnderstandingService(repository: repository).buildLessonFromUserContent(
        topicTitle: explicitTopic,
        content: content,
        language: AppLanguage.teluguEnglish,
      );
      expect(topic.title, equals(explicitTopic));
    });

    test('Generates structured 10-step pedagogical sections from study notes', () {
      const content = '''
Python is an interpreted, high-level programming language.
It uses dynamic typing and automatic memory management.
For example, def greet(name): print(name) defines a reusable function.
Important for semester exam: differentiate List and Tuple.
''';

      final topic = ContentUnderstandingService(repository: repository).buildLessonFromUserContent(
        topicTitle: null,
        content: content,
        language: AppLanguage.teluguEnglish,
      );

      expect(topic.sections.length, equals(10));
      expect(topic.sections[0].title, contains('Introduction'));
      expect(topic.sections[1].title, contains('Core Concepts'));
      expect(topic.sections[2].title, contains('Why It Is Needed'));
      expect(topic.sections[4].title, contains('Practical Example'));
      expect(topic.sections[8].title, contains('Semester Exam'));
      expect(topic.sections[9].title, contains('Quick Revision'));
    });
  });

  group('Part 7 & 12: Telugu + English Bilingual Teaching', () {
    test('Generates natural Telugu + English classroom script with Telugu characters and English technical terms', () {
      final script = ContentUnderstandingService.generateClassroomScript(
        sectionTitle: 'Functions in Python',
        explanation: 'A function receives parameters and returns calculated results.',
        example: 'def add(a, b): return a + b',
        teluguExplanation: 'Function అంటే repeated tasks ని ఒకే unit లో group చేయడం.',
        examPoints: 'Explain default vs keyword arguments.',
        language: AppLanguage.teluguEnglish,
        topicTitle: 'Python Functions',
      );

      expect(script, contains('Okay, ippudu manam'));
      expect(script, contains('Function అంటే'));
      expect(script, contains('def add(a, b): return a + b'));
      expect(script, contains('Exam point of view lo idi chala important'));
    });

    test('Generates pure English script when English is chosen', () {
      final script = ContentUnderstandingService.generateClassroomScript(
        sectionTitle: 'Binary Search Algorithm',
        explanation: 'Divide and conquer strategy reducing search space by half.',
        example: 'Mid element comparison.',
        teluguExplanation: '',
        examPoints: 'Time complexity is O(log n).',
        language: AppLanguage.english,
        topicTitle: 'Binary Search',
      );

      expect(script, contains('Okay class'));
      expect(script, contains('Binary Search Algorithm'));
      expect(script, contains('Time complexity is O(log n).'));
    });
  });

  group('Part 13: Topic-Only Teaching', () {
    test('Generates structured syllabus for Python when no material is pasted', () async {
      final success = await teachingState.startTopicOnlyLesson('Python');
      expect(success, isTrue);
      expect(teachingState.activeTopic, isNotNull);
      expect(teachingState.activeTopic!.title, contains('Python'));
      expect(teachingState.sections.isNotEmpty, isTrue);
    });
  });

  group('Part 15, 16, 28, 31: Doubt Interruption & Exact Lesson Continuation', () {
    test('Exact continuation restores section index and segment position without restarting', () async {
      const content = 'Python is dynamic. It is versatile. It has automatic garbage collection.';
      await teachingState.startUserContentLesson('Python Basics', content);

      // Advance to section 2 and segment 1
      await teachingState.jumpToSection(2);
      expect(teachingState.currentSectionIndex, equals(2));

      // Student interrupts with a doubt
      teachingState.enterClassroomDoubt();
      expect(teachingState.isInDoubtInterruption, isTrue);
      expect(teachingState.doubtSnapshotStack.length, equals(1));

      // Continue lesson
      await teachingState.continueFromDoubt();
      expect(teachingState.isInDoubtInterruption, isFalse);
      expect(teachingState.currentSectionIndex, equals(2)); // Exact section preserved!
    });

    test('Multiple consecutive doubts preserve interruption stack', () async {
      const content = 'Operating systems manage CPU, memory, and devices efficiently.';
      await teachingState.startUserContentLesson('Operating Systems', content);

      // Interrupt 1
      teachingState.enterClassroomDoubt();
      expect(teachingState.doubtSnapshotStack.length, equals(1));

      // Interrupt 2 (nested doubt while reviewing)
      teachingState.enterClassroomDoubt();
      expect(teachingState.doubtSnapshotStack.length, equals(2));

      // Return 1
      await teachingState.continueFromDoubt();
      expect(teachingState.doubtSnapshotStack.length, equals(1));

      // Return 2
      await teachingState.continueFromDoubt();
      expect(teachingState.doubtSnapshotStack.isEmpty, isTrue);
    });
  });

  group('Part 2, 3, 10: TTS Service State Machine', () {
    test('TTS Service starts in idle/stopped state', () {
      final tts = TtsService(mockMode: true);
      expect(tts.isStopped, isTrue);
      expect(tts.isSpeaking, isFalse);
      expect(tts.hasPlaybackError, isFalse);
    });

    test('Splits lesson scripts into sentence segments for granular resumption', () {
      const script = 'Hello class. Today we study Python. It is very simple! Do you understand?';
      final segments = ContentUnderstandingService.splitIntoSpeechSegments(script);
      expect(segments.length, equals(4));
      expect(segments[0], equals('Hello class.'));
      expect(segments[1], equals('Today we study Python.'));
      expect(segments[2], equals('It is very simple!'));
      expect(segments[3], equals('Do you understand?'));
    });
  });

  group('Part 7, 18, 19: Speech Service States & Diagnostics', () {
    test('SpeechService initializes in idle state', () {
      final speech = SpeechService(mockMode: true);
      expect(speech.state, equals(SpeechServiceState.idle));
      expect(speech.isListening, isFalse);
    });

    test('SpeechService listening transitions state correctly', () async {
      final speech = SpeechService(mockMode: true);
      await speech.startListening(
        onResult: (_) {},
        onError: (_, _) {},
      );
      expect(speech.isListening, isTrue);
      await speech.stopListening();
      expect(speech.isListening, isFalse);
    });
  });
}
