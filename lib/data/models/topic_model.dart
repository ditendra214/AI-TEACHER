import 'teaching_segment_model.dart';

class Topic {
  final int? id;
  final int subjectId;
  final String title;
  final String summary;
  final int orderIndex;
  final bool isCompleted;
  final List<LessonSection> sections;

  const Topic({
    this.id,
    required this.subjectId,
    required this.title,
    this.summary = '',
    this.orderIndex = 0,
    this.isCompleted = false,
    this.sections = const [],
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'subject_id': subjectId,
      'title': title,
      'summary': summary,
      'order_index': orderIndex,
      'is_completed': isCompleted ? 1 : 0,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Topic.fromMap(Map<String, dynamic> map, {List<LessonSection> sections = const []}) {
    return Topic(
      id: map['id'] as int?,
      subjectId: map['subject_id'] as int? ?? 0,
      title: map['title'] as String? ?? 'Untitled Topic',
      summary: map['summary'] as String? ?? '',
      orderIndex: map['order_index'] as int? ?? 0,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      sections: sections,
    );
  }

  Topic copyWith({
    int? id,
    int? subjectId,
    String? title,
    String? summary,
    int? orderIndex,
    bool? isCompleted,
    List<LessonSection>? sections,
  }) {
    return Topic(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      orderIndex: orderIndex ?? this.orderIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      sections: sections ?? this.sections,
    );
  }
}

class LessonSection {
  final int? id;
  final int topicId;
  final String title;
  final String definition;
  final String importance;
  final String explanation;
  final String example;
  final String teluguExplanation;
  final String examPoints;
  final String checkQuestion;
  final String checkAnswer;
  final int sectionOrder;

  final String? classroomScript;
  final String? visualAid;
  final String? originalText;
  final TeachingSegment? segment;

  const LessonSection({
    this.id,
    required this.topicId,
    required this.title,
    required this.definition,
    this.importance = '',
    required this.explanation,
    this.example = '',
    this.teluguExplanation = '',
    this.examPoints = '',
    this.checkQuestion = '',
    this.checkAnswer = '',
    required this.sectionOrder,
    this.classroomScript,
    this.visualAid,
    this.originalText,
    this.segment,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'topic_id': topicId,
      'title': title,
      'definition': definition,
      'importance': importance,
      'explanation': explanation,
      'example': example,
      'telugu_explanation': teluguExplanation,
      'exam_points': examPoints,
      'check_question': checkQuestion,
      'check_answer': checkAnswer,
      'section_order': sectionOrder,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory LessonSection.fromMap(Map<String, dynamic> map) {
    return LessonSection(
      id: map['id'] as int?,
      topicId: map['topic_id'] as int? ?? 0,
      title: map['title'] as String? ?? 'Untitled Section',
      definition: map['definition'] as String? ?? '',
      importance: map['importance'] as String? ?? '',
      explanation: map['explanation'] as String? ?? '',
      example: map['example'] as String? ?? '',
      teluguExplanation: map['telugu_explanation'] as String? ?? '',
      examPoints: map['exam_points'] as String? ?? '',
      checkQuestion: map['check_question'] as String? ?? '',
      checkAnswer: map['check_answer'] as String? ?? '',
      sectionOrder: map['section_order'] as int? ?? 0,
    );
  }

  LessonSection copyWith({
    int? id,
    int? topicId,
    String? title,
    String? definition,
    String? importance,
    String? explanation,
    String? example,
    String? teluguExplanation,
    String? examPoints,
    String? checkQuestion,
    String? checkAnswer,
    int? sectionOrder,
    String? classroomScript,
    String? visualAid,
    String? originalText,
    TeachingSegment? segment,
  }) {
    return LessonSection(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      definition: definition ?? this.definition,
      importance: importance ?? this.importance,
      explanation: explanation ?? this.explanation,
      example: example ?? this.example,
      teluguExplanation: teluguExplanation ?? this.teluguExplanation,
      examPoints: examPoints ?? this.examPoints,
      checkQuestion: checkQuestion ?? this.checkQuestion,
      checkAnswer: checkAnswer ?? this.checkAnswer,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      classroomScript: classroomScript ?? this.classroomScript,
      visualAid: visualAid ?? this.visualAid,
      originalText: originalText ?? this.originalText,
      segment: segment ?? this.segment,
    );
  }
}
