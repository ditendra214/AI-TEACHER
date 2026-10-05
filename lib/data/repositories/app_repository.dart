import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/subject_model.dart';
import '../models/document_model.dart';
import '../models/topic_model.dart';
import '../models/lesson_progress_model.dart';
import '../models/chat_message_model.dart';
import '../models/quiz_model.dart';

class AppRepository {
  Future<Database> get _db async => await DbHelper.database;

  // ================= SUBJECTS =================
  Future<List<Subject>> getAllSubjects() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query('subjects', orderBy: 'id ASC');

    final List<Subject> subjects = [];
    for (final map in maps) {
      final subjectId = map['id'] as int;
      final topicCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM topics WHERE subject_id = ?',
        [subjectId],
      );
      final count = Sqflite.firstIntValue(topicCountResult) ?? 0;
      subjects.add(Subject.fromMap(map, topicCount: count));
    }
    return subjects;
  }

  Future<Subject?> getSubjectById(int id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Subject.fromMap(maps.first);
  }

  Future<int> insertSubject(Subject subject) async {
    final db = await _db;
    return await db.insert('subjects', subject.toMap());
  }

  Future<int> deleteSubject(int id) async {
    final db = await _db;
    return await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  // ================= TOPICS & SECTIONS =================
  Future<List<Topic>> getTopicsForSubject(int subjectId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'topics',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'order_index ASC',
    );

    final List<Topic> topics = [];
    for (final map in maps) {
      final topicId = map['id'] as int;
      final sections = await getSectionsForTopic(topicId);
      topics.add(Topic.fromMap(map, sections: sections));
    }
    return topics;
  }

  Future<Topic?> getTopicWithSections(int topicId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'topics',
      where: 'id = ?',
      whereArgs: [topicId],
    );
    if (maps.isEmpty) return null;
    final sections = await getSectionsForTopic(topicId);
    return Topic.fromMap(maps.first, sections: sections);
  }

  /// Search for a topic by title query (case-insensitive substring or token match)
  Future<Topic?> findTopicByTitle(String query) async {
    final db = await _db;
    final clean = query.trim().toLowerCase();
    final List<Map<String, dynamic>> maps = await db.query('topics');

    // First try exact or substring containment
    for (final map in maps) {
      final title = (map['title'] as String? ?? '').toLowerCase();
      if (title.contains(clean) || clean.contains(title)) {
        final topicId = map['id'] as int;
        final sections = await getSectionsForTopic(topicId);
        return Topic.fromMap(map, sections: sections);
      }
    }

    // Try token overlap
    final queryTokens = clean.split(RegExp(r'\s+')).where((t) => t.length > 2);
    for (final map in maps) {
      final title = (map['title'] as String? ?? '').toLowerCase();
      for (final t in queryTokens) {
        if (title.contains(t)) {
          final topicId = map['id'] as int;
          final sections = await getSectionsForTopic(topicId);
          return Topic.fromMap(map, sections: sections);
        }
      }
    }

    return null;
  }

  Future<List<LessonSection>> getSectionsForTopic(int topicId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'lesson_sections',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'section_order ASC',
    );
    return maps.map((m) => LessonSection.fromMap(m)).toList();
  }

  Future<int> insertTopic(Topic topic) async {
    final db = await _db;
    return await db.insert('topics', topic.toMap());
  }

  Future<int> insertLessonSection(LessonSection section) async {
    final db = await _db;
    return await db.insert('lesson_sections', section.toMap());
  }

  Future<void> markTopicCompleted(int topicId, bool isCompleted) async {
    final db = await _db;
    await db.update(
      'topics',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  // ================= LESSON PROGRESS & RESUME =================
  Future<LessonProgress?> getProgressForTopic(int topicId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT lp.*, s.title as subject_title, t.title as topic_title
      FROM lesson_progress lp
      JOIN subjects s ON lp.subject_id = s.id
      JOIN topics t ON lp.topic_id = t.id
      WHERE lp.topic_id = ?
    ''', [topicId]);

    if (maps.isEmpty) return null;
    final row = maps.first;
    return LessonProgress.fromMap(
      row,
      subjectTitle: row['subject_title'] as String? ?? '',
      topicTitle: row['topic_title'] as String? ?? '',
    );
  }

  Future<LessonProgress?> getMostRecentProgress() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT lp.*, s.title as subject_title, t.title as topic_title
      FROM lesson_progress lp
      JOIN subjects s ON lp.subject_id = s.id
      JOIN topics t ON lp.topic_id = t.id
      ORDER BY lp.last_studied_at DESC
      LIMIT 1
    ''');

    if (maps.isEmpty) return null;
    final row = maps.first;
    return LessonProgress.fromMap(
      row,
      subjectTitle: row['subject_title'] as String? ?? '',
      topicTitle: row['topic_title'] as String? ?? '',
    );
  }

  Future<void> saveProgress({
    required int subjectId,
    required int topicId,
    required int currentSectionIndex,
    required int totalSections,
    bool isCompleted = false,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'lesson_progress',
      {
        'subject_id': subjectId,
        'topic_id': topicId,
        'current_section_index': currentSectionIndex,
        'total_sections': totalSections,
        'is_completed': isCompleted ? 1 : 0,
        'last_studied_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (isCompleted) {
      await markTopicCompleted(topicId, true);
    }
  }

  // ================= DOCUMENTS & CHUNKS =================
  Future<List<DocumentModel>> getAllDocuments() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query('documents', orderBy: 'id DESC');

    final List<DocumentModel> docs = [];
    for (final map in maps) {
      final docId = map['id'] as int;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM document_chunks WHERE document_id = ?',
        [docId],
      );
      final chunkCount = Sqflite.firstIntValue(countResult) ?? 0;
      docs.add(DocumentModel.fromMap(map, chunkCount: chunkCount));
    }
    return docs;
  }

  Future<int> insertDocument(DocumentModel doc) async {
    final db = await _db;
    return await db.insert('documents', doc.toMap());
  }

  Future<int> deleteDocument(int id) async {
    final db = await _db;
    // Delete chunks first
    await db.delete('document_chunks', where: 'document_id = ?', whereArgs: [id]);
    return await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertChunks(List<Map<String, dynamic>> chunkMaps) async {
    final db = await _db;
    final batch = db.batch();
    for (final chunk in chunkMaps) {
      batch.insert('document_chunks', chunk);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getChunksForDocument(int documentId) async {
    final db = await _db;
    return await db.query(
      'document_chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'chunk_index ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllChunks() async {
    final db = await _db;
    return await db.query('document_chunks');
  }

  // ================= CHAT MESSAGES =================
  Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  Future<int> insertChatMessage(ChatMessage message) async {
    final db = await _db;
    return await db.insert('chat_messages', message.toMap());
  }

  Future<void> clearChatHistory(String sessionId) async {
    final db = await _db;
    await db.delete('chat_messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> clearAllChat() async {
    final db = await _db;
    await db.delete('chat_messages');
  }

  // ================= QUIZ =================
  Future<List<QuizQuestion>> getQuizQuestions({int? topicId}) async {
    final db = await _db;
    List<Map<String, dynamic>> maps;
    if (topicId != null) {
      maps = await db.query('quiz_questions', where: 'topic_id = ?', whereArgs: [topicId]);
    } else {
      maps = await db.query('quiz_questions');
    }
    return maps.map((m) => QuizQuestion.fromMap(m)).toList();
  }

  Future<int> insertQuizQuestion(QuizQuestion question) async {
    final db = await _db;
    return await db.insert('quiz_questions', question.toMap());
  }

  Future<int> saveQuizResult(QuizResult result) async {
    final db = await _db;
    return await db.insert('quiz_results', result.toMap());
  }

  Future<List<QuizResult>> getQuizResults() async {
    final db = await _db;
    final maps = await db.query('quiz_results', orderBy: 'id DESC');
    return maps.map((m) => QuizResult.fromMap(m)).toList();
  }

  // ================= STATS & PROGRESS =================
  Future<Map<String, dynamic>> getProgressStatistics() async {
    final db = await _db;

    final totalSubjects = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM subjects'),
        ) ??
        0;

    final totalTopics = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM topics'),
        ) ??
        0;

    final completedTopics = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM topics WHERE is_completed = 1'),
        ) ??
        0;

    final totalQuizzes = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM quiz_results'),
        ) ??
        0;

    final avgScoreResult = await db.rawQuery(
      'SELECT AVG(CAST(score AS FLOAT) / total_questions * 100) as avg_score FROM quiz_results WHERE total_questions > 0',
    );
    final double avgScore = (avgScoreResult.first['avg_score'] as num?)?.toDouble() ?? 0.0;

    final totalDocuments = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM documents'),
        ) ??
        0;

    return {
      'total_subjects': totalSubjects,
      'total_topics': totalTopics,
      'completed_topics': completedTopics,
      'total_quizzes': totalQuizzes,
      'average_quiz_score': avgScore,
      'total_documents': totalDocuments,
    };
  }

  Future<void> clearAllData() async {
    final db = await _db;
    await db.delete('quiz_results');
    await db.delete('chat_messages');
    await db.delete('lesson_progress');
    await db.delete('document_chunks');
    await db.delete('documents');
  }
}
