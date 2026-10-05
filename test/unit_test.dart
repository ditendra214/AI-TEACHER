import 'package:flutter_test/flutter_test.dart';
import 'package:ai_teacher/core/constants/app_constants.dart';
import 'package:ai_teacher/core/utils/text_chunker.dart';
import 'package:ai_teacher/core/utils/retrieval_scorer.dart';
import 'package:ai_teacher/ai/prompt_builder.dart';
import 'package:ai_teacher/data/models/lesson_progress_model.dart';
import 'package:ai_teacher/data/models/quiz_model.dart';

void main() {
  group('TextChunker Tests', () {
    test('Cleans control characters and multiple spaces', () {
      const raw = 'Hello \x00 world!\r\n\r\n\nThis is a    test.';
      final cleaned = TextChunker.cleanText(raw);
      expect(cleaned, contains('Hello world!'));
      expect(cleaned, contains('This is a test.'));
      expect(cleaned.contains('\x00'), isFalse);
    });

    test('Splits long text into overlapping chunks', () {
      final words = List.generate(500, (i) => 'word$i').join(' ');
      final chunks = TextChunker.chunkText(words, targetChunkWords: 200, overlapWords: 50);

      expect(chunks.length, greaterThan(1));
      expect(chunks.first.wordCount, equals(200));
      expect(chunks.first.index, equals(0));
    });
  });

  group('RetrievalScorer Tests', () {
    test('Tokenizes text removing punctuation and stop words', () {
      const text = 'The quick brown fox jumps over the lazy dog!';
      final tokens = RetrievalScorer.tokenize(text);

      expect(tokens, contains('quick'));
      expect(tokens, contains('brown'));
      expect(tokens, contains('fox'));
      expect(tokens.contains('the'), isFalse);
      expect(tokens.contains('over'), isFalse);
    });

    test('Scores and retrieves most relevant chunk for query', () {
      final chunks = [
        {
          'id': 1,
          'document_id': 10,
          'chunk_index': 0,
          'content': 'Database Management Systems use SQL and Relational algebra for querying tables.',
          'page_number': 1,
        },
        {
          'id': 2,
          'document_id': 10,
          'chunk_index': 1,
          'content': 'Big O notation represents the asymptotic upper bound of algorithm time complexity.',
          'page_number': 2,
        },
        {
          'id': 3,
          'document_id': 10,
          'chunk_index': 2,
          'content': 'Computer Networks use TCP and UDP protocols for transport layer communication.',
          'page_number': 3,
        },
      ];

      final results = RetrievalScorer.retrieveTopChunks('What is Big O time complexity?', chunks, topK: 1);

      expect(results, isNotEmpty);
      expect(results.first.chunkId, equals(2));
      expect(results.first.content, contains('Big O notation'));
    });
  });

  group('PromptBuilder Tests', () {
    test('Builds English prompt for Learn Mode with 7-step structure', () {
      final prompt = PromptBuilder.buildSystemPrompt(
        language: AppLanguage.english,
        mode: TeachingMode.learn,
        subjectTitle: 'Algorithms',
        topicTitle: 'Time Complexity',
      );

      expect(prompt, contains('TEACHING STYLE'));
      expect(prompt, contains('CURRENT TEACHING MODE: LEARN'));
      expect(prompt, contains('LANGUAGE INSTRUCTION - ENGLISH'));
      expect(prompt, contains('[SUBJECT CONTEXT]: Algorithms'));
    });

    test('Builds Telugu + English prompt for Doubt Mode', () {
      final prompt = PromptBuilder.buildSystemPrompt(
        language: AppLanguage.teluguEnglish,
        mode: TeachingMode.doubt,
        subjectTitle: 'Algorithms',
        topicTitle: 'Recursion',
      );

      expect(prompt, contains('TELUGU + ENGLISH'));
      expect(prompt, contains('CURRENT TEACHING MODE: DOUBT'));
      expect(prompt, contains('DO NOT translate technical keywords'));
    });
  });

  group('Model Calculations Tests', () {
    test('LessonProgress calculates percentage correctly', () {
      final progress = LessonProgress(
        subjectId: 1,
        topicId: 1,
        currentSectionIndex: 2,
        totalSections: 4,
        lastStudiedAt: DateTime.now(),
      );

      expect(progress.percentComplete, equals(0.75));
      expect(progress.percentInt, equals(75));
    });

    test('QuizResult calculates score percentage correctly', () {
      final result = QuizResult(
        topicTitle: 'Algorithms',
        score: 4,
        totalQuestions: 5,
        date: DateTime.now(),
      );

      expect(result.percentage, equals(80.0));
    });
  });
}
