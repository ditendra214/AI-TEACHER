import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_teacher/core/constants/app_constants.dart';
import 'package:ai_teacher/ai/ai_service.dart';
import 'package:ai_teacher/data/models/topic_model.dart';
import 'package:ai_teacher/data/models/teaching_segment_model.dart';
import 'package:ai_teacher/data/models/lesson_progress_model.dart';
import 'package:ai_teacher/data/services/content_understanding_service.dart';
import 'package:ai_teacher/data/services/teaching_state.dart';
import 'package:ai_teacher/data/services/tts_service.dart';
import 'package:ai_teacher/data/repositories/app_repository.dart';

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
      subjectTitle: 'Line-by-Line Notes',
      topicTitle: 'Test Notes',
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

  const sampleNotes = '''
An API is an Application Programming Interface.
It allows communication between two software applications.
Client sends a request to the server.
Server processes the request and returns a response.
Common formats include JSON and XML.
''';

  final expectedLines = [
    'An API is an Application Programming Interface.',
    'It allows communication between two software applications.',
    'Client sends a request to the server.',
    'Server processes the request and returns a response.',
    'Common formats include JSON and XML.',
  ];

  late SharedPreferences prefs;
  late _TestRepository repository;
  late AiService aiService;
  late TtsService ttsService;
  late TeachingState state;
  late ContentUnderstandingService contentService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _TestRepository();
    contentService = ContentUnderstandingService(repository: repository);
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

  group('A. Line-by-Line Content Understanding & Strict Sequential Order', () {
    test('1. Preserves exact line-by-line order (Line 1 -> 2 -> 3 -> 4 -> 5) without retrieval reordering', () {
      final topic = contentService.buildLineByLineLesson(
        topicTitle: 'API Overview',
        content: sampleNotes,
        language: AppLanguage.teluguEnglish,
      );

      expect(topic.sections.length, equals(5));

      for (int i = 0; i < expectedLines.length; i++) {
        final sec = topic.sections[i];
        expect(sec.originalText, equals(expectedLines[i]),
            reason: 'Section $i must preserve exact original line text');
        expect(sec.segment, isNotNull);
        expect(sec.segment!.lineIndex, equals(i));
        expect(sec.segment!.sectionIndex, equals(i));
        expect(sec.title.startsWith('Line ${i + 1}'), isTrue);
      }
    });

    test('2. Preserves both original text and rich teacher explanation', () {
      final topic = contentService.buildLineByLineLesson(
        topicTitle: 'API Basics',
        content: sampleNotes,
        language: AppLanguage.teluguEnglish,
      );

      final line1 = topic.sections[0];
      expect(line1.originalText, equals('An API is an Application Programming Interface.'));
      expect(line1.explanation, isNotEmpty);
      expect(line1.classroomScript, isNotNull);
      expect(line1.classroomScript, isNotEmpty);
      // Explanations should not simply be raw dumps of the input line
      expect(line1.explanation.length, greaterThan(line1.originalText!.length));
    });

    test('3. Classroom Tanglish explanation is conversational and clear', () {
      final topic = contentService.buildLineByLineLesson(
        topicTitle: 'API',
        content: sampleNotes,
        language: AppLanguage.teluguEnglish,
      );

      // Line 1 contains acronym API
      final line1Script = topic.sections[0].classroomScript ?? topic.sections[0].explanation;
      expect(
        line1Script.contains('API') || line1Script.contains('Application Programming Interface'),
        isTrue,
      );

      // Line 3 contains client request
      final line3Script = topic.sections[2].classroomScript ?? topic.sections[2].explanation;
      expect(line3Script.toLowerCase().contains('client') || line3Script.toLowerCase().contains('request'), isTrue);

      // Line 4 contains server response
      final line4Script = topic.sections[3].classroomScript ?? topic.sections[3].explanation;
      expect(line4Script.toLowerCase().contains('server') || line4Script.toLowerCase().contains('response'), isTrue);
    });

    test('4. TeachingSegment model serializes and deserializes accurately', () {
      final segment = TeachingSegment(
        segmentId: 'sec_0_p_0_l_0',
        originalText: 'An API is an Application Programming Interface.',
        teacherExplanation: 'API ante Application Programming Interface.',
        speechText: 'API ante Application Programming Interface.',
        sectionIndex: 0,
        paragraphIndex: 0,
        lineIndex: 0,
      );

      final map = segment.toMap();
      final fromMap = TeachingSegment.fromMap(map);

      expect(fromMap.segmentId, equals(segment.segmentId));
      expect(fromMap.originalText, equals(segment.originalText));
      expect(fromMap.teacherExplanation, equals(segment.teacherExplanation));
      expect(fromMap.speechText, equals(segment.speechText));
      expect(fromMap.sectionIndex, equals(segment.sectionIndex));
      expect(fromMap.paragraphIndex, equals(segment.paragraphIndex));
      expect(fromMap.lineIndex, equals(segment.lineIndex));
    });
  });

  group('B. TeachingState Line-by-Line Flow & Doubt Interruption', () {
    test('1. startLineByLineLesson configures state, segments, and autoAdvance', () async {
      await state.startLineByLineLesson('API Notes', sampleNotes);

      expect(state.isLineByLineMode, isTrue);
      expect(state.sourceType, equals(LessonSourceType.lineByLine));
      expect(state.sections.length, equals(5));
      expect(state.currentSectionIndex, equals(0));
      expect(state.autoAdvance, isTrue);
      expect(state.currentLineSegment, isNotNull);
      expect(state.currentLineSegment!.lineIndex, equals(0));
      expect(state.lineSegments.length, equals(5));
    });

    test('2. Sequential navigation advances smoothly through lines', () async {
      await state.startLineByLineLesson('API Notes', sampleNotes);

      expect(state.currentSectionIndex, equals(0));
      expect(state.currentSection?.originalText, equals(expectedLines[0]));

      await state.nextSection();
      expect(state.currentSectionIndex, equals(1));
      expect(state.currentSection?.originalText, equals(expectedLines[1]));

      await state.nextSection();
      expect(state.currentSectionIndex, equals(2));
      expect(state.currentSection?.originalText, equals(expectedLines[2]));

      await state.previousSection();
      expect(state.currentSectionIndex, equals(1));
      expect(state.currentSection?.originalText, equals(expectedLines[1]));

      await state.jumpToSection(4);
      expect(state.currentSectionIndex, equals(4));
      expect(state.currentSection?.originalText, equals(expectedLines[4]));
    });

    test('3. Doubt interruption at Line 3 captures exact line snapshot and continueFromDoubt resumes Line 3', () async {
      await state.startLineByLineLesson('API Notes', sampleNotes);

      // Jump to Line 3 (Client sends a request to the server)
      await state.jumpToSection(2);
      expect(state.currentSectionIndex, equals(2));
      expect(state.currentSection?.originalText, equals(expectedLines[2]));

      // Student interrupts with Doubt
      state.enterClassroomDoubt();

      expect(state.isInDoubtInterruption, isTrue);
      expect(state.currentMode, equals(TeachingMode.doubt));
      expect(state.doubtSnapshotStack.isNotEmpty, isTrue);

      final snapshot = state.doubtSnapshotStack.last;
      expect(snapshot.sectionIndex, equals(2));
      expect(snapshot.lineIndex, equals(2));
      expect(snapshot.originalText, equals(expectedLines[2]));
      expect(snapshot.sourceType, equals(LessonSourceType.lineByLine));

      // Student taps [CONTINUE LESSON]
      await state.continueFromDoubt();

      expect(state.isInDoubtInterruption, isFalse);
      expect(state.currentMode, equals(TeachingMode.learn));
      // Must resume exactly at Line 3, NOT Line 1 and NOT Line 4
      expect(state.currentSectionIndex, equals(2));
      expect(state.currentSection?.originalText, equals(expectedLines[2]));
    });

    test('4. Immediate audio stoppage on leaving lesson screen', () async {
      await state.startLineByLineLesson('API Notes', sampleNotes);
      await state.playCurrentSectionAudio();

      expect(ttsService.isSpeaking, isTrue);

      // Student presses Back button
      await state.leaveTeachingScreen();

      expect(ttsService.isStopped, isTrue);
      expect(ttsService.isSpeaking, isFalse);
    });
  });
}
