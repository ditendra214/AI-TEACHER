class QuizQuestion {
  final int? id;
  final int? topicId;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String type; // 'mcq', 'true_false', 'short_answer'

  const QuizQuestion({
    this.id,
    this.topicId,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    this.type = 'mcq',
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'topic_id': topicId,
      'question': question,
      'options': options.join('|||'),
      'correct_index': correctOptionIndex,
      'explanation': explanation,
      'type': type,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'] as String? ?? '';
    final options = rawOptions.isNotEmpty ? rawOptions.split('|||') : <String>[];
    return QuizQuestion(
      id: map['id'] as int?,
      topicId: map['topic_id'] as int?,
      question: map['question'] as String? ?? '',
      options: options,
      correctOptionIndex: map['correct_index'] as int? ?? 0,
      explanation: map['explanation'] as String? ?? '',
      type: map['type'] as String? ?? 'mcq',
    );
  }
}

class QuizResult {
  final int? id;
  final String topicTitle;
  final int score;
  final int totalQuestions;
  final DateTime date;

  const QuizResult({
    this.id,
    required this.topicTitle,
    required this.score,
    required this.totalQuestions,
    required this.date,
  });

  double get percentage => totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'topic_title': topicTitle,
      'score': score,
      'total_questions': totalQuestions,
      'date': date.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory QuizResult.fromMap(Map<String, dynamic> map) {
    return QuizResult(
      id: map['id'] as int?,
      topicTitle: map['topic_title'] as String? ?? 'General Quiz',
      score: map['score'] as int? ?? 0,
      totalQuestions: map['total_questions'] as int? ?? 0,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
