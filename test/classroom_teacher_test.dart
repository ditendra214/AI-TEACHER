import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_teacher/core/constants/app_constants.dart';
import 'package:ai_teacher/ai/ai_service.dart';
import 'package:ai_teacher/data/models/subject_model.dart';
import 'package:ai_teacher/data/models/topic_model.dart';
import 'package:ai_teacher/data/models/chat_message_model.dart';
import 'package:ai_teacher/data/models/quiz_model.dart';
import 'package:ai_teacher/data/models/lesson_progress_model.dart';
import 'package:ai_teacher/data/repositories/app_repository.dart';
import 'package:ai_teacher/data/services/teaching_state.dart';
import 'package:ai_teacher/data/services/tts_service.dart';
import 'package:ai_teacher/data/services/speech_service.dart';
import 'package:ai_teacher/data/services/content_understanding_service.dart';
import 'package:ai_teacher/features/classroom/classroom_screen.dart';
import 'package:ai_teacher/features/classroom/teach_material_screen.dart';

/// Hermetic repository for automated classroom testing
class FakeClassroomRepository extends AppRepository {
  final List<ChatMessage> chatMessages = [];
  final Map<int, LessonProgress> progressMap = {};
  final List<QuizResult> quizResults = [];

  final List<Topic> mockTopics = [
    Topic(
      id: 1,
      subjectId: 1,
      title: '1. Algorithm Definition & Essentials',
      summary: 'Fundamental concept of algorithms.',
      orderIndex: 0,
      sections: [
        LessonSection(
          id: 101,
          topicId: 1,
          title: 'What is an Algorithm?',
          definition: 'An algorithm is a finite, step-by-step sequence of unambiguous instructions.',
          importance: 'Foundational concept in computer engineering exams.',
          explanation: 'It takes inputs, executes deterministic steps, and produces expected outputs.',
          example: 'Finding the maximum element in an array.',
          teluguExplanation: 'Algorithm ante problem solve cheyadaniki step-by-step instructions set.',
          examPoints: '• 2-Mark question: Define algorithm and state its 5 criteria.',
          sectionOrder: 0,
        ),
      ],
    ),
    Topic(
      id: 3,
      subjectId: 1,
      title: '3. Dynamic Programming & 0/1 Knapsack',
      summary: 'Optimal substructure and memoization.',
      orderIndex: 2,
      sections: [
        LessonSection(
          id: 301,
          topicId: 3,
          title: 'Introduction to Dynamic Programming',
          definition: 'Dynamic programming solves complex problems by breaking them down into simpler subproblems and memoizing overlapping results.',
          importance: 'Frequently asked 10-mark problem in university exams.',
          explanation: 'Rather than recomputing identical subproblems, DP stores results in a table.',
          example: 'Fibonacci numbers computation or 0/1 Knapsack problem.',
          teluguExplanation: 'Dynamic programming లో subproblems results ని memoize చేసి re-compute చేయడాన్ని avoid చేస్తాము.',
          examPoints: '• Must show overlapping subproblems and optimal substructure.\n• 10-mark favorite.',
          sectionOrder: 0,
        ),
        LessonSection(
          id: 302,
          topicId: 3,
          title: 'Overlapping Subproblems',
          definition: 'A problem has overlapping subproblems when identical smaller subproblems are computed repeatedly.',
          importance: 'Key requirement for applying memoization.',
          explanation: 'In naive recursive Fibonacci, fib(3) is called multiple times across branches.',
          example: 'Recursion tree of fib(5) shows duplicate nodes.',
          teluguExplanation: 'Overlapping subproblems అంటే ఒకే చిన్న పనిని మళ్ళీ మళ్ళీ repeat చేయడం.',
          examPoints: '• Draw recursion tree diagram for full marks.',
          sectionOrder: 1,
        ),
      ],
    ),
  ];

  @override
  Future<Topic?> findTopicByTitle(String query) async {
    final clean = query.trim().toLowerCase();
    for (final t in mockTopics) {
      if (t.title.toLowerCase().contains(clean) || clean.contains(t.title.toLowerCase())) {
        return t;
      }
    }
    return null;
  }

  @override
  Future<List<LessonSection>> getSectionsForTopic(int topicId) async {
    final topic = mockTopics.firstWhere((t) => t.id == topicId, orElse: () => mockTopics.first);
    return topic.sections;
  }

  @override
  Future<LessonProgress?> getProgressForTopic(int topicId) async {
    return progressMap[topicId];
  }

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
      subjectTitle: 'Design & Analysis of Algorithms',
      topicTitle: 'Topic $topicId',
      currentSectionIndex: currentSectionIndex,
      totalSections: totalSections,
      isCompleted: isCompleted,
      lastStudiedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    return chatMessages.where((m) => m.sessionId == sessionId).toList();
  }

  @override
  Future<int> insertChatMessage(ChatMessage message) async {
    chatMessages.add(message);
    return chatMessages.length;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllChunks() async {
    return [
      {
        'id': 1,
        'document_id': 1,
        'chunk_index': 0,
        'content': 'Dynamic Programming solves optimization problems by storing solutions to overlapping subproblems.',
        'page_number': 1,
      },
      {
        'id': 2,
        'document_id': 1,
        'chunk_index': 1,
        'content': 'Algorithm analysis evaluates execution time and space as input size n grows asymptotically.',
        'page_number': 2,
      },
    ];
  }

  @override
  Future<List<QuizQuestion>> getQuizQuestions({int? topicId}) async {
    return [
      const QuizQuestion(
        id: 1,
        question: 'What are the two conditions needed for Dynamic Programming?',
        options: [
          'Optimal substructure and overlapping subproblems',
          'Sorting and searching',
          'Divide and conquer only',
          'Greedy choice only',
        ],
        correctOptionIndex: 0,
        explanation: 'DP requires optimal substructure and overlapping subproblems.',
        type: 'mcq',
      ),
    ];
  }

  @override
  Future<int> saveQuizResult(QuizResult result) async {
    quizResults.add(result);
    return quizResults.length;
  }

  @override
  Future<List<QuizResult>> getQuizResults() async {
    return quizResults;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeClassroomRepository repository;
  late AiService aiService;
  late SharedPreferences prefs;
  late TtsService mockTts;
  late TeachingState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = FakeClassroomRepository();
    aiService = AiService();
    mockTts = TtsService(mockMode: true);
    state = TeachingState(
      repository: repository,
      aiService: aiService,
      prefs: prefs,
      tts: mockTts,
    );
  });

  group('Classroom AI Teacher Final Functional Fix Test Suite', () {
    // 1. Topic-Only Mode & Automatic Syllabus Creation (No Rejection)
    test('1. Topic-only lesson creation generates structured curriculum for any topic', () async {
      // A: Built-in / matched syllabus
      final found = await state.startTopicOnlyLesson('Dynamic Programming');
      expect(found, isTrue);
      expect(state.activeTopic?.title, contains('Dynamic Programming'));
      expect(state.sections.length, greaterThanOrEqualTo(2));
      expect(state.sourceType, equals(LessonSourceType.topicOnly));

      // B: Any topic generates full fallback structured curriculum (never rejects with no material)
      final quantumTopic = await state.startTopicOnlyLesson('Quantum Computing Architecture');
      expect(quantumTopic, isTrue);
      expect(state.activeTopic?.title, contains('Quantum Computing Architecture'));
      expect(state.sections.length, greaterThanOrEqualTo(3));

      // C: Empty or whitespace topic returns false with validation error
      final emptyTopic = await state.startTopicOnlyLesson('   ');
      expect(emptyTopic, isFalse);
      expect(state.topicErrorMessage, equals('Please enter a topic name to start teaching.'));
    });

    // 2. User Content Lesson Creation with Optional Topic Name
    test('2. User content lesson creation decomposes notes and infers topic if omitted', () async {
      const studyContent = '''
Python is a high-level, general-purpose programming language.
Its design philosophy emphasizes code readability with the use of significant indentation.
For example, print("Hello World") executes immediately without boilerplate class declarations.
Functions and classes allow modular design.
Always watch out for indentation errors and mutable default arguments.
Semester exam tips: State high-level features and write short syntax examples.
      ''';

      // Pass null for topic name -> must infer "Python Programming" or "Python"
      final success = await state.startUserContentLesson(null, studyContent);
      expect(success, isTrue);
      expect(state.sourceType, equals(LessonSourceType.userContent));
      expect(state.activeTopic?.title.toLowerCase(), contains('python'));
      expect(state.sections.length, greaterThanOrEqualTo(5));
      expect(state.sections.first.classroomScript, isNotNull);
    });

    // 3. Topic Inference Helper
    test('3. Topic inference extracts clean titles from headings, prefixes, or content', () {
      expect(ContentUnderstandingService.inferTopicTitle('# Operating Systems\nMemory management...'), equals('Operating Systems'));
      expect(ContentUnderstandingService.inferTopicTitle('Topic: Binary Search\nBinary search is an efficient...'), equals('Binary Search'));
      expect(ContentUnderstandingService.inferTopicTitle('Python is a high-level language...'), contains('Python'));
    });

    // 4. Setup Language Persistence
    test('4. Setup language persistence in local storage', () async {
      await state.setLanguage(AppLanguage.telugu);
      expect(state.language, equals(AppLanguage.telugu));
      expect(prefs.getString(AppConstants.prefLanguage), equals('telugu'));

      await state.setLanguage(AppLanguage.teluguEnglish);
      expect(state.language, equals(AppLanguage.teluguEnglish));
      expect(prefs.getString(AppConstants.prefLanguage), equals('teluguEnglish'));

      await state.setLanguage(AppLanguage.english);
      expect(state.language, equals(AppLanguage.english));
      expect(prefs.getString(AppConstants.prefLanguage), equals('english'));
    });

    // 5. English Teaching Output
    test('5. English teaching output produces natural classroom speech', () {
      final script = ContentUnderstandingService.generateClassroomScript(
        sectionTitle: 'What is Dynamic Programming?',
        explanation: 'Dynamic Programming breaks a complex problem into simpler subproblems.',
        example: 'Fibonacci numbers computation.',
        teluguExplanation: '',
        examPoints: '10-mark question favorite.',
        language: AppLanguage.english,
        topicTitle: 'Dynamic Programming',
      );

      expect(script, contains('Okay class, let us focus on'));
      expect(script, contains('Fibonacci numbers computation'));
      expect(script, contains('Make sure you note this down.'));
    });

    // 6. Telugu Teaching Output with Proper Telugu Script
    test('6. Telugu teaching output produces natural teacher Telugu in proper script', () {
      final script = ContentUnderstandingService.generateClassroomScript(
        sectionTitle: 'Overlapping Subproblems',
        explanation: 'Subproblems are computed repeatedly.',
        example: 'Recursion tree of fib(5).',
        teluguExplanation: 'ఒకే చిన్న పనిని మళ్ళీ మళ్ళీ repeat చేయడం.',
        examPoints: 'Draw recursion tree diagram.',
        language: AppLanguage.telugu,
        topicTitle: 'Dynamic Programming',
      );

      expect(script, contains('సరే students, ఇప్పుడు మనం'));
      expect(script, contains('ఒకే చిన్న పనిని మళ్ళీ మళ్ళీ repeat చేయడం.'));
      expect(script, contains('ముఖ్యమైనది:'));
    });

    // 7. Telugu + English Teaching Output with Bilingual Script
    test('7. Telugu + English bilingual teaching output contains Telugu script and English terms', () {
      final script = ContentUnderstandingService.generateClassroomScript(
        sectionTitle: 'Optimal Substructure',
        explanation: 'Optimal solution contains optimal solutions to subproblems.',
        example: 'Shortest path finding.',
        teluguExplanation: 'Main problem solution లో subproblem solution ఉంటుంది.',
        examPoints: 'Write Bellman equation.',
        language: AppLanguage.teluguEnglish,
        topicTitle: 'Dynamic Programming',
      );

      expect(script, contains('Okay, ippudu manam'));
      expect(script, contains('Main problem solution లో subproblem solution ఉంటుంది.'));
      expect(script, contains('Exam point of view lo idi chala important:'));
    });

    // 8. Granular Speech Segments Generation
    test('8. ContentUnderstandingService splits scripts into sentence speech segments', () {
      const sampleScript = 'Okay class, let us focus on Section 1. This is the first sentence. Now here is an example: fib(5). Good luck!';
      final segments = ContentUnderstandingService.splitIntoSpeechSegments(sampleScript);
      expect(segments.length, greaterThanOrEqualTo(3));
      expect(segments.first, contains('Okay class'));
    });

    // 9. Segment-Based Position Tracking
    test('9. Teaching position tracking maintains section progress and segment indices', () async {
      await state.startTopicOnlyLesson('Dynamic Programming');
      expect(state.currentSectionIndex, equals(0));
      expect(state.currentSegmentIndex, equals(0));
      expect(state.currentSectionSegments.isNotEmpty, isTrue);
    });

    // 10. Doubt Interruption Snapshot with Segment Index
    test('10. Doubt interruption snapshot captures complete lesson state including segment index', () async {
      await state.startTopicOnlyLesson('Dynamic Programming');
      await state.nextSection(); // Section 1 (Overlapping Subproblems)

      state.enterClassroomDoubt();

      expect(state.isInDoubtInterruption, isTrue);
      expect(state.currentMode, equals(TeachingMode.doubt));
      expect(state.doubtSnapshotStack.length, equals(1));

      final snapshot = state.doubtSnapshotStack.last;
      expect(snapshot.sectionIndex, equals(1));
      expect(snapshot.sectionTitle, contains('Overlapping Subproblems'));
      expect(snapshot.currentSegmentIndex, equals(state.currentSegmentIndex));
      expect(snapshot.language, equals(state.language));
    });

    // 11. Return to Exact Teaching Position & Segment Resumption
    test('11. Return to exact teaching position restores position and segment index after doubt', () async {
      await state.startTopicOnlyLesson('Dynamic Programming');
      await state.nextSection(); // Section 1

      state.enterClassroomDoubt();
      expect(state.isInDoubtInterruption, isTrue);

      await state.continueFromDoubt();
      expect(state.isInDoubtInterruption, isFalse);
      expect(state.currentMode, equals(TeachingMode.learn));
      expect(state.currentSectionIndex, equals(1), reason: 'Must restore exact Section 1');
      expect(state.currentSection?.title, contains('Overlapping Subproblems'));
    });

    // 12. Multiple Doubt Interruptions Preserve Stack
    test('12. Multiple doubt interruptions preserve stack across multiple doubts', () async {
      await state.startTopicOnlyLesson('Dynamic Programming');

      // Doubt 1
      state.enterClassroomDoubt();
      expect(state.doubtSnapshotStack.length, equals(1));
      await state.continueFromDoubt();
      expect(state.doubtSnapshotStack.length, equals(0));

      // Move to Section 1
      await state.nextSection();

      // Doubt 2
      state.enterClassroomDoubt();
      expect(state.doubtSnapshotStack.length, equals(1));
      expect(state.doubtSnapshotStack.last.sectionIndex, equals(1));

      // Nested Doubt 3 during discussion
      state.enterClassroomDoubt();
      expect(state.doubtSnapshotStack.length, equals(2));

      await state.continueFromDoubt();
      expect(state.doubtSnapshotStack.length, equals(1));

      await state.continueFromDoubt();
      expect(state.doubtSnapshotStack.length, equals(0));
      expect(state.currentSectionIndex, equals(1));
    });

    // 13. TTS Service Segment Playback Transitions
    test('13. TTS service handles segmented playback and pause/resume gracefully', () async {
      final tts = TtsService(mockMode: true);
      await tts.init();

      int reportedIdx = -1;
      await tts.speakSegments(
        ['Segment one.', 'Segment two.', 'Segment three.'],
        startSegment: 1,
        language: AppLanguage.english,
        onSegmentChanged: (idx) => reportedIdx = idx,
      );

      expect(reportedIdx, equals(1));
      expect(tts.isSpeaking, isTrue);

      await tts.pause();
      expect(tts.isPaused, isTrue);

      await tts.resume();
      expect(tts.isSpeaking, isTrue);

      await tts.stop();
      expect(tts.isStopped, isTrue);
    });

    // 14. Speech Service Offline & Permission Handling
    test('14. SpeechService handles permission errors and offline availability', () async {
      final speech = SpeechService(mockMode: true);
      final ok = await speech.init();
      expect(ok, isTrue);
      expect(speech.hasPermissionError, isFalse);

      bool receivedResult = false;
      await speech.startListening(
        onResult: (text) => receivedResult = true,
        onError: (err, isPermission) {},
      );

      expect(receivedResult, isFalse);
      expect(speech.isListening, isTrue);
      await speech.stopListening();
      expect(speech.isListening, isFalse);
    });

    // 15. No GGUF Model Still Allows Local Teaching
    test('15. No GGUF model installed still allows rich local teaching & doubts', () async {
      await state.startTopicOnlyLesson('Dynamic Programming');
      state.enterClassroomDoubt();

      await state.askClassroomDoubt('What is overlapping?');
      expect(state.messages.isNotEmpty, isTrue);
      expect(state.messages.first.content, equals('What is overlapping?'));
    });

    // 16. Existing Course Topics & Quizzes Functionality
    test('16. Existing course topics, quizzes, and progress remain completely functional', () async {
      final topic = repository.mockTopics.first;
      await state.loadTopicLesson(topic, Subject(title: 'Algorithms', code: 'CS', createdAt: DateTime.now()));
      expect(state.activeTopic?.title, equals(topic.title));
      expect(state.sections.isNotEmpty, isTrue);

      final questions = await repository.getQuizQuestions();
      expect(questions.isNotEmpty, isTrue);
      expect(questions.first.correctOptionIndex, equals(0));

      final progress = LessonProgress(
        subjectId: 1,
        topicId: 3,
        currentSectionIndex: 1,
        totalSections: 2,
        lastStudiedAt: DateTime.now(),
      );
      expect(progress.percentInt, equals(100));
    });

    // 17. UI Widget Test: ClassroomScreen Renders with High Contrast and Controls
    testWidgets('17. ClassroomScreen renders visual cards, audio controls dock, and Ask Doubt button', (tester) async {
      await state.startTopicOnlyLesson('Dynamic Programming');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TeachingState>.value(
            value: state,
            child: const ClassroomScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Dynamic Programming'), findsWidgets);
      expect(find.text('Teacher Explanation'), findsOneWidget);
      expect(find.text('Ask Doubt'), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    // 18. UI Widget Test: TeachMaterialScreen with Optional Topic Name
    testWidgets('18. TeachMaterialScreen renders Study Material first and Optional Topic Name second', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TeachingState>.value(
            value: state,
            child: const TeachMaterialScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Study Material'), findsOneWidget);
      expect(find.text('Optional Topic Name'), findsOneWidget);
      expect(find.text('Start Teaching'), findsOneWidget);
    });
  });
}
